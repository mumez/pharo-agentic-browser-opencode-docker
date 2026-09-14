# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS webui

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ARG WEBUI_REPO=https://github.com/mumez/pharo-agentic-browser-web-ui.git
ARG WEBUI_REF=develop
RUN git clone --depth 1 --branch "${WEBUI_REF}" "${WEBUI_REPO}" . \
  && npm ci \
  && npm run build

FROM mumez/pharo-vnc-supervisor
LABEL maintainer="Masashi Umezawa <ume@softumeya.com>"

ARG SMALLTALK_INTEROP_DIR=/root/smalltalk-interop
ARG INTEROP_REPOS_URL=github://mumez/PharoSmalltalkInteropServer:main/src
ARG AGENTIC_BROWSER_REPOS_URL=github://mumez/pharo-agentic-browser:main/src
ARG PLUGIN_REPO=https://github.com/mumez/smalltalk-dev-plugin.git
ARG PLUGIN_REF=develop

ENV PATH="/usr/local/bin:/root/.opencode/bin:/root/.local/bin:${PATH}"
ENV PHARO_RIPPLE_PORT=8080
ENV PHARO_RIPPLE_BIND_ADDRESS=0.0.0.0
ENV AGENTIC_BROWSER_SEED_DIR=/opt/agentic-browser-seed

RUN apt-get update \
  && apt-get install -y --no-install-recommends git jq ca-certificates curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
  && curl -fsSL https://opencode.ai/install | env OPENCODE_INSTALL_DIR=/usr/local/bin bash \
  && git clone --depth 1 --branch "${PLUGIN_REF}" "${PLUGIN_REPO}" /opt/smalltalk-dev-plugin \
  && if [ -x /root/.opencode/bin/opencode ] && [ ! -e /usr/local/bin/opencode ]; then \
  ln -s /root/.opencode/bin/opencode /usr/local/bin/opencode; \
  fi

COPY ./seed /opt/repo-seed
COPY scripts/prepare-topic-template.sh /tmp/prepare-topic-template.sh
RUN chmod +x /tmp/prepare-topic-template.sh \
  && /tmp/prepare-topic-template.sh /opt/smalltalk-dev-plugin /opt/agentic-browser-seed/topic-template /opt/repo-seed/topic-template \
  && rm /tmp/prepare-topic-template.sh \
  && cp /opt/repo-seed/ab-settings.json /opt/agentic-browser-seed/ab-settings.json \
  && (timeout 90 uvx --from git+https://github.com/mumez/smalltalk-interop-mcp-server.git smalltalk-interop-mcp-server --help || true) \
  && (timeout 90 uvx --from git+https://github.com/mumez/smalltalk-validator-mcp-server.git@main smalltalk-validator-mcp-server --help || true)

RUN PHARO_MODE=headless setup.sh \
  && PHARO_MODE=headless save-pharo.sh metacello install ${INTEROP_REPOS_URL} BaselineOfPharoSmalltalkInteropServer \
  && PHARO_MODE=headless save-pharo.sh metacello install ${AGENTIC_BROWSER_REPOS_URL} BaselineOfAgenticBrowser --groups=all \
  && cp -r /root/data ${SMALLTALK_INTEROP_DIR} \
  && mkdir -p /root/screenshots \
  ${SMALLTALK_INTEROP_DIR}/agentic-browser \
  ${SMALLTALK_INTEROP_DIR}/assets \
  && cp -a /opt/agentic-browser-seed/topic-template ${SMALLTALK_INTEROP_DIR}/agentic-browser/topic-template \
  && cp /opt/agentic-browser-seed/ab-settings.json ${SMALLTALK_INTEROP_DIR}/agentic-browser/ab-settings.json

COPY --from=webui /src/assets/agentic-browser ${SMALLTALK_INTEROP_DIR}/assets/agentic-browser
COPY ./config/startup.st ${SMALLTALK_INTEROP_DIR}/config/startup.st
COPY ./scripts/seed-agentic-browser.sh /usr/local/bin/seed-agentic-browser.sh
COPY ./scripts/ab-entrypoint.sh /usr/local/bin/ab-entrypoint.sh
RUN chmod +x /usr/local/bin/seed-agentic-browser.sh /usr/local/bin/ab-entrypoint.sh

# Allow the container to run as an arbitrary non-root UID/GID (see run.sh
# --user / compose.yaml's HOST_UID/HOST_GID): everything under /root is
# root-owned from the build, and /run, /var/log/supervisor default to
# root:root, so any other UID needs explicit rwX to read/write its own
# home, Pharo image, OpenCode state, and supervisord's pid/socket/logs.
RUN chmod -R a+rwX /root \
  && chmod a+rwX /run /var/log/supervisor

ENV HOME=/root
ENV PHARO_HOME=${SMALLTALK_INTEROP_DIR}
ENV PHARO_SIS_PORT=8086
ENV PHARO_SIS_SCREENSHOT_DIR=/root/screenshots
ENV PHARO_START_SCRIPT=${SMALLTALK_INTEROP_DIR}/config/startup.st
ENV PHARO_RIPPLE_ASSETS_DIR=${SMALLTALK_INTEROP_DIR}/assets

VOLUME ["${PHARO_SIS_SCREENSHOT_DIR}", "${SMALLTALK_INTEROP_DIR}/agentic-browser"]
EXPOSE 8080 8086

ENTRYPOINT ["/usr/local/bin/ab-entrypoint.sh"]
CMD ["supervisord"]
