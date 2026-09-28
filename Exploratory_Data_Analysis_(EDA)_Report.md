# SQL Data Warehouse Project: Exploratory Data Analysis (EDA) Report

**Part 2 of the project.** Part 1 built the data warehouse (Bronze, Silver, Gold). This part explores the Gold layer to understand the data and answer business questions.

---

## 1. Introduction

The Gold layer of the warehouse (built with the medallion architecture on SQL Server) exposes three analytical views:

| View | Type | Description |
|---|---|---|
| `gold.dim_customer` | Dimension | Customer attributes (name, country, gender, birthdate) |
| `gold.dim_prodcut` | Dimension | Product attributes (name, category, subcategory, cost) |
| `gold.fact_sales` | Fact | Sales transactions (order, ship date, quantity, price, sales amount) |

The data comes from two source systems (CRM and ERP), which were cleaned in the Silver layer and modeled as a star schema in the Gold layer.

**Objectives of this EDA**

1. **Dimensions exploration:** understand the categorical fields (countries, categories).
2. **Date exploration:** find the time boundaries of the data.
3. **Measures exploration:** calculate the key business numbers.
4. **Magnitude analysis:** compare measures across dimensions.
5. **Ranking analysis:** find the top and bottom performers.

> **Note:** Queries are shown exactly as written, including the object names `dim_prodcut` and `prodcut_name`, which are spelled that way in the warehouse schema.

---

## 2. Dimensions Exploration

### 2.1 Countries of customers

```sql
select distinct country 
from gold.dim_customer
```

**Result**

| country |
|---|
| n/a |
| Germany |
| United States |
| Australia |
| United Kingdom |
| Canada |
| France |

**Finding:** There are **6 real countries**, plus an `n/a` value for customers with an unknown country.

### 2.2 Categories and subcategories of products

```sql
select distinct category_name,subcategory_name
from gold.dim_prodcut
```

**Sample result**

| category_name | subcategory_name | (product) |
|---|---|---|
| Accessories | Bike Racks | Hitch Rack - 4-Bike |
| Accessories | Bike Stands | All-Purpose Bike Stand |
| Accessories | Bottles and Cages | Mountain Bottle Cage |
| Accessories | Bottles and Cages | Road Bottle Cage |
| Accessories | Bottles and Cages | Water Bottle - 30 oz. |
| Accessories | Cleaners | Bike Wash - Dissolver |
| Accessories | Fenders | Fender Set - Mountain |
| Accessories | Helmets | Sport-100 Helmet- Black |
| Accessories | Helmets | Sport-100 Helmet- Blue |
| Accessories | Helmets | Sport-100 Helmet- Red |
| Accessories | Hydration Packs | Hydration Pack - 70 oz. |
| Accessories | Lights | Headlights - Dual-Beam |
| ... | ... | ... |

**Finding:** There are **4 categories** (Accessories, Bikes, Clothing, Components). Each category has **2 or more subcategories**, and there are **295 products** in total.

---

## 3. Date Exploration

### 3.1 Boundaries of order date and ship date

```sql
select min(order_date) as first_order_date,
max(order_date) as last_order_date , 
min(ship_date) as first_ship_date,
max(ship_date) as last_ship_date,
datediff(year,min(order_date),max(order_date)) as order_range_year
from gold.fact_sales
```

**Result**

| first_order_date | last_order_date | first_ship_date | last_ship_date | order_range_year |
|---|---|---|---|---|
| 2010-12-29 | 2014-01-28 | 2011-01-05 | 2014-02-04 | 4 |

**Finding:** Orders span from **29 Dec 2010 to 28 Jan 2014**. Each order ships about 7 days after it is placed. `datediff(year, ...)` counts calendar-year boundaries crossed (2010 to 2014), so the value 4 is approximate; the real span is just over 3 years.

### 3.2 Youngest and oldest customer

In the Silver layer, missing birthdates were replaced with `1900-01-01`, so they are filtered out here.

```sql
select
    min(birthdate) as oldest_customer,
    max(birthdate) as youngest_customer,
	datediff(year,min(birthdate),getdate()) as oldest_age,
	datediff(year,max(birthdate),getdate()) as youngest_age
from gold.dim_customer
where birthdate > '1900-01-01'
  and birthdate <= getdate()
```

**Result**

| oldest_customer | youngest_customer | oldest_age | youngest_age |
|---|---|---|---|
| 1916-02-10 | 1986-06-25 | 110 | 40 |

**Finding:** The oldest customer was born in **1916** (about 110 years old today) and the youngest in **1986** (about 40 years old). The 110-year age suggests that some birthdates may be unreliable.

---

## 4. Measures Exploration

Key business numbers for the whole dataset.

### 4.1 Total sales

```sql
select sum(sales_amount)
from gold.fact_sales
```

**Result:** `29,356,250`

### 4.2 Total number of items sold

```sql
select sum(quantity)
from gold.fact_sales
```

**Result:** `29356250` was recorded in the original notes, which is identical to total sales and looks like a copy-paste error. Query 5.2 (quantity by country) adds up to **60,423 items**, which is the value used in this report.

### 4.3 Average selling price

```sql
select avg(price)
from gold.fact_sales
```

**Result:** `486`

### 4.4 Total number of orders

```sql
select count(distinct order_number)
from gold.fact_sales
```

**Result:** `27,659`

### 4.5 Total number of products

```sql
select count(distinct product_key)
from gold.dim_prodcut
```

**Result:** `295`

### 4.6 Total number of customers

```sql
select count(distinct customer_key)
from gold.dim_customer
```

**Result:** `18,484`

### 4.7 Customers who have placed an order

```sql
select count(distinct customer_key) 
from gold.fact_sales
```

**Result:** `18,484`

### Summary of key measures

| Measure | Value |
|---|---|
| Total sales | 29,356,250 |
| Total items sold | 60,423 |
| Average selling price | 486 |
| Total orders | 27,659 |
| Total products | 295 |
| Total customers | 18,484 |
| Customers with at least one order | 18,484 |

**Findings**

- **Every customer has placed at least one order** (18,484 of 18,484).
- Average revenue per order is about **1,061**, and each customer places about **1.5 orders**.

---

## 5. Magnitude Analysis

Comparing measures across dimensions.

### 5.1 Total customers by country

```sql
select count(distinct customer_key ) as total_customer_by_country ,country
from gold.dim_customer
group by country
```

**Result**

| country | total_customer_by_country | Share |
|---|---|---|
| United States | 7,482 | 40.5% |
| Australia | 3,591 | 19.4% |
| United Kingdom | 1,913 | 10.4% |
| France | 1,810 | 9.8% |
| Germany | 1,780 | 9.6% |
| Canada | 1,571 | 8.5% |
| n/a | 337 | 1.8% |

**Finding:** The **United States** has the largest customer base (about 40%), followed by **Australia**. Only 337 customers have an unknown country.

### 5.2 Total customers by gender

```sql
select count( customer_key ) as total_customer_by_gender ,gender
from gold.dim_customer
group by gender
```

**Result**

| gender | total_customer_by_gender |
|---|---|
| Male | 9,292 |
| Female | 9,085 |
| n/a | 107 |

**Finding:** The customer base is **nearly balanced** between male and female.

### 5.3 Total products by category

```sql
select count(distinct product_key ) as total_product_by_category ,category_name
from gold.dim_prodcut
group by category_name
```

**Result**

| category_name | total_product_by_category |
|---|---|
| Components | 127 |
| Bikes | 97 |
| Clothing | 35 |
| Accessories | 29 |
| NULL | 7 |

**Finding:** **Components** and **Bikes** are the largest categories. **7 products have no category** (NULL), a data quality issue to look into.

### 5.4 Average cost in each category

```sql
select avg( prodcut_cost ) as average_productcost_by_category ,category_name
from gold.dim_prodcut
group by category_name
```

**Result**

| category_name | average_productcost_by_category |
|---|---|
| Bikes | 913 |
| Components | 245 |
| NULL | 28 |
| Clothing | 24 |
| Accessories | 13 |

**Finding:** **Bikes** are by far the most expensive to produce (913 on average), followed by Components (245).

### 5.5 Total revenue generated by each category

```sql
select pd.category_name , sum(fc.sales_amount) as total_revenue_by_category
from gold.fact_sales as fc
join gold.dim_prodcut as pd on pd.product_key=fc.product_key
group by pd.category_name
```

**Result**

| category_name | total_revenue_by_category | Share |
|---|---|---|
| Bikes | 28,316,272 | 96.5% |
| Accessories | 700,262 | 2.4% |
| Clothing | 339,716 | 1.2% |

**Findings**

- **Bikes generate about 96.5% of all revenue.** The business depends heavily on one category.
- **Components** (127 products) and the 7 uncategorised products have **no sales** in the fact table.

### 5.6 Total revenue generated by each customer

```sql
select dc.customer_key,dc.first_name, sum(fc.sales_amount) as total_revenue_customer
from gold.fact_sales as fc
join gold.dim_customer as dc on dc.customer_key=fc.customer_key
group by dc.customer_key,dc.first_name
order by total_revenue_customer desc
```

**Result (top rows)**

| customer_key | first_name | total_revenue_customer |
|---|---|---|
| 1302 | Nichole | 13,294 |
| 1133 | Kaitlyn | 13,294 |
| 1309 | Margaret | 13,268 |
| 1132 | Randall | 13,265 |
| 1301 | Adriana | 13,242 |
| 1322 | Rosa | 13,215 |
| 1125 | Brandi | 13,195 |
| 1308 | Brad | 13,172 |
| 1297 | Francisco | 13,164 |
| ... | ... | ... |

**Finding:** The highest-spending customers each generate around **13,000** in revenue.

### 5.7 Distribution of sold items across countries

```sql
select dc.country, sum(fc.quantity) as quantity_by_countries
from gold.fact_sales as fc
join gold.dim_customer as dc on dc.customer_key=fc.customer_key
group by dc.country
```

**Result**

| country | quantity_by_countries | Share |
|---|---|---|
| United States | 20,481 | 33.9% |
| Australia | 13,346 | 22.1% |
| Canada | 7,630 | 12.6% |
| United Kingdom | 6,910 | 11.4% |
| Germany | 5,626 | 9.3% |
| France | 5,559 | 9.2% |
| n/a | 871 | 1.4% |
| **Total** | **60,423** | 100% |

**Findings**

- The **United States** and **Australia** together account for about **56%** of items sold.
- Items per customer differ by country: Canada is highest (about 4.9 items per customer), while the United States is lower (about 2.7) despite having the most customers.

---

## 6. Ranking Analysis

### 6.1 Top 5 products by revenue

```sql
select top 5
row_number() over (order by sum(fc.sales_amount) desc) as product_rank,
pd.prodcut_name,sum(fc.sales_amount) as sales_amount
from gold.fact_sales as fc
join gold.dim_prodcut as pd on fc.product_key = pd.product_key
group by pd.product_key, pd.prodcut_name
```

**Result**

| product_rank | prodcut_name | sales_amount |
|---|---|---|
| 1 | Mountain-200 Black- 46 | 1,373,454 |
| 2 | Mountain-200 Black- 42 | 1,363,128 |
| 3 | Mountain-200 Silver- 38 | 1,339,394 |
| 4 | Mountain-200 Silver- 46 | 1,301,029 |
| 5 | Mountain-200 Black- 38 | 1,294,854 |

**Finding:** All top 5 products are variants of the **Mountain-200** bike. Together they generate about **6.67 million**, or roughly **22.7%** of total revenue.

### 6.2 Five worst-performing products by sales

```sql
select top 5
row_number() over (order by sum(fc.sales_amount)) as product_rank,
pd.prodcut_name,sum(fc.sales_amount) as sales_amount
from gold.fact_sales as fc
join gold.dim_prodcut as pd on fc.product_key = pd.product_key
group by pd.product_key, pd.prodcut_name
```

**Result**

| product_rank | prodcut_name | sales_amount |
|---|---|---|
| 1 | Racing Socks- L | 2,430 |
| 2 | Racing Socks- M | 2,682 |
| 3 | Patch Kit/8 Patches | 6,382 |
| 4 | Bike Wash - Dissolver | 7,272 |
| 5 | Touring Tire Tube | 7,440 |

**Finding:** The weakest products are low-priced **Clothing** and **Accessories** items, and all five generate less than 7,500 each.

### 6.3 Top 10 customers by revenue

```sql
select top 10
row_number() over (order by sum(fc.sales_amount)desc) as customer_rank,
dc.first_name,sum(fc.sales_amount) as sales_amount
from gold.fact_sales as fc
join gold.dim_customer as dc on fc.customer_key = dc.customer_key
group by dc.customer_key, dc.first_name
```

**Result**

| customer_rank | first_name | sales_amount |
|---|---|---|
| 1 | Nichole | 13,294 |
| 2 | Kaitlyn | 13,294 |
| 3 | Margaret | 13,268 |
| 4 | Randall | 13,265 |
| 5 | Adriana | 13,242 |
| 6 | Rosa | 13,215 |
| 7 | Brandi | 13,195 |
| 8 | Brad | 13,172 |
| 9 | Francisco | 13,164 |
| 10 | Maurice | 12,914 |

**Finding:** The top 10 customers are close in spend (12,914 to 13,294). Nichole and Kaitlyn are tied at 13,294, and `row_number()` gave them different ranks arbitrarily. Use `rank()` or `dense_rank()` if ties should share a rank.

---

## 7. Key Findings

1. **Revenue is concentrated in Bikes.** They generate about 96.5% of the 29.36M total, while Accessories and Clothing together add under 4%.
2. **Mountain-200 bikes dominate.** The top 5 products are all Mountain-200 variants (about 22.7% of revenue).
3. **The United States is the largest market** in both customers (40.5%) and items sold (33.9%).
4. **Customers are evenly split by gender** (9,292 male vs 9,085 female).
5. **All 18,484 customers have ordered**, with about 1.5 orders per customer and about 1,061 revenue per order.
6. **The data covers Dec 2010 to Jan 2014**, roughly 3 years of sales.

## 8. EDA code 
you can find the sql query that generate this report in EDA
