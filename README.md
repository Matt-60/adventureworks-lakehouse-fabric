# Fabric Data Lakehouse — AdventureWorksLT

A Data Lakehouse project built in Microsoft Fabric on top of the AdventureWorksLT sample database (Azure SQL). Implements the **Medallion architecture (Bronze → Silver → Gold)** with a dimensional model (star schema) and Power BI reporting.

`Microsoft Fabric` · `OneLake` · `Data Pipelines` · `Star Schema` · `DAX` · `Direct Lake`

---

## 🎯 Business Goal

Simulates a bicycle sales company needing one reliable model of sales performance — by product, customer, and region — built directly on top of its operational (OLTP) database. Along the way, the project surfaces a real data quality issue (header totals not matching line-item totals) and makes an explicit, documented decision about which number to trust — the kind of judgment call required when moving raw transactional data into an analytics-ready model.

## 🏗️ Architecture

```
Azure SQL (AdventureWorksLT)
         │
         ▼
   Data Pipeline (watermark-driven, incremental upsert / full load)
         │
         ▼
┌─────────────────────────────────────────────────────┐
│                     OneLake                          │
│  Bronze Lakehouse  → Notebook →  Silver   → Dataflow  │
│  Raw data 1:1        (PySpark)   OBT_Sales   Gen2 →   │
│  (Delta Parquet)                             Gold     │
└─────────────────────────────────────────────────────┘
         │
         ▼
    Power BI (Direct Lake)
```

| Layer | Purpose |
|---|---|
| **Bronze** | Raw data loaded from `SalesLT` schema via a watermark-driven incremental pipeline (full load on first run, incremental upsert afterward), no transformations |
| **Silver** | Single wide table (`OBT_Sales`) built in a PySpark notebook, joining all Bronze tables (grain = one order line item); profiled & cleansed using Data Wrangler |
| **Gold** | Star schema (Fact + Dimensions) built via Dataflow Gen2, served via SQL Analytics Endpoint / Warehouse |

## ⚙️ Orchestration

<img width="774" height="231" alt="orchestration pipeline" src="https://github.com/user-attachments/assets/3b638994-b7f3-4653-968d-f75332dd4774" />

A watermark-driven pipeline handles Bronze ingestion incrementally, followed by notebook-based Silver transformation and Dataflow Gen2 Gold modeling:

1. **Initial load** — first run performs a full load of all `SalesLT` tables into Bronze
2. **Incremental branch (`if_incremental`)** — on subsequent runs, a Lookup activity checks the last watermark value:
   - **Yes (incremental)** → pulls only new/changed records since the last watermark and **upserts** them into Bronze
   - **No** → falls back to a full load, overwriting Bronze
3. **Notebook: Bronze → Silver** — a PySpark notebook builds `OBT_Sales` by joining all Bronze tables, then uses **Data Wrangler** to profile and clean the data
4. **Dataflow Gen2: Silver → Gold** — builds the Fact and Dimension tables from `OBT_Sales`

## ⭐ Star Schema

<img width="921" height="569" alt="star schema" src="https://github.com/user-attachments/assets/c86a59d7-2da3-4592-90a2-87ed844ddf8d" />

`Fact_Sales` at the center, surrounded by `Dim_Date`, `Dim_Customer`, `Dim_Product`, `Dim_Address`, and `Dim_Flags`.

<details>
<summary><b>📋 Full table schemas (click to expand)</b></summary>

### Data Source — Azure SQL AdventureWorksLT (`SalesLT` schema, 10 tables)

| Table | Type |
|---|---|
| `SalesOrderHeader` | Fact |
| `SalesOrderDetail` | Fact |
| `Customer` | Dimension |
| `Address` | Dimension |
| `CustomerAddress` | Bridge |
| `Product` | Dimension |
| `ProductCategory` | Dimension |
| `ProductModel` | Dimension |
| `ProductDescription` | Dimension |
| `ProductModelProductDescription` | Bridge |

### Fact_Sales

| Column | Type | Description |
|---|---|---|
| `SalesOrderID` / `SalesOrderDetailID` | INT | Degenerate dimensions |
| `DateKey`, `CustomerKey`, `ProductKey`, `AddressKey` | INT | Foreign keys |
| `OrderQty`, `UnitPrice`, `ListPrice`, `UnitPriceDiscount`, `LineTotal` | DECIMAL | Transaction measures |
| `price_to_list` | DECIMAL | UnitPrice / ListPrice |

### Dimensions

- **Dim_Date** — synthetic calendar table (Year, Quarter, Month, MonthName, DayOfWeek, IsWeekend)
- **Dim_Customer** — from `Customer` (CustomerID, name, email, company, sales person)
- **Dim_Product** — from `Product` + `ProductCategory` + `ProductModel` (name, category, model, color, size, weight, list price, standard cost)
- **Dim_Address** — from `Address` (city, state/province, country, postal code)
- **Dim_Flags** — `OnlineOrderFlag` extracted from the fact table

</details>

<details>
<summary><b>📐 DAX measures (click to expand)</b></summary>

```dax
Total Revenue = SUM ( FactSales[LineTotal] )

Revenue at List Price =
    SUMX ( FactSales, FactSales[OrderQty] * RELATED ( DimProduct[ListPrice] ) )

Discount Amount = [Revenue at List Price] - [Total Revenue]

Average Selling Price = DIVIDE ( [Total Revenue], SUM ( FactSales[OrderQty] ) )

Discount Rate % = DIVIDE ( [Discount Amount], [Revenue at List Price] )

Orders Count = DISTINCTCOUNT ( FactSales[SalesOrderID] )

Average Order Value = DIVIDE ( [Total Revenue], [Orders Count] )

Revenue Previous Year =
    CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( DimDate[Date] ) )

Revenue YoY % =
    DIVIDE ( [Total Revenue] - [Revenue Previous Year], [Revenue Previous Year] )

Revenue YTD = TOTALYTD ( [Total Revenue], DimDate[Date] )
```

</details>

## 🧠 Key Decision: Data Quality Issue

`SalesOrderHeader.SubTotal` doesn't match `SUM(SalesOrderDetail.LineTotal)` for all 32 orders (differences up to ~18,692 units) — an intentional AdventureWorksLT quirk simulating real-world issues like historical imports or post-close price changes.

**Decision:** `LineTotal` from `SalesOrderDetail` is the single source of truth. `SubTotal`, `TaxAmt`, and `TotalDue` from the header are excluded from the model.

<details>
<summary><b>⚙️ Requirements & Fabric workspace structure (click to expand)</b></summary>

**Requirements:** Microsoft Fabric (Trial or F2+ capacity) · Azure SQL Database with AdventureWorksLT · Power BI Desktop

**Workspace structure:**
```
Workspace: AdventureWorksLT-DW
├── lh_bronze              (Lakehouse)
├── lh_silver              (Lakehouse)
├── wh_gold                (Warehouse)
├── pl_bronze_incremental  (Data Pipeline — watermark-driven load)
├── nb_bronze_to_silver    (Notebook — PySpark + Data Wrangler)
├── df_silver_to_gold      (Dataflow Gen2)
└── AdventureWorks     (Power BI Report)
```

</details>
