"""Download every episode of a Quran Central reciter feed for local, personal processing.

Usage: python download.py <rss-url> <work-dir>
Writes <work-dir>/raw/<n>.mp3 and <work-dir>/episodes.json. Existing complete files are kept.
"""
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# The feed host rejects generic clients; it serves podcast apps.
HEADERS = {"User-Agent": "Podcasts/1.0 (Macintosh; macOS)"}
ITUNES = "{http://www.itunes.com/dtds/podcast-1.0.dtd}"


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=120) as response:
        return response.read()


def main(feed: str, work: Path) -> None:
    raw = work / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    root = ET.fromstring(fetch(feed))
    episodes = []
    for index, item in enumerate(root.findall("./channel/item")):
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue
        episodes.append({
            "id": f"{index:03d}",
            "title": (item.findtext("title") or "").strip(),
            "url": enclosure.get("url"),
            "length": int(enclosure.get("length") or 0),
            "duration": item.findtext(f"{ITUNES}duration"),
        })
    (work / "episodes.json").write_text(json.dumps(episodes, ensure_ascii=False, indent=1))

    def download(episode: dict) -> str:
        target = raw / f"{episode['id']}.mp3"
        if target.exists() and (episode["length"] <= 0 or target.stat().st_size == episode["length"]):
            return f"kept {target.name}"
        partial = target.with_suffix(".part")
        partial.write_bytes(fetch(episode["url"]))
        partial.rename(target)
        return f"saved {target.name} {episode['title']}"

    with ThreadPoolExecutor(max_workers=6) as pool:
        for line in pool.map(download, episodes):
            print(line, flush=True)
    print(f"done: {len(episodes)} episodes")


if __name__ == "__main__":
    main(sys.argv[1], Path(sys.argv[2]))
