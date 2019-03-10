# sql2bq

A command line tool for loading CloudSQL tables to BigQuery.

Usage:
```bash
./sql2bq.sh <sql-project-id> <sql-region> <sql-instance-name> <fully-qualified-table-name> <sql-username> <sql-password> <staging-bucket> <bq-project-id>
```

### Disclaimer

This software has not been rigorously tested and should not be used in production without prior analysis. 
For example, if there is a file collision in the staging bucket, the existing file will be overwritten. 
Measures have been taken to make sure obvious accidents are avoided (if a BigQuery table of the same name exists loading will fail).

### TODO

* Nulls not supported yet: When a CloudSQL dump occurs, the null character is: **"N**. 
For obvious reasons this is problematic with CSV dumps. 
The plan here is to pull the exported file locally, pass a (well tested) sed over it and re-upload the modified file to the staging bucket.
Longer term a VM can be spun up, the connection should be faster that way as this process can be extremely painful if you have a slow internet connection. 
* So far only MySQL 5.7 is supported. There is no support for PostgreSQL yet.
* Permissions checks: The assumption here is that the GCP account which this is run with has all required permissions. There are no explicit checks.
* Cleanup: Temporary files both locally and on the cloud are not cleaned up. 
* Named arguments: The script caller currently has to remember the order of 8 arguments. Ideally there should be named arguments.
* Portability: Initially, the entire thing was going to be a bash script. But mapping the SQL table definition to BQ and then JSON was just quicker in Python. Maybe the entire thing should be moved to Python.
* SQL/BQ type mapping: This is incomplete so far (see sql2bq.py). Furthermore it is unclear what the right thing to do is with a lot of columns types.
* Diff loading: Currently only full-table loads is supported. It would be useful to be able to load diffs so that you can synchronize between CloudSQL and BigQuery using a scheduler. 
