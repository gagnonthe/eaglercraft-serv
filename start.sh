#!/usr/bin/env sh
set -eu

PORT="${PORT:-8080}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
SERVER_NAME="${SERVER_NAME:-EaglerCraft Render}"
EAGLER_WS_PATH="${EAGLER_WS_PATH:-/}"
EAGLER_ALLOWED_ORIGIN="${EAGLER_ALLOWED_ORIGIN:-*}"
ACCEPT_EULA="${ACCEPT_EULA:-true}"
USE_PORT_PROXY="${USE_PORT_PROXY:-true}"
INTERNAL_SERVER_PORT="${INTERNAL_SERVER_PORT:-25565}"
MINIMAL_TEMPLATE="${MINIMAL_TEMPLATE:-true}"

APP_DIR="/app"
DATA_DIR="/data"
TEMPLATE_DIR="${APP_DIR}/templates/eaglerxbungee"
SERVER_WORKDIR="${DATA_DIR}"
TEMPLATE_EXTRACT_DIR="${DATA_DIR}/server-dist"

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
  if [ -n "${EAGLER_TEMPLATE_ZIP_URL:-}" ]; then
    FOUND_JAR="$(find "${TEMPLATE_EXTRACT_DIR}" -type f -name 'paper-*.jar' | head -n 1 || true)"
    if [ -z "$FOUND_JAR" ]; then
      FOUND_JAR="$(find "${TEMPLATE_EXTRACT_DIR}" -type f -name '*.jar' | head -n 1 || true)"
    fi

    if [ -z "$FOUND_JAR" ]; then
      echo "[boot] Downloading server template zip from EAGLER_TEMPLATE_ZIP_URL..."
      TMP_ZIP="${DATA_DIR}/server-template.zip"
      rm -f "$TMP_ZIP"
      mkdir -p "${TEMPLATE_EXTRACT_DIR}"
      curl -fsSL "$EAGLER_TEMPLATE_ZIP_URL" -o "$TMP_ZIP"
      rm -rf "${TEMPLATE_EXTRACT_DIR}"/*
      unzip -oq "$TMP_ZIP" -d "${TEMPLATE_EXTRACT_DIR}"

      FOUND_JAR="$(find "${TEMPLATE_EXTRACT_DIR}" -type f -name 'paper-*.jar' | head -n 1 || true)"
      if [ -z "$FOUND_JAR" ]; then
        FOUND_JAR="$(find "${TEMPLATE_EXTRACT_DIR}" -type f -name '*.jar' | head -n 1 || true)"
      fi
    else
      echo "[boot] Reusing extracted template server"
    fi

    if [ -z "$FOUND_JAR" ]; then
      echo "[error] Aucun jar exécutable trouvé dans le template téléchargé."
      exit 1
    fi

    JAR_PATH="$FOUND_JAR"
    SERVER_WORKDIR="$(dirname "$FOUND_JAR")"
    echo "[boot] Template server jar: $JAR_PATH"

    if [ "${MINIMAL_TEMPLATE}" = "true" ]; then
      echo "[boot] Applying minimal plugin profile for low-memory instance"
      rm -rf "${SERVER_WORKDIR}/plugins/AuthMe" || true
      rm -f "${SERVER_WORKDIR}/plugins/AuthMe.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/SkinsRestorer.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/ViaVersion.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/ViaBackwards.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/ViaRewind.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/ViaRewind-Legacy-Support.jar" || true
      rm -f "${SERVER_WORKDIR}/plugins/EaglerXRewind.jar" || true
    fi
  elif [ -n "${EAGLER_JAR_URL:-}" ]; then
    echo "[boot] Downloading server jar from EAGLER_JAR_URL..."
    mkdir -p /data
    curl -fsSL "$EAGLER_JAR_URL" -o /data/server.jar
    JAR_PATH="/data/server.jar"
  else
    echo "[error] server.jar introuvable."
    echo "[hint] Option simple: définis EAGLER_TEMPLATE_ZIP_URL vers un zip de serveur complet (ex: Eaglercraft-Server-Paper)."
    echo "[hint] Définis EAGLER_JAR_URL dans les variables d'environnement Render (mode recommandé en plan Free)."
    echo "[hint] Exemple: https://ton-hebergeur.exemple/EaglerXBungee.jar"
    exit 1
  fi
fi

# If a Paper/Spigot-style server.properties exists, bind it to configured port
SERVER_PROPERTIES_FILE="${SERVER_WORKDIR}/server.properties"
if [ -f "${SERVER_PROPERTIES_FILE}" ]; then
  TARGET_PORT="${PORT}"
  TARGET_HOST="${BIND_HOST}"
  if [ "${USE_PORT_PROXY}" = "true" ]; then
    TARGET_PORT="${INTERNAL_SERVER_PORT}"
    TARGET_HOST="127.0.0.1"
  fi

  if grep -q '^server-port=' "${SERVER_PROPERTIES_FILE}"; then
    sed -i "s/^server-port=.*/server-port=${TARGET_PORT}/" "${SERVER_PROPERTIES_FILE}"
  else
    echo "server-port=${TARGET_PORT}" >> "${SERVER_PROPERTIES_FILE}"
  fi

  if grep -q '^server-ip=' "${SERVER_PROPERTIES_FILE}"; then
    sed -i "s/^server-ip=.*/server-ip=${TARGET_HOST}/" "${SERVER_PROPERTIES_FILE}"
  else
    echo "server-ip=${TARGET_HOST}" >> "${SERVER_PROPERTIES_FILE}"
  fi

  echo "[boot] Patched server.properties: ${TARGET_HOST}:${TARGET_PORT}"
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

# Use server workdir when available
if [ -d "${SERVER_WORKDIR}" ] && [ -w "${SERVER_WORKDIR}" ]; then
  cd "${SERVER_WORKDIR}"
elif [ -w "${DATA_DIR}" ]; then
  cd "${DATA_DIR}"
else
  cd "${APP_DIR}"
fi

if [ "${ACCEPT_EULA}" = "true" ]; then
  echo "eula=true" > "${PWD}/eula.txt"
  echo "[boot] eula.txt generated (eula=true)"
fi

JAVA_OPTS_VALUE="${JAVA_OPTS:--Xms64M -Xmx256M -XX:+UseSerialGC}"

if [ "${USE_PORT_PROXY}" = "true" ]; then
  echo "[boot] Starting TCP proxy ${BIND_HOST}:${PORT} -> 127.0.0.1:${INTERNAL_SERVER_PORT}"
  socat TCP-LISTEN:${PORT},bind=${BIND_HOST},reuseaddr,fork TCP:127.0.0.1:${INTERNAL_SERVER_PORT} &
fi

echo "[boot] Starting: $JAR_PATH"
# -Dserver.port peut être ignoré par certains jars (normal)
exec java $JAVA_OPTS_VALUE -Dserver.port="$PORT" -jar "$JAR_PATH"
