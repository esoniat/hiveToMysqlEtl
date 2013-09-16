--
-- Demo script for inserting some random sessoinIds and visitorIds
--
-- Create the table if needed
USE hiveetl;
--
LOAD DATA LOCAL INFILE 'CapOneSales' REPLACE  INTO TABLE capone_sales_app_id FIELDS TERMINATED BY '\t';