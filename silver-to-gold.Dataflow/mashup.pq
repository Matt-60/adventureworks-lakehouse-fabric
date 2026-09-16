[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data]{[lakehouseId = "2db4b04e-d810-4f79-b787-9b149394a65f"]}[Data];
[BindToDefaultDestination = true]
shared DimDate = let
    StartDate = #date(2008, 6, 1),
    EndDate = #date(2008, 7, 1),
    DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    ChangeType = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddYear = Table.AddColumn(ChangeType, "year", each Date.Year([Date]), Int32.Type),
    AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([Date]), Int32.Type),
    AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.ToText([Date], "MMMM"), type text),
    AddQuarter = Table.AddColumn(AddMonthName, "quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddDay = Table.AddColumn(AddQuarter, "day", each Date.Day([Date]), Int32.Type),
    AddDayName = Table.AddColumn(AddDay, "day_name", each Date.ToText([Date], "dddd"), type text),
    AddIsWeekend = Table.AddColumn(AddDayName, "is_weekend", each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical)
in
    AddIsWeekend;
[BindToDefaultDestination = true]
shared DimCustomer = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"Sales.CustomerID"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress"}),
  #"Renamed columns1" = Table.RenameColumns(#"Reordered columns", {{"Sales.CustomerID", "CustomerID"}, {"Customer.FullName", "FullName"}, {"Customer.Gender", "Gender"}, {"Customer.CompanyName", "CompanyName"}, {"Customer.SalesPerson", "SalesPerson"}, {"Customer.EmailAddress", "EmailAddress"}, {"Index", "CustomerKey"}})
in
  #"Renamed columns1";
[BindToDefaultDestination = true]
shared DimFlags = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "Sales.Status", "is_discounted", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "FlagKey"}, {"Sales.Status", "Status"}, {"Sales.OnlineOrderFlag", "OnlineOrderFlag"}, {"Sales.ShipMethod", "ShipMethod"}, {"is_discounted", "IsDiscounted"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared DimProduct = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "ProductKey"}, {"Product.Name", "ProductName"}, {"Product.ProductNumber", "ProductNumber"}, {"Product.Color", "Color"}, {"Product.StandardCost", "StandardCost"}, {"Product.ListPrice", "ListPrice"}, {"Product.Size", "Size"}, {"ProductCategory.Name", "CategoryName"}, {"ProductModel.Name", "ModelName"}, {"Sales.ProductID", "ProductID"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared DimAddress = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "ShipToAddressID", "ShipAddress.City", "ShipAddress.StateProvince", "ShipAddress.CountryRegion", "BillToAddressID", "BillAddress.City", "BillAddress.StateProvince", "BillAddress.CountryRegion"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "AddressKey"}, {"ShipToAddressID", "ShipAddressID"},
        {"ShipAddress.City", "ShipCity"},
        {"ShipAddress.StateProvince", "ShipStateProvince"},
        {"ShipAddress.CountryRegion", "ShipCountryRegion"},
        {"BillToAddressID", "BillAddressID"},
        {"BillAddress.City", "BillCity"},
        {"BillAddress.StateProvince", "BillStateProvince"},
        {"BillAddress.CountryRegion", "BillCountryRegion"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared FactSales = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.ProductID", "price_vs_list", "Sales.CustomerID", "ShipToAddressID", "BillToAddressID", "silver_processed_date"}),
  #"Merged Customer" = Table.NestedJoin(#"Choose columns", {"Sales.CustomerID"}, DimCustomer, {"CustomerID"}, "DimCustomer", JoinKind.LeftOuter),
  #"Merged Flags" = Table.NestedJoin(#"Merged Customer", {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}, DimFlags, {"IsDiscounted", "Status", "OnlineOrderFlag", "ShipMethod"}, "DimFlags", JoinKind.LeftOuter),
  #"Merged Product" = Table.NestedJoin(#"Merged Flags", {"Sales.ProductID"}, DimProduct, {"ProductID"}, "DimProduct", JoinKind.LeftOuter),
  #"Merged ShipAddress" = Table.NestedJoin(#"Merged Product", {"ShipToAddressID"}, DimAddress, {"ShipAddressID"}, "DimAddress", JoinKind.LeftOuter),
  #"Merged BillAddress" = Table.NestedJoin(#"Merged ShipAddress", {"BillToAddressID"}, DimAddress, {"BillAddressID"}, "DimAddress (2)", JoinKind.LeftOuter),
  #"Expanded DimCustomer" = Table.ExpandTableColumn(#"Merged BillAddress", "DimCustomer", {"CustomerKey"}, {"CustomerKey"}),
  #"Expanded DimFlags" = Table.ExpandTableColumn(#"Expanded DimCustomer", "DimFlags", {"FlagKey"}, {"FlagKey"}),
  #"Expanded DimProduct" = Table.ExpandTableColumn(#"Expanded DimFlags", "DimProduct", {"ProductKey"}, {"ProductKey"}),
  #"Expanded DimAddress Ship" = Table.ExpandTableColumn(#"Expanded DimProduct", "DimAddress", {"AddressKey"}, {"AddressKey"}),
  #"Expanded DimAddress Bill" = Table.ExpandTableColumn(#"Expanded DimAddress Ship", "DimAddress (2)", {"AddressKey"}, {"AddressKey.1"}),
  #"Choose final columns" = Table.SelectColumns(#"Expanded DimAddress Bill", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "price_vs_list", "silver_processed_date", "CustomerKey", "FlagKey", "ProductKey", "AddressKey", "AddressKey.1"}),
  #"Final order" = Table.ReorderColumns(#"Choose final columns", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "CustomerKey", "FlagKey", "ProductKey", "AddressKey", "AddressKey.1", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "price_vs_list", "silver_processed_date"}),
  #"Final column names" = Table.RenameColumns(#"Final order", {{"Sales.SalesOrderID", "SalesOrderID"}, {"Sales.SalesOrderDetailID", "SalesOrderDetailID"}, {"Sales.OrderDate", "OrderDate"}, {"Sales.DueDate", "DueDate"}, {"Sales.ShipDate", "ShipDate"}, {"Sales.OrderQty", "OrderQty"}, {"Sales.UnitPrice", "UnitPrice"}, {"Sales.UnitPriceDiscount", "UnitPriceDiscount"}, {"Sales.LineTotal", "LineTotal"}, {"AddressKey", "ShipAddressKey"}, {"AddressKey.1", "BillAddressKey"}}),
  #"Added gold_processed_date" = Table.TransformColumnTypes(Table.AddColumn(#"Final column names", "gold_processed_date", each DateTime.FixedLocalNow()), {{"gold_processed_date", type datetime}})
in
  #"Added gold_processed_date";
[BindToDefaultDestination = true]
shared SilverOBT = let
  Source = Lakehouse.Contents(null),
  #"Navigation 1" = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "d6396ec3-0af0-45af-80fc-15f6a5a2313f"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "SilverOBT", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
