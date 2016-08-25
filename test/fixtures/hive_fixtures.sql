DROP TABLE IF EXISTS hive_test_table;
CREATE EXTERNAL TABLE hive_test_table(id STRING, name STRING, description STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LOCATION '/tmp/warehouse/fdw_tests';