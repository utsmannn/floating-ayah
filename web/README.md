# Floating Ayah website

React/Vite landing page with a code-built terminal and transparent Quran overlay.
The download button links to the latest release of `utsmannn/floating-ayah`.

## Development

```sh
bun install
bunx vite --port 3456 --strictPort
```

## Production build

```sh
bunx tsc --noEmit
bunx vite build
```

Vite writes the static site to `dist/`, including the demo MP3 from `public/audio/`
and the CLI installer from `public/install.sh`.

## CLI installer

Public URL: https://floating-ayah.kiatkoding.com/install.sh.

```sh
curl -fsSL https://floating-ayah.kiatkoding.com/install.sh | bash
```

The installer verifies the latest release ZIP and app signature, installs without
sudo, removes quarantine only from the verified bundle, and launches the app.
See the root README for the security notice and inspect-before-running option.

On macOS, test installation and rollback with isolated local release fixtures:

```sh
# From the repository root; does not launch or quit the real app
python3 scripts/test-installer.py
```

## Deployment

Host: Katrina. Directory: `~/floating-ayah`.
Public URL: https://floating-ayah.kiatkoding.com.

From the repository root:

```sh
rsync -az --delete web/dist/ katrina:~/floating-ayah/dist/
rsync -az web/compose.yaml web/nginx.conf katrina:~/floating-ayah/
ssh katrina 'cd ~/floating-ayah && docker compose up -d'
```

Nginx serves the production assets on `127.0.0.1:3457`. The `ovh-katrina`
Cloudflare Tunnel routes the public hostname to that origin. The container
restarts automatically; no Vite development server is exposed publicly.
