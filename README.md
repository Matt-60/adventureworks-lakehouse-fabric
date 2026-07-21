# Fabric Data Lakehouse — AdventureWorksLT

A Data Lakehouse project built in Microsoft Fabric on top of the AdventureWorksLT sample database (Azure SQL). Implements the Medallion architecture (Bronze → Silver → Gold) with a dimensional model (star schema) and Power BI reporting.

---

## Architecture

```
Azure SQL (AdventureWorksLT)
         │
         ▼
   Data Pipeline
   (For Each + Copy Activity)
         │
         ▼
┌─────────────────────────────────────────────────────┐
│                     OneLake                         │
│                                                     │
│  Bronze Lakehouse      Silver Lakehouse    Gold      │
│  ─────────────────     ────────────────   ──────    │
│  Raw data 1:1      ──► OBT_Sales       ──► Fact     │
│  (Delta Parquet)       (One Big Table)     & Dims   │
└─────────────────────────────────────────────────────┘
         │
         ▼
    Power BI (Direct Lake)
```

---

## Data Source

**Azure SQL Database — AdventureWorksLT**

The database simulates a transactional system (OLTP) for a bicycle sales company. The `SalesLT` schema contains 10 business tables:

| Table | Description | Type |
|---|---|---|
| `SalesLT.SalesOrderHeader` | Order headers | Fact |
| `SalesLT.SalesOrderDetail` | Order line items | Fact |
| `SalesLT.Customer` | Customers | Dimension |
| `SalesLT.Address` | Addresses | Dimension |
| `SalesLT.CustomerAddress` | Customer–address mapping | Bridge |
| `SalesLT.Product` | Products | Dimension |
| `SalesLT.ProductCategory` | Product categories | Dimension |
| `SalesLT.ProductModel` | Product models | Dimension |
| `SalesLT.ProductDescription` | Product descriptions | Dimension |
| `SalesLT.ProductModelProductDescription` | Model–description mapping | Bridge |

---

## Medallion Layers

### Bronze — Raw Data

Lakehouse storing data 1:1 from the source with no transformations. Data is loaded incrementally via a Data Pipeline.

**Tables:**

```
bronze_customer
bronze_address
bronze_customer_address
bronze_sales_order_header
bronze_sales_order_detail
bronze_product
bronze_product_category
bronze_product_model
bronze_product_description
bronze_product_model_description
```

**Pipeline Configuration:**

The `TableList` variable (type Array) drives the list of tables to load:

```json
[
  {"src_schema": "SalesLT", "src_table": "Customer",                       "dst_table": "bronze_customer"},
  {"src_schema": "SalesLT", "src_table": "Address",                        "dst_table": "bronze_address"},
  {"src_schema": "SalesLT", "src_table": "CustomerAddress",                "dst_table": "bronze_customer_address"},
  {"src_schema": "SalesLT", "src_table": "SalesOrderHeader",               "dst_table": "bronze_sales_order_header"},
  {"src_schema": "SalesLT", "src_table": "SalesOrderDetail",               "dst_table": "bronze_sales_order_detail"},
  {"src_schema": "SalesLT", "src_table": "Product",                        "dst_table": "bronze_product"},
  {"src_schema": "SalesLT", "src_table": "ProductCategory",                "dst_table": "bronze_product_category"},
  {"src_schema": "SalesLT", "src_table": "ProductModel",                   "dst_table": "bronze_product_model"},
  {"src_schema": "SalesLT", "src_table": "ProductDescription",             "dst_table": "bronze_product_description"},
  {"src_schema": "SalesLT", "src_table": "ProductModelProductDescription", "dst_table": "bronze_product_model_description"}
]
```

### Silver — Cleansing and OBT

Lakehouse containing a single wide table `OBT_Sales` built by joining all Bronze tables. Grain: one order line item (`SalesOrderDetailID`).

**Modelling decisions:**

- Measures from `SalesOrderHeader` (`SubTotal`, `TaxAmt`, `TotalDue`) **excluded** — inconsistent with `LineTotal` from `SalesOrderDetail` (data quality issue detected across all 32 orders)
- `LineTotal` from `SalesOrderDetail` is the single source of truth for sales value
- `price_to_list` column = `UnitPrice / ListPrice` — ratio of transaction price to list price
- `load_date` metadata column added for auditability

### Gold — Dimensional Model

Star schema built from `OBT_Silver`. Accessible via the SQL Analytics Endpoint or Warehouse.

---

## Dimensional Model (Star Schema)

```
                    Dim_Date
                       │
         Dim_Customer ─┤
                       │
         Dim_Address ──┼── Fact_Sales
                       │
         Dim_Product ──┤
                       │
                    Dim_Flags
```

### Fact_Sales

| Column | Type | Description |
|---|---|---|
| `SalesOrderID` | INT | Degenerate dimension — order ID |
| `SalesOrderDetailID` | INT | Degenerate dimension — line item ID |
| `DateKey` | INT | FK → Dim_Date |
| `CustomerKey` | INT | FK → Dim_Customer (surrogate key) |
| `ProductKey` | INT | FK → Dim_Product (surrogate key) |
| `AddressKey` | INT | FK → Dim_Address (surrogate key) |
| `OrderQty` | INT | Quantity ordered |
| `UnitPrice` | DECIMAL | Transaction price |
| `ListPrice` | DECIMAL | Catalogue price (snapshot at transaction date) |
| `UnitPriceDiscount` | DECIMAL | Discount applied |
| `LineTotal` | DECIMAL | Line item value |
| `price_to_list` | DECIMAL | UnitPrice / ListPrice |

### Dim_Date

Generated synthetically — a date sequence with calendar attributes.

| Column | Description |
|---|---|
| `DateKey` (PK) | Format YYYYMMDD |
| `Date` | Full date |
| `Year`, `Quarter`, `Month`, `Day` | Calendar attributes |
| `MonthName`, `DayOfWeek` | Descriptive labels |
| `IsWeekend` | Boolean flag |

### Dim_Customer

Source: `SalesLT.Customer`

| Column | Description |
|---|---|
| `CustomerKey` (PK) | Surrogate key |
| `CustomerID` | Natural key (retained) |
| `FirstName`, `LastName` | Name |
| `EmailAddress` | Email |
| `CompanyName` | Company |
| `SalesPerson` | Assigned sales person |

### Dim_Product

Source: `SalesLT.Product` + `ProductCategory` + `ProductModel`

| Column | Description |
|---|---|
| `ProductKey` (PK) | Surrogate key |
| `ProductID` | Natural key |
| `ProductName` | Product name |
| `ProductNumber` | Catalogue number |
| `Category` | Category (denormalised) |
| `Model` | Model (denormalised) |
| `Color`, `Size`, `Weight` | Physical attributes |
| `ListPrice` | Catalogue price |
| `StandardCost` | Manufacturing cost |

### Dim_Address

Source: `SalesLT.Address`

| Column | Description |
|---|---|
| `AddressKey` (PK) | Surrogate key |
| `AddressID` | Natural key |
| `City` | City |
| `StateProvince` | State or province |
| `CountryRegion` | Country |
| `PostalCode` | Postal code |

### Dim_Flags

Flag attributes extracted from the fact table.

| Column | Description |
|---|---|
| `OnlineOrderFlag` | Online vs. in-store order |

---

## DAX Measures

```dax
-- 1. Core revenue
Total Revenue = SUM ( FactSales[LineTotal] )

-- 2. Revenue at catalogue prices
Revenue at List Price =
    SUMX ( FactSales, FactSales[OrderQty] * RELATED ( DimProduct[ListPrice] ) )

-- 3. Total discount given
Discount Amount = [Revenue at List Price] - [Total Revenue]

-- 4. Average selling price
Average Selling Price =
    DIVIDE ( [Total Revenue], SUM ( FactSales[OrderQty] ) )

-- 5. Discount rate
Discount Rate % =
    DIVIDE ( [Discount Amount], [Revenue at List Price] )

-- 6. Number of orders
Orders Count = DISTINCTCOUNT ( FactSales[SalesOrderID] )

-- 7. Average order value (AOV)
Average Order Value = DIVIDE ( [Total Revenue], [Orders Count] )

-- 8. Revenue same period last year
Revenue Previous Year =
    CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( DimDate[Date] ) )

-- 9. Year-over-year growth
Revenue YoY % =
    DIVIDE ( [Total Revenue] - [Revenue Previous Year], [Revenue Previous Year] )

-- 10. Year-to-date revenue
Revenue YTD = TOTALYTD ( [Total Revenue], DimDate[Date] )
```

---

## Known Data Quality Issues

**SubTotal vs LineTotal discrepancy**

`SalesOrderHeader.SubTotal` does not match `SUM(SalesOrderDetail.LineTotal)` for all 32 orders in AdventureWorksLT. Differences reach up to ~18,692 units.

This is an intentional characteristic of the sample database, simulating real-world data quality issues (e.g. historical imports, manual corrections, price changes after order closure).

Decision taken: `LineTotal` from `SalesOrderDetail` is the single source of truth. `SubTotal`, `TaxAmt`, and `TotalDue` from `SalesOrderHeader` are excluded from the model.

---

## Requirements

- Microsoft Fabric (Trial or F2+ capacity)
- Azure SQL Database with AdventureWorksLT sample data
- Power BI Desktop (for local model development)

---

## Fabric Workspace Structure

```
Workspace: AdventureWorksLT-DW
├── lh_bronze          (Lakehouse)
├── lh_silver          (Lakehouse)
├── wh_gold            (Warehouse)
├── pl_bronze_load     (Data Pipeline)
├── df_silver_obt      (Dataflow Gen2)
└── AdventureWorks     (Power BI Report)
```
