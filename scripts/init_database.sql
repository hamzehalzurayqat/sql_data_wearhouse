/*
=============================================================
    Create Database: datawarehouse
=============================================================
Script Purpose:
    This script creates a new database named 'datawarehouse' 
    after checking if it already exists. If it exists, it is 
    dropped and recreated. The script also creates three 
    schemas within the database: 'bronze', 'silver', and 'gold'.

WARNING:
    Running this script will DROP the entire 'datawarehouse' 
    database if it already exists. ALL DATA in that database 
    will be PERMANENTLY DELETED. 

    - Ensure you have a full backup before running this script.
    - Verify you are connected to the correct SQL Server instance.
    - Do NOT run this on a production environment without 
      explicit approval and a tested backup/restore plan.

    Proceed with caution, and ensure you understand the 
    consequences of this action before continuing.
=============================================================
*/
-- create database 'datawarehouse'

USE master;
GO

-- Drop or recreate the datawarehouse database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'datawarehouse')
BEGIN
    ALTER DATABASE datawarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE datawarehouse;
END;
GO

CREATE DATABASE datawarehouse;
GO

USE datawarehouse;
GO

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
