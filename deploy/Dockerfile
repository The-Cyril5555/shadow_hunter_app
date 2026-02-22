FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libgl1 \
    nginx \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Download Godot 4.6 Linux x86_64
ARG GODOT_VERSION=4.6
RUN wget -q \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp/ \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

WORKDIR /app

# Copy project files (heavy assets excluded via .dockerignore)
COPY . .

# Generate .godot/ import cache in editor mode (required for class_name registration)
RUN godot --headless --editor --path /app --quit 2>&1 ; exit 0

# nginx: proxy WebSocket to Godot + respond to health checks
RUN mkdir -p /etc/nginx/templates
COPY deploy/nginx.conf.template /etc/nginx/templates/ws.conf.template
RUN rm -f /etc/nginx/sites-enabled/default

# Startup script
COPY deploy/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 9080

CMD ["/start.sh"]
