#!/usr/bin/env bash

# Checks

# Permissions
# sql_dump, bq_load, bq_create_table, vm_instance_create, vm_instance_delete

if [[ "$#" -ne 1 ]]; then
	echo "ERROR: Illegal number of arguments."
	echo "Usage: sql2bq <schema.table>"
	exit 1;
fi

TABLE_NAME=$1
MYSQL_USER=0
MYSQL_PASSWORD=0
PROJECT=0
INSTANCE=0
DATA_SET=0
STAGING_BUCKET=0

echo 'Starting the proxy'

nohup ./cloud_sql_proxy --instances=tank-io-0:europe-west1:sql2bq=tcp:3306 &

sleep 3

QUERY="SHOW FIELDS FROM ${TABLE_NAME}"

# Get columns from mysql
COLUMNS=$(mysql -u root -pjEiFaflHlo16IJw4 --host 127.0.0.1 test_db_1 -e "${QUERY}" --batch --silent)

# SQL proxy no longer necessary
pkill cloud_sql_proxy

# Retain only the first two fields (Column Name, Type)
COLUMNS=$(echo "${COLUMNS}" | cut -d$'\t' --fields=1,2,3)

# Remove brackets
COLUMNS=$(echo "${COLUMNS}" | sed s/\(.*\)// )

COLUMNS_JSON=$(python sql2bq.py "${COLUMNS}")

echo ${COLUMNS_JSON}

gcloud sql export csv sql2bq "gs://sql2bq/test_db_1.person.csv" --query="SELECT * FROM test_db_1.person"


exit 0;

