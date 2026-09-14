#!/bin/bash
# Install smalltalk-dev-plugin for OpenCode (user scope + topic-template).
# Topic-template gets skills/commands only — no MCP — so AgenticBrowser's
# default MCP servers are not registered twice on ACP sessions.
#
# Custom AGENTS.md/CLAUDE.md (and any other file under seed/topic-template/)
# are overlaid last, so editing seed/topic-template/ is enough to customize
# the template without touching this script.
set -euo pipefail

PLUGIN="${1:-/opt/smalltalk-dev-plugin}"
TEMPLATE="${2:-/opt/agentic-browser-seed/topic-template}"
REPO_SEED_TEMPLATE="${3:-/opt/repo-seed/topic-template}"

"${PLUGIN}/extra/setup-opencode.sh" -y --user

mkdir -p "${TEMPLATE}"
"${PLUGIN}/extra/setup-opencode.sh" -y "${TEMPLATE}"
rm -f "${TEMPLATE}/opencode.json" "${TEMPLATE}/opencode.json.bak"

if [ -d "${REPO_SEED_TEMPLATE}" ]; then
  cp -a "${REPO_SEED_TEMPLATE}/." "${TEMPLATE}/"
fi
