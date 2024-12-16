#!/bin/false

# This file will be sourced in init.sh

function preflight_main() {
    preflight_update_comfyui
    printf "%s" "${COMFYUI_ARGS}" > /etc/comfyui_args.conf
    
    # Install Ollama with proper verification
    printf "Installing Ollama...\n"
    if curl -fsSL https://ollama.com/install.sh | sh; then
        # Verify installation
        if [ -f "/usr/local/bin/ollama" ]; then
            printf "Ollama installed successfully\n"
            # Create necessary directories
            mkdir -p /opt/ollama_service
            # Signal that Ollama is installed and ready for supervisor
            touch /run/ollama_installed
        else
            printf "ERROR: Ollama installation failed - binary not found\n"
            exit 1
        fi
    else
        printf "ERROR: Ollama installation script failed\n"
        exit 1
    fi
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