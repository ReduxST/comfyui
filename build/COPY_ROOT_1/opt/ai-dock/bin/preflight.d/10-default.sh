#!/bin/false

# This file will be sourced in init.sh

function preflight_main() {
    preflight_update_comfyui
    printf "%s" "${COMFYUI_ARGS}" > /etc/comfyui_args.conf
    
    # Install Ollama
    printf "Installing Ollama...\n"
    curl -fsSL https://ollama.com/install.sh | sh
    
    # Create necessary directories
    mkdir -p /opt/ollama_service
    
    # Initialize Ollama and pull default model
    printf "Pulling minicpm-v model for ollama\n"
    ollama serve &
    OLLAMA_PID=$!
    sleep 5  # Give Ollama time to start
    ollama pull minicpm-v  # Optional: Pull a default model
    
    # Stop the temporary Ollama instance
    kill $OLLAMA_PID
    wait $OLLAMA_PID
    
    # Signal Ollama is ready
    touch /run/ollama_ready
}

function preflight_serverless() {
    printf "Skipping ComfyUI updates in serverless mode\n"
    printf "%s" "${COMFYUI_ARGS}" > /etc/comfyui_args.conf
}

function preflight_update_comfyui() {
    if [[ ${AUTO_UPDATE,,} == "true" ]]; then
        /opt/ai-dock/bin/update-comfyui.sh
    else
        printf "Skipping auto update (AUTO_UPDATE != true)"
    fi
}

# move this to base-image
sudo chown user.ai-dock /var/log/timing_data

if [[ ${SERVERLESS,,} != "true" ]]; then
    preflight_main "$@"
else
    preflight_serverless "$@"
fi