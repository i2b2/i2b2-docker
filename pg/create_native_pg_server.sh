#!/bin/bash

# ==============================================================================
# Script Name: create_native_pg_server.sh
# Description: Installs and configures a native PostgreSQL server for i2b2.
#              Sets up the database, user, scram-sha-256 encryption, and 
#              configures network access including Docker subnets.
# Usage: 
#   sh create_native_pg_server.sh
# Configuration:
#   Can override default parameters by exporting variables before running:
#   export POSTGRES_VERSION=16; export DB_NAME="i2b2" ...
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

POSTGRES_VERSION=16
DB_NAME="i2b2"
DB_USER="i2b2"
DB_PASSWORD="demouser"

PG_CONF="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"

echo "Updating packages..."
sudo apt-get update

echo "Installing PostgreSQL $POSTGRES_VERSION..."
sudo apt-get install -y postgresql-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION

if [ ! -f "$PG_CONF" ] || [ ! -f "$PG_HBA" ]; then
    echo "Error: PostgreSQL configuration files not found at expected paths."
    exit 1
fi

echo "Temporarily allowing local trust for postgres..."
sudo sed -i "s/^local.*postgres.*peer/local all postgres trust/" $PG_HBA

echo "Restarting PostgreSQL..."
sudo systemctl restart postgresql

echo "Waiting for PostgreSQL to become ready..."
MAX_RETRIES=15
RETRY_COUNT=0
until pg_isready -U postgres > /dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Error: PostgreSQL failed to start in time."
    exit 1
fi

echo "Configuring PostgreSQL SCRAM password encryption..."
if grep -q "^#password_encryption" $PG_CONF; then
  sudo sed -i "s/^#password_encryption.*/password_encryption = scram-sha-256/" $PG_CONF
elif ! grep -q "^password_encryption" $PG_CONF; then
  echo "password_encryption = scram-sha-256" | sudo tee -a $PG_CONF
fi

echo "Creating database and users..."

# Create database safely if it doesn't exist
if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 <<EOF
ALTER USER postgres PASSWORD '$DB_PASSWORD';

DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE ROLE $DB_USER LOGIN SUPERUSER PASSWORD '$DB_PASSWORD';
   END IF;
END
\$\$;

GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "Enabling external connections..."

sudo sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" $PG_CONF

echo "Updating pg_hba.conf authentication rules..."

sudo sed -i "s/^local.*all.*peer/local all all scram-sha-256/" $PG_HBA
sudo sed -i "s/^host.*all.*127.0.0.1.*ident/host all all 127.0.0.1\/32 scram-sha-256/" $PG_HBA

echo "Detecting Docker network..."

if docker network inspect i2b2-net >/dev/null 2>&1; then
    subnet=$(docker network inspect i2b2-net -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')

    echo "Allowing Docker subnet: $subnet"

    if ! grep -q "$subnet" $PG_HBA; then
        echo "host $DB_NAME all $subnet scram-sha-256" | sudo tee -a $PG_HBA
    fi
else
    echo "Docker network i2b2-net not found. Skipping subnet rule."
fi

echo "Restarting PostgreSQL..."
sudo systemctl restart postgresql

echo "PostgreSQL setup completed successfully."