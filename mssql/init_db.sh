#!/bin/bash

# ==============================================================================
# Script Name: init_db.sh
# Description: Initializing an empty production database with i2b2 mssql 
#              local docker container database by exporting and importing .bacpac files.
# Prerequisite: i2b2 docker demo must be working and running.
# Usage: 
#   sh init_db.sh <TARGET_SERVER> <TARGET_PORT> <TARGET_USER> <TARGET_PASS> \
#                 <TARGET_CRC_DB> <TARGET_ONT_DB> <TARGET_PM_DB> \
#                 <TARGET_HIVE_DB> <TARGET_WD_DB> <CORE_SERVER_IP> <CORE_SERVER_PORT>
# Example:
#   bash init_db.sh local-db-ip 1432 SA '<YourStrong@Passw0rd>' i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata i2b2-core-server 8080
# ==============================================================================

if [ "$#" -lt 11 ]; then
    echo "Error: Missing arguments."
    echo "Usage: $0 TARGET_SERVER TARGET_PORT TARGET_USER TARGET_PASS TARGET_CRC_DB TARGET_ONT_DB TARGET_PM_DB TARGET_HIVE_DB TARGET_WD_DB CORE_SERVER_IP CORE_SERVER_PORT"
    exit 1
fi

export SOURCE_SERVER="localhost"
export SOURCE_USER="sa"
export SOURCE_PASS="<YourStrong@Passw0rd>"
export SOURCE_CRC_DB="i2b2demodata"
export SOURCE_ONT_DB="i2b2metadata"
export SOURCE_PM_DB="i2b2pm"
export SOURCE_HIVE_DB="i2b2hive"
export SOURCE_WD_DB="i2b2workdata"

export TARGET_SERVER=$1
export TARGET_PORT=$2
export TARGET_USER=$3
export TARGET_PASS=$4
export TARGET_CRC_DB=$5
export TARGET_ONT_DB=$6
export TARGET_PM_DB=$7
export TARGET_HIVE_DB=$8
export TARGET_WD_DB=$9
export CORE_SERVER_IP=${10}
export CORE_SERVER_PORT=${11}

if [ "$TARGET_SERVER" = "local-db-ip" ]; then
    export docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    export TARGET_SERVER_PORT="$docker_network_gateway_ip,$TARGET_PORT"
    echo "Targeting local environment via gateway: $TARGET_SERVER_PORT" 
    docker run -i -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=<YourStrong@Passw0rd>" -p 1432:1433 --name target_db_container -d adityapersistent/i2b2:custom-mssql-2019-fts  #mcr.microsoft.com/mssql/server:2019-latest
    sleep 30 # Allow time for the local target container to initialize
    # docker exec --user root target_db_container bash -c "apt-get update && apt-get install -yq curl apt-transport-https gnupg && curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && curl -sL https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list | tee /etc/apt/sources.list.d/mssql-server-2019.list && apt-get update && apt-get install -y mssql-server-fts"
    # docker restart target_db_container
    # sleep 30
else
    export TARGET_SERVER_PORT="$TARGET_SERVER,$TARGET_PORT"
    echo "Targeting remote environment: $TARGET_SERVER_PORT"
fi 

# ==============================================================================
# FUNCTION: initialize_database
# Description: Exports a specific DB to a .bacpac file and imports it to the target
# Arguments: 
#   $1 - Source Database Name
#   $2 - Target Database Name
#   $3 - Database Label for logging (e.g., CRC, ONT)
# ==============================================================================
initialize_database() {
    local db_source=$1
    local db_target=$2
    local db_label=$3

    echo "=========================================="
    echo " ${db_label} DATABASE MIGRATION"
    echo "=========================================="
    
    echo "Exporting ${db_source}..."
    docker exec -i i2b2-data-mssql /opt/sqlpackage/sqlpackage \
        /Action:Export \
        /SourceServerName:$SOURCE_SERVER \
        /SourceDatabaseName:$db_source \
        /SourceUser:$SOURCE_USER \
        /SourcePassword:$SOURCE_PASS \
        /TargetFile:$db_source.bacpac \
        /SourceTrustServerCertificate:True
    sleep 20

    echo "Importing to ${db_target}..."
    docker exec -i i2b2-data-mssql /opt/sqlpackage/sqlpackage \
        /Action:Import \
        /TargetServerName:$TARGET_SERVER_PORT \
        /TargetDatabaseName:$db_target \
        /TargetUser:$TARGET_USER \
        /TargetPassword:$TARGET_PASS \
        /SourceFile:$db_source.bacpac \
        /TargetTrustServerCertificate:True
    
    echo "Completed ${db_label} db restore"
    sleep 20
}

# Execute database migrations
initialize_database "$SOURCE_CRC_DB" "$TARGET_CRC_DB" "CRC"
initialize_database "$SOURCE_ONT_DB" "$TARGET_ONT_DB" "ONT"
initialize_database "$SOURCE_PM_DB" "$TARGET_PM_DB" "PM"
initialize_database "$SOURCE_HIVE_DB" "$TARGET_HIVE_DB" "HIVE"
initialize_database "$SOURCE_WD_DB" "$TARGET_WD_DB" "WD"

echo "Completed Initializing database."
echo "=========================================="

echo "Scenario: Production install on existing i2b2 database - Run reconfigure_pm_hive.sh script with required arguments:"
echo "# sh reconfigure_pm_hive.sh $CORE_SERVER_IP $CORE_SERVER_PORT $TARGET_SERVER $TARGET_PORT ${TARGET_CRC_DB}.dbo ${TARGET_ONT_DB}.dbo $TARGET_PM_DB $TARGET_HIVE_DB ${TARGET_WD_DB}.dbo $TARGET_USER '$TARGET_PASS'"

echo "Run mod_env_file.sh script with required arguments:"
echo "# sh mod_env_file.sh $TARGET_SERVER $TARGET_PORT $TARGET_USER '$TARGET_PASS' $TARGET_CRC_DB $TARGET_ONT_DB $TARGET_PM_DB $TARGET_HIVE_DB $TARGET_WD_DB"

echo "Run restart_containers.sh script:"
echo "# sh restart_containers.sh"