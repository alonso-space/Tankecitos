# syntax=docker/dockerfile:1
# Tres objetivos a partir de una misma base con Godot:
#   server -> servidor headless (puerto 9080)
#   web    -> Caddy sirviendo el cliente web exportado y reenviando /ws al servidor
# Se usan desde docker-compose.yml; no hace falta Godot instalado en la máquina.

ARG GODOT_VERSION=4.7.2

FROM debian:bookworm-slim AS godot
ARG GODOT_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libasound2 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && rm /tmp/godot.zip


# --- Exporta el cliente web (solo la plantilla "web sin hilos" que usa export_presets.cfg) ---
FROM godot AS build
ARG GODOT_VERSION
RUN curl -fsSL -o /tmp/templates.tpz \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
    && unzip -q -j /tmp/templates.tpz templates/version.txt templates/web_nothreads_release.zip \
        -d "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
    && rm /tmp/templates.tpz
WORKDIR /project
COPY tankecitos/ .
# --import genera la caché de class_name (GameConfig, ServerTank...) antes de exportar
RUN godot --headless --path . --import \
    && mkdir -p /out \
    && godot --headless --path . --export-release Web /out/index.html


# --- Servidor del juego ---
FROM godot AS server
RUN useradd --create-home --uid 10001 tank && mkdir /app && chown tank:tank /app
WORKDIR /app
COPY --chown=tank:tank tankecitos/ .
USER tank
RUN godot --headless --path . --import
EXPOSE 9080
CMD ["godot", "--headless", "--path", ".", "res://server/server.tscn"]


# --- Web: cliente exportado + proxy WebSocket ---
FROM caddy:2-alpine AS web
COPY Caddyfile.docker /etc/caddy/Caddyfile
COPY --from=build /out /srv
