#!/bin/bash
set -euo pipefail

if [ -x /root/.opencode/bin/opencode ] && [ ! -e /usr/local/bin/opencode ]; then
  ln -s /root/.opencode/bin/opencode /usr/local/bin/opencode
fi

/usr/local/bin/seed-agentic-browser.sh

exec /usr/local/bin/docker-entrypoint.sh "$@"
