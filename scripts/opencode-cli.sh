#!/bin/bash
set -euo pipefail

cd "${PHARO_HOME:-/root/smalltalk-interop}/agentic-browser"
exec opencode "$@"
