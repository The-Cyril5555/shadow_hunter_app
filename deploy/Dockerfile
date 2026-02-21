FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Download Godot 4.6 Linux x86_64 (adjust version if needed)
ARG GODOT_VERSION=4.6
RUN wget -q \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp/ \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

WORKDIR /app

# Copy project files (assets excluded via .dockerignore)
COPY . .

# Generate .godot/ import cache then quit
RUN godot --headless --path /app --quit 2>&1 ; exit 0

EXPOSE 9080

# Run the dedicated server entry scene
CMD ["godot", "--headless", "--path", "/app", "res://scenes/server/server_main.tscn"]
