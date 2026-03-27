#!/usr/bin/env sh
set -eu

PORT="${PORT:-8080}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
SERVER_NAME="${SERVER_NAME:-EaglerCraft Render}"
EAGLER_WS_PATH="${EAGLER_WS_PATH:-/}"
EAGLER_ALLOWED_ORIGIN="${EAGLER_ALLOWED_ORIGIN:-*}"

APP_DIR="/app"
DATA_DIR="/data"
TEMPLATE_DIR="${APP_DIR}/templates/eaglerxbungee"

echo "[boot] Render bind: ${BIND_HOST}:${PORT}"
echo "[boot] Server name: ${SERVER_NAME}"

mkdir -p "${DATA_DIR}" "${DATA_DIR}/plugins/EaglercraftXBungee"

copy_if_missing() {
  SRC="$1"
  DST="$2"
  if [ -f "$SRC" ] && [ ! -f "$DST" ]; then
    mkdir -p "$(dirname "$DST")"
    cp "$SRC" "$DST"
    echo "[boot] Seeded template: $DST"
  fi
}

# Seed EaglerXBungee template files on first run
copy_if_missing "${TEMPLATE_DIR}/listeners.yml" "${DATA_DIR}/plugins/EaglercraftXBungee/listeners.yml"
copy_if_missing "${TEMPLATE_DIR}/settings.yml" "${DATA_DIR}/plugins/EaglercraftXBungee/settings.yml"
copy_if_missing "${TEMPLATE_DIR}/authservice.yml" "${DATA_DIR}/plugins/EaglercraftXBungee/authservice.yml"

if [ -f "/data/server.jar" ]; then
  JAR_PATH="/data/server.jar"
elif [ -f "/app/server.jar" ]; then
  JAR_PATH="/app/server.jar"
else
  if [ -n "${EAGLER_JAR_URL:-}" ]; then
    echo "[boot] Downloading server jar from EAGLER_JAR_URL..."
    mkdir -p /data
    curl -fsSL "$EAGLER_JAR_URL" -o /data/server.jar
    JAR_PATH="/data/server.jar"
  else
    echo "[error] server.jar introuvable."
    echo "[hint] Définis EAGLER_JAR_URL dans les variables d'environnement Render (mode recommandé en plan Free)."
    echo "[hint] Exemple: https://ton-hebergeur.exemple/EaglerXBungee.jar"
    exit 1
  fi
fi

# Prepare candidate config files (Bungee + EaglerXBungee + generic)
CFG_FILES="
${DATA_DIR}/config.yml
${APP_DIR}/config.yml
${DATA_DIR}/plugins/EaglercraftXBungee/listeners.yml
${DATA_DIR}/plugins/EaglercraftXBungee/settings.yml
${DATA_DIR}/plugins/EaglercraftXBungee/authservice.yml
${APP_DIR}/plugins/EaglercraftXBungee/listeners.yml
${APP_DIR}/plugins/EaglercraftXBungee/settings.yml
${APP_DIR}/plugins/EaglercraftXBungee/authservice.yml
"

for CFG in $CFG_FILES; do
  if [ -f "$CFG" ]; then
    sed -i "s/__PORT__/${PORT}/g" "$CFG"
    sed -i "s/__BIND_HOST__/${BIND_HOST}/g" "$CFG"
    sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$CFG"
    sed -i "s#__WS_PATH__#${EAGLER_WS_PATH}#g" "$CFG"
    sed -i "s#__ALLOWED_ORIGIN__#${EAGLER_ALLOWED_ORIGIN}#g" "$CFG"
    echo "[boot] Applied placeholders in $CFG"
  fi
done

# Use /data as working dir when available so plugin/database files persist
if [ -w "${DATA_DIR}" ]; then
  cd "${DATA_DIR}"
else
  cd "${APP_DIR}"
fi

JAVA_OPTS_VALUE="${JAVA_OPTS:--Xms512M -Xmx1024M}"

echo "[boot] Starting: $JAR_PATH"
# -Dserver.port peut être ignoré par certains jars (normal)
exec java $JAVA_OPTS_VALUE -Dserver.port="$PORT" -jar "$JAR_PATH"
