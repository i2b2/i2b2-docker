#!/bin/bash

# --- 1. Initialization & Inputs ---
echo "Starting i2b2 Remote Database Initialization..."

# Root path from your environment i2b2-data repo path
root="/mnt/c/Users/Admin/Desktop/oracle_tes/i2b2-data"

DB_IP="172.30.208.1"
DB_SERVICE="FREEPDB1"
SYS_PASS="MyStrongPass123"
DEMO_PASS="demouser"
DB_PORT=1521
echo $DB_IP

localhost 
ls
PWD

cd $root

# --- 2. Create Users/Schema via SQL*Plus ---
echo "Creating i2b2 users on remote database..."
# This assumes create_users.sql is in the current directory
sqlplus -s sys/$SYS_PASS@$DB_IP:$DB_PORT/$DB_SERVICE as sysdba @create_users.sql

# --- 3. Process i2b2 Cells ---
# Define the cells and their relative paths
cells=("demodata" "hive" "imdata" "metadata" "pm" "workdata")
paths=(
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Crcdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Hivedata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Imdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Metadata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Pmdata"
    "edu.harvard.i2b2.data/Release_1-8/NewInstall/Workdata"
)

for i in "${!cells[@]}"; do
    CELL_NAME=${cells[$i]}
    CELL_PATH=${paths[$i]}
    
    echo "------------------------------------------"
    echo "Processing Cell: $CELL_NAME"
    cd "$root/$CELL_PATH"

    # Update db.properties
    # Logic: Replace localhost with DB_IP, 1521 with DB_PORT, PWD with DEMO_PASS
    # We use a template db.properties to generate the active one
    cat "$root/db.properties" | \
    sed "s/localhost/$DB_IP/" | \
    sed "s/1521/$DB_PORT/" | \
    sed "s/FREEPDB1/$DB_SERVICE/" | \
    sed "s/PWD/$DEMO_PASS/" | \
    sed "s/USER_NAME/i2b2${CELL_NAME,,}/" > db.properties

    # Execute Ant Tasks
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
            # Special handling for PM address insertion
            echo "Updating PM access SQL..."
            # Assuming variables I2B2_WILDFLY_HOST/PORT are set in environment
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

# --- 4. Final Cleanup ---
# echo "Tasks complete. Cleaning up source files..."
# cd $root
# # rm -rf edu.harvard.i2b2.data
echo "Done."