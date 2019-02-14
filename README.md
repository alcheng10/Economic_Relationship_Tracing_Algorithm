# Economic_Relationship_Tracing_Algorithm
Sanitised version of a tracing algorithm that uses government and financial datasets to trace economic ownerships of corporate groups.  Developed in SQL for Teradata environment housing Big Data (>100 TB).  

Tracing algorithm steps:  

1. Takes user_input of a CLNT_ID and stores in USER_INPUT (outside of SQL code - done in web front-end UI)

2. Grabs all the group members of that user input CLNT_ID  

3. Grabs the head of that user input CLNT_ID  

4. Grabs the UHC of the user input CLNT_ID  

5. Grabs all the Sister entities that have the same UHC of the user input CLNT_ID  

6. Traces up 1 level by all economic relationships that have an ownership percentage greater than 0%
