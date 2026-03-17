# prerequisite - i2b2 docker demo working
#sh init_db.sh dummy_host 5432 i2b2 demouser i2b2 i2b2demodata i2b2metadata i2b2pm i2b2hive i2b2workdata i2b2-core-server 8080

#sh init_db.sh target_ip target_port target_username target_password target_db_name target_crc_schema target_ont_schema target_pm_schema target_hive_schema target_wd_schema core_server_ip core_server_port

host=$1
port=$2
username=$3
password=$4
dbname=$5

crc_db_schema=$6
ont_db_schema=$7
pm_db_schema=$8
hive_db_schema=$9
wd_db_schema=${10}

core_server_ip=${11}
core_server_port=${12}

echo "Host- $host Port- $port Username- $username Password- $password DBname- $dbname"
if [ "$host" = "dummy_host" ]; then
  
    docker_network_gateway_ip=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}') 
    host=$docker_network_gateway_ip
    sh create_native_pg_server.sh #install native postgresql database locally and update the configuration 
fi

echo "waiting for database & docker container to get start"
sleep 180

echo "Dump process started"

docker exec -i -e PG_PASSWORD=demouser i2b2-data-pgsql pg_dump -U postgres -d i2b2 -F c --no-owner --no-acl -f i2b2_db_backup.dump
#dump - 1min approx.
echo "Dump process completed"
echo "restore process started"

echo $host $port $username $dbname $password
docker exec -i -e PGPASSWORD=$password i2b2-data-pgsql pg_restore  -h $host -p $port -U $username -d $dbname  -F c --no-owner i2b2_db_backup.dump

echo "Restore process completed"
#within 2 minutes

echo "Completed backup and restore for all the databases."
echo "Updating hive and pm cell for production database"
sh upgrade_pm_hive.sh $host $port $username $password $dbname $crc_db_schema $ont_db_schema $pm_db_schema $hive_db_schema $wd_db_schema $core_server_ip $core_server_port

echo "run mod_env_file.sh script with required arguments"
# sh mod_env_file.sh $host $port $username $password $dbname
echo "run restart_containers.sh script"
# sh restart_containers.sh

