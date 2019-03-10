#!/usr/bin/env bash

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

nohup ./cloud_sql_proxy --instances=tank-io-0:europe-west1:sql2bq=tcp:3306 &

sleep 3

QUERY="SHOW FIELDS FROM ${TABLE_NAME}"

# Get columns from mysql
COLUMNS=$(mysql -u root -pjEiFaflHlo16IJw4 --host 127.0.0.1 test_db_1 -e "${QUERY}" --batch --silent)

# SQL proxy no longer necessary
pkill cloud_sql_proxy

# Retain only the first two fields (Column Name, Type, Nullable)
COLUMNS=$(echo "${COLUMNS}" | cut -d$'\t' --fields=1,2,3)

# Remove brackets
COLUMNS=$(echo "${COLUMNS}" | sed s/\(.*\)// )

# Temporary file for BigQuery schema
TMP_BQ_SCHEMA_FILE=$(mktemp /tmp/sql2bq.XXXXX)

python sql2bq.py "${COLUMNS}" > "${TMP_BQ_SCHEMA_FILE}" 

gcloud sql export csv sql2bq "gs://sql2bq/${TABLE_NAME}.csv" --query="SELECT * FROM test_db_1.person"

# Remove characters including and after . to get schema (or data-set name)
DATA_SET_NAME=$(echo "${TABLE_NAME}" | sed "s/\..*//")

bq show ${DATA_SET_NAME} > /dev/null

if [[ "$?" -ne 0 ]]; then
	echo "Dataset ${DATA_SET_NAME} does not exist. Creating dataset..."
	bq mk "${DATA_SET_NAME}"
fi

# Check that table does not exist
bq show ${TABLE_NAME} > /dev/null

if [[ "$?" -eq 0 ]]; then
	echo "Table ${TABLE_NAME} already exists. Exiting..."
	exit 1;
fi

bq mk --schema="${TMP_BQ_SCHEMA_FILE}" "${TABLE_NAME}"|| exit 1;

bq load --null_marker="\"N" --source_format="csv" "${TABLE_NAME}" "gs://sql2bq/${TABLE_NAME}.csv"

# Clean up resources

exit 0;
