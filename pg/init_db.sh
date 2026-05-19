#!/bin/bash

# ==============================================================================
# Script Name: init_db.sh
# Description: Initializes an empty production database with i2b2 pgsql 
#              local docker container database by exporting and importing dumps.
# Prerequisite: i2b2 docker demo must be working and running.
# Usage: 
#   sh init_db.sh <TARGET_IP> <TARGET_PORT> <TARGET_USER> <TARGET_PASS> \
#                 <TARGET_DB> <TARGET_CRC_SCHEMA> <TARGET_ONT_SCHEMA> \
#                 <TARGET_PM_SCHEMA> <TARGET_HIVE_SCHEMA> <TARGET_WD_SCHEMA> \
#                 <CORE_SERVER_IP> <CORE_SERVER_PORT>
# Example:
#   bash init_db.sh local-db-ip 5432 i2b2 demouser i2b2 i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata i2b2-core-server 8080
# ==============================================================================

if [ "$#" -lt 12 ]; then
    echo "Error: Missing arguments. 12 arguments are required."
    echo "Usage: $0 TARGET_IP TARGET_PORT TARGET_USER TARGET_PASS TARGET_DB TARGET_CRC_SCHEMA TARGET_ONT_SCHEMA TARGET_PM_SCHEMA TARGET_HIVE_SCHEMA TARGET_WD_SCHEMA CORE_SERVER_IP CORE_SERVER_PORT"
    exit 1
fi

TARGET_HOST=$1
TARGET_PORT=$2
TARGET_USER=$3
TARGET_PASS=$4
TARGET_DB=$5

TARGET_CRC_SCHEMA=$6
TARGET_ONT_SCHEMA=$7
TARGET_PM_SCHEMA=$8
TARGET_HIVE_SCHEMA=$9
TARGET_WD_SCHEMA=${10}

CORE_SERVER_IP=${11}
CORE_SERVER_PORT=${12}

echo "Target Configuration:"
echo "Host: $TARGET_HOST | Port: $TARGET_PORT | User: $TARGET_USER | DB: $TARGET_DB"

if [ "$TARGET_HOST" = "local-db-ip" ]; then
    echo "Detecting local Docker network gateway..."
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}') 
    TARGET_HOST=$docker_network_gateway_ip
    
    echo "Installing native postgresql database locally and updating configuration..."
    bash create_native_pg_server.sh
fi

echo "Waiting for database & docker container to start (180 seconds)..."
sleep 180

echo "Dump process started"
# dump - 1min approx.
docker exec -i -e PGPASSWORD=demouser i2b2-data-pgsql pg_dump -U postgres -d i2b2 -F c --no-owner --no-acl -f i2b2_db_backup.dump
echo "Dump process completed"

echo "Restore process started to $TARGET_HOST:$TARGET_PORT ($TARGET_DB)..."
# within 2 minutes
docker exec -i -e PGPASSWORD="$TARGET_PASS" i2b2-data-pgsql pg_restore -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USER" -d "$TARGET_DB" -F c --no-owner i2b2_db_backup.dump

echo "Restore process completed"

echo "Completed backup and restore for all the databases."

echo "================================================="
echo "Next steps:"

echo "Scenario: Production install on existing i2b2 database - Run reconfigure_pm_hive.sh script with required arguments:"
echo  "sh reconfigure_pm_hive.sh $TARGET_HOST $TARGET_PORT $TARGET_USER $TARGET_PASS $TARGET_DB $TARGET_CRC_SCHEMA $TARGET_ONT_SCHEMA $TARGET_PM_SCHEMA $TARGET_HIVE_SCHEMA $TARGET_WD_SCHEMA $CORE_SERVER_IP $CORE_SERVER_PORT"

echo "Run mod_env_file.sh script with required arguments:"
echo "sh mod_env_file.sh $TARGET_HOST $TARGET_PORT $TARGET_USER '$TARGET_PASS' $TARGET_DB"
echo "Run restart_containers.sh script:"
echo "sh restart_containers.sh"

