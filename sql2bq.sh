#!/usr/bin/env bash

if [[ "$#" -ne 8 ]]; then
	echo "ERROR: Illegal number of arguments."
	echo "Usage: ./sql2bq.sh <schema.table> <sql-project-id> <sql-region> <sql-instance-name> <fully-qualified-table-name> <sql-username> <sql-password> <staging-bucket> <bq-project-id>"
	exit 1;
fi

function clean_and_exit () {
    echo "$1"
    pkill cloud_sql_proxy
    # Delete BQ table
    # Delete file in staging bucket
    exit 1;
}

SQL_PROJECT=$1
SQL_PROJECT_REGION=$2
INSTANCE=$3
TABLE_NAME=$4
MYSQL_USER=$5
MYSQL_PASSWORD=$6
STAGING_BUCKET=$7
BQ_PROJECT=$8

# Remove characters including and after . to get schema (or data-set name)
SCHEMA_NAME=$(echo "${TABLE_NAME}" | sed "s/\..*//")


nohup ./cloud_sql_proxy --instances="${SQL_PROJECT}":"${SQL_PROJECT_REGION}":"${INSTANCE}"=tcp:3306 &

sleep 2

QUERY="SHOW FIELDS FROM ${TABLE_NAME}"

# Get columns from mysql
COLUMNS=$(mysql -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --host 127.0.0.1 "${SCHEMA_NAME}" -e "${QUERY}" --batch --silent) \
    || clean_and_exit "Could not get table definition for ${SCHEMA_NAME}. Exiting..."

# SQL proxy no longer necessary
pkill cloud_sql_proxy

# Retain only the first two fields (Column Name, Type, Nullable)
COLUMNS=$(echo "${COLUMNS}" | cut -d$'\t' --fields=1,2,3)

# Remove brackets
COLUMNS=$(echo "${COLUMNS}" | sed s/\(.*\)// )

# Temporary file for BigQuery schema
TMP_BQ_SCHEMA_FILE=$(mktemp /tmp/sql2bq.XXXXX)

python sql2bq.py "${COLUMNS}" > "${TMP_BQ_SCHEMA_FILE}" \
    || clean_and_exit "Could not convert SQL table definition to BigQuery schema. Exiting..."

# Update IAM programmatically?
gcloud sql export csv "${INSTANCE}" "${STAGING_BUCKET}${TABLE_NAME}.csv" --query="SELECT * FROM ${TABLE_NAME}" \
    || clean_and_exit "Could not export table ${TABLE_NAME} to ${STAGING_BUCKET}. Exiting..."

bq show --project_id="${BQ_PROJECT}" "${SCHEMA_NAME}" > /dev/null

if [[ "$?" -ne 0 ]]; then
	echo "Data set ${SCHEMA_NAME} does not exist. Creating data set..."
	bq mk --project_id="${BQ_PROJECT}" "${SCHEMA_NAME}"
fi

# Check that table does not exist
bq show --project_id="${BQ_PROJECT}" "${TABLE_NAME}" > /dev/null \
    && clean_and_exit "Table ${TABLE_NAME} already exists. Exiting..."

bq mk --project_id="${BQ_PROJECT}" --schema="${TMP_BQ_SCHEMA_FILE}" "${TABLE_NAME}" \
    || clean_and_exit "Could not create table ${TABLE_NAME} in BigQuery. Exiting..."

bq load --project_id="${BQ_PROJECT}" --null_marker="\"N" --source_format=CSV "${TABLE_NAME}" "${STAGING_BUCKET}${TABLE_NAME}.csv" \
    || clean_and_exit "Could not load export from ${STAGING_BUCKET}${TABLE_NAME} to BigQuery ${TABLE_NAME}. Exiting..."


exit 0;
