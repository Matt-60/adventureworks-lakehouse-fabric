[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"bronze Address" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.Address", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"bronze Customer" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.Customer", ItemKind = "Table"]}[Data],
  #"Sorted rows" = Table.Sort(#"Navigation 2", {{"CustomerID", Order.Ascending}})
in
  #"Sorted rows";
shared #"bronze Product" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.Product", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"bronze ProductCategory" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.ProductCategory", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"bronze ProductModel" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.ProductModel", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"bronze SalesOrderDetail" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.SalesOrderDetail", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"bronze SalesOrderHeader" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.SalesOrderHeader", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared Count_rows_fact_table = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "a618a618-7c48-4876-bc22-4e802bfd2b12"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.SalesOrderDetail", ItemKind = "Table"]}[Data],
  #"Counted rows" = Table.RowCount(#"Navigation 2")
in
  #"Counted rows";
shared SilverOBTDetail = let
  Source = Table.NestedJoin(#"bronze SalesOrderDetail", {"ProductID"}, #"bronze Product", {"ProductID"}, "Product", JoinKind.LeftOuter),
  #"Expanded Product" = Table.ExpandTableColumn(Source, "Product", {"Name", "ProductNumber", "Color", "StandardCost", "ListPrice", "Size", "Weight", "ProductCategoryID", "ProductModelID", "SellStartDate", "SellEndDate", "DiscontinuedDate", "ThumbNailPhoto", "ThumbnailPhotoFileName", "rowguid", "ModifiedDate"}, {"Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "Product.Weight", "Product.ProductCategoryID", "Product.ProductModelID", "Product.SellStartDate", "Product.SellEndDate", "Product.DiscontinuedDate", "Product.ThumbNailPhoto", "Product.ThumbnailPhotoFileName", "Product.rowguid", "Product.ModifiedDate"}),
  #"Merged queries 3" = Table.NestedJoin(#"Expanded Product", {"Product.ProductCategoryID"}, #"bronze ProductCategory", {"ProductCategoryID"}, "ProductCategory", JoinKind.LeftOuter),
  #"Merged queries 4" = Table.NestedJoin(#"Merged queries 3", {"Product.ProductModelID"}, #"bronze ProductModel", {"ProductModelID"}, "ProductModel", JoinKind.LeftOuter),
  #"Expanded ProductCategory" = Table.ExpandTableColumn(#"Merged queries 4", "ProductCategory", {"ParentProductCategoryID", "Name", "rowguid", "ModifiedDate"}, {"ProductCategory.ParentProductCategoryID", "ProductCategory.Name", "ProductCategory.rowguid", "ProductCategory.ModifiedDate"}),
  #"Expanded ProductModel" = Table.ExpandTableColumn(#"Expanded ProductCategory", "ProductModel", {"Name", "CatalogDescription", "rowguid", "ModifiedDate"}, {"ProductModel.Name", "ProductModel.CatalogDescription", "ProductModel.rowguid", "ProductModel.ModifiedDate"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded ProductModel", {
    {"SalesOrderID", "Sales.SalesOrderID"},
    {"SalesOrderDetailID", "Sales.SalesOrderDetailID"},
    {"OrderQty", "Sales.OrderQty"},
    {"ProductID", "Sales.ProductID"},
    {"UnitPrice", "Sales.UnitPrice"},
    {"UnitPriceDiscount", "Sales.UnitPriceDiscount"},
    {"LineTotal", "Sales.LineTotal"}
}),
  #"Choose columns" = Table.SelectColumns(#"Renamed columns", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderQty", "Sales.ProductID", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Choose columns", "is_discounted", each if [Sales.UnitPriceDiscount] > 0 then true else false), {{"is_discounted", type logical}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "price_vs_list", each [Sales.UnitPrice] / [Product.ListPrice]), {{"price_vs_list", Percentage.Type}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "silver_processed_date", each DateTime.FixedLocalNow()), {{"silver_processed_date", type datetime}}),
  #"Reordered columns" = Table.ReorderColumns(#"Added custom 2", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name", "is_discounted", "price_vs_list", "silver_processed_date"})
in
    #"Reordered columns";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data]{[lakehouseId = "d6396ec3-0af0-45af-80fc-15f6a5a2313f"]}[Data];
shared SilverOBTHeader = let
  Source = Table.NestedJoin(#"bronze SalesOrderHeader", {"CustomerID"}, #"bronze Customer", {"CustomerID"}, "Customer", JoinKind.LeftOuter),
  #"Merged queries" = Table.NestedJoin(Source, {"ShipToAddressID"}, #"bronze Address", {"AddressID"}, "ShipAddress", JoinKind.LeftOuter),
  #"Merged queries 1" = Table.NestedJoin(#"Merged queries", {"BillToAddressID"}, #"bronze Address", {"AddressID"}, "BillAddress", JoinKind.LeftOuter),
  #"Expanded Customer" = Table.ExpandTableColumn(#"Merged queries 1", "Customer", {"NameStyle", "Title", "FirstName", "MiddleName", "LastName", "Suffix", "CompanyName", "SalesPerson", "EmailAddress", "Phone", "PasswordHash", "PasswordSalt", "rowguid", "ModifiedDate"}, {"Customer.NameStyle", "Customer.Title", "Customer.FirstName", "Customer.MiddleName", "Customer.LastName", "Customer.Suffix", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "Customer.Phone", "Customer.PasswordHash", "Customer.PasswordSalt", "Customer.rowguid", "Customer.ModifiedDate"}),
  #"Expanded ShipAddress" = Table.ExpandTableColumn(#"Expanded Customer", "ShipAddress", {"AddressLine1", "AddressLine2", "City", "StateProvince", "CountryRegion", "PostalCode", "rowguid", "ModifiedDate"}, {"ShipAddress.AddressLine1", "ShipAddress.AddressLine2", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "ShipAddress.PostalCode", "ShipAddress.rowguid", "ShipAddress.ModifiedDate"}),
  #"Expanded BillAddress" = Table.ExpandTableColumn(#"Expanded ShipAddress", "BillAddress", {"AddressLine1", "AddressLine2", "City", "StateProvince", "CountryRegion", "PostalCode", "rowguid", "ModifiedDate"}, {"BillAddress.AddressLine1", "BillAddress.AddressLine2", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "BillAddress.PostalCode", "BillAddress.rowguid", "BillAddress.ModifiedDate"}),
  #"Added Conditional Column" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded BillAddress", "Customer.Gender", each if [Customer.Title] = "Mr." then "Male" else if [Customer.Title] = "Ms." then "Female" else null), {{"Customer.Gender", type text}}),
  #"Inserted Merged Column" = Table.TransformColumnTypes(Table.AddColumn(#"Added Conditional Column", "Customer.FullName", each Text.Combine({[Customer.FirstName], " ", [Customer.LastName]})), {{"Customer.FullName", type text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Inserted Merged Column", "days_to_ship", each [ShipDate] - [OrderDate]), {{"days_to_ship", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "days_to_due", each [DueDate] - [OrderDate]), {{"days_to_due", Int64.Type}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "silver_processed_date", each DateTime.FixedLocalNow()), {{"silver_processed_date", type datetime}}),
  #"Choose columns" = Table.SelectColumns(#"Added custom 3", {"SalesOrderID", "OrderDate", "DueDate", "ShipDate", "Status", "OnlineOrderFlag", "CustomerID", "ShipToAddressID", "BillToAddressID", "ShipMethod", "SubTotal", "TaxAmt", "Freight", "TotalDue", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "Customer.Gender", "Customer.FullName", "days_to_ship", "days_to_due", "silver_processed_date"}),
  #"Renamed Columns" = Table.RenameColumns(
    #"Choose columns",
    {
        {"SalesOrderID", "Sales.SalesOrderID"},
        {"CustomerID", "Sales.CustomerID"},
        {"OrderDate", "Sales.OrderDate"},
        {"DueDate", "Sales.DueDate"},
        {"ShipDate", "Sales.ShipDate"},
        {"Status", "Sales.Status"},
        {"OnlineOrderFlag", "Sales.OnlineOrderFlag"},
        {"ShipMethod", "Sales.ShipMethod"},
        {"SubTotal", "Sales.SubTotal"},
        {"TaxAmt", "Sales.TaxAmt"},
        {"Freight", "Sales.Freight"},
        {"TotalDue", "Sales.TotalDue"}
    },
    MissingField.Ignore
),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed Columns", {"Sales.SalesOrderID", "Sales.SubTotal", "Sales.TaxAmt", "Sales.Freight", "Sales.TotalDue", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "days_to_ship", "days_to_due", "silver_processed_date"})
in
    #"Reordered columns";
[BindToDefaultDestination = true]
shared SilverOBT = let
  Source = Table.NestedJoin(SilverOBTDetail, {"Sales.SalesOrderID"}, SilverOBTHeader, {"Sales.SalesOrderID"}, "SilverOBTHeader", JoinKind.LeftOuter),
  #"Expanded SilverOBTHeader" = Table.ExpandTableColumn(Source, "SilverOBTHeader", {"Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "days_to_ship", "days_to_due"}, {"Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "days_to_ship", "days_to_due"}),
  #"Reordered columns" = Table.ReorderColumns(#"Expanded SilverOBTHeader", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name", "price_vs_list", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress", "ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion", "silver_processed_date"})
in
  #"Reordered columns";
