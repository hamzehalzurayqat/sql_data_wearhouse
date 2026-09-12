/*
===============================================================================
Stored Procedure: bronze.load_bronze
===============================================================================
Purpose:
    This procedure loads data into the 'bronze' schema from external CSV 
    source files (CRM and ERP systems). It performs the following actions:
        1. Truncates each bronze table before loading (full refresh, not 
           incremental — old data is wiped every run).
        2. Uses BULK INSERT to load data from flat CSV files on disk into 
           the corresponding bronze tables.
        3. Prints progress messages and load duration for each table, as 
           well as a total duration for the whole bronze layer load.

Parameters:
    None. 
    This procedure does not accept any parameters and does not return any 
    values.

Data Sources:
    CRM files (from source_crm folder):
        - cust_info.csv        -> bronze.crm_cust_info
        - prd_info.csv         -> bronze.crm_prd_info
        - sales_details.csv    -> bronze.crm_sales_details

    ERP files (from source_erp folder):
        - LOC_A101.csv         -> bronze.erp_loc_a101
        - CUST_AZ12.csv        -> bronze.erp_cust_az12
        - PX_CAT_G1V2.csv      -> bronze.erp_px_cat_g1v2

Usage Example:
    EXEC bronze.load_bronze;

Notes:
    - File paths are hardcoded (local Windows paths) — update these if the 
      source files are moved, or if this is run on a different machine.
    - firstrow = 2 is used because row 1 in each CSV is a header row.
    - TABLOCK is used to improve bulk load performance by taking a table-level 
      lock during the insert.
    - Any error during the TRY block is caught and printed (error message, 
      error number, error state) in the CATCH block, rather than stopping 
      execution silently.
===============================================================================
*//*
===============================================================================
Stored Procedure: bronze.load_bronze
===============================================================================
Purpose:
    This procedure loads data into the 'bronze' schema from external CSV 
    source files (CRM and ERP systems). It performs the following actions:
        1. Truncates each bronze table before loading (full refresh, not 
           incremental — old data is wiped every run).
        2. Uses BULK INSERT to load data from flat CSV files on disk into 
           the corresponding bronze tables.
        3. Prints progress messages and load duration for each table, as 
           well as a total duration for the whole bronze layer load.

Parameters:
    None. 
    This procedure does not accept any parameters and does not return any 
    values.

Data Sources:
    CRM files (from source_crm folder):
        - cust_info.csv        -> bronze.crm_cust_info
        - prd_info.csv         -> bronze.crm_prd_info
        - sales_details.csv    -> bronze.crm_sales_details

    ERP files (from source_erp folder):
        - LOC_A101.csv         -> bronze.erp_loc_a101
        - CUST_AZ12.csv        -> bronze.erp_cust_az12
        - PX_CAT_G1V2.csv      -> bronze.erp_px_cat_g1v2

Usage Example:
    EXEC bronze.load_bronze;

Notes:
    - File paths are hardcoded (local Windows paths) — update these if the 
      source files are moved, or if this is run on a different machine.
    - firstrow = 2 is used because row 1 in each CSV is a header row.
    - TABLOCK is used to improve bulk load performance by taking a table-level 
      lock during the insert.
    - Any error during the TRY block is caught and printed (error message, 
      error number, error state) in the CATCH block, rather than stopping 
      execution silently.
===============================================================================
*/
create or alter procedure bronze.load_bronze as 
begin
	declare @start_time datetime, @end_time datetime;
	set @start_time=getdate();
	begin try
		-- refresh the table 
		print('===================================');
		print('load the bronze layer');
		print('===================================');
		print('-----------------------------------');
		print('load the crm dataset csv files trunck and insert by bulk');
		print('-----------------------------------');
		set @start_time=getdate(); 
		truncate table bronze.crm_cust_info; 
		bulk insert bronze.crm_cust_info
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		with (
			firstrow=2,
			fieldterminator=',',
			tablock
		);
		set @end_time=getdate();
		print 'load duration: ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'secnods'
		set @start_time=getdate();
		truncate table bronze.crm_prd_info;
		bulk insert bronze.crm_prd_info
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		with(
			firstrow=2,
			fieldterminator=',',
			tablock
		);
		set @end_time=getdate();
		print 'load duration: ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'secnods';
		set @start_time = getdate();
		truncate table bronze.crm_sales_details;
		bulk insert bronze.crm_sales_details
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv' 
		with(
			firstrow=2,
			fieldterminator=',',
			tablock);
		set @end_time=getdate();
		print 'load_duration : ' + cast(datediff(second,@start_time,@end_time) as nvarchar) + 'second';
		print('-----------------------------------');
		print('load the crm dataset csv files trunck and insert by bulk ');
		print('-----------------------------------');
		set @start_time=getdate();
		truncate table bronze.erp_loc_a101;
		bulk insert bronze.erp_loc_a101
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
		with (
			firstrow = 2,
			fieldterminator=',',
			tablock);
		set @end_time=getdate();
		print 'load_duration' + cast(datediff(second,@start_time,@end_time)as nvarchar) + 'second';
		set @start_time=getdate();
		truncate table bronze.erp_cust_az12;
		bulk insert bronze.erp_cust_az12
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
		with ( 
			firstrow=2,
			fieldterminator=',',
			tablock
		);
		set @end_time=getdate();
		print 'load_duration' + cast(datediff(second,@start_time,@end_time)as nvarchar) + 'second';
		set @start_time=getdate();
		truncate table bronze.erp_px_cat_g1v2;
		bulk insert bronze.erp_px_cat_g1v2
		from 'C:\Users\2025\Documents\project\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
		with(
			firstrow=2,
			fieldterminator=',',
			tablock
		);
	end try
	begin catch
		print('=========================');
		print('error in load the bronze layer');
		print 'error message:' + error_message();
		print 'error message : ' + cast(error_number() as nvarchar);
		print 'error message:' + cast(error_state() as nvarchar);
		print('=========================');

	end catch
	set @end_time=getdate();
	print 'load_duration od bronze layer' + cast(datediff(second,@start_time,@end_time)as nvarchar) + 'second';

end
-- in new query just say exec bronze.load_branze
