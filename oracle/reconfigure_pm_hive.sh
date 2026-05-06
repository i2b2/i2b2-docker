#!/bin/bash

# ==============================================================================
# Script Name: reconfigure_pm_hive.sh
# Description: Reconfigures the PM and HIVE tables connecting directly as owners.
# Usage: 
#   sh reconfigure_pm_hive.sh <CORE_SERVER_IP> <CORE_SERVER_PORT> <TARGET_SERVER> \
#                                    <TARGET_PORT> <TARGET_CRC_USER> <TARGET_ONT_USER> \
#                                    <TARGET_PM_USER> <TARGET_HIVE_USER> <TARGET_WD_USER> \
#                                    <SCHEMA_PASS> <SERVICE_NAME>
# Example:
#   sh reconfigure_pm_hive.sh i2b2-core-server 8080 localhost 1522 I2B2DEMODATA I2B2METADATA I2B2PM I2B2HIVE I2B2WORKDATA demouser FREEPDB1
# ==============================================================================

if [ "$#" -lt 11 ]; then
    echo "Error: Missing arguments. 11 arguments are required."
    echo "Usage: $0 CORE_SERVER_IP CORE_SERVER_PORT TARGET_SERVER TARGET_PORT TARGET_CRC_USER TARGET_ONT_USER TARGET_PM_USER TARGET_HIVE_USER TARGET_WD_USER SCHEMA_PASS SERVICE_NAME"
    exit 1
fi

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

if [ "$TARGET_SERVER" = "localhost" ]; then
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER=$docker_network_gateway_ip
    echo "Target Server IP: $TARGET_SERVER" 
fi  

# ==========================================
# 1. Update PM Data (Connecting as PM User)
# ==========================================
echo "Injecting PM configuration as ${TARGET_PM_USER}..."

pm_sql="
MERGE INTO PM_CELL_DATA dest
USING (
    SELECT 'CRC' as CELL_ID, '/' as PROJECT_PATH, 'Data Repository' as NAME, 'REST' as METHOD_CD, 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/QueryToolService/' as URL, 1 as CAN_OVERRIDE, 'A' as STATUS_CD FROM DUAL UNION ALL
    SELECT 'FRC', '/', 'File Repository ', 'SOAP', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/FRService/', 1, 'A' FROM DUAL UNION ALL
    SELECT 'ONT', '/', 'Ontology Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/OntologyService/', 1, 'A' FROM DUAL UNION ALL
    SELECT 'WORK', '/', 'Workplace Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/WorkplaceService/', 1, 'A' FROM DUAL UNION ALL
    SELECT 'IM', '/', 'IM Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/IMService/', 1, 'A' FROM DUAL
) src
ON (dest.CELL_ID = src.CELL_ID AND dest.PROJECT_PATH = src.PROJECT_PATH)
WHEN MATCHED THEN
    UPDATE SET dest.NAME = src.NAME, dest.METHOD_CD = src.METHOD_CD, dest.URL = src.URL, dest.CAN_OVERRIDE = src.CAN_OVERRIDE, dest.STATUS_CD = src.STATUS_CD
WHEN NOT MATCHED THEN
    INSERT (CELL_ID, PROJECT_PATH, NAME, METHOD_CD, URL, CAN_OVERRIDE, STATUS_CD)
    VALUES (src.CELL_ID, src.PROJECT_PATH, src.NAME, src.METHOD_CD, src.URL, src.CAN_OVERRIDE, src.STATUS_CD);

COMMIT;
EXIT;
"

# Execute PM Block
echo "$pm_sql" | docker exec -i oracle23 sqlplus -s "${TARGET_PM_USER}/${SCHEMA_PASS}@${TARGET_SERVER}:${TARGET_PORT}/${SERVICE_NAME}"

# ============================================
# 2. Update HIVE Data (Connecting as HIVE User)
# ============================================
echo "Injecting HIVE configuration as ${TARGET_HIVE_USER}..."

hive_sql="
UPDATE crc_db_lookup SET c_db_fullschema = '${TARGET_CRC_USER}';
UPDATE ont_db_lookup SET c_db_fullschema = '${TARGET_ONT_USER}';
UPDATE work_db_lookup SET c_db_fullschema = '${TARGET_WD_USER}';

COMMIT;
EXIT;
"

# Execute HIVE Block
echo "$hive_sql" | docker exec -i oracle23 sqlplus -s "${TARGET_HIVE_USER}/${SCHEMA_PASS}@${TARGET_SERVER}:${TARGET_PORT}/${SERVICE_NAME}"

echo "Updated PM and HIVE cells successfully."