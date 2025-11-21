export i2b2_core_server_branch=$1

core_server_image=$docker_username/$docker_reponame:i2b2-core-server_$i2b2_core_server_branch
mssql_image=$docker_username/$docker_reponame:i2b2-data-mssql_latest

#updating docker image tag
# sed -i "s|i2b2/i2b2-webclient:\${I2B2_WEBCLIENT_TAG}|$docker_username/$docker_reponame:i2b2-webclient_latest|g" docker-compose.yml
sed -i "s|i2b2/i2b2-core-server:\${I2B2_CORE_SERVER_TAG}|$core_server_image|g" docker-compose.yml
sed -i "s|i2b2/i2b2-data-mssql:\${I2B2_DATA_MSSQL_TAG}|$mssql_image|g" docker-compose.yml
docker compose up -d 
docker ps 
#waiting for core-server and database to get started
sleep 150

cd test_case_integration/

#copying db.properties & *.xml files 
docker cp . i2b2-core-server:/opt/jboss/wildfly/

#install apt & git
docker exec -i i2b2-core-server bash -c "apt-get install -y ant git vim"

#set timezone to EST - using old core-server image - it will set only for this terminal session
# docker exec -i i2b2-core-server bash -c "apt update && apt install -y tzdata 
# ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime 
# dpkg-reconfigure -f noninteractive tzdata "

#cloning i2b2-core-server repo
docker exec -e i2b2_core_server_branch=$i2b2_core_server_branch -i i2b2-core-server bash -c "cd /opt/jboss/wildfly && git clone http://github.com/i2b2/i2b2-core-server -b $i2b2_core_server_branch"

#using mssql-jdbc-8.2.2.jre8.jar jdbc mssql driver for testing
docker exec -i i2b2-core-server bash -c "cp -v /opt/jboss/wildfly/customization/mssql-jdbc-8.2.2.jre8.jar /opt/jboss/wildfly/i2b2-core-server/edu.harvard.i2b2.server-common/lib/jdbc/"

#updating jboss location & core-server services URL
docker exec -i i2b2-core-server bash -c " cd /opt/jboss/wildfly/  && cp build.properties i2b2-core-server/edu.harvard.i2b2.crc/build.properties && cp build.properties i2b2-core-server/edu.harvard.i2b2.fr/build.properties  && cp build.properties i2b2-core-server/edu.harvard.i2b2.im/build.properties  && cp build.properties i2b2-core-server/edu.harvard.i2b2.ontology/build.properties  && cp build.properties i2b2-core-server/edu.harvard.i2b2.pm/build.properties && cp build.properties i2b2-core-server/edu.harvard.i2b2.workplace/build.properties && sed -i 's|jboss.home=/opt/wildfly-37\.0\.1\.Final|jboss.home=/opt/jboss/wildfly|' i2b2-core-server/edu.harvard.i2b2.server-common/build.properties "

#updating Datasource  - MSSQL 
docker exec -i i2b2-core-server bash -c " cd /opt/jboss/wildfly/ && cp crc-ds.xml i2b2-core-server/edu.harvard.i2b2.crc/etc/jboss/crc-ds.xml && cp im-ds.xml i2b2-core-server/edu.harvard.i2b2.im/etc/jboss/im-ds.xml && cp ont-ds.xml i2b2-core-server/edu.harvard.i2b2.ontology/etc/jboss/ont-ds.xml && cp pm-ds.xml i2b2-core-server/edu.harvard.i2b2.pm/etc/jboss/pm-ds.xml && cp work-ds.xml i2b2-core-server/edu.harvard.i2b2.workplace/etc/jboss/work-ds.xml "

#resolving unmappable character (0xC2) for encoding US-ASCII issue (UTF-8)
docker exec -i i2b2-core-server bash -c " sed -i 's/[^\x00-\x7F]//g' /opt/jboss/wildfly/i2b2-core-server/edu.harvard.i2b2.crc/src/server/edu/harvard/i2b2/crc/delegate/quartz/SchedulerInfoBean.java "

#verifying the timezone EST 
# docker exec -i i2b2-core-server bash -c "date"
# docker exec -i i2b2-data-mssql bash -c "date"

# running ant test cases for PM, ONT, CRC, WD 
#pending for FR, IM
docker exec -i i2b2-core-server bash -c " cd /opt/jboss/wildfly/i2b2-core-server/edu.harvard.i2b2.server-common &&  ant -v && ant init && cd ../edu.harvard.i2b2.pm/ && ant test && cd ../edu.harvard.i2b2.ontology/ && ant test && cd ../edu.harvard.i2b2.crc/ && ant test && cd ../edu.harvard.i2b2.workplace/ && ant test "
