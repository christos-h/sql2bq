# sql2bq

A command line tool for loading CloudSQL tables into BigQuery. 

* First a column definition is extracted for the desired table from CloudSQL.
* A mapping then occurs between SQL data-types and BigQuery data-types. (The mapping is not 1:1. For more details see sql2bq.py)
* Next the data for that table is exported to Google Cloud Storage at a specified staging bucket
* Next a dataset is create in BigQuery with the name of the schema (If it does not already exist)
* Next a table is created under that dataset in BigQuery with the name of the SQL table. If the table already exists the process will fail.
* Finally the csv file is loaded from Google Cloud Storage to BigQuery. If the loading fails for any reason the table will remain empty.

Usage:
```bash
./sql2bq.sh <sql-project-id> <sql-region> <sql-instance-name> <fully-qualified-table-name> <sql-username> <sql-password> <staging-bucket> <bq-project-id>
```
### Disclaimer

This software has not been rigorously tested and should not be used in production without prior analysis. 
For example, if there is a file collision in the staging bucket, the existing file will be overwritten. 
Measures have been taken to make sure obvious accidents are avoided (if a BigQuery table of the same name exists loading will fail).


### TODO

* So far only MySQL 5.7 is supported. There is no support for PostgreSQL yet.
* Permissions checks: The assumption here is that the GCP account which this is run with has all required permissions. There are no explicit checks.
* Cleanup: Temporary files on the cloud are not cleaned up. This is intentional but there should be an option to do so. 
* Named arguments: The script caller currently has to remember the order of 8 arguments. Ideally there should be named arguments.
* Portability: Initially, the entire thing was going to be a bash script. But mapping the SQL table definition to BQ and then JSON was just quicker in Python. Maybe the entire thing should be moved to Python.
* SQL/BQ type mapping: This is incomplete so far (see sql2bq.py). Furthermore it is unclear what the right thing to do is with a lot of columns types.
* Diff loading: Currently only full-table loads are supported. It would be useful to be able to load diffs so that you can synchronize between CloudSQL and BigQuery using a scheduler.
* Schema extraction: It should be possible to define entire schemas for extraction instead of just tables.
* Currently files are copied locally in order to run some null replacement operations over them. There should be an option to spin up a VM for that. Also it may be possible to remove the need for sed if the null marker is set correctly in BQ load.
