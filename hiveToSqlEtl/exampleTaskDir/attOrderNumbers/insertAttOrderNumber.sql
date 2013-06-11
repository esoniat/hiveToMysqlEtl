--
-- Demo script for inserting some random sessoinIds and visitorIds
--
-- Create the table if needed
USE hiveetl;
CREATE TABLE IF NOT EXISTS att_order ( 
       session_id VARCHAR(256) PRIMARY KEY,
       visitor_id VARCHAR(256), 
       session_time DATETIME,
       ude_value VARCHAR(256)  );
--
LOAD DATA LOCAL INFILE 'attOrderNumber' REPLACE  INTO TABLE att_order FIELDS TERMINATED BY '\t'
(session_id,visitor_id,session_time,ude_value);
