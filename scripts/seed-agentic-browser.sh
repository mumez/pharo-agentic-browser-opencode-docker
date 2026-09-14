#!/bin/bash
# Copy image-baked topic-template into PHARO_HOME when a host bind-mount
# hid the image copy (empty ./agentic-browser directory).
set -euo pipefail

SEED="${AGENTIC_BROWSER_SEED_DIR:-/opt/agentic-browser-seed}"
DEST="${PHARO_HOME:-/root/smalltalk-interop}/agentic-browser"
MARKER="${DEST}/topic-template/AGENTS.md"

mkdir -p "${DEST}"

if [ -e "${MARKER}" ]; then
  exit 0
fi

if [ ! -d "${SEED}/topic-template" ]; then
  echo "seed-agentic-browser: no seed at ${SEED}/topic-template, skipping"
  exit 0
fi

echo "seed-agentic-browser: seeding ${DEST}/topic-template"
mkdir -p "${DEST}/topic-template"
cp -a "${SEED}/topic-template/." "${DEST}/topic-template/"
