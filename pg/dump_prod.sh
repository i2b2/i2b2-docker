docker-compose up -d i2b2-data-pgsql i2b2-core-server i2b2-webclient

host=$1
port=$2
username=$3
password=$4
dbname=$5

echo "Host- $host Port- $port Username- $username Password- $password DBname- $dbname"
echo "waiting for database docker container to get start"
sleep 180

echo "Dump process started"

docker exec -i -e PG_PASSWORD=demouser i2b2-data-pgsql pg_dump -U postgres -d i2b2 -F c --no-owner --no-acl -f i2b2_db_backup.dump
#dump - 1min approx.
echo "Dump process completed"


#install postgresql database locally and update the configuration 
#bash install_postgresql.sh

echo "restore process started"

docker exec -i -e PGPASSWORD=$password i2b2-data-pgsql pg_restore  -h $host -p $port -U $username -d $dbname  -F c --no-owner i2b2_db_backup.dump

echo "Restore process completed"
#within 2 minutes


default_host="_IP=i2b2-data-pgsql"
default_port="_PORT=5432"
default_username="_USER=i2b2"
default_password="_PASS=demouser"
default_dbname="_DB=i2b2"


#updating the .env file

sed -i "s/${default_host}/_IP=${host}/g" .env
sed -i "s/${default_port}/_PORT=${port}/g" .env
sed -i "s/${default_username}/_USER=${username}/g" .env
sed -i "s/${default_password}/_PASS=${password}/g" .env
sed -i "s/${default_dbname}/_DB=${dbname}/g" .env



#docker rm -f i2b2-data-pgsql #uncomment this line if you have space issue

docker compose down
docker compose up -d i2b2-core-server i2b2-webclient

echo "Started i2b2-core-server & i2b2-webclient Docker containers"
echo "logs of i2b2-core-server container    - "
sleep 10 
docker logs -f i2b2-core-server




