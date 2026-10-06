# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "a618a618-7c48-4876-bc22-4e802bfd2b12",
# META       "default_lakehouse_name": "AW_Data_Product",
# META       "default_lakehouse_workspace_id": "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c",
# META       "known_lakehouses": [
# META         {
# META           "id": "a618a618-7c48-4876-bc22-4e802bfd2b12"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # CELL 1 — Configuration

# CELL ********************

BRONZE_SCHEMA = "`AW E-commerce`.AW_Data_Product.bronze"
SILVER_SCHEMA = "`AW E-commerce`.AW_Data_Product.silver"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 2 — Read Bronze tables

# CELL ********************

df_detail   = spark.read.table(f"{BRONZE_SCHEMA}.SalesOrderDetail")
df_header   = spark.read.table(f"{BRONZE_SCHEMA}.SalesOrderHeader")
df_customer = spark.read.table(f"{BRONZE_SCHEMA}.Customer")
df_address  = spark.read.table(f"{BRONZE_SCHEMA}.Address")
df_product  = spark.read.table(f"{BRONZE_SCHEMA}.Product")
df_category = spark.read.table(f"{BRONZE_SCHEMA}.ProductCategory")
df_model    = spark.read.table(f"{BRONZE_SCHEMA}.ProductModel")
 
print("Bronze tables loaded:")
print(f"  detail   : {df_detail.count():,} rows")
print(f"  header   : {df_header.count():,} rows")
print(f"  customer : {df_customer.count():,} rows")
print(f"  product  : {df_product.count():,} rows")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql.functions import col, to_date, regexp_replace, trim

# --- Sales ---
sales_order_header = df_header.select(
    "SalesOrderID", "RevisionNumber",
    to_date("OrderDate").alias("OrderDate"),
    to_date("DueDate").alias("DueDate"),
    to_date("ShipDate").alias("ShipDate"),
    "Status", "OnlineOrderFlag", "SalesOrderNumber", "PurchaseOrderNumber",
    "CustomerID", "ShipToAddressID", "BillToAddressID", "ShipMethod",
    # SubTotal / TaxAmt / TotalDue excluded — LineTotal is the source of truth
)

sales_order_detail = df_detail.select(
    "SalesOrderID", "SalesOrderDetailID", "ProductID",
    "OrderQty", "UnitPrice", "UnitPriceDiscount", "LineTotal",
)

# --- Customer (PasswordHash / PasswordSalt / rowguid removed) ---
customer = df_customer.select(
    "CustomerID", "Title", "FirstName", "MiddleName", "LastName", "Suffix",
    "CompanyName",
    regexp_replace("SalesPerson", r"^adventure-works\\", "").alias("SalesPerson"),
    "EmailAddress", "Phone",
)

address = df_address.select(
    "AddressID", "AddressLine1", "AddressLine2", "City",
    "StateProvince", "CountryRegion", "PostalCode",
)


# --- Product (ThumbNailPhoto / rowguid removed) ---
product = (
    df_product.select(
        "ProductID", "Name", "ProductNumber", "Color", "Size", "Weight",
        "StandardCost", "ListPrice", "ProductCategoryID", "ProductModelID",
        to_date("SellStartDate").alias("SellStartDate"),
        to_date("SellEndDate").alias("SellEndDate"),
        to_date("DiscontinuedDate").alias("DiscontinuedDate"),
    )
    .fillna("Unknown", subset=["Color", "Size"])
)

product_category = df_category.select("ProductCategoryID", "ParentProductCategoryID", "Name")
product_model    = df_model.select("ProductModelID", "Name")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql.functions import col, abs as sabs

errors = []

def check(condition_count, message):
    if condition_count > 0:
        errors.append(f"{message}: {condition_count}")

# 1. Klucze główne — unikalne i bez nulli
def check_pk(df, keys, name):
    keys = keys if isinstance(keys, list) else [keys]
    check(df.filter(" OR ".join(f"{k} IS NULL" for k in keys)).count(), f"{name}: null PK {keys}")
    check(df.groupBy(keys).count().filter("count > 1").count(),          f"{name}: duplicate PK {keys}")

check_pk(sales_order_header, "SalesOrderID",       "SalesOrderHeader")
check_pk(sales_order_detail, "SalesOrderDetailID", "SalesOrderDetail")
check_pk(customer,           "CustomerID",         "Customer")
check_pk(address,            "AddressID",          "Address")
check_pk(product,            "ProductID",          "Product")
check_pk(product_category,   "ProductCategoryID",  "ProductCategory")
check_pk(product_model,      "ProductModelID",     "ProductModel")

# 2. Integralność referencyjna — każdy klucz obcy ma rodzica
#    (nulle pomijamy: opcjonalny FK to nie sierota)
def check_fk(child, fk, parent, pk, name):
    orphans = (child.filter(col(fk).isNotNull())
                    .join(parent.select(col(pk).alias(fk)), fk, "left_anti")
                    .count())
    check(orphans, f"{name}: orphaned {fk}")

check_fk(sales_order_detail, "SalesOrderID",            sales_order_header, "SalesOrderID",      "Detail→Header")
check_fk(sales_order_detail, "ProductID",               product,            "ProductID",         "Detail→Product")
check_fk(sales_order_header, "CustomerID",              customer,           "CustomerID",        "Header→Customer")
check_fk(sales_order_header, "ShipToAddressID",         address,            "AddressID",         "Header→ShipAddress")
check_fk(sales_order_header, "BillToAddressID",         address,            "AddressID",         "Header→BillAddress")
check_fk(product,            "ProductCategoryID",       product_category,   "ProductCategoryID", "Product→Category")
check_fk(product,            "ProductModelID",          product_model,      "ProductModelID",    "Product→Model")
check_fk(product_category,   "ParentProductCategoryID", product_category,   "ProductCategoryID", "Category→Parent")

# 3. Reguły wartości — liczby i daty mają sens
check(sales_order_detail.filter("OrderQty <= 0").count(),                         "OrderQty <= 0")
check(sales_order_detail.filter("UnitPrice < 0").count(),                         "UnitPrice < 0")
check(sales_order_detail.filter("UnitPriceDiscount < 0 OR UnitPriceDiscount > 1").count(), "Discount outside 0–1")
check(sales_order_detail.filter(
        sabs(col("LineTotal") - col("OrderQty") * col("UnitPrice") * (1 - col("UnitPriceDiscount"))) > 0.01
      ).count(),                                                                   "LineTotal ≠ Qty × Price × (1 − Discount)")
check(sales_order_header.filter("ShipDate < OrderDate").count(),                  "ShipDate before OrderDate")
check(sales_order_header.filter("DueDate < OrderDate").count(),                   "DueDate before OrderDate")
check(product.filter("ListPrice < 0 OR StandardCost < 0").count(),                "Negative product price/cost")

# 4. Czyszczenie zadziałało, a nic nie zginęło po drodze
check(product.filter("Color IS NULL OR Size IS NULL").count(),                    "Product Color/Size still null")
check(df_detail.count() - sales_order_detail.count(),                             "SalesOrderDetail rows lost vs Bronze")
check(df_header.count() - sales_order_header.count(),                             "SalesOrderHeader rows lost vs Bronze")

# Wynik
if errors:
    raise Exception("Data quality checks failed:\n  - " + "\n  - ".join(errors))
print("✅ All Silver data quality checks passed")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

silver_tables = {
    "SalesOrderHeader": sales_order_header,
    "SalesOrderDetail": sales_order_detail,
    "Customer": customer,
    "Address": address,
    "Product": product,
    "ProductCategory": product_category,
    "ProductModel": product_model,
}
for name, df in silver_tables.items():
    (df.write.format("delta").mode("overwrite")
       .option("overwriteSchema", "true")
       .saveAsTable(f"{SILVER_SCHEMA}.{name}"))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# CELL — Build OBT_Sales from cleaned Silver DataFrames
from pyspark.sql.functions import col

d   = sales_order_detail.alias("d")
h   = sales_order_header.alias("h")
c   = customer.alias("c")
p   = product.alias("p")
m   = product_model.alias("m")
sc  = product_category.alias("sc")   # subcategory (category assigned to the product)
pc  = product_category.alias("pc")   # parent category
sa  = address.alias("sa")            # ship-to address
ba  = address.alias("ba")            # bill-to address

obt = (
    d
    .join(h,  col("d.SalesOrderID")          == col("h.SalesOrderID"),        "left")
    .join(c,  col("h.CustomerID")            == col("c.CustomerID"),          "left")
    .join(p,  col("d.ProductID")             == col("p.ProductID"),           "left")
    .join(m,  col("p.ProductModelID")        == col("m.ProductModelID"),      "left")
    .join(sc, col("p.ProductCategoryID")     == col("sc.ProductCategoryID"),  "left")
    .join(pc, col("sc.ParentProductCategoryID") == col("pc.ProductCategoryID"), "left")
    .join(sa, col("h.ShipToAddressID")       == col("sa.AddressID"),          "left")
    .join(ba, col("h.BillToAddressID")       == col("ba.AddressID"),          "left")
    .select(
        # Order line — keys & measures
        col("d.SalesOrderID"), col("d.SalesOrderDetailID"),
        col("d.OrderQty"), col("d.UnitPrice"), col("d.UnitPriceDiscount"), col("d.LineTotal"),

        # Order header
        col("h.SalesOrderNumber"), col("h.OrderDate"), col("h.DueDate"), col("h.ShipDate"),
        col("h.Status"), col("h.OnlineOrderFlag"), col("h.ShipMethod"),

        # Customer
        col("c.CustomerID"), col("c.FirstName"), col("c.LastName"),
        col("c.CompanyName"), col("c.SalesPerson"),

        # Product
        col("p.ProductID"), col("p.Name").alias("ProductName"), col("p.ProductNumber"),
        col("p.Color"), col("p.Size"), col("p.StandardCost"), col("p.ListPrice"),
        col("m.Name").alias("ModelName"),
        col("sc.Name").alias("SubcategoryName"),
        col("pc.Name").alias("CategoryName"),

        # Addresses
        col("h.ShipToAddressID"),
        col("sa.City").alias("ShipCity"),
        col("sa.StateProvince").alias("ShipStateProvince"),
        col("sa.CountryRegion").alias("ShipCountryRegion"),
        col("h.BillToAddressID"),
        col("ba.City").alias("BillCity"),
        col("ba.StateProvince").alias("BillStateProvince"),
        col("ba.CountryRegion").alias("BillCountryRegion"),
    )
)

# Grain check — joins must not multiply order lines
obt_rows, detail_rows = obt.count(), sales_order_detail.count()
assert obt_rows == detail_rows, f"OBT fan-out: {obt_rows} rows vs {detail_rows} order lines"

(obt.write.format("delta").mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(f"{SILVER_SCHEMA}.OBT_Sales"))

print(f"✅ OBT_Sales written: {obt_rows:,} rows × {len(obt.columns)} columns")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
