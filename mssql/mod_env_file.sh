#!/bin/bash

# ==============================================================================
# Script Name: mod_env_file.sh
# Description: Modifies the local .env file with target database connection 
#              details for the i2b2 environment.
# Usage: 
#   sh mod_env_file.sh <TARGET_SERVER> <TARGET_PORT> <TARGET_USER> <TARGET_PASS> \
#                      <TARGET_CRC_DB> <TARGET_ONT_DB> <TARGET_PM_DB> \
#                      <TARGET_HIVE_DB> <TARGET_WD_DB>
# Example:
#   sh mod_env_file.sh localhost 1432 SA '<YourStrong@Passw0rd>' i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata
# ==============================================================================

if [ "$#" -lt 9 ]; then
    echo "Error: Missing arguments. 9 arguments are required."
    echo "Usage: $0 TARGET_SERVER TARGET_PORT TARGET_USER TARGET_PASS TARGET_CRC_DB TARGET_ONT_DB TARGET_PM_DB TARGET_HIVE_DB TARGET_WD_DB"
    exit 1
fi

TARGET_SERVER=$1
TARGET_PORT=$2
TARGET_USER=$3
TARGET_PASS=$4
TARGET_CRC_DB=$5
TARGET_ONT_DB=$6
TARGET_PM_DB=$7
TARGET_HIVE_DB=$8
TARGET_WD_DB=$9

default_host="_IP=i2b2-data-mssql"
default_port="_PORT=1433"
default_username="_USER=i2b2"
default_password="_PASS=demouser"
 
default_crc_dbname="_CRC_DB=i2b2demodata"
default_ont_db_name="_ONT_DB=i2b2metadata"
default_pm_db_name="_PM_DB=i2b2pm"
default_hive_dbname="_HIVE_DB=i2b2hive"
default_wd_dbname="_WD_DB=i2b2workdata"

if [ "$TARGET_SERVER" = "localhost" ]; then
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER=$docker_network_gateway_ip
    echo "Target Server IP- " $TARGET_SERVER 
fi  

#updating the .env file
echo "Updating .env file"
sed -i "s/${default_host}/_IP=${TARGET_SERVER}/g" .env
sed -i "s/${default_port}/_PORT=${TARGET_PORT}/g" .env
sed -i "s/${default_username}/_USER=${TARGET_USER}/g" .env
sed -i "s/${default_password}/_PASS=${TARGET_PASS}/g" .env
 
sed -i "s/${default_crc_dbname}/_CRC_DB=${TARGET_CRC_DB}/g" .env
sed -i "s/${default_ont_db_name}/_ONT_DB=${TARGET_ONT_DB}/g" .env
sed -i "s/${default_pm_db_name}/_PM_DB=${TARGET_PM_DB}/g" .env
sed -i "s/${default_hive_dbname}/_HIVE_DB=${TARGET_HIVE_DB}/g" .env
sed -i "s/${default_wd_dbname}/_WD_DB=${TARGET_WD_DB}/g" .env

echo "Run the restart_containers script for updating docker configuration."