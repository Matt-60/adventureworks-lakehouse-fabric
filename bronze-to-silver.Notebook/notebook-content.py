# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "a618a618-7c48-4876-bc22-4e802bfd2b12",
# META       "default_lakehouse_name": "Bronze",
# META       "default_lakehouse_workspace_id": "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c",
# META       "known_lakehouses": [
# META         {
# META           "id": "a618a618-7c48-4876-bc22-4e802bfd2b12"
# META         },
# META         {
# META           "id": "d6396ec3-0af0-45af-80fc-15f6a5a2313f"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # CELL 1 — Configuration

# CELL ********************

BRONZE_SCHEMA = "Bronze"
SILVER_SCHEMA = "`AdventureWorks LT_project`.Silver.dbo"

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

# MARKDOWN ********************

# # CELL 3 — Prepare tables for JOIN

# CELL ********************

from pyspark.sql.functions import col

# Detail — measures + keys
detail = df_detail.select(
    col("SalesOrderID"),
    col("SalesOrderDetailID"),
    col("ProductID"),
    col("OrderQty"),
    col("UnitPrice"),
    col("UnitPriceDiscount"),
    col("LineTotal"),
)
 
# Header — attributes only, NO measures (SubTotal/TaxAmt/TotalDue excluded)
header = df_header.select(
    col("SalesOrderID").alias("h_SalesOrderID"),
    col("OrderDate"),
    col("DueDate"),
    col("ShipDate"),
    col("Status"),
    col("OnlineOrderFlag"),
    col("ShipMethod"),
    col("CustomerID"),
    col("ShipToAddressID"),
    col("BillToAddressID"),
)
 
# Customer
customer = df_customer.select(
    col("CustomerID").alias("c_CustomerID"),
    col("Title"),
    col("FirstName"),
    col("LastName"),
    col("CompanyName"),
    col("SalesPerson"),
    col("EmailAddress"),
)
 
# Product
product = df_product.select(
    col("ProductID").alias("p_ProductID"),
    col("Name").alias("ProductName"),
    col("ProductNumber"),
    col("Color"),
    col("StandardCost"),
    col("ListPrice"),
    col("Size"),
    col("ProductCategoryID").alias("p_CategoryID"),
    col("ProductModelID").alias("p_ModelID"),
)
 
# Category
category = df_category.select(
    col("ProductCategoryID").alias("cat_ID"),
    col("Name").alias("CategoryName"),
)
 
# Model
model = df_model.select(
    col("ProductModelID").alias("mod_ID"),
    col("Name").alias("ModelName"),
)
 
# Ship address
ship_address = df_address.select(
    col("AddressID").alias("ship_AddressID"),
    col("City").alias("ShipCity"),
    col("StateProvince").alias("ShipStateProvince"),
    col("CountryRegion").alias("ShipCountryRegion"),
)
 
# Bill address
bill_address = df_address.select(
    col("AddressID").alias("bill_AddressID"),
    col("City").alias("BillCity"),
    col("StateProvince").alias("BillStateProvince"),
    col("CountryRegion").alias("BillCountryRegion"),
)
 
print("All tables prepared for JOIN.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 4 — Build OBT via JOINs

# CELL ********************

obt = (
    detail
    .join(header,       detail.SalesOrderID == header.h_SalesOrderID,    "left")
    .join(customer,     header.CustomerID   == customer.c_CustomerID,     "left")
    .join(product,      detail.ProductID    == product.p_ProductID,       "left")
    .join(category,     product.p_CategoryID == category.cat_ID,          "left")
    .join(model,        product.p_ModelID   == model.mod_ID,              "left")
    .join(ship_address, header.ShipToAddressID == ship_address.ship_AddressID, "left")
    .join(bill_address, header.BillToAddressID == bill_address.bill_AddressID, "left")
)
 
print(f"OBT after JOINs: {obt.count():,} rows, {len(obt.columns)} columns")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 5 — Add derived columns

# CELL ********************

from pyspark.sql.functions import (
    when, round, datediff, current_timestamp,
    concat, lit, trim
)

obt = (
    obt
    # --- Customer derived ---
    .withColumn("FullName",
        trim(concat(col("FirstName"), lit(" "), col("LastName")))
    )
    .withColumn("Gender",
        when(col("Title").isin("Mr.", "Sr."), "Male")
        .when(col("Title").isin("Ms.", "Mrs.", "Sra."), "Female")
        .otherwise("Unknown")
    )
    # --- Time metrics ---
    .withColumn("days_to_ship",  datediff(col("ShipDate"), col("OrderDate")))
    .withColumn("days_to_due",   datediff(col("DueDate"),  col("OrderDate")))
    # --- Discount flag ---
    .withColumn("is_discounted",
        when(col("UnitPriceDiscount") > 0, True).otherwise(False)
    )
    # --- Price ratio ---
    .withColumn("price_vs_list",
        round(col("UnitPrice") / col("ListPrice"), 4)
    )
    # --- Audit ---
    .withColumn("silver_processed_date", current_timestamp())
)

print("Derived columns added to OBT:")
print("  FullName, Gender, days_to_ship, days_to_due,")
print("  is_discounted, price_vs_list, silver_processed_date")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 6 — Final column selection in target order

# CELL ********************

obt_final = obt.select(
 
    # Sales — keys and dates
    col("SalesOrderID")         .alias("Sales.SalesOrderID"),
    col("SalesOrderDetailID")   .alias("Sales.SalesOrderDetailID"),
    col("OrderDate")            .alias("Sales.OrderDate"),
    col("DueDate")              .alias("Sales.DueDate"),
    col("ShipDate")             .alias("Sales.ShipDate"),
 
    # Sales — measures
    col("OrderQty")             .alias("Sales.OrderQty"),
    col("UnitPrice")            .alias("Sales.UnitPrice"),
    col("UnitPriceDiscount")    .alias("Sales.UnitPriceDiscount"),
    col("LineTotal")            .alias("Sales.LineTotal"),
 
    # Sales — derived time metrics
    col("days_to_ship"),
    col("days_to_due"),
    col("is_discounted"),
 
    # Sales — attributes
    col("Status")               .alias("Sales.Status"),
    col("OnlineOrderFlag")      .alias("Sales.OnlineOrderFlag"),
    col("ShipMethod")           .alias("Sales.ShipMethod"),
 
    # Product
    col("p_ProductID")          .alias("Sales.ProductID"),
    col("ProductName")          .alias("Product.Name"),
    col("ProductNumber")        .alias("Product.ProductNumber"),
    col("Color")                .alias("Product.Color"),
    col("StandardCost")         .alias("Product.StandardCost"),
    col("ListPrice")            .alias("Product.ListPrice"),
    col("Size")                 .alias("Product.Size"),
    col("CategoryName")         .alias("ProductCategory.Name"),
    col("ModelName")            .alias("ProductModel.Name"),
    col("price_vs_list"),
 
    # Customer
    col("CustomerID")           .alias("Sales.CustomerID"),
    col("FullName")             .alias("Customer.FullName"),
    col("Gender")               .alias("Customer.Gender"),
    col("CompanyName")          .alias("Customer.CompanyName"),
    col("SalesPerson")          .alias("Customer.SalesPerson"),
    col("EmailAddress")         .alias("Customer.EmailAddress"),
 
    # Addresses
    col("ShipToAddressID"),
    col("ShipCity")             .alias("ShipAddress.City"),
    col("ShipStateProvince")    .alias("ShipAddress.StateProvince"),
    col("ShipCountryRegion")    .alias("ShipAddress.CountryRegion"),
 
    col("BillToAddressID"),
    col("BillCity")             .alias("BillAddress.City"),
    col("BillStateProvince")    .alias("BillAddress.StateProvince"),
    col("BillCountryRegion")    .alias("BillAddress.CountryRegion"),
 
    # Audit
    col("silver_processed_date"),
)
 
print(f"OBT_Sales final: {obt_final.count():,} rows x {len(obt_final.columns)} columns")
print("\nColumns:")
for c in obt_final.columns:
    print(f"  {c}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 7 — Null check on key columns

# CELL ********************

from pyspark.sql.functions import count
 
key_cols = [
    "Sales.SalesOrderID",
    "Sales.SalesOrderDetailID",
    "Sales.ProductID",
    "Sales.CustomerID",
    "Sales.LineTotal",
    "Sales.OrderDate",
]
 
print("Null counts on key columns:")
obt_final.select([
    count(when(col(f"`{c}`").isNull(), c)).alias(c)
    for c in key_cols
]).show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 8  — clean_data() Data Wrangler

# CELL ********************

# Code generated by Data Wrangler for PySpark DataFrame
from pyspark.sql.functions import to_date

def clean_data(obt_final):
    obt_final = obt_final.withColumn('Sales.OrderDate', to_date(col('`Sales.OrderDate`')))
    obt_final = obt_final.withColumn('Sales.DueDate',   to_date(col('`Sales.DueDate`')))
    obt_final = obt_final.withColumn('Sales.ShipDate',  to_date(col('`Sales.ShipDate`')))
    obt_final = obt_final.fillna(value="Unkown", subset=['`Product.Color`', '`Product.Size`'])
    return obt_final

obt_final_clean = clean_data(obt_final)
display(obt_final_clean)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # CELL 9 — Write SilverOBT to Silver Lakehouse

# CELL ********************

(
    obt_final_clean
    .write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(f"{SILVER_SCHEMA}.SilverOBT")
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
