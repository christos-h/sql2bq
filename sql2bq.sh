#!/usr/bin/env bash

if [[ "$#" -ne 8 ]]; then
	echo "ERROR: Illegal number of arguments."
	echo "Usage: ./sql2bq.sh <sql-project-id> <sql-region> <sql-instance-name> <fully-qualified-table-name> <sql-username> <sql-password> <staging-bucket> <bq-project-id>"
	exit 1;
fi

SQL_PROJECT=$1
SQL_PROJECT_REGION=$2
INSTANCE=$3
TABLE_NAME=$4
MYSQL_USER=$5
MYSQL_PASSWORD=$6
STAGING_BUCKET=$7
BQ_PROJECT=$8

function clean_and_exit () {
    echo "$1"
    # Use trap for cloud-sql-rpoxu
    pkill cloud_sql_proxy
    rm "${TABLE_NAME}.csv" 2> /dev/null
    rm "${TABLE_NAME}_no_nulls.csv" 2> /dev/null

    exit 1;
}

PERIOD_OCCURRENCES=$(echo "${TABLE_NAME}" | grep -o "\." | wc -l)

if [[ "${PERIOD_OCCURRENCES}" != 1 ]]; then
  clean_and_exit "Invalid table name ${TABLE_NAME}. Tables should be of the form <schema>.<table>. Exiting..."
fi

# Remove characters including and after . to get schema (or data-set name)
SCHEMA_NAME=$(echo "${TABLE_NAME}" | sed "s/\..*//")


nohup ./cloud_sql_proxy --instances="${SQL_PROJECT}":"${SQL_PROJECT_REGION}":"${INSTANCE}"=tcp:3308 >/dev/null 2>&1 &

sleep 2


QUERY="SHOW FIELDS FROM ${TABLE_NAME}"


# Get columns from mysql
COLUMNS=$(mysql -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --host 127.0.0.1 "${SCHEMA_NAME}" --port=3308 -e "${QUERY}" --batch --silent) \
    || clean_and_exit "Could not get table definition for ${SCHEMA_NAME}. Exiting..."


# SQL proxy no longer necessary
pkill cloud_sql_proxy


# Retain only the first two fields (Column Name, Type, Nullable)
COLUMNS=$(echo "${COLUMNS}" | cut -d$'\t' --fields=1,2,3)


# Remove brackets
COLUMNS=$(echo "${COLUMNS}" | sed s/\(.*\)// )


# Temporary file for BigQuery schema
TMP_BQ_SCHEMA_FILE=$(mktemp /tmp/sql2bq.XXXXX)

# Convert SQL table definition to BigQuery schema
python sql2bq.py "${COLUMNS}" > "${TMP_BQ_SCHEMA_FILE}" \
    || clean_and_exit "Could not convert SQL table definition for ${TABLE_NAME} to BigQuery schema. Exiting..."


# Update IAM programmatically?
gcloud sql export csv "${INSTANCE}" "${STAGING_BUCKET}${TABLE_NAME}.csv" --query="SELECT * FROM ${TABLE_NAME}" --project="${SQL_PROJECT}" \
    || clean_and_exit "Could not export table ${TABLE_NAME} to ${STAGING_BUCKET}. Exiting..."


bq show --project_id="${BQ_PROJECT}" "${SCHEMA_NAME}" > /dev/null

if [[ "$?" -ne 0 ]]; then
	echo "Data set ${SCHEMA_NAME} does not exist. Creating data set..."
	bq mk --project_id="${BQ_PROJECT}" "${SCHEMA_NAME}"
fi


# Check that table does not exist
bq show --project_id="${BQ_PROJECT}" "${TABLE_NAME}" > /dev/null \
    && clean_and_exit "Table ${TABLE_NAME} already exists. Exiting..."


# Create the table
bq mk --project_id="${BQ_PROJECT}" --schema="${TMP_BQ_SCHEMA_FILE}" "${TABLE_NAME}" \
    || clean_and_exit "Could not create table ${TABLE_NAME} in BigQuery. Exiting..."


# Copy CSV export locally for cleaning
gsutil cp "${STAGING_BUCKET}${TABLE_NAME}.csv" . \
    || clean_and_exit "Could not copy table locally for null removal. Exiting..."


# Remove null values from export
cat "${TABLE_NAME}.csv" | sed s/\"\N\,/\,/g | sed s/\"\N$//g > "${TABLE_NAME}_no_nulls.csv"


# Copy back to the bucket
gsutil -q cp "${TABLE_NAME}_no_nulls.csv" "${STAGING_BUCKET}${TABLE_NAME}_no_nulls.csv" \
    || clean_and_exit "Could not upload file to ${STAGING_BUCKET}${TABLE_NAME}_no_nulls.csv. Exiting..."

# Load from Google Cloud Storage to BigQuery
bq load --project_id="${BQ_PROJECT}" --source_format=CSV "${TABLE_NAME}" "${STAGING_BUCKET}${TABLE_NAME}_no_nulls.csv" \
    || clean_and_exit "Could not load export from ${STAGING_BUCKET}${TABLE_NAME} to BigQuery ${TABLE_NAME}. Exiting..."

clean_and_exit "Done."

exit 0;
