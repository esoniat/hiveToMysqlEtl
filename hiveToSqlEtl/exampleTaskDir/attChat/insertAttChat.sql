--
-- Demo script for inserting some random sessoinIds and visitorIds
--
-- Create the table if needed
USE hiveetl;
CREATE TABLE IF NOT EXISTS att_chat ( 
       session_id VARCHAR(256) PRIMARY KEY , 
       visitor_id VARCHAR(256), 
       session_time DATETIME,
       chat_indicator VARCHAR(256)  );
--
LOAD DATA LOCAL INFILE 'attChats' REPLACE  INTO TABLE att_chat FIELDS TERMINATED BY '\t';
