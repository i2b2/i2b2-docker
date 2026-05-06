#!/bin/bash

# ==============================================================================
# Script Name: reconfigure_pm_hive.sh
# Description: Reconfigures the PM and HIVE databases with new target details.
# Usage: 
#   sh reconfigure_pm_hive.sh <CORE_SERVER_IP> <CORE_SERVER_PORT> <TARGET_SERVER> \
#                             <TARGET_PORT> <TARGET_CRC_DB> <TARGET_ONT_DB> \
#                             <TARGET_PM_DB> <TARGET_HIVE_DB> <TARGET_WD_DB> \
#                             <TARGET_USER> <TARGET_PASS>
# Example:
#   sh reconfigure_pm_hive.sh i2b2-core-server 8080 localhost 1432 i2b2demodata.dbo i2b2metadata.dbo i2b2pm i2b2hive i2b2workdata.dbo SA '<YourStrong@Passw0rd>'
# ==============================================================================

if [ "$#" -lt 11 ]; then
    echo "Error: Missing arguments. 11 arguments are required."
    echo "Usage: $0 CORE_SERVER_IP CORE_SERVER_PORT TARGET_SERVER TARGET_PORT TARGET_CRC_DB TARGET_ONT_DB TARGET_PM_DB TARGET_HIVE_DB TARGET_WD_DB TARGET_USER TARGET_PASS"
    exit 1
fi

CORE_SERVER_IP=$1
CORE_SERVER_PORT=$2

TARGET_SERVER=$3
TARGET_PORT=$4
TARGET_CRC_DB=$5
TARGET_ONT_DB=$6
TARGET_PM_DB=$7
TARGET_HIVE_DB=$8
TARGET_WD_DB=$9

TARGET_USER=${10}
TARGET_PASS=${11}

if [ "$TARGET_SERVER" = "localhost" ]; then

    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER=$docker_network_gateway_ip
    echo "Target Server IP- " $TARGET_SERVER 
fi  

pm_sql="USE i2b2pm;
MERGE INTO PM_CELL_DATA AS target
USING (
    VALUES
    ('CRC', '/', 'Data Repository', 'REST', 'http://$CORE_SERVER_IP:$CORE_SERVER_PORT/i2b2/services/QueryToolService/', 1, 'A'),
    ('FRC', '/', 'File Repository ', 'SOAP', 'http://$CORE_SERVER_IP:$CORE_SERVER_PORT/i2b2/services/FRService/', 1, 'A'),
    ('ONT', '/', 'Ontology Cell', 'REST', 'http://$CORE_SERVER_IP:$CORE_SERVER_PORT/i2b2/services/OntologyService/', 1, 'A'),
    ('WORK', '/', 'Workplace Cell', 'REST', 'http://$CORE_SERVER_IP:$CORE_SERVER_PORT/i2b2/services/WorkplaceService/', 1, 'A'),
    ('IM', '/', 'IM Cell', 'REST', 'http://$CORE_SERVER_IP:$CORE_SERVER_PORT/i2b2/services/IMService/', 1, 'A')
) AS source (CELL_ID, PROJECT_PATH, NAME, METHOD_CD, URL, CAN_OVERRIDE, STATUS_CD)
ON (target.CELL_ID = source.CELL_ID AND target.PROJECT_PATH = source.PROJECT_PATH)
WHEN MATCHED THEN
    UPDATE SET 
        NAME = source.NAME, 
        METHOD_CD = source.METHOD_CD, 
        URL = source.URL, 
        CAN_OVERRIDE = source.CAN_OVERRIDE, 
        STATUS_CD = source.STATUS_CD
WHEN NOT MATCHED THEN
    INSERT (CELL_ID, PROJECT_PATH, NAME, METHOD_CD, URL, CAN_OVERRIDE, STATUS_CD)
    VALUES (source.CELL_ID, source.PROJECT_PATH, source.NAME, source.METHOD_CD, source.URL, source.CAN_OVERRIDE, source.STATUS_CD);"

hive_sql="USE i2b2hive;
UPDATE crc_db_lookup SET c_db_fullschema = '$TARGET_CRC_DB';
UPDATE ont_db_lookup SET c_db_fullschema = '$TARGET_ONT_DB';
UPDATE work_db_lookup SET c_db_fullschema = '$TARGET_WD_DB';"

echo "Injecting PM and HIVE SQL configuration..."

# Execute both SQL statements in a single docker exec call via standard input for better performance
printf "%s\nGO\n%s\nGO\n" "$pm_sql" "$hive_sql" | docker exec -i i2b2-data-mssql /opt/mssql-tools/bin/sqlcmd -S "$TARGET_SERVER,$TARGET_PORT" -U "$TARGET_USER" -P "$TARGET_PASS"