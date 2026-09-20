/*
===============================================================================
Stored Procedure:  silver.load_silver
File:              silver_load_silver.sql
-------------------------------------------------------------------------------
PURPOSE
    Performs the ETL that moves data from the [bronze] layer into the [silver]
    layer. For each table it cleans the raw bronze data into a temp table,
    truncates the silver target, then inserts the cleaned rows.

WHAT IT CLEANS
    crm_cust_info       Deduplicates cst_id (keeps the newest cst_create_date),
                        trims names, maps marital status M/S -> Married/Single
                        and gender M/F -> Male/Female, unknowns -> 'n/a'.
    crm_prd_info        Splits prd_key into cat_id + prd_key, trims names,
                        replaces NULL cost with 0, maps prd_line codes to full
                        names, derives prd_end_dt from the next start date.
    crm_sales_details   Converts integer yyyymmdd dates to DATE, recalculates
                        sls_sales when it does not equal quantity * price, and
                        derives sls_price when it is missing.
    erp_cust_az12       Extracts cust_id from cid, normalises gender values.
    erp_loc_a101        Strips dashes from cid, extracts cust_id, maps country
                        codes to full names.
    erp_px_cat_g1v2     Copied as-is (no cleaning required).

PARAMETERS
    None. The procedure takes no input and returns no result set. All progress
    and timing information is written to the Messages tab via PRINT.

HOW TO RUN
    USE DataWarehouse;
    GO
    EXEC silver.load_silver;
    GO

    Run it from SSMS with the Messages tab open so you can read the progress
    output. A full run normally takes a few seconds.

PREREQUISITES
    1. The bronze tables must already be loaded (run the bronze load first).
    2. The silver tables must exist. If they do not, run silver_ddl.sql.
    3. Optional but recommended: run bronze_quality_checks.sql first to see
       what problems exist in the source data before cleaning it.

WARNING
    This procedure TRUNCATES every silver table before inserting. It is a full
    reload, not an incremental one. Any existing silver data is deleted. It is
    safe to re-run as often as you like; the result is always a fresh load.

ERROR HANDLING
    The body is wrapped in TRY/CATCH. If any step fails, the error message,
    number, and state are printed and the procedure exits without raising.
    Because there is no transaction, a mid-run failure leaves the already
    loaded tables populated and the remaining ones empty. Read the Messages
    output to see which step failed, fix it, and re-run the whole procedure.

===============================================================================
*/

USE [DataWarehouse]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE or ALTER PROCEDURE [silver].[load_silver] AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start DATETIME;
    SET @batch_start = GETDATE();
    SET @start_time = GETDATE();

    BEGIN TRY
        PRINT '========== crm ===========';
        PRINT '========== crm_cust_info ===========';
        SET @start_time = GETDATE();

        IF OBJECT_ID('tempdb..#cleaned_data_crm_cust_info') IS NOT NULL
            DROP TABLE #cleaned_data_crm_cust_info;

        -- deduplicate on cst_id, keeping the most recent create date
        ;WITH crm_cust_info2 AS (
            SELECT
                cst_id,
                cst_key,
                TRIM(cst_firstname) AS cst_firstname,
                TRIM(cst_lastname)  AS cst_lastname,
                cst_marital_status,
                cst_gndr,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rk,
                cst_create_date
            FROM [DataWarehouse].[bronze].[crm_cust_info]
            WHERE cst_id IS NOT NULL
        )
        SELECT
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        INTO #cleaned_data_crm_cust_info
        FROM crm_cust_info2
        WHERE rk = 1;

        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        PRINT '>> Inserting Data Into: silver.crm_cust_info';

        INSERT INTO [DataWarehouse].[silver].[crm_cust_info]
            (cst_id, cst_key, cst_firstname, cst_lastname,
             cst_marital_status, cst_gndr, cst_create_date)
        SELECT
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        FROM #cleaned_data_crm_cust_info;

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        PRINT '========== crm_prd_info ===========';
        SET @start_time = GETDATE();

        IF OBJECT_ID('tempdb..#cleaded_data_crm_prd_info') IS NOT NULL
            DROP TABLE #cleaded_data_crm_prd_info;

        ;WITH crm_prd_info2 AS (
            SELECT
                prd_id,
                TRIM(REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'))   AS cat_id,
                TRIM(SUBSTRING(prd_key, 7, LEN(prd_key)))           AS prd_key,
                TRIM(prd_nm)                                        AS prd_nm,
                COALESCE(prd_cost, 0)                               AS prd_cost,
                CASE
                    WHEN prd_line = 'M' THEN 'Mountain'
                    WHEN prd_line = 'R' THEN 'Road'
                    WHEN prd_line = 'S' THEN 'Other Slaes'
                    WHEN prd_line = 'T' THEN 'Touring'
                    ELSE 'n/a'
                END AS prd_line,
                CAST(prd_start_dt AS DATE) AS prd_start_dt,
                CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt DESC) - 1 AS DATE) AS prd_end_dt
            FROM [DataWarehouse].[bronze].[crm_prd_info]
        )
        SELECT *
        INTO #cleaded_data_crm_prd_info
        FROM crm_prd_info2;

        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;
        PRINT '>> Inserting Data Into: silver.crm_prd_info';

        INSERT INTO [DataWarehouse].[silver].[crm_prd_info]
            (prd_id, cat_id, prd_key, prd_nm, prd_cost,
             prd_line, prd_start_dt, prd_end_dt)
        SELECT
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt
        FROM #cleaded_data_crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        PRINT '========== crm_sales_details ===========';
        SET @start_time = GETDATE();

        IF OBJECT_ID('tempdb..#cleaned_data_crm_sales_details') IS NOT NULL
            DROP TABLE #cleaned_data_crm_sales_details;

        ;WITH crm_sales_d2 AS (
            SELECT
                sls_ord_num,
                sls_prd_key,
                sls_cust_id,
                CASE WHEN LEN(sls_ship_dt) >= 8
                     THEN CONVERT(DATE, CAST(sls_ship_dt AS VARCHAR(8)), 112)
                     ELSE NULL
                END AS sls_ship_dt,
                CASE WHEN LEN(sls_order_dt) >= 8
                     THEN CONVERT(DATE, CAST(sls_order_dt AS VARCHAR(8)), 112)
                     ELSE NULL
                END AS sls_order_dt,
                CASE WHEN LEN(sls_due_dt) >= 8
                     THEN CONVERT(DATE, CAST(sls_due_dt AS VARCHAR(8)), 112)
                     ELSE NULL
                END AS sls_due_dt,
                sls_quantity,
                CASE
                    WHEN sls_sales <> sls_quantity * sls_price OR sls_sales IS NULL
                        THEN sls_quantity * ABS(sls_price)
                    ELSE sls_sales
                END AS sls_sales,
                CASE
                    WHEN sls_price IS NULL THEN ABS(sls_sales / NULLIF(sls_quantity, 0))
                    ELSE ABS(sls_price)
                END AS sls_price
            FROM [DataWarehouse].[bronze].[crm_sales_details]
        )
        SELECT *
        INTO #cleaned_data_crm_sales_details
        FROM crm_sales_d2;

        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;
        PRINT '>> Inserting Data Into: silver.crm_sales_details';

        INSERT INTO [DataWarehouse].[silver].[crm_sales_details]
            (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt,
             sls_due_dt, sls_sales, sls_quantity, sls_price)
        SELECT
            sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt,
            sls_due_dt, sls_sales, sls_quantity, sls_price
        FROM #cleaned_data_crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        PRINT '===============erp====================';
        PRINT '===============[erp_cust_az12]====================';
        SET @start_time = GETDATE();

        IF OBJECT_ID('tempdb..#cleaded_data_erp_cust_az12') IS NOT NULL
            DROP TABLE #cleaded_data_erp_cust_az12;

        ;WITH erp_cust_az12_v2 AS (
            SELECT
                cid,
                SUBSTRING(cid, LEN(cid) - 4, 5) AS cust_id,
                bdate,
                CASE
                    WHEN TRIM(UPPER(gen)) = 'F' THEN 'Female'
                    WHEN TRIM(UPPER(gen)) = 'M' THEN 'Male'
                    WHEN TRIM(UPPER(gen)) = ''  THEN 'n/a'
                    WHEN gen IS NULL            THEN 'n/a'
                    ELSE gen
                END AS gen
            FROM [DataWarehouse].[bronze].[erp_cust_az12]
        )
        SELECT *
        INTO #cleaded_data_erp_cust_az12
        FROM erp_cust_az12_v2;

        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;
        PRINT '>> Inserting Data Into: silver.erp_cust_az12';

        INSERT INTO [DataWarehouse].[silver].[erp_cust_az12] (cid, cust_id, bdate, gen)
        SELECT cid, cust_id, bdate, gen
        FROM #cleaded_data_erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        PRINT '===============[erp_loc_a101]====================';
        SET @start_time = GETDATE();

        IF OBJECT_ID('tempdb..#clearn_loc_a101') IS NOT NULL
            DROP TABLE #clearn_loc_a101;

        SELECT
            REPLACE(cid, '-', '')           AS cid,
            SUBSTRING(cid, LEN(cid) - 4, 5) AS cust_id,
            CASE
                WHEN cntry = 'USA' THEN 'United States'
                WHEN cntry = 'US'  THEN 'United States'
                WHEN cntry = ''    THEN 'n/a'
                WHEN cntry = 'DE'  THEN 'Germany'
                ELSE 'n/a'
            END AS cntry
        INTO #clearn_loc_a101
        FROM [DataWarehouse].[bronze].[erp_loc_a101];

        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;
        PRINT '>> Inserting Data Into: silver.erp_loc_a101';

        INSERT INTO [DataWarehouse].[silver].[erp_loc_a101] (cid, cust_id, cntry)
        SELECT cid, cust_id, cntry
        FROM #clearn_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        PRINT '===============[erp_px_cat_g1v2]====================';
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';

        INSERT INTO [DataWarehouse].[silver].[erp_px_cat_g1v2] (id, cat, subcat, maintenance)
        SELECT id, cat, subcat, maintenance
        FROM [DataWarehouse].[bronze].[erp_px_cat_g1v2];

        SET @end_time = GETDATE();
        PRINT '>> Load duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        PRINT '=========================';
        PRINT 'Silver layer load completed successfully';
        PRINT 'Total batch duration: ' + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + ' seconds';
        PRINT '=========================';

    END TRY
    BEGIN CATCH
        PRINT '=========================';
        PRINT 'ERROR LOADING THE SILVER LAYER';
        PRINT 'Error message : ' + ERROR_MESSAGE();
        PRINT 'Error number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error state   : ' + CAST(ERROR_STATE()  AS NVARCHAR);
        PRINT 'Error line    : ' + CAST(ERROR_LINE()   AS NVARCHAR);
        PRINT '=========================';
    END CATCH
END
GO
