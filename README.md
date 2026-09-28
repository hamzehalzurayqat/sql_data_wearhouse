# SQL Data Warehouse Project

A SQL Server-based data warehouse project built using the medallion architecture pattern: Bronze, Silver, and Gold layers. This project ingests CRM and ERP CSV files, cleans and standardizes them, and exposes analytics-ready views for reporting and business analysis.

## Overview

This repository demonstrates a practical end-to-end data warehouse pipeline using T-SQL scripts only. The flow is:

- Bronze layer: raw CSV ingestion into staging tables
- Silver layer: cleaning, normalization, deduplication, and business rules
- Gold layer: curated dimension and fact views for analysis

The main objective is to convert raw operational data into a cleaner, trusted, and query-friendly data model for business reporting.

## Architecture

```text
raw CSV files
    ↓
[Bronze]  -- raw ingestion / schema matching
    ↓
[Silver]  -- cleanup / validation / transformations
    ↓
[Gold]   -- analytical views and star schema
```

## Data Sources

The project loads data from two source systems:

- CRM data
  - cust_info.csv
  - prd_info.csv
  - sales_details.csv
- ERP data
  - LOC_A101.csv
  - CUST_AZ12.csv
  - PX_CAT_G1V2.csv

These files are stored under the `dataset/` folder and are loaded into corresponding Bronze tables.

## Project Structure

```text
sql_data_wearhouse/
├── README.md
├── dataset/
│   ├── crm/
│   │   ├── cust_info.csv
│   │   ├── prd_info.csv
│   │   └── sales_details.csv
│   └── erp/
│       ├── CUST_AZ12.csv
│       ├── LOC_A101.csv
│       └── PX_CAT_G1V2.csv
├── docs/
│   ├── data_architecture.png
│   ├── data_flow.png
│   ├── data modeling.md
│   ├── data intgration.png
│   └── gold_layer_data_catalog.md
├── scripts/
│   ├── init_database.sql
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   └── load_bronze.sql
│   ├── silver/
│   │   ├── ddl_silver_layer
│   │   └── load_silver.sql
│   └── gold/
│       └── create_views
├── test/
│   ├── silver_layer_test.sql
│   └── test_gold_layer
└── .gitignore
```

## Database Design

### Bronze layer
The Bronze layer stores raw, minimally transformed data exactly as it arrives from the source files.

Key tables:
- `bronze.crm_cust_info`
- `bronze.crm_prd_info`
- `bronze.crm_sales_details`
- `bronze.erp_loc_a101`
- `bronze.erp_cust_az12`
- `bronze.erp_px_cat_g1v2`

### Silver layer
The Silver layer applies cleaning, standardization, deduplication, and date normalization rules.

Examples:
- Trim whitespace from text fields
- Map status codes to readable values
- Deduplicate customer records
- Normalize dates and country values
- Derive product lifecycle fields

### Gold layer
The Gold layer exposes business-ready analytical objects.

Main views:
- `gold.dim_customer`
- `gold.dim_prodcut`
- `gold.fact_sales`

These are designed to support reporting, sales analysis, customer understanding, and product analysis.

## Setup Instructions

### 1. Create the database and schemas
Run:

```sql
scripts/init_database.sql
```

This script:
- creates the `datawarehouse` database
- drops it first if it already exists
- creates the `bronze`, `silver`, and `gold` schemas

### 2. Create Bronze tables
Run:

```sql
scripts/bronze/ddl_bronze.sql
```

This creates all raw Bronze tables.

### 3. Load the Bronze layer
Run:

```sql
EXEC bronze.load_bronze;
```

This procedure loads CSV files from the local file system into the Bronze tables using `BULK INSERT`.

### 4. Load the Silver layer
Run:

```sql
EXEC silver.load_silver;
```

This procedure performs the transformation and standardization work.

### 5. Create Gold views
Run the script in `scripts/gold/create_views` to create the star-schema-style analytical views.

## Example Queries

### View customer dimension
```sql
SELECT *
FROM gold.dim_customer;
```

### View product dimension
```sql
SELECT *
FROM gold.dim_prodcut;
```

### View sales fact table
```sql
SELECT *
FROM gold.fact_sales;
```

### Example sales analysis
```sql
SELECT
    c.first_name,
    c.last_name,
    p.prodcut_name,
    f.sales_amount,
    f.quantity
FROM gold.fact_sales f
JOIN gold.dim_customer c
    ON f.customer_key = c.customer_key
JOIN gold.dim_prodcut p
    ON f.product_key = p.product_key;
```

## Documentation

Additional documentation is included in the `docs/` folder:

- `docs/data modeling.md` — dimension and fact model notes
- `docs/gold_layer_data_catalog.md` — catalog of Gold-layer objects
- `docs/data_architecture.png` — architecture diagram
- `docs/data_flow.png` — data flow diagram
- `docs/data intgration.png` — integration overview

