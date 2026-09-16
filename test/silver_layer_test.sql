/*
===============================================================================
Script:      silver_quality_checks.sql
Purpose:     Data quality checks on the [DataWarehouse].[silver] layer.
             Validates that the cleaning rules applied by silver.load_silver
             actually held: no duplicate keys, no white space, dates convert
             and are correctly ordered, numeric columns are consistent, and
             categorical columns only contain the standardised values the
             load procedure maps to.
             Checks only - no cleaning, no temp tables, no loads.
             Each check prints a verdict instead of returning a result set.
Tables:      silver.crm_sales_details
             silver.crm_cust_info
             silver.crm_prd_info
             silver.erp_cust_az12
             silver.erp_loc_a101
             silver.erp_px_cat_g1v2
Usage:       Run in SSMS with the Messages tab open, after silver.load_silver
             has completed.
===============================================================================
*/

SET NOCOUNT ON;

PRINT '===============================================================';
PRINT '                 SILVER LAYER QUALITY CHECKS                   ';
PRINT '===============================================================';


/*---------------------------------------------------------------------------
  1. crm_sales_details
---------------------------------------------------------------------------*/
PRINT '';
PRINT '--------------- [silver].[crm_sales_details] -------------------';

-- unwanted spaces: sls_ord_num
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details]
           WHERE sls_ord_num <> TRIM(sls_ord_num))
    PRINT 'sls_ord_num        : white space found';
ELSE
    PRINT 'sls_ord_num        : no white space';

-- unwanted spaces: sls_prd_key
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details]
           WHERE sls_prd_key <> TRIM(sls_prd_key))
    PRINT 'sls_prd_key        : white space found';
ELSE
    PRINT 'sls_prd_key        : no white space';

-- dates should already be proper DATE values; only order_dt is nullable by design
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details]
           WHERE sls_ship_dt IS NULL OR sls_due_dt IS NULL)
    PRINT 'sls_ship/due_dt    : unexpected nulls found';
ELSE
    PRINT 'sls_ship/due_dt    : no unexpected nulls';

-- date ordering: order <= ship <= due
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details]
           WHERE sls_ship_dt < sls_order_dt OR sls_order_dt > sls_due_dt)
    PRINT 'date order         : bad ordering found (ship < order or order > due)';
ELSE
    PRINT 'date order         : all dates in correct order';

-- numeric consistency: sales = quantity * price, no nulls / negatives / zeros
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details]
           WHERE sls_sales <> sls_quantity * sls_price
              OR sls_sales    IS NULL
              OR sls_quantity IS NULL
              OR sls_price    IS NULL
              OR sls_sales    <= 0
              OR sls_quantity <= 0
              OR sls_price    <= 0)
    PRINT 'sales/qty/price    : inconsistent or invalid values found';
ELSE
    PRINT 'sales/qty/price    : all values consistent';


/*---------------------------------------------------------------------------
  2. crm_cust_info
---------------------------------------------------------------------------*/
PRINT '';
PRINT '----------------- [silver].[crm_cust_info] ---------------------';

-- the load deduplicates on cst_id keeping the newest row, so no duplicates
-- or nulls should remain
IF EXISTS (SELECT cst_id FROM [DataWarehouse].[silver].[crm_cust_info]
           GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL)
    PRINT 'cst_id             : duplicates or nulls found';
ELSE
    PRINT 'cst_id             : no duplicates';

-- unwanted spaces in textual columns
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info]
           WHERE cst_key <> TRIM(cst_key))
    PRINT 'cst_key            : white space found';
ELSE
    PRINT 'cst_key            : no white space';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info]
           WHERE cst_firstname <> TRIM(cst_firstname))
    PRINT 'cst_firstname      : white space found';
ELSE
    PRINT 'cst_firstname      : no white space';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info]
           WHERE cst_lastname <> TRIM(cst_lastname))
    PRINT 'cst_lastname       : white space found';
ELSE
    PRINT 'cst_lastname       : no white space';

-- values should now be fully standardised by the load
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info]
           WHERE cst_marital_status NOT IN ('Married','Single','n/a'))
    PRINT 'cst_marital_status : unexpected values found (not Married/Single/n/a)';
ELSE
    PRINT 'cst_marital_status : only expected values (Married/Single/n/a)';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info]
           WHERE cst_gndr NOT IN ('Male','Female','n/a'))
    PRINT 'cst_gndr           : unexpected values found (not Male/Female/n/a)';
ELSE
    PRINT 'cst_gndr           : only expected values (Male/Female/n/a)';


/*---------------------------------------------------------------------------
  3. crm_prd_info
---------------------------------------------------------------------------*/
PRINT '';
PRINT '------------------ [silver].[crm_prd_info] ---------------------';

-- duplicates / nulls in the primary key
IF EXISTS (SELECT prd_id FROM [DataWarehouse].[silver].[crm_prd_info]
           GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL)
    PRINT 'prd_id             : duplicates or nulls found';
ELSE
    PRINT 'prd_id             : no duplicates';

-- cat_id should always be populated now that it is split out of prd_key
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE cat_id IS NULL OR cat_id <> TRIM(cat_id))
    PRINT 'cat_id             : nulls or white space found';
ELSE
    PRINT 'cat_id             : populated, no white space';

-- unwanted spaces
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE prd_key <> TRIM(prd_key))
    PRINT 'prd_key            : white space found';
ELSE
    PRINT 'prd_key            : no white space';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE prd_nm <> TRIM(prd_nm))
    PRINT 'prd_nm             : white space found';
ELSE
    PRINT 'prd_nm             : no white space';

-- cost should have nulls replaced with 0, so only non-negative values remain
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE prd_cost IS NULL OR prd_cost < 0)
    PRINT 'prd_cost           : nulls or negative costs found';
ELSE
    PRINT 'prd_cost           : all costs valid';

-- product line should be fully mapped to display names
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE prd_line NOT IN ('Mountain','Road','Other Slaes','Touring','n/a'))
    PRINT 'prd_line           : unexpected values found (not mapped names)';
ELSE
    PRINT 'prd_line           : only expected values (mapped names)';

-- start date must not be after end date
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info]
           WHERE prd_start_dt > prd_end_dt)
    PRINT 'prd_start/end_dt   : start date after end date found';
ELSE
    PRINT 'prd_start/end_dt   : all date ranges valid';


/*---------------------------------------------------------------------------
  4. erp_cust_az12
---------------------------------------------------------------------------*/
PRINT '';
PRINT '===================== ERP SOURCE TABLES =======================';
PRINT '';
PRINT '----------------- [silver].[erp_cust_az12] ---------------------';

IF EXISTS (SELECT cid FROM [DataWarehouse].[silver].[erp_cust_az12]
           GROUP BY cid HAVING COUNT(*) > 1 OR cid IS NULL)
    PRINT 'cid                : duplicates or nulls found';
ELSE
    PRINT 'cid                : no duplicates';

-- cust_id is extracted from cid and should always be populated
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_cust_az12]
           WHERE cust_id IS NULL OR LEN(cust_id) <> 5)
    PRINT 'cust_id            : nulls or wrong length found';
ELSE
    PRINT 'cust_id            : populated, correct length';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_cust_az12]
           WHERE bdate IS NULL)
    PRINT 'bdate              : nulls found';
ELSE
    PRINT 'bdate              : no nulls';

-- gen should be fully normalised, blanks/nulls mapped to n/a
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_cust_az12]
           WHERE gen NOT IN ('Male','Female','n/a') OR gen IS NULL)
    PRINT 'gen                : unexpected values found (not Male/Female/n/a)';
ELSE
    PRINT 'gen                : only expected values (Male/Female/n/a)';


/*---------------------------------------------------------------------------
  5. erp_loc_a101
---------------------------------------------------------------------------*/
PRINT '';
PRINT '------------------ [silver].[erp_loc_a101] ---------------------';

IF EXISTS (SELECT cid FROM [DataWarehouse].[silver].[erp_loc_a101]
           GROUP BY cid HAVING COUNT(*) > 1 OR cid IS NULL)
    PRINT 'cid                : duplicates or nulls found';
ELSE
    PRINT 'cid                : no duplicates';

-- dashes should have been stripped out of cid by the load
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_loc_a101]
           WHERE cid LIKE '%-%')
    PRINT 'cid                : dashes still present';
ELSE
    PRINT 'cid                : no dashes';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_loc_a101]
           WHERE cust_id IS NULL OR LEN(cust_id) <> 5)
    PRINT 'cust_id            : nulls or wrong length found';
ELSE
    PRINT 'cust_id            : populated, correct length';

-- country should be fully standardised, unmapped values become n/a
IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_loc_a101]
           WHERE cntry NOT IN ('United States','Germany','n/a') OR cntry IS NULL)
    PRINT 'cntry              : unexpected values found (not standardised)';
ELSE
    PRINT 'cntry              : only expected values (standardised)';


/*---------------------------------------------------------------------------
  6. erp_px_cat_g1v2
---------------------------------------------------------------------------*/
PRINT '';
PRINT '---------------- [silver].[erp_px_cat_g1v2] --------------------';

-- this table is copied through unchanged, so the same checks as bronze apply
IF EXISTS (SELECT id FROM [DataWarehouse].[silver].[erp_px_cat_g1v2]
           GROUP BY id HAVING COUNT(*) > 1 OR id IS NULL)
    PRINT 'id                 : duplicates or nulls found';
ELSE
    PRINT 'id                 : no duplicates';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_px_cat_g1v2]
           WHERE cat <> TRIM(cat) OR subcat <> TRIM(subcat)
              OR maintenance <> TRIM(maintenance))
    PRINT 'cat/subcat/maint   : white space found';
ELSE
    PRINT 'cat/subcat/maint   : no white space';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_px_cat_g1v2]
           WHERE UPPER(TRIM(ISNULL(maintenance,''))) NOT IN ('YES','NO'))
    PRINT 'maintenance        : unexpected values found (not Yes/No)';
ELSE
    PRINT 'maintenance        : only expected values (Yes/No)';


/*---------------------------------------------------------------------------
  7. dwh_create_date audit column (present on every silver table)
---------------------------------------------------------------------------*/
PRINT '';
PRINT '------------------- audit column checks -------------------------';

IF EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_cust_info] WHERE dwh_create_date IS NULL)
   OR EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_prd_info] WHERE dwh_create_date IS NULL)
   OR EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[crm_sales_details] WHERE dwh_create_date IS NULL)
   OR EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_cust_az12] WHERE dwh_create_date IS NULL)
   OR EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_loc_a101] WHERE dwh_create_date IS NULL)
   OR EXISTS (SELECT 1 FROM [DataWarehouse].[silver].[erp_px_cat_g1v2] WHERE dwh_create_date IS NULL)
    PRINT 'dwh_create_date    : nulls found in one or more tables';
ELSE
    PRINT 'dwh_create_date    : populated in all tables';

PRINT '';
PRINT '===============================================================';
PRINT '                  QUALITY CHECKS COMPLETED                     ';
PRINT '===============================================================';
