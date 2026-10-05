#!/usr/bin/env python3
"""Exercise the installer with local release fixtures and an isolated HOME.

Run on macOS: python3 scripts/test-installer.py
Requires the existing v0.1.2 ZIP in dist/. Never launches or quits a real app.
"""
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INSTALLER = ROOT / "web/public/install.sh"
ZIP_NAME = "Floating-Ayah-0.1.2-macos-arm64.zip"
SHA_NAME = ZIP_NAME[:-4] + ".sha256"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="floating-ayah-installer-test-")
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fixtures = self.root / "fixtures"
        self.fixtures.mkdir()
        self.zip = ROOT / "dist" / ZIP_NAME
        if not self.zip.is_file():
            self.skipTest("Build the v0.1.2 ZIP fixture first")
        (self.fixtures / SHA_NAME).write_text(hashlib.sha256(self.zip.read_bytes()).hexdigest() + "  " + ZIP_NAME + "\n")
        self.release = {"tag_name": "v0.1.2", "assets": [
            {"name": name, "browser_download_url": "https://github.com/utsmannn/floating-ayah/releases/download/v0.1.2/" + name}
            for name in [ZIP_NAME, SHA_NAME]
        ]}
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ":" + os.environ["PATH"])
        self.app = self.home / "Applications/Floating Ayah.app"
        self.mock("pgrep", "exit 1\n")
        self.mock("open", 'printf "%s\\n" "$1" > "$HOME/launch-path"\n')
        self.mock("curl", '''while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
case "$url" in
    */releases/latest) cp "''' + str(self.fixtures / "release.json") + '''" "$output" ;;
    *.zip) cp "''' + str(self.zip) + '''" "$output" ;;
    *.sha256) cp "''' + str(self.fixtures / SHA_NAME) + '''" "$output" ;;
    *) exit 22 ;;
esac
''')

    def tearDown(self):
        self.temp.cleanup()

    def mock(self, name, body):
        file = self.bin / name
        file.write_text("#!/bin/bash\nset -eu\n" + body)
        file.chmod(0o755)

    def install(self):
        (self.fixtures / "release.json").write_text(json.dumps(self.release))
        result = subprocess.run(["/bin/bash", str(INSTALLER)], env=self.env, capture_output=True, text=True)
        self.assertFalse(list((self.home / "Applications").glob(".floating-ayah-install.*")))
        return result

    def old_app(self):
        contents = self.app / "Contents"
        contents.mkdir(parents=True)
        (contents / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "com.codeutsman.floating-ayah"}))
        (self.app / "old-marker").write_text("keep me")
        audio = self.home / "Library/Application Support/FloatingAyah/Audio/test.mp3"
        audio.parent.mkdir(parents=True)
        audio.write_bytes(b"offline audio")
        return audio

    def test_fresh_install(self):
        # Attach quarantine before removing it, so the scoped removal is tested.
        self.mock("xattr", '''/usr/bin/xattr -w com.apple.quarantine "0081;00000000;InstallerTest;" "$3"
exec /usr/bin/xattr "$@"
''')
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "launch-path").read_text().strip(), str(self.app))
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(self.app)], check=True)
        attrs = subprocess.check_output(["xattr", str(self.app)], text=True)
        self.assertNotIn("com.apple.quarantine", attrs)

    def test_update_preserves_offline_audio(self):
        audio = self.old_app()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.app / "old-marker").exists())
        self.assertEqual(audio.read_bytes(), b"offline audio")

    def test_checksum_failure_keeps_previous_app(self):
        self.old_app()
        (self.fixtures / SHA_NAME).write_text("0" * 64 + "  " + ZIP_NAME + "\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Checksum verification failed", result.stderr)
        self.assertTrue((self.app / "old-marker").exists())
        self.assertFalse((self.home / "launch-path").exists())

    def test_missing_manifest(self):
        self.release["assets"] = self.release["assets"][:1]
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing its SHA-256 manifest", result.stderr)
        self.assertFalse(self.app.exists())

    def test_signature_failure(self):
        self.mock("codesign", "exit 1\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signature verification failed", result.stderr)
        self.assertFalse(self.app.exists())

    def test_launch_failure_rolls_back(self):
        audio = self.old_app()
        self.mock("open", "exit 1\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.app / "old-marker").exists())
        self.assertEqual(audio.read_bytes(), b"offline audio")

    def test_destination_symlink_is_rejected(self):
        self.app.parent.mkdir()
        target = self.root / "unrelated"
        target.mkdir()
        self.app.symlink_to(target, target_is_directory=True)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Destination is a symlink", result.stderr)
        self.assertTrue(self.app.is_symlink())


if __name__ == "__main__":
    unittest.main(verbosity=2)
