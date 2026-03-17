#sh upgrade_pm_hive.sh dummy_host 5432 i2b2 demouser i2b2 i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata i2b2-core-server 8080

#sh upgrade_pm_hive.sh TARGET_SERVER TARGET_PORT TARGET_USER TARGET_PASSWORD TARGET_DB_NAME TARGET_CRC_SCHEMA TARGET_ONT_SCHEMA TARGET_PM_SCHEMA TARGET_HIVE_SCHEMA TARGET_WD_SCHEMA CORE_SERVER_IP CORE_SERVER_PORT

TARGET_SERVER=$1
TARGET_PORT=$2
TARGET_USER=$3
TARGET_PASSWORD=$4
TARGET_DB_NAME=$5

TARGET_CRC_SCHEMA=$6
TARGET_ONT_SCHEMA=$7
TARGET_PM_SCHEMA=$8
TARGET_HIVE_SCHEMA=$9
TARGET_WD_SCHEMA=${10}

CORE_SERVER_IP=${11}
CORE_SERVER_PORT=${12}

if [ $TARGET_SERVER = "dummy_host" ]; then

    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    TARGET_SERVER=$docker_network_gateway_ip
    echo "Target Server IP- " $TARGET_SERVER 
fi  

export pm_sql="""SET search_path TO i2b2pm;

INSERT INTO PM_CELL_DATA 
    (CELL_ID, PROJECT_PATH, NAME, METHOD_CD, URL, CAN_OVERRIDE, STATUS_CD) 
VALUES
    ('CRC', '/', 'Data Repository', 'REST', 'http://i2b2-core-server:8080/i2b2/services/QueryToolService/', 1, 'A'),
    ('FRC', '/', 'File Repository ', 'SOAP', 'http://i2b2-core-server:8080/i2b2/services/FRService/', 1, 'A'),
    ('ONT', '/', 'Ontology Cell', 'REST', 'http://i2b2-core-server:8080/i2b2/services/OntologyService/', 1, 'A'),
    ('WORK', '/', 'Workplace Cell', 'REST', 'http://i2b2-core-server:8080/i2b2/services/WorkplaceService/', 1, 'A'),
    ('IM', '/', 'IM Cell', 'REST', 'http://i2b2-core-server:8080/i2b2/services/IMService/', 1, 'A')
ON CONFLICT (CELL_ID, PROJECT_PATH) 
DO UPDATE SET 
    NAME = EXCLUDED.NAME, 
    METHOD_CD = EXCLUDED.METHOD_CD, 
    URL = EXCLUDED.URL, 
    CAN_OVERRIDE = EXCLUDED.CAN_OVERRIDE, 
    STATUS_CD = EXCLUDED.STATUS_CD;"""

pm_sql=$(echo "$pm_sql" | sed "s/i2b2pm/$TARGET_PM_SCHEMA/g")
pm_sql=$(echo "$pm_sql" | sed "s/i2b2-core-server/$CORE_SERVER_IP/g")
pm_sql=$(echo "$pm_sql" | sed "s/8080/$CORE_SERVER_PORT/g")

hive_sql="set search_path to i2b2hive ; update crc_db_lookup set c_db_fullschema = 'crc_db_name';update ont_db_lookup set c_db_fullschema = 'ont_db_name';update work_db_lookup set c_db_fullschema = 'wd_db_name';"

hive_sql=$(echo "$hive_sql" | sed "s/i2b2hive/$TARGET_HIVE_SCHEMA/g")
hive_sql=$(echo "$hive_sql" | sed "s/crc_db_name/$TARGET_CRC_SCHEMA/g")
hive_sql=$(echo "$hive_sql" | sed "s/ont_db_name/$TARGET_ONT_SCHEMA/g")
hive_sql=$(echo "$hive_sql" | sed "s/wd_db_name/$TARGET_WD_SCHEMA/g")

docker exec -i i2b2-data-pgsql bash -c "echo \"$pm_sql\" > /tmp/pm_sql.sql"
docker exec -i i2b2-data-pgsql bash -c "echo \"$hive_sql\" > /tmp/hive_sql.sql"

echo "$pm_sql"
echo "$hive_sql"

docker exec -i -e PGPASSWORD=$TARGET_PASSWORD i2b2-data-pgsql psql -h $TARGET_SERVER -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DB_NAME -f /tmp/pm_sql.sql

docker exec -i -e PGPASSWORD=$TARGET_PASSWORD i2b2-data-pgsql psql -h $TARGET_SERVER -p $TARGET_PORT -U $TARGET_USER -d $TARGET_DB_NAME -f /tmp/hive_sql.sql

echo "Updated pm and hive cell successfully"