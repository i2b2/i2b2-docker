#!/bin/bash

# ==============================================================================
# Script Name: restart_containers.sh
# Description: Removes and restarts the i2b2-core-server and i2b2-webclient 
#              Docker containers, then tails the core-server logs.
# Usage: 
#   sh restart_containers.sh
# ==============================================================================

# docker rm -f i2b2-data-mssql # Uncomment this line if you have space issues

# Remove existing containers (ignore errors if they do not exist)
docker rm -f i2b2-core-server i2b2-webclient || true

# Start the containers in detached mode
docker compose up -d i2b2-core-server i2b2-webclient

echo "Started i2b2-core-server & i2b2-webclient Docker containers."
echo "Fetching logs for i2b2-core-server container in 10 seconds..."
sleep 10
docker logs -f i2b2-core-server