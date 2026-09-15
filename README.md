# pharo-agentic-browser-opencode-docker

An all-in-one development container for AI-assisted Smalltalk development.

As long as Docker is installed, you can start developing right away. The container packages:

- **Pharo** ([AgenticBrowser](https://github.com/mumez/pharo-agentic-browser) + [SmalltalkInteropServer](https://github.com/mumez/PharoSmalltalkInteropServer))
- **OpenCode** ([smalltalk-dev-plugin](https://github.com/mumez/smalltalk-dev-plugin))

The only thing you need to bring is your coding agent's credentials (e.g. an Anthropic API key).

## Setup

### Option A: Pull the pre-built docker image from GHCR

> Note: the pre-built image is for AMD64. If you are using Apple Silicon (Mac ARM64), please follow Option B.

Please edit `.env` first and execute `run.sh`, which automatically load `.env`:

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY (and/or other provider keys) in .env
./run.sh
```

or with Docker Compose:

```bash
docker compose up -d
```

Or, without cloning this repo at all, pull and run it directly:

```bash
mkdir -p agentic-browser screenshots opencode-data
docker pull ghcr.io/mumez/pharo-agentic-browser-opencode-docker:latest
docker run --name pharo-ab-opencode01 -d \
    -p 6901:6901 -p 8080:8080 -p 8086:8086 \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -v "$PWD/agentic-browser:/root/smalltalk-interop/agentic-browser" \
    -v "$PWD/screenshots:/root/screenshots" \
    -v "$PWD/opencode-data:/root/.local/share/opencode" \
    ghcr.io/mumez/pharo-agentic-browser-opencode-docker:latest
```

Add other provider keys (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`) or `-u "$(id -u):$(id -g)"` (to keep created files host-owned) as needed — see the env vars documented in `.env.example` if you clone the repo for reference.

### Option B: Build locally

You can also build the image yourself with `build_run.sh` (builds, then delegates to `run.sh`, which auto-loads `.env`).
Good for modifying the Dockerfile, seed files, or plugin/webui refs:

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY (and/or other provider keys) in .env
./build_run.sh
```

or with Docker Compose, layer `compose.build.yaml` on top of the base `compose.yaml` to add the `build:` step and switch to the local image tag:

```bash
docker compose -f compose.yaml -f compose.build.yaml up -d --build
```

Give it a few minutes on first boot (Pharo GUI + Web UI need to come up).

`run.sh` always runs the container as the invoking host user, so files it creates under `./agentic-browser` and `./screenshots` are owned by you, not root. With Docker Compose this is opt-in: set `HOST_UID`/`HOST_GID` in `.env` (via `id -u` / `id -g`) — left unset, it runs as root as before.

Once you've built the image, you can use `./run_local.sh` to start the container without rebuilding.

## Host-side directories

| Path | What it's for |
| --- | --- |
| `./agentic-browser` | Where your source repositories live. AgenticBrowser topics work inside this tree, and it's where you clone/place the project(s) you want to develop. |
| `./screenshots` | Where screenshots taken from Pharo/AgenticBrowser are saved. |
| `./opencode-data` | OpenCode's own session database (`opencode.db`). Bind-mounted so ACP sessions survive a container restart/recreate — see [Session persistence](#session-persistence) below. |

The first time you start the container, a `topic-template` directory is created under `./agentic-browser` if it doesn't already exist. It holds the configuration that lets OpenCode use `smalltalk-dev-plugin` (skills/commands) inside each topic.

## Usage

### Basic

Open the **AgenticBrowser Web UI** in your host browser:

- http://localhost:8080/assets/agentic-browser/

Create a topic, pick OpenCode as the agent, and start chatting. This covers most day-to-day development.

### Advanced

- **VNC into the Pharo screen** to use AgenticBrowser's native UI, which supports operations the Web UI doesn't expose (Settings, target packages, System Browser drag-and-drop, the debugger, etc.):
  - http://localhost:6901/?password=vncpassword
- **`opencode-cli`** opens the OpenCode TUI directly in the container, in the `agentic-browser` working directory. It's baked into the image, so it works whether you built locally or pulled from GHCR — no repo clone needed:
  ```bash
  docker exec -it pharo-ab-opencode01 opencode-cli
  ```
- **`opencode-web`** runs OpenCode's own Web UI (`opencode web`) instead of the TUI — a separate server from AgenticBrowser's ACP sessions, useful for standalone OpenCode work against the Interop MCP:
  ```bash
  docker exec -it pharo-ab-opencode01 opencode-web
  ```
  Requires `OPENCODE_SERVER_PASSWORD` to be set and port `4096` published (uncomment it in `compose.yaml`, or add `-p 4096:4096` to the `docker run` above) before exposing it.

  Replace `pharo-ab-opencode01` with your container's name if you're not running against the default.

## Session persistence

AgenticBrowser's topic/session bookkeeping (`ab-topics.fuel`) lives under `./agentic-browser`.
OpenCode's sessions are saved under `./opencode-data`. As long as you keep these files, sessions survive container recreation. 

## Security notes

- Never put API keys in `opencode.json` or bake them into the image. Keys only flow through `.env` (gitignored) → container environment → OpenCode reads them directly.
- The AgenticBrowser Web UI (`:8080`) has **no authentication**. It's meant for LAN/localhost use only — do not expose it to the internet.
- Don't publish OpenCode's own web server (`:4096`) without setting `OPENCODE_SERVER_PASSWORD` first.

## Customizing OpenCode (`opencode.json`)

To change the default model, add MCP servers, or add/configure providers for topics started via AgenticBrowser, you can customize `opencode.json`. Common changes:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {},
  "model": "anthropic/claude-sonnet-5",
  "small_model": "anthropic/claude-haiku-4-5"
}
```

- **Default model**: set `model` / `small_model` (`provider/model-id`).
- **Add a provider**: add an entry under `provider` (e.g. custom base URL, extra models). Never put API keys here — see [Security notes](#security-notes); keys still flow only through `.env`.
- **Add MCP servers**: add entries under `mcp`.

There are a few ways to apply it, from most to least permanent:

1. **Baked into the image**: place the file at `seed/topic-template/opencode.json` (create it if it doesn't exist) and rebuild (`docker compose up -d --build`). Files under `seed/topic-template/` are copied on top of the generated template last, so this always wins. This is the way to go if you want the customization to survive rebuilds and be the default for new checkouts.
2. **Directly on the host, no rebuild**: if `./agentic-browser/topic-template/` already exists (created on first boot), just edit `./agentic-browser/topic-template/opencode.json` there directly — it's bind-mounted, so the container sees the change immediately for new topics. Quick to iterate with, but local to your checkout and not tracked in this repo.
3. **`OPENCODE_CONFIG` env var**: point OpenCode at a config file without touching `topic-template/` at all. The path is resolved inside the container, so put the file under `./agentic-browser` (already bind-mounted) and reference its container-side path:
   ```bash
   OPENCODE_CONFIG=/root/smalltalk-interop/agentic-browser/opencode.json
   ```
   With Docker Compose or `run.sh`, set it in `.env` and restart (`docker compose up -d` / `./run.sh`) — both auto-load `.env`. Either way, no rebuild needed. This overrides config for every topic uniformly, which is handy for a one-off override but less flexible than editing `topic-template/opencode.json` per topic.

## Relation to smalltalk-interop-docker

[smalltalk-interop-docker](https://github.com/mumez/smalltalk-interop-docker) is a lighter, related project that this repo builds on conceptually but not directly:

| | This repo | smalltalk-interop-docker |
| --- | --- | --- |
| What's inside the container | Pharo + AgenticBrowser (Web UI) + OpenCode + smalltalk-dev-plugin | Pharo + PharoSmalltalkInteropServer only |
| Where the coding agent runs | Inside the container　(OpenCode) | Outside the container, on the host (Claude Code, OpenCode, etc.) |
| How you interact | AgenticBrowser Web UI (`:8080`) or VNC (`:6901`), no host agent needed | Your own host-side coding agent + [smalltalk-dev-plugin](https://github.com/mumez/smalltalk-dev-plugin), or AgenticBrowser on your host |
| Project source location | Must live under the bind-mounted `./agentic-browser` (AgenticBrowser topics can't point elsewhere) | Any host directory you mount to `/root/repos` |

Pick **this repo** if you want a self-contained, all-in-one box where the AI agent runs alongside Pharo and you drive everything through the Web UI or VNC without installing anything else on the host.

Pick **smalltalk-interop-docker** if you already have a coding agent on your host (Claude Code, AgenticBrowser, etc.) and just want an isolated, disposable Pharo sandbox it can talk to over MCP.

## Other settings

- Environment variables, volumes, MCP wiring, and build details are documented in [CLAUDE.md](CLAUDE.md).
- VNC settings: [ubuntu-vnc-supervisor](https://github.com/mumez/ubuntu-vnc-supervisor). Pharo image settings: [pharo-vnc-supervisor](https://github.com/mumez/pharo-vnc-supervisor).
- If `docker compose build` fails with `driver not connecting` (Docker Desktop / BuildKit), fall back to the legacy builder:
  ```bash
  DOCKER_BUILDKIT=0 docker build -t pharo-agentic-browser-opencode-docker .
  docker compose up -d --no-build
  ```

## License

MIT
