# pharo-agentic-browser-opencode-docker

An all-in-one development container for AI-assisted Smalltalk development.

As long as Docker is installed, you can start developing right away. The container packages:

- **Pharo** ([AgenticBrowser](https://github.com/mumez/pharo-agentic-browser) + SmalltalkInteropServer)
- **OpenCode** ([smalltalk-dev-plugin](https://github.com/mumez/smalltalk-dev-plugin))

The only thing you need to bring is your coding agent's credentials (e.g. an Anthropic API key).

## Setup

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY (and/or other provider keys) in .env
```

Then start the container either with `run.sh`:

```bash
./run.sh
```

or with Docker Compose:

```bash
docker compose up -d --build
```

Give it a few minutes on first boot (Pharo GUI + Web UI need to come up).

`run.sh` always runs the container as the invoking host user, so files it creates under `./agentic-browser` and `./screenshots` are owned by you, not root. With Docker Compose this is opt-in: set `HOST_UID`/`HOST_GID` in `.env` (via `id -u` / `id -g`) — left unset, it runs as root as before.

## Host-side directories

| Path | What it's for |
| --- | --- |
| `./agentic-browser` | Where your source repositories live. AgenticBrowser topics work inside this tree, and it's where you clone/place the project(s) you want to develop. |
| `./screenshots` | Where screenshots taken from Pharo/AgenticBrowser are saved. |

The first time you start the container, a `topic-template` directory is created under `./agentic-browser` if it doesn't already exist. It holds the configuration that lets OpenCode use `smalltalk-dev-plugin` (skills/commands) inside each topic.

## Usage

### Basic

Open the **AgenticBrowser Web UI** in your host browser:

- http://localhost:8080/assets/agentic-browser/

Create a topic, pick OpenCode as the agent, and start chatting. This covers most day-to-day development.

### Advanced

- **VNC into the Pharo screen** to use AgenticBrowser's native UI, which supports operations the Web UI doesn't expose (Settings, target packages, System Browser drag-and-drop, the debugger, etc.):
  - http://localhost:6901/?password=vncpassword
- **`./opencode-cli.sh`** opens the OpenCode TUI directly in the container, in a topic's working directory:
  ```bash
  ./opencode-cli.sh
  ```
- **`./opencode-web.sh`** runs OpenCode's own Web UI (`opencode web`) instead of the TUI — a separate server from AgenticBrowser's ACP sessions, useful for standalone OpenCode work against the Interop MCP:
  ```bash
  ./opencode-web.sh
  ```
  Requires `OPENCODE_SERVER_PASSWORD` to be set and port `4096` published (uncomment it in `compose.yaml`) before exposing it.

  Both are thin wrappers around `docker exec -it pharo-ab-opencode01 ...` — use that directly if you're not running against the default container name.

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
   With Docker Compose, set it in `.env` and restart (`docker compose up -d`). With `run.sh`, export it in your shell before running (`run.sh` reads env vars directly, not `.env`). Either way, no rebuild needed. This overrides config for every topic uniformly, which is handy for a one-off override but less flexible than editing `topic-template/opencode.json` per topic.

## Other settings

- Environment variables, volumes, MCP wiring, and build details are documented in [CLAUDE.md](CLAUDE.md).
- VNC settings: [ubuntu-vnc-supervisor](https://github.com/mumez/ubuntu-vnc-supervisor). Pharo image settings: [pharo-vnc-supervisor](https://github.com/mumez/pharo-vnc-supervisor).
- If `docker compose build` fails with `driver not connecting` (Docker Desktop / BuildKit), fall back to the legacy builder:
  ```bash
  DOCKER_BUILDKIT=0 docker build -t pharo-agentic-browser-opencode-docker-sis-pharo .
  docker compose up -d --no-build
  ```
