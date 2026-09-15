#!/bin/bash
set -euo pipefail

exec opencode web --hostname 0.0.0.0 --port 4096
