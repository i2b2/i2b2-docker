#!/bin/bash

# ==============================================================================
# Script Name: mod_env_file.sh
# Description: Modifies the local .env file with target database connection 
#              details for the i2b2 environment.
# Usage: 
#   sh mod_env_file.sh <TARGET_SERVER> <TARGET_PORT> <TARGET_USER> <TARGET_PASS> <DB_SERVICE_NAME>
#
# Example:
#   sh mod_env_file.sh localhost 1522 oracle_user 'MyStrongPass123' FREEPDB1
# ==============================================================================
echo "[DEV NOTICE] Updating only Host IP, Port, and DB Service Name"
echo "[INFO] Pending: one DB user per i2b2 cell OR a single shared DB user for all cells"

if [ "$#" -lt 5 ]; then
    echo "Error: Missing arguments. 9 arguments are required."
    echo "Usage: $0 TARGET_SERVER TARGET_PORT TARGET_USER TARGET_PASS TARGET_CRC_DB TARGET_ONT_DB TARGET_PM_DB TARGET_HIVE_DB TARGET_WD_DB"
    exit 1
fi

TARGET_SERVER=$1
TARGET_PORT=$2
TARGET_USER=$3
TARGET_PASS=$4
DB_SERVICE_NAME=$5


default_host="_IP=i2b2-data-oracle"
default_port="_PORT=1521"
default_username="_USER=i2b2"
default_password="_PASS=demouser"
default_service_name="_SERVICE_NAME=FREEPDB1"

if [ "$TARGET_SERVER" = "localhost" ]; then
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER=$docker_network_gateway_ip
    echo "Target Server IP- " $TARGET_SERVER 
fi  

#updating the .env file
echo "Updating .env file"
sed -i "s/${default_host}/_IP=${TARGET_SERVER}/g" .env
sed -i "s/${default_port}/_PORT=${TARGET_PORT}/g" .env
# sed -i "s/${default_username}/_USER=${TARGET_USER}/g" .env
# sed -i "s/${default_password}/_PASS=${TARGET_PASS}/g" .env
sed -i "s/${default_service_name}/_SERVICE_NAME=${DB_SERVICE_NAME}/g" .env


echo "Run the sh restart_containers script for updating docker configuration."