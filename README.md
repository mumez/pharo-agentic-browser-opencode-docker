# pharo-agentic-browser-opencode-docker

Pharo + [AgenticBrowser](https://github.com/mumez/pharo-agentic-browser) (Web UI) + [OpenCode](https://opencode.ai/) + [smalltalk-dev-plugin](https://github.com/mumez/smalltalk-dev-plugin) in one container.

This is a **container-side** Smalltalk AI coding environment: Pharo starts `opencode acp` as a child process over ACP. It is not a host-AI sandbox (that remains [smalltalk-interop-docker](https://github.com/mumez/smalltalk-interop-docker)).

```
Host browser  →  AgenticBrowser Web UI :8080  →  Pharo
Host noVNC    →  Spec2 UI :6901               →  Pharo
docker exec   →  OpenCode TUI
Pharo         →  opencode acp (stdio)         →  smalltalk-dev-plugin
plugin / MCP  →  SisServer :8086              →  Pharo
```

## Quick start

```bash
cp .env.example .env
# Put provider keys in .env (ANTHROPIC_API_KEY, OPENAI_API_KEY, …)

docker compose up -d --build
```

Then open:

- **AgenticBrowser Web UI (primary):** http://localhost:8080/assets/agentic-browser/
- **Pharo noVNC (secondary):** http://localhost:6901/?password=vncpassword
- **Interop Server:** http://localhost:8086

Give the image several minutes on first boot (Pharo GUI + Web UI). WSL2 Docker memory should be comfortable (4 GiB+).

## API keys

Do **not** put secrets in `opencode.json` and mount that file.

1. Copy `.env.example` to `.env` (gitignored). Compose interpolates it into container env.
2. OpenCode reads `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / etc. from the environment.
3. Optional, non-secret config only: mount `~/.config/opencode/opencode.json` and use `{env:ANTHROPIC_API_KEY}` references if you need extra settings.
4. Optional auth store from a host `opencode auth login`: `~/.local/share/opencode/auth.json` → `/root/.local/share/opencode/auth.json`.

Never bake keys into the image. Do not publish port 4096 without `OPENCODE_SERVER_PASSWORD`.

## How to operate AgenticBrowser

**Web UI is the main UI.** Create a topic, pick OpenCode, chat.

Web UI can pick Auto / existing / new working directories **under** `<PHARO_HOME>/agentic-browser`. It cannot point at an arbitrary path outside that tree. For a project cloned outside `agentic-browser/`, set the working directory once from Spec2 (noVNC) or the Playground.

VNC is still useful for Settings, target packages, System Browser drag-and-drop, `[ ]` screenshots, and the debugger.

The Web UI has **no auth** (LAN / localhost). Do not expose `:8080` to the internet.

## OpenCode CLI

The main agent path is **not** `opencode web`. AgenticBrowser spawns `opencode acp` per topic on stdio. `opencode web` is a different server and does not share those ACP sessions.

```bash
# TUI in a topic working directory
docker exec -it sis-pharo01 bash -lc 'cd /root/smalltalk-interop/agentic-browser && ls && opencode'

# One-shot
docker exec -it sis-pharo01 opencode run "Smalltalk version"
```

Optional standalone OpenCode web (Interop MCP, not AgenticBrowser):

```bash
docker exec -it sis-pharo01 bash -lc 'opencode web --hostname 0.0.0.0 --port 4096'
```

Set `OPENCODE_SERVER_PASSWORD` and uncomment `4096:4096` in `compose.yaml` first. `opencode attach` only works with `web`/`serve`, not ACP.

## Tonel / working directories

OpenCode and Pharo share the container filesystem. No extra mount is required between them.

| Path                                      | Role                                                                                                                                        |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `/root/smalltalk-interop/agentic-browser` | Topic cwd (`<title>-<uuid>/`), `topic-template`, `ab-topics.fuel`, `ab-settings.json`, source repos. Bind-mounted from `./agentic-browser`. |
| `/root/screenshots`                       | Interop + AgenticBrowser screenshots.                                                                                                       |

The entrypoint copies image `topic-template` into the bind-mount if it is missing or empty, so a fresh `./agentic-browser` does not hide the baked template.

MCP for ACP topics comes from AgenticBrowser defaults (`smalltalk-interop` + `smalltalk-validator`, `SIS_PORT=8086`). The topic-template ships plugin **skills/commands** only (no `opencode.json` MCP) to avoid double registration. User-scope OpenCode config still has MCP so `docker exec opencode` can talk to Pharo. If an ACP session shows the same MCP server twice, turn off **Use default MCP servers** in AgenticBrowser Settings (VNC).

## Environment variables

| Variable                                      | Description                                     | Default             |
| --------------------------------------------- | ----------------------------------------------- | ------------------- |
| `PHARO_SIS_PORT`                              | Interop Server port                             | `8086`              |
| `PHARO_SIS_SCREENSHOT_DIR`                    | Screenshot directory                            | `/root/screenshots` |
| `PHARO_RIPPLE_PORT`                           | AgenticBrowser Web UI / Ripple port             | `8080`              |
| `PHARO_RIPPLE_BIND_ADDRESS`                   | Ripple bind address                             | `0.0.0.0`           |
| `ANTHROPIC_API_KEY` (and other provider keys) | Passed through to OpenCode                      | (empty)             |
| `OPENCODE_SERVER_PASSWORD`                    | Required if you run `opencode web` on `0.0.0.0` | (empty)             |

VNC settings: [ubuntu-vnc-supervisor](https://github.com/mumez/ubuntu-vnc-supervisor). Pharo image settings: [pharo-vnc-supervisor](https://github.com/mumez/pharo-vnc-supervisor).

## Volumes

| Path                                      | Description                                                                                                                                                                        |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/root/smalltalk-interop`                 | Pharo home (image, config, assets). Not a named volume, so image rebuilds take effect. Bind the whole tree only if you need to persist `.image` (heavy; not recommended at first). |
| `/root/smalltalk-interop/agentic-browser` | Topics + template (compose bind-mounts `./agentic-browser`)                                                                                                                        |
| `/root/screenshots`                       | Screenshots                                                                                                                                                                        |

## Build notes

The image:

- loads Interop Server, then AgenticBrowser group `all`
- copies Web UI assets from [pharo-agentic-browser-web-ui](https://github.com/mumez/pharo-agentic-browser-web-ui)
- installs OpenCode, `uv`/`uvx`, git
- runs `setup-opencode.sh --user` and seeds `topic-template`
- pre-caches the Smalltalk MCP servers via `uvx`

If `docker compose build` fails with `driver not connecting` (Docker Desktop / BuildKit), use the legacy builder:

```bash
DOCKER_BUILDKIT=0 docker build -t pharo-agentic-browser-opencode-docker-sis-pharo .
docker compose up -d --no-build
```

Startup order: SisServer, then `AgenticBrowser startWebUI`. OpenCode itself is not a daemon; ACP sessions spawn it.
