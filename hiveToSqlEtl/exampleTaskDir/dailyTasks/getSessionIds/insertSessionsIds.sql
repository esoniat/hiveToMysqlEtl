--
-- Demo script for inserting some random sessoinIds and visitorIds
--
-- Create the table if needed
USE hiveetl;
CREATE TABLE IF NOT EXISTS testSessionIds ( sessionId VARCHAR(20) PRIMARY KEY, timestamp VARCHAR(20), tsAdDate VARCHAR(20), selectTime VARCHAR(20) );
LOAD DATA LOCAL INFILE 'testSessionIds' REPLACE  INTO TABLE testSessionIds FIELDS TERMINATED BY '\t';
