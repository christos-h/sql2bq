import sys
import json


def main():
    if len(sys.argv) != 2:
        print("usage: sql2bq.py <columns>")
        exit(1)

    sql_columns_string = sys.argv[1]
    bq_columns = []

    for line in sql_columns_string.split("\n"):
        sql_column = line.split("\t")
        bq_columns.append(
            {
                "name": sql_column[0],
                "type": map_sql_type_to_bq(sql_column[1]),
                "mode": map_sql_nullable_to_bq(sql_column[2])
            }
        )

    print json.dumps(bq_columns)

    exit(0)


def map_sql_type_to_bq(sql_type):
    sql_bq_type_map = {
        "int": "INTEGER",
        "varchar": "STRING",
        "decimal": "FLOAT",
        "binary": "STRING",
        # "blob": "String", Check what the output of a mysql dump looks like here
        # "longblob": "String", Check what the output of a mysql dump looks like here
        # "mediumblob": "String", Check what the output of a mysql dump looks like here
        # "tinyblob": "String", Check what the output of a mysql dump looks like here
        "date": "DATE",
        "datetime": "DATETIME",
        "time": "TIME",
        "timestamp": "TIMESTAMP",
        # "year" : "String" Check what the output of a mysql dump looks like here
        # All the geometry sets

    }

    try:
        bq_type = sql_bq_type_map[sql_type]
        return bq_type
    except:
        print("Cannot map type " + sql_type + " to BigQuery. Exiting...")
        exit(1)


def map_sql_nullable_to_bq(nullable):
    return "NULLABLE" if nullable == "NO" else "REQUIRED"


main()
