#!/bin/bash
set -e

# nginx listens on $PORT (injected by Render, default 10000)
# Godot WebSocket server on internal port 9080
export NGINX_PORT="${PORT:-10000}"

envsubst '$NGINX_PORT' < /etc/nginx/templates/ws.conf.template \
    > /etc/nginx/conf.d/ws.conf

nginx
echo "[start.sh] nginx on :${NGINX_PORT} → proxying WebSocket to :9080"

PORT=9080 exec godot --headless --path /app res://scenes/server/server_main.tscn
