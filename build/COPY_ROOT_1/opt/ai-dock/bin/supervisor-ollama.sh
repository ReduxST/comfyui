#!/bin/bash

trap cleanup EXIT

LISTEN_PORT=${OLLAMA_PORT_LOCAL:-11434}
METRICS_PORT=${OLLAMA_METRICS_PORT:-29188}
SERVICE_URL="${OLLAMA_URL:-}"
QUICKTUNNELS=true

function cleanup() {
    kill $(jobs -p) > /dev/null 2>&1
    rm /run/http_ports/$PROXY_PORT > /dev/null 2>&1
    fuser -k -SIGTERM ${LISTEN_PORT}/tcp > /dev/null 2>&1 &
    wait -n
}

function start() {
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh serviceportal
    
    # Exit with code 125 if Ollama is not installed yet
    # Supervisor will treat this as expected and won't restart
    if [[ ! -f "/run/ollama_installed" ]]; then
        printf "Waiting for Ollama installation to complete...\n"
        exit 125
    fi
    
    if [[ ! -v OLLAMA_PORT || -z $OLLAMA_PORT ]]; then
        OLLAMA_PORT=${OLLAMA_PORT_HOST:-19188}
    fi
    PROXY_PORT=$OLLAMA_PORT
    SERVICE_NAME="Ollama"
    
    file_content="$(
      jq --null-input \
        --arg listen_port "${LISTEN_PORT}" \
        --arg metrics_port "${METRICS_PORT}" \
        --arg proxy_port "${PROXY_PORT}" \
        --arg proxy_secure "${PROXY_SECURE,,}" \
        --arg service_name "${SERVICE_NAME}" \
        --arg service_url "${SERVICE_URL}" \
        '$ARGS.named'
    )"
    
    printf "%s" "$file_content" > /run/http_ports/$PROXY_PORT
    
    printf "Starting %s...\n" "${SERVICE_NAME}"
    
    # Set Ollama environment variables
    export OLLAMA_HOST="0.0.0.0:${LISTEN_PORT}"
    
    # Start Ollama service
    /usr/local/bin/ollama serve
}

start 2>&1
