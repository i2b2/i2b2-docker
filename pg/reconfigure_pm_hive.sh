#!/bin/bash

# ==============================================================================
# Script Name: reconfigure_pm_hive.sh
# Description: Reconfigures the PM and HIVE databases with new target details
#              for the PostgreSQL environment.
# Usage: 
#   sh reconfigure_pm_hive.sh <TARGET_SERVER> <TARGET_PORT> <TARGET_USER> \
#                             <TARGET_PASSWORD> <TARGET_DB_NAME> <TARGET_CRC_SCHEMA> \
#                             <TARGET_ONT_SCHEMA> <TARGET_PM_SCHEMA> <TARGET_HIVE_SCHEMA> \
#                             <TARGET_WD_SCHEMA> <CORE_SERVER_IP> <CORE_SERVER_PORT>
# Example:
#   sh reconfigure_pm_hive.sh localhost 5432 i2b2 demouser i2b2 i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata i2b2-core-server 8080
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

if [ "$#" -lt 12 ]; then
    echo "Error: Missing arguments. 12 arguments are required."
    echo "Usage: $0 TARGET_SERVER TARGET_PORT TARGET_USER TARGET_PASSWORD TARGET_DB_NAME TARGET_CRC_SCHEMA TARGET_ONT_SCHEMA TARGET_PM_SCHEMA TARGET_HIVE_SCHEMA TARGET_WD_SCHEMA CORE_SERVER_IP CORE_SERVER_PORT"
    exit 1
fi

TARGET_SERVER="$1"
TARGET_PORT="$2"
TARGET_USER="$3"
TARGET_PASSWORD="$4"
TARGET_DB_NAME="$5"

TARGET_CRC_SCHEMA="$6"
TARGET_ONT_SCHEMA="$7"
TARGET_PM_SCHEMA="$8"
TARGET_HIVE_SCHEMA="$9"
TARGET_WD_SCHEMA="${10}"

CORE_SERVER_IP="${11}"
CORE_SERVER_PORT="${12}"

if [ "$TARGET_SERVER" = "localhost" ]; then
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER="$docker_network_gateway_ip"
    echo "Target Server IP- $TARGET_SERVER" 
fi  

echo "Injecting PM and HIVE SQL configuration..."

# Execute both SQL statements in a single docker exec call via standard input
docker exec -i -e PGPASSWORD="$TARGET_PASSWORD" i2b2-data-pgsql psql -h "$TARGET_SERVER" -p "$TARGET_PORT" -U "$TARGET_USER" -d "$TARGET_DB_NAME" <<EOF
SET search_path TO ${TARGET_PM_SCHEMA};

INSERT INTO PM_CELL_DATA 
    (CELL_ID, PROJECT_PATH, NAME, METHOD_CD, URL, CAN_OVERRIDE, STATUS_CD) 
VALUES
    ('CRC', '/', 'Data Repository', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/QueryToolService/', 1, 'A'),
    ('FRC', '/', 'File Repository ', 'SOAP', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/FRService/', 1, 'A'),
    ('ONT', '/', 'Ontology Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/OntologyService/', 1, 'A'),
    ('WORK', '/', 'Workplace Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/WorkplaceService/', 1, 'A'),
    ('IM', '/', 'IM Cell', 'REST', 'http://${CORE_SERVER_IP}:${CORE_SERVER_PORT}/i2b2/services/IMService/', 1, 'A')
ON CONFLICT (CELL_ID, PROJECT_PATH) 
DO UPDATE SET 
    NAME = EXCLUDED.NAME, 
    METHOD_CD = EXCLUDED.METHOD_CD, 
    URL = EXCLUDED.URL, 
    CAN_OVERRIDE = EXCLUDED.CAN_OVERRIDE, 
    STATUS_CD = EXCLUDED.STATUS_CD;

SET search_path TO ${TARGET_HIVE_SCHEMA};
UPDATE crc_db_lookup SET c_db_fullschema = '${TARGET_CRC_SCHEMA}';
UPDATE ont_db_lookup SET c_db_fullschema = '${TARGET_ONT_SCHEMA}';
UPDATE work_db_lookup SET c_db_fullschema = '${TARGET_WD_SCHEMA}';
EOF

echo "Updated pm and hive cell successfully."