#!/bin/bash

# ==============================================================================
# Script Name: test_case.sh
# Description: Runs integration tests for the i2b2 core-server against an ORACLE 
#              database. It modifies docker-compose.yml, starts the containers, 
#              installs dependencies, configures datasources, and runs ant tests.
# Usage: 
#   sh test_case.sh [I2B2_CORE_SERVER_BRANCH] [I2B2_DATA_BRANCH]
# Example:
#   sh test_case.sh master master
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

export i2b2_core_server_branch="${1:-master}"
export i2b2_data_branch="${2:-master}"

# Provide defaults for docker env vars if they are not set in the environment
docker_username="${docker_username:-i2b2}"
docker_reponame="${docker_reponame:-i2b2-docker}"

core_server_image="${docker_username}/${docker_reponame}:i2b2-core-server_${i2b2_core_server_branch}"
oracle_image="${docker_username}/${docker_reponame}:i2b2-data-oracle_${i2b2_data_branch}"

echo "=========================================="
echo " Setting up Docker images"
echo " Core Server: $core_server_image"
echo " Oracle Data : $oracle_image"
echo "=========================================="

#updating docker image tag
sed -i "s|i2b2/i2b2-core-server:\${I2B2_CORE_SERVER_TAG}|${core_server_image}|g" docker-compose.yml
sed -i "s|i2b2/i2b2-data-oracle:\${I2B2_DATA_ORACLE_TAG}|${oracle_image}|g" docker-compose.yml

echo "Starting containers..."
docker compose up -d 
docker ps 

#waiting for core-server and database to get started
echo "Waiting for core-server and database to initialize (150 seconds)..."
sleep 150

cd test_case_integration/

#copying db.properties & *.xml files 
echo "Copying db.properties & *.xml files..."
docker cp . i2b2-core-server:/opt/jboss/wildfly/

#install apt & git
echo "Installing apt dependencies and git..."
docker exec -i i2b2-core-server bash -c "apt-get clean && apt-get update --fix-missing && apt-get install -y ant git vim"

#cloning i2b2-core-server repo
echo "Cloning i2b2-core-server repo (branch: $i2b2_core_server_branch)..."
docker exec -e i2b2_core_server_branch="$i2b2_core_server_branch" -i i2b2-core-server bash -c "cd /opt/jboss/wildfly && git clone http://github.com/adityapersistent/i2b2-core-server -b $i2b2_core_server_branch"

#updating jboss location & core-server services URL
echo "Updating jboss location & core-server services URL..."
docker exec -i i2b2-core-server bash -c "cd /opt/jboss/wildfly/ && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.crc/build.properties && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.fr/build.properties && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.im/build.properties && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.ontology/build.properties && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.pm/build.properties && \
    cp build.properties i2b2-core-server/edu.harvard.i2b2.workplace/build.properties && \
    sed -i 's|jboss.home=/opt/wildfly-37\.0\.1\.Final|jboss.home=/opt/jboss/wildfly|' i2b2-core-server/edu.harvard.i2b2.server-common/build.properties"

#updating Datasource  - ORACLE 
echo "Updating Datasource - ORACLE..."
docker exec -i i2b2-core-server bash -c "cd /opt/jboss/wildfly/ && \
    cp crc-ds.xml i2b2-core-server/edu.harvard.i2b2.crc/etc/jboss/crc-ds.xml && \
    cp im-ds.xml i2b2-core-server/edu.harvard.i2b2.im/etc/jboss/im-ds.xml && \
    cp ont-ds.xml i2b2-core-server/edu.harvard.i2b2.ontology/etc/jboss/ont-ds.xml && \
    cp pm-ds.xml i2b2-core-server/edu.harvard.i2b2.pm/etc/jboss/pm-ds.xml && \
    cp work-ds.xml i2b2-core-server/edu.harvard.i2b2.workplace/etc/jboss/work-ds.xml"

#resolving unmappable character (0xC2) for encoding US-ASCII issue (UTF-8)
echo "Fixing source code encoding issue..."
docker exec -i i2b2-core-server bash -c "sed -i 's/[^\x00-\x7F]//g' /opt/jboss/wildfly/i2b2-core-server/edu.harvard.i2b2.crc/src/server/edu/harvard/i2b2/crc/delegate/quartz/SchedulerInfoBean.java"

# running ant test cases for PM, ONT, CRC, WD, IM
echo "Running ant test cases for PM, ONT, CRC, WD, IM..."
docker exec -i i2b2-core-server bash -c "cd /opt/jboss/wildfly/i2b2-core-server/edu.harvard.i2b2.server-common && \
    ant -v && ant init && \
    cd ../edu.harvard.i2b2.pm/ && ant test && \
    cd ../edu.harvard.i2b2.ontology/ && ant test && \
    cd ../edu.harvard.i2b2.crc/ && ant test && \
    cd ../edu.harvard.i2b2.workplace/ && ant test && \
    cd ../edu.harvard.i2b2.im/ && ant test"

echo "All tests executed successfully."
