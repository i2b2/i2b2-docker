#!/bin/bash

# ==============================================================================
# Script Name: init_db.sh 
# Description: Automates the initialization of an Oracle 23ai database for i2b2,
#              creates required schemas, and executes Ant tasks to load data.
# Usage: 
#   bash init_db.sh <CORE_SERVER_IP> <CORE_SERVER_PORT> <TARGET_SERVER> \
#                          <TARGET_PORT> <TARGET_CRC_USER> <TARGET_ONT_USER> \
#                          <TARGET_PM_USER> <TARGET_HIVE_USER> <TARGET_WD_USER> \
#                          <SCHEMA_PASS> <SERVICE_NAME>
# Example:
#   bash init_db.sh i2b2-core-server 8080 localhost 1522 I2B2DEMODATA I2B2METADATA I2B2PM I2B2HIVE I2B2WORKDATA demouser FREEPDB1
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- 0. Prerequisites ---
echo "Installing necessary build tools (Ant)..."
apt-get update
apt-get install -y ant

# --- 1. Initialization & Inputs ---
echo "Starting i2b2 Remote Database Initialization..."

# Default Oracle password if not provided in the environment
TARGET_ORACLE_PWD="${TARGET_ORACLE_PWD:-'MyStrongPass123'}"

# Map command-line arguments to variables
CORE_SERVER_IP=$1
CORE_SERVER_PORT=$2
TARGET_SERVER=$3
TARGET_PORT=$4
TARGET_CRC_USER=$5
TARGET_ONT_USER=$6
TARGET_PM_USER=$7
TARGET_HIVE_USER=$8
TARGET_WD_USER=$9
SCHEMA_PASS=${10}
SERVICE_NAME=${11}

echo "Target Server IP: $TARGET_SERVER"

# Define project directories
BASE_DIR=$(pwd) 
root="i2b2-data"
dbproperties="/home/admin/i2b2/i2b2-docker_adityapersistent/oracle"

# Clone the required i2b2 data repository
if [ ! -d "$root" ]; then
    echo "Cloning i2b2-data repository..."
    git clone http://github.com/i2b2/i2b2-data
else
    echo "Directory $root already exists, skipping clone."
fi

# --- 2. Local Docker Setup ---
# If the target is localhost, spin up a fresh Oracle 23ai container
if [ "$TARGET_SERVER" = "localhost" ]; then
    echo "Local setup detected. Starting Oracle 23ai Docker container..."

    docker run -d \
    --name oracle23 \
    -p 1522:1521 \
    -e ORACLE_PWD="$TARGET_ORACLE_PWD" \
    -v "/home/runner/work/i2b2-data/i2b2-data/:/i2b2" \
    --network i2b2-net \
    container-registry.oracle.com/database/free:latest
        
    echo "Waiting for Oracle database to initialize (sleeping for 100 seconds)..."
    sleep 100
    echo "Oracle 23ai container is ready!"
fi

# --- 3. Create Users/Schema via SQL*Plus ---
echo "Creating i2b2 users on remote database..."
# Pipe the local create_users.sql script directly into the Oracle container
docker exec -i oracle23 sqlplus -s sys/$TARGET_ORACLE_PWD@localhost:1521/$DB_SERVICE as sysdba < create_users.sql


# --- 4. Process i2b2 Cells (Ant Builds) ---
# Define the cells and their respective relative paths inside the repo
cells=("demodata" "hive" "imdata" "metadata" "pm" "workdata")
paths=(
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Crcdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Hivedata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Imdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Metadata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Pmdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Workdata"
)

# Loop through each cell to configure its properties and run Ant tasks
for i in "${!cells[@]}"; do
    CELL_NAME=${cells[$i]}
    CELL_PATH=${paths[$i]}
    
    echo "------------------------------------------"
    echo "Processing Cell: $CELL_NAME"
    
    # Navigate to the specific cell directory using an absolute path reference
    cd "$BASE_DIR/$root/$CELL_PATH"

    # Update db.properties using sed to inject environment variables
    # Note: Converted USER_NAME replacement to UPPERCASE as Oracle schemas default to uppercase
    cat "$dbproperties/db.properties" | \
    sed "s/localhost/$TARGET_SERVER/" | \
    sed "s/1521/$TARGET_PORT/" | \
    sed "s/FREEPDB1/$DB_SERVICE/" | \
    sed "s/PWD/$SCHEMA_PASS/" | \
    sed "s/USER_NAME/I2B2${CELL_NAME^^}/" > db.properties

    # Execute Cell-Specific Ant Tasks
    case $CELL_NAME in
        "demodata")
            cat db.properties
            ant -f data_build.xml create_crcdata_tables_release_1-8
            ant -f data_build.xml create_procedures_release_1-8
            ant -f data_build.xml db_demodata_load_data
            ;;
        "hive")
            ant -f data_build.xml create_hivedata_tables_release_1-8
            ant -f data_build.xml db_hivedata_load_data
            ;;
        "imdata")
            ant -f data_build.xml create_imdata_tables_release_1-8
            ant -f data_build.xml db_imdata_load_data
            ;;
        "metadata")
            ant -f data_build.xml create_metadata_tables_release_1-8
            ant -f data_build.xml db_metadata_load_data
            ;;
        "pm")
            echo "Updating PM access SQL..."
            # Replace placeholder with actual Wildfly Host/Port dynamically
            sed -i "s/localhost:9090/$I2B2_WILDFLY_HOST:$I2B2_WILDFLY_PORT/g" ./scripts/demo/pm_access_insert_data.sql
            
            ant -f data_build.xml create_pmdata_tables_release_1-8
            ant -f data_build.xml create_triggers_release_1-8
            ant -f data_build.xml db_pmdata_load_data
            ;;
        "workdata")
            ant -f data_build.xml create_workdata_tables_release_1-8
            ant -f data_build.xml db_workdata_load_data
            ;;
    esac
done

# --- 5. Final Cleanup & Next Steps ---
echo "Initialization Completed successfully."

echo "================================================="
echo "Next steps:"

echo "Scenario: Production install on existing i2b2 database - Run reconfigure_pm_hive.sh script with required arguments:"

echo "bash reconfigure_pm_hive.sh $CORE_SERVER_IP $CORE_SERVER_PORT $TARGET_SERVER $TARGET_PORT $TARGET_CRC_USER $TARGET_ONT_USER $TARGET_PM_USER $TARGET_HIVE_USER $TARGET_WD_USER $SCHEMA_PASS $SERVICE_NAME"

echo "Run mod_env_file.sh script with required arguments:"
echo "# sh mod_env_file.sh $TARGET_SERVER $TARGET_PORT 'dummy_user' 'dummy_pass' $DB_SERVICE"

echo "Run restart_containers.sh script:"
echo "# sh restart_containers.sh"