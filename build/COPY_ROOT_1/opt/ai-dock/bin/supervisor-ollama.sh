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
    
    # Wait for Ollama installation to complete
    while [[ ! -f "/run/ollama_ready" ]]; do
        printf "Waiting for Ollama installation to complete...\n"
        sleep 2
    done
    
    # Delay launch until container is ready
    if [[ -f /run/workspace_sync || -f /run/container_config ]]; then
        if [[ ${SERVERLESS,,} != "true" ]]; then
            printf "Waiting for workspace sync...\n"
            fuser -k -SIGKILL ${LISTEN_PORT}/tcp > /dev/null 2>&1 &
            wait -n
            "$SERVICEPORTAL_VENV_PYTHON" /opt/ai-dock/fastapi/logviewer/main.py \
                -p $LISTEN_PORT \
                -r 5 \
                -s "${SERVICE_NAME}" \
                -t "Preparing ${SERVICE_NAME}" &
            fastapi_pid=$!
            
            while [[ -f /run/workspace_sync || -f /run/container_config ]]; do
                sleep 1
            done
            
            kill $fastapi_pid &
            wait -n
        else
            printf "Waiting for workspace symlinks and pre-flight checks...\n"
            while [[ -f /run/workspace_sync || -f /run/container_config ]]; do
                sleep 1
            done
        fi
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
