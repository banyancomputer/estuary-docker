#!/bin/bash

#This is the script that is run when the docker container is started.
# Please see the Dockerfile for more information on the context of this script.

# Here for notation purposes
# The Workdir for the container
WORK_DIR=/app

# Read The Username and Password for the database from the script arguments
DB_USERNAME=$1
DB_PASSWORD=$2

# Our Infra Config
echo "WORK_DIR: $WORK_DIR"
echo "VOLUME_DIR: $VOLUME_DIR"

# Log our Deployment Config
echo "API_HOSTNAME: $API_HOSTNAME"
echo "WWW_HOSTNAME: $WWW_HOSTNAME"
echo "FULLNODE_API: $FULLNODE_API"
echo "DB_ENDPOINT: $DB_ENDPOINT"

# Define a Database Connection String
DB_CONN_STRING="$DB_TYPE=$DB_TYPE://$DB_USERNAME:$DB_PASSWORD@$DB_ENDPOINT/$DB_NAME"
# Define our Store Dirs
DATA_DIR=$VOLUME_DIR/blockstore
PRIV_DIR=$VOLUME_DIR/private

# We'll take PRIVATE_DIR existing as a test of whether or not we've initialized this Container
if test ! -d "$PRIV_DIR"; then
  echo "Initializing Estuary Node Credentials..."

  # This is needed to make sure we dont get 'too many open files' errors
  ulimit -n 100000 # This needs to be reaaally big for PostGres

  # Initialize our Mounts
  mkdir -p $DATA_DIR
  mkdir -p $PRIV_DIR

  # setup our node in the container
  ESTUARY_TOKEN=$(/app/estuary setup --database="$DB_CONN_STRING" --username=admin | grep Token | cut -d ' ' -f 3)
  # Check if we have a token
  if [ -z "$ESTUARY_TOKEN" ]; then
    echo "Failed to get Estuary Token"
    exit 1
  fi
  # Store our Admin Token
  echo "$ESTUARY_TOKEN" > $PRIVATE_DIR/token
  echo "Estuary Admin Key: $ESTUARY_TOKEN"
fi

# Start the Estuary node
# --database: is the connection string for our Postgres or MySQL DB. We use Postgres here.
# --datadir: Where the Node stores data
# --front-end-hostname: Where the front end is being served
echo "Starting Estuary Node..."
/app/estuary \
  --database="$DB_CONN_STRING" \
  --datadir="$DATA_DIR" \
  --front-end-hostname="$FRONTEND_HOSTNAME" \
  --logging=true