#!/bin/bash
set -euo pipefail

IMAGE="${IMAGE:-pharo-agentic-browser-opencode-docker}"

IMAGE="$IMAGE" exec "$(dirname "$0")/run.sh"
