#!/bin/bash

mkdir -p "$PWD/screenshots" "$PWD/agentic-browser"

docker rm -f pharo-ab-opencode01 2>/dev/null || true

docker build -t pharo-agentic-browser-opencode-docker-sis-pharo .
docker run --name pharo-ab-opencode01 -d \
    --user "$(id -u):$(id -g)" \
    -p 5900:5900 \
    -p 6901:6901 \
    -p 8080:8080 \
    -p 8086:8086 \
    -e PHARO_SIS_PORT=8086 \
    -e PHARO_RIPPLE_PORT=8080 \
    -e PHARO_RIPPLE_BIND_ADDRESS=0.0.0.0 \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
    -e OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}" \
    -e GOOGLE_GENERATIVE_AI_API_KEY="${GOOGLE_GENERATIVE_AI_API_KEY:-}" \
    -e OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD:-}" \
    -e OPENCODE_CONFIG="${OPENCODE_CONFIG:-}" \
    -v "$PWD/screenshots:/root/screenshots" \
    -v "$PWD/agentic-browser:/root/smalltalk-interop/agentic-browser" \
    pharo-agentic-browser-opencode-docker-sis-pharo
