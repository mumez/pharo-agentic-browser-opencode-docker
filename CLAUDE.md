# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Dockerfile that packages Pharo + [AgenticBrowser](https://github.com/mumez/pharo-agentic-browser) (Web UI) + [OpenCode](https://opencode.ai/) + [smalltalk-dev-plugin](https://github.com/mumez/smalltalk-dev-plugin) into one container. There is no application source code here — this repo *is* the build/deploy configuration (Dockerfile, compose.yaml, shell scripts, one Pharo startup script). Changes here are almost always to the image build, entrypoint scripts, or compose/env wiring, not to Smalltalk or JS application logic.

Architecture at runtime:

```
Host browser  →  AgenticBrowser Web UI :8080  →  Pharo
Host noVNC    →  Spec2 UI :6901               →  Pharo
docker exec   →  OpenCode TUI
Pharo         →  opencode acp (stdio)         →  smalltalk-dev-plugin
plugin / MCP  →  SisServer :8086              →  Pharo
```

Pharo starts `opencode acp` as a *child process* over ACP (Agent Client Protocol) per AgenticBrowser topic — this is a container-side Smalltalk AI coding environment, not a host-AI sandbox (that's the separate `smalltalk-interop-docker` project).

## Common commands

```bash
# Pull-based compose (preferred; compose.yaml defaults `image:` to the GHCR tag, no build)
cp .env.example .env      # fill in ANTHROPIC_API_KEY etc.
docker compose up -d

# Build-based compose: layer compose.build.yaml on top to add `build:` and
# switch to the local image tag
docker compose -f compose.yaml -f compose.build.yaml up -d --build

# Build and run via build_run.sh (builds the local image, then delegates to run.sh)
./build_run.sh

# run.sh itself does not build — plain `docker run`, defaults IMAGE to the GHCR
# image, mounts ./agentic-browser too. Works standalone against a pulled image,
# or set IMAGE=<local-tag> to run something you already built.
./run.sh

# If BuildKit fails with "driver not connecting" (Docker Desktop):
DOCKER_BUILDKIT=0 docker build -t pharo-agentic-browser-opencode-docker .
docker compose -f compose.yaml -f compose.build.yaml up -d --no-build

# Exec into the running container
docker exec -it pharo-ab-opencode01 bash -lc 'cd /root/smalltalk-interop/agentic-browser && opencode'
docker exec -it pharo-ab-opencode01 opencode run "Smalltalk version"
```

There is no lint/test suite in this repo; "verification" means rebuilding the image and confirming the container boots and the three ports respond (8080 Web UI, 6901 noVNC, 8086 Interop Server).

## Build structure (Dockerfile)

Multi-stage build:
1. **`webui` stage** (`node:22-bookworm-slim`): clones `pharo-agentic-browser-web-ui` (branch pinned by `WEBUI_REF`, default `develop`) and runs `npm ci && npm run build`. Only the built `assets/agentic-browser` dir is copied into the final image.
2. **Final stage** (`FROM mumez/pharo-vnc-supervisor`): installs `uv`, OpenCode CLI, clones `smalltalk-dev-plugin` (branch pinned by `PLUGIN_REF`), copies the checked-in `seed/` dir to `/opt/repo-seed`, runs `scripts/prepare-topic-template.sh` to seed the OpenCode topic template with plugin skills/commands and then overlay `seed/topic-template/` on top (deliberately **no MCP config** in the template — see below), bakes `seed/ab-settings.json` in as the default AgenticBrowser settings, pre-warms the two Smalltalk MCP server `uvx` caches, then does a headless Pharo build (`setup.sh`, `save-pharo.sh metacello install ...`) to load `PharoSmalltalkInteropServer` and `AgenticBrowser` (group `all`) into the saved image.

## Customizing the topic template and AgenticBrowser settings

`seed/topic-template/` (currently `AGENTS.md`, `CLAUDE.md`) and `seed/ab-settings.json` are the source of truth — edit them directly, no script changes needed:
- `scripts/prepare-topic-template.sh` runs `setup-opencode.sh` to generate skills/commands, then copies `seed/topic-template/` on top, so anything placed there always wins.
- `seed/ab-settings.json` is copied verbatim into the image as the default `agentic-browser/ab-settings.json` (no MCP-merging logic — it already ships with `useDefaultMcpServers: false` and `OpenCode` first in `codingAgents`, see below).
- At runtime, `scripts/seed-agentic-browser.sh` re-seeds `topic-template/` and `ab-settings.json` from the image into `agentic-browser/` individually, only when each is missing — so a host bind-mount that already has its own customized file is never overwritten.

Key ARGs for pinning upstream versions: `WEBUI_REPO`/`WEBUI_REF`, `INTEROP_REPOS_URL`, `AGENTIC_BROWSER_REPOS_URL`, `PLUGIN_REPO`/`PLUGIN_REF`.

Entrypoint chain: `ab-entrypoint.sh` (symlinks `opencode` if needed, runs `seed-agentic-browser.sh`, then `exec`s the base image's `docker-entrypoint.sh` → `supervisord`) → supervisord starts Pharo, which runs `config/startup.st` (`SisServer current start. AgenticBrowser startWebUI.`).

## Why the topic-template has no MCP config

`smalltalk-dev-plugin`'s `setup-opencode.sh` is run twice in `scripts/prepare-topic-template.sh`: once `--user` (full config, including MCP, so `docker exec ... opencode` can talk to Pharo), once against the topic-template (skills/commands only, `opencode.json` stripped). This is intentional: AgenticBrowser already registers its own default MCP servers (`smalltalk-interop`, `smalltalk-validator`, via `SIS_PORT=8086`) for ACP sessions it spawns. If the template also shipped `opencode.json` with MCP, ACP topics would see each server registered twice. This is why `seed/ab-settings.json` ships with `useDefaultMcpServers: false` — no MCP-merging logic is needed; if you ever see a doubled MCP server in an ACP session, check that setting in `agentic-browser/ab-settings.json` (or AgenticBrowser Settings in the VNC UI) rather than adding merge logic here.

## Volumes and working directories

| Host path | Container path | Notes |
| --- | --- | --- |
| `./agentic-browser` | `/root/smalltalk-interop/agentic-browser` | Topic cwds (`<title>-<uuid>/`), `topic-template`, `ab-topics.fuel`, `ab-settings.json`. Gitignored except `.gitkeep`; `seed-agentic-browser.sh` re-seeds `topic-template` and `ab-settings.json` individually from `seed/` (baked into the image) if this bind-mount hides/empties them. |
| `./screenshots` | `/root/screenshots` | Interop + AgenticBrowser screenshots. |
| `./repos` | `/root/repos` | Only mounted by `run.sh`, not by `compose.yaml`. |

AgenticBrowser's Web UI can only point topics at working directories **under** `agentic-browser/` inside the container — not arbitrary paths. For a project cloned elsewhere, the working directory must be set once via Spec2 (noVNC) or the Playground, not through the Web UI.

## Secrets

Never bake provider API keys into the image or into `opencode.json`. Keys flow only via `.env` (gitignored) → compose interpolation or `run.sh`'s auto-load → container environment → OpenCode reads them directly (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`). `OPENCODE_SERVER_PASSWORD` is required before ever exposing port `4096` (`opencode web`) or the Web UI (`:8080`, which has no auth and is LAN/localhost-only by design).
