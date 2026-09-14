#!/bin/bash
# Copy image-baked seed content (topic-template, ab-settings.json) into
# PHARO_HOME when a host bind-mount hid the image copy (empty
# ./agentic-browser directory), without overwriting files the user already
# customized there.
set -euo pipefail

SEED="${AGENTIC_BROWSER_SEED_DIR:-/opt/agentic-browser-seed}"
DEST="${PHARO_HOME:-/root/smalltalk-interop}/agentic-browser"

mkdir -p "${DEST}"

if [ ! -e "${DEST}/topic-template/AGENTS.md" ] && [ -d "${SEED}/topic-template" ]; then
  echo "seed-agentic-browser: seeding ${DEST}/topic-template"
  mkdir -p "${DEST}/topic-template"
  cp -a "${SEED}/topic-template/." "${DEST}/topic-template/"
fi

if [ ! -e "${DEST}/ab-settings.json" ] && [ -f "${SEED}/ab-settings.json" ]; then
  echo "seed-agentic-browser: seeding ${DEST}/ab-settings.json"
  cp "${SEED}/ab-settings.json" "${DEST}/ab-settings.json"
fi
