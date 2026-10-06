# Fabric Data Lakehouse — AdventureWorksLT (OLTP → OLAP)

An end-to-end **OLTP → OLAP** project in Microsoft Fabric: transactional data from the AdventureWorksLT database (Azure SQL) is ingested incrementally, cleaned in PySpark, modeled as a star schema in a Fabric Warehouse with T-SQL, and served through an **analytics-ready Direct Lake semantic model** with business measures.

The deliverable is the semantic model itself — a governed, documented layer that analysts can connect to from Power BI, Excel or any XMLA client, rather than a single report.

`Microsoft Fabric` · `Data Pipelines` · `PySpark` · `T-SQL` · `Fabric Warehouse` · `Lakehouse Schemas` · `Star Schema` · `Direct Lake` · `DAX` · `Data Quality`

---

## 🎯 Business Context

Adventure Works is a bicycle manufacturer selling bikes, components, clothing and accessories to **reseller companies (B2B wholesale)**. In the source data, a *customer* is a reseller company; first name, last name and title belong to the contact person at that company, and `SalesPerson` is the Adventure Works account representative.

The goal is one reliable model of sales performance — by product, product category, reseller, region and sales representative, including discounts and gross margin — built directly on top of the operational (OLTP) database.

### Source: OLTP database (`SalesLT`)

The source is a normalized transactional database: order header and order lines, customers linked to addresses through a bridge table, products with a self-referencing category hierarchy, and two foreign keys from each order to `Address` (ship-to and bill-to).

<details>
<summary><b>📸 Click to view the OLTP schema</b></summary>

<br>

<img width="979" height="760" alt="image" src="https://github.com/user-attachments/assets/2e47f4a6-7546-4c2c-8ef9-c609aad723dc" />

</details>

## 🏗️ Architecture

```
Azure SQL Database — AdventureWorksLT (SalesLT, 10 tables)
        │   AW Incremental Load  — watermark-driven, per-table incremental upsert / full load
        ▼
AW_Data_Product (Lakehouse) ── schema bronze   raw 1:1 copy of the source
        │   AW Silver Cleaning   — PySpark notebook + data quality gate
        ▼
AW_Data_Product (Lakehouse) ── schema silver   cleaned entity tables (+ OBT_Sales)
        │   gold.usp_load_gold   — T-SQL stored procedure + data quality gate
        ▼
AW Data Warehouse ── schema gold               star schema (FactSales + 5 dimensions)
        │
        ▼
AW Semantic Model (Direct Lake on SQL) — 21 measures, hidden keys, display folders

Orchestrated end to end by: AW Pipeline
```

| Layer | Storage | Tool | What happens |
|---|---|---|---|
| **Bronze** | `AW_Data_Product.bronze` | Data Pipeline | All 10 `SalesLT` tables copied 1:1. Transactional tables (`SalesOrderHeader`, `SalesOrderDetail`, `Customer`) load incrementally on a `ModifiedDate` watermark with upsert; small reference tables use full load |
| **Silver** | `AW_Data_Product.silver` | PySpark notebook | 7 cleaned entity tables: types fixed, technical and sensitive columns removed (`rowguid`, `PasswordHash`, `PasswordSalt`, `ThumbNailPhoto`), `SalesPerson` normalized, missing `Color`/`Size` set to `Unknown`. `OBT_Sales` is written as a secondary, denormalized table for ad-hoc analysis |
| **Gold** | `AW Data Warehouse.gold` | T-SQL stored procedure | Star schema built from the Silver entity tables (not from the OBT); all business logic lives here |
| **Semantic model** | Direct Lake on SQL | TMDL | Relationships, role-playing dimensions, measures, hidden keys, sort orders and descriptions |

## ⚙️ Orchestration

<img width="766" height="115" alt="image" src="https://github.com/user-attachments/assets/7578ad2d-66b0-45ef-b802-8e5048cafc95" />

**`AW Pipeline`** runs the whole flow with on-success dependencies:

1. **Bronze incremental load** — invokes the child pipeline `AW Incremental Load`
2. **Silver cleaning** — runs the `AW Silver Cleaning` notebook
3. **Gold star schema** — executes the stored procedure `gold.usp_load_gold` in the Warehouse

**`AW Incremental Load`** is parameter-driven: a `tables` list defines, per table, the source schema/table, target name, business key and load type.

- **`incremental`** → a Lookup reads `MAX(ModifiedDate)` from the Bronze table (no separate control table needed), Copy Data pulls only rows changed since that watermark and **upserts** them on the business key
- **`full`** → Copy Data reloads the table and overwrites it

**`AW Initial Load`** performs the one-off full load that creates the Bronze tables before the first incremental run.

## ✅ Data Quality Gates

Quality is enforced at two layers. A failed check stops the pipeline, so bad data is never published downstream.

<details>
<summary><b>Silver — PySpark checks before writing (click to expand)</b></summary>

<br>

- **Primary keys:** unique and not null for all 7 entity tables
- **Referential integrity:** order line → order, order line → product, order → customer, order → ship-to / bill-to address, product → category / model, category → parent category
- **Business rules:** `OrderQty > 0`, `UnitPrice ≥ 0`, discount within 0–1, `LineTotal = OrderQty × UnitPrice × (1 − UnitPriceDiscount)`, ship and due dates not before order date, non-negative prices and costs
- **Completeness:** no nulls left in cleaned columns, no rows lost between Bronze and Silver
- **OBT grain check:** `OBT_Sales` row count equals the number of order lines (no join fan-out)

</details>

<details>
<summary><b>Gold — T-SQL checks at the end of the stored procedure (click to expand)</b></summary>

<br>

- `FactSales` row count equals `silver.salesorderdetail`
- every `ProductID` and `CustomerID` in the fact exists in its dimension
- every `OrderDate` falls inside `DimDate`

Each failed check raises an error with `THROW`, which marks the pipeline run as failed.

</details>

## ⭐ Star Schema

<img width="855" height="559" alt="image" src="https://github.com/user-attachments/assets/ed7f2f59-e76f-40b7-83f1-76d013c0808b" />

| Table | Grain | Key | Notes |
|---|---|---|---|
| `FactSales` | 1 row = 1 order line | `SalesOrderDetailID` | Keys, three dates and numeric measures only |
| `DimProduct` | 1 row = 1 product | `ProductID` | Category → Subcategory hierarchy, model, color, size, list price, standard cost, `IsActive` |
| `DimCustomer` | 1 row = 1 customer account | `CustomerID` | Reseller company, contact name, sales representative; **all** customers, not only those with orders |
| `DimAddress` | 1 row = 1 address | `AddressID` | **Role-playing**: ship-to (active) and bill-to (inactive) |
| `DimDate` | 1 row = 1 day | `Date` | Generated dynamically from order / ship / due dates, extended to full years; **role-playing** on order (active), ship and due dates |
| `DimFlags` | 1 row = 1 combination | `FlagKey` | **Junk dimension**: order status, order channel (online/offline), ship method, discounted vs full price |

<details>
<summary><b>📋 Column details (click to expand)</b></summary>

<br>

**FactSales**

| Column | Description |
|---|---|
| `SalesOrderID`, `SalesOrderDetailID` | Degenerate dimensions |
| `CustomerID`, `ProductID`, `ShipAddressID`, `BillAddressID`, `FlagKey` | Foreign keys |
| `OrderDate`, `ShipDate`, `DueDate` | Role-playing date keys |
| `OrderQty`, `UnitPrice`, `UnitPriceDiscount`, `LineTotal` | Transaction values from the source |
| `LineTotalAtListPrice` | `OrderQty × ListPrice` — basis for discount analysis |
| `LineCost` | `OrderQty × StandardCost` — basis for gross margin |
| `DaysToShip`, `DaysToDue` | Days from order to shipment / payment due date |

**Source tables used:** `SalesOrderHeader`, `SalesOrderDetail`, `Customer`, `Address`, `Product`, `ProductCategory`, `ProductModel`.
**Loaded to Bronze but not modeled:** `CustomerAddress`, `ProductDescription`, `ProductModelProductDescription` — no analytical use in this scope.

</details>

## 📊 Semantic Model

`AW Semantic Model` is a **Direct Lake on SQL** model on top of the Warehouse `gold` schema. It is designed to be used without knowing the underlying tables:

- **Only measures and descriptive attributes are visible** — keys, technical codes and raw fact columns are hidden, and default summarization is disabled everywhere
- **21 measures in display folders**, each with a format string
- **Sort orders** for month and weekday names; `DimDate` is marked as the date table
- **Descriptions** on non-obvious fields (e.g. `Gender`, `CompanyName`, `Category`)

| Folder | Measures |
|---|---|
| 1. Sales | Total Revenue, Units Sold, Orders Count, Average Order Value, Average Selling Price |
| 2. Discounts | Revenue at List Price, Discount Amount, Discount Rate % |
| 3. Profitability | Total Cost, Gross Profit, Gross Margin % |
| 4. Customers | Active Customers, Total Customers, Customer Activation %, Revenue per Customer |
| 5. Products & Mix | Products Sold, Revenue Share %, Online Revenue % |
| 6. Fulfillment | Avg Days to Ship, Avg Days to Due |
| 7. Regions | Revenue by Bill-To Region |

<details>
<summary><b>📐 Key DAX measures (click to expand)</b></summary>

<br>

```dax
Total Revenue         = SUM ( FactSales[LineTotal] )
Revenue at List Price = SUM ( FactSales[LineTotalAtListPrice] )
Discount Rate %       = DIVIDE ( [Revenue at List Price] - [Total Revenue], [Revenue at List Price] )

Gross Profit          = [Total Revenue] - SUM ( FactSales[LineCost] )
Gross Margin %        = DIVIDE ( [Gross Profit], [Total Revenue] )

Orders Count          = DISTINCTCOUNT ( FactSales[SalesOrderID] )
Average Order Value   = DIVIDE ( [Total Revenue], [Orders Count] )

Active Customers      = DISTINCTCOUNT ( FactSales[CustomerID] )
Customer Activation % = DIVIDE ( [Active Customers], COUNTROWS ( DimCustomer ) )

Revenue Share %       = DIVIDE ( [Total Revenue], CALCULATE ( [Total Revenue], ALLSELECTED () ) )

-- bill-to region via the inactive role-playing relationship
Revenue by Bill-To Region =
CALCULATE (
    [Total Revenue],
    USERELATIONSHIP ( FactSales[BillAddressID], DimAddress[AddressID] )
)
```

</details>

## 🧠 Design Decisions

- **`LineTotal` is the single source of truth.** `SalesOrderHeader.SubTotal` does not match `SUM(SalesOrderDetail.LineTotal)` — an intentional AdventureWorksLT quirk that simulates real-world issues such as historical imports or post-close price changes. `SubTotal`, `TaxAmt` and `TotalDue` are excluded from Silver and Gold; the Silver quality gate verifies that `LineTotal` is consistent with quantity, price and discount.
- **Entity tables in Silver, OBT as a by-product.** Gold dimensions are built from entity tables, so they contain all customers and products — not only those that appear in orders. Building dimensions from a denormalized OBT would silently drop them (e.g. `Total Customers` would always equal `Active Customers`). `OBT_Sales` is still published for ad-hoc analysis.
- **Business logic only in Gold.** Silver does cleaning and standardization; derived attributes and metrics (`DaysToShip`, `IsDiscounted`, `LineCost`, `Gender`, category hierarchy) are computed in the Warehouse.
- **Gold in T-SQL instead of Dataflow Gen2.** The star schema is version-controlled SQL (Warehouse database project in Git), readable as plain joins and easy to review.
- **`TRUNCATE` + `INSERT` instead of `DROP` + `CTAS`.** Gold tables are created once with an explicit schema; the procedure only reloads their contents. Recreating tables changes their underlying files and breaks the Direct Lake model between refreshes; fixed schemas also catch accidental type changes.
- **Natural keys instead of generated surrogate keys.** Dimensions use stable source IDs, so keys don't shift between full reloads. The junk dimension `DimFlags` uses a deterministic `ROW_NUMBER()` key rebuilt together with the fact.
- **Role-playing dimensions.** One `DimAddress` serves ship-to and bill-to addresses; one `DimDate` serves order, ship and due dates — inactive relationships are activated in measures with `USERELATIONSHIP`.
- **Junk dimension for low-cardinality flags.** Status, order channel, ship method and discount flag are moved out of the fact into `DimFlags` with readable labels.
- **`Gender` is derived, and labeled as such.** It is inferred from the contact person's title (Mr./Ms./Mrs.), not stored in the source; in a B2B context it describes the contact, not the customer.
- **Incremental vs full per table.** Order header and order lines load incrementally together (an order is always header + lines, and header fields such as `Status` change over time); small reference tables use full load, which is simpler and also handles deletes.

## ⚠️ Limitations & Next Steps

- **Deletes are not propagated** by incremental upsert — a removed order line would remain in Bronze. Next step: soft deletes in the source or a periodic full reconciliation of transactional tables.
- **Silver and Gold are full reloads.** Fine at this size; at scale, Silver would use Delta `MERGE` and Gold an incremental `MERGE` on changed orders.
- **`LineCost` uses the current `StandardCost`**, not the cost at the time of sale — gross margin is an approximation.
- **Single order date in the sample data.** All AdventureWorksLT orders share one order date, so time-intelligence measures (YTD, YoY) were left out; the model focuses on product, customer, region, discount and margin analysis.
- **Hard-coded workspace / item IDs.** Promotion between dev / test / prod would use Fabric deployment pipelines and variable libraries.

<details>
<summary><b>🛠️ Deployment notes (click to expand)</b></summary>

<br>

- **First run:** execute `AW Initial Load` once to create the Bronze tables; afterwards `AW Pipeline` handles incremental loads.
- **Warehouse:** run the table scripts from `AW Data Warehouse.Warehouse/gold/Tables` once, then `gold.usp_load_gold`.
- **Case-sensitive names:** Spark writes lakehouse table names in lowercase and the Warehouse is case-sensitive, so the procedure reads `AW_Data_Product.silver.salesorderheader` etc.
- **No `nvarchar` in Fabric Warehouse:** text produced by `DATENAME` / `FORMAT` is cast to `varchar`.
- **After a Git sync (Update all)** the semantic model may lose its data source credentials (`datasetToken` error on refresh): open the model **Settings → Data source credentials → Edit credentials (OAuth2)**, taking over the model first if needed.

</details>

<details>
<summary><b>⚙️ Requirements & workspace items (click to expand)</b></summary>

<br>

**Requirements:** Microsoft Fabric (Trial or F2+ capacity) · Azure SQL Database with the AdventureWorksLT sample · Power BI Desktop (optional, for TMDL editing)

**Workspace items:**
```
├── AW_Data_Product          (Lakehouse — schemas bronze, silver)
├── AW Data Warehouse        (Warehouse — schema gold, stored procedure)
├── AW Initial Load          (Data Pipeline — one-off full load)
├── AW Incremental Load      (Data Pipeline — watermark-driven upsert / full load)
├── AW Silver Cleaning       (Notebook — PySpark + data quality gate)
├── AW Pipeline              (Data Pipeline — end-to-end orchestration)
└── AW Semantic Model        (Semantic model — Direct Lake on SQL)
```

</details>
