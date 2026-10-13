#!/bin/sh
# Rebuilds the local Ziyaad Patel reciter. See README.md in this folder.
set -eu
cd "$(dirname "$0")/../.."
WORK=work/ziyaad-patel
DEST="$HOME/Library/Application Support/FloatingAyah/Audio/Ziyaad_Patel"
if [ ! -x work/.venv/bin/python ]; then
    uv venv -q --python 3.12 work/.venv
    VIRTUAL_ENV="$PWD/work/.venv" uv pip install -q mlx-whisper ctc-forced-aligner rapidfuzz
fi
PY=work/.venv/bin/python
$PY scripts/local-reciter/download.py https://rss.qurancentral.com/ziyaad-patel.rss "$WORK"
$PY scripts/local-reciter/transcribe.py "$WORK"
$PY scripts/local-reciter/locate.py "$WORK"
$PY scripts/local-reciter/align.py "$WORK"
$PY scripts/local-reciter/export.py "$WORK" "$DEST"
