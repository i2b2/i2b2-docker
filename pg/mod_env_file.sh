#!/bin/bash

# ==============================================================================
# Script Name: mod_env_file.sh
# Description: Modifies the local .env file with target PostgreSQL database 
#              connection details for the i2b2 environment.
# Usage: 
#   sh mod_env_file.sh <TARGET_HOST> <TARGET_PORT> <TARGET_USER> <TARGET_PASS> <TARGET_DB>
# Example:
#   sh mod_env_file.sh localhost 5432 i2b2 demouser i2b2
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

if [ "$#" -lt 5 ]; then
    echo "Error: Missing arguments. 5 arguments are required."
    echo "Usage: $0 TARGET_HOST TARGET_PORT TARGET_USER TARGET_PASS TARGET_DB"
    exit 1
fi

target_host="$1"
target_port="$2"
target_username="$3"
target_password="$4"
target_dbname="$5"

default_host="_IP=i2b2-data-pgsql"
default_port="_PORT=5432"
default_username="_USER=i2b2"
default_password="_PASS=demouser"
default_dbname="_DB=i2b2"

if [ "$target_host" = "localhost" ]; then
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    target_host="$docker_network_gateway_ip"
    echo "Target Server IP- $target_host"
fi  

echo "Updating .env file..."

if [ ! -f ".env" ]; then
    echo "Error: .env file not found in the current directory."
    exit 1
fi

# Updating the .env file using '|' as delimiter to avoid conflicts with special characters (e.g. in passwords)
sed -i "s|${default_host}|_IP=${target_host}|g" .env
sed -i "s|${default_port}|_PORT=${target_port}|g" .env
sed -i "s|${default_username}|_USER=${target_username}|g" .env #single user for all databases
sed -i "s|${default_password}|_PASS=${target_password}|g" .env
sed -i "s|${default_dbname}|_DB=${target_dbname}|g" .env

echo "Run the restart_containers script for updating docker configuration."