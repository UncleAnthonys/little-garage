#!/usr/bin/env bash
# Generates the ios/, android/ and web/ folders with `flutter create` if they
# are missing, then applies Little Garage's settings. Safe to run repeatedly:
# flutter create never overwrites existing files, and the patch is idempotent.
set -euo pipefail

ORG="${ORG:-com.littlefortstudios}"

if [ ! -d ios ] || [ ! -d android ] || [ ! -d web ]; then
  echo "Generating platform folders (org: $ORG)…"
  flutter create . --org "$ORG" --project-name little_garage --platforms ios,android,web --no-pub
else
  echo "Platform folders already present."
fi

python3 scripts/patch_platforms.py
