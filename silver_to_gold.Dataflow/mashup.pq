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
shared SilverOBT = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "7ade5bd0-e9ec-4999-9dc0-1dfa63be203c"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "d6396ec3-0af0-45af-80fc-15f6a5a2313f"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "SilverOBT", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared DimCustomer = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"Sales.CustomerID"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "CustomerKey"}}),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"CustomerKey", "Sales.CustomerID", "Customer.FullName", "Customer.Gender", "Customer.CompanyName", "Customer.SalesPerson", "Customer.EmailAddress"}),
  #"Renamed columns1" = Table.RenameColumns(
    #"Reordered columns",
    {
        {"Sales.CustomerID", "CustomerID"},
        {"Customer.FullName", "FullName"},
        {"Customer.Gender", "Gender"},
        {"Customer.CompanyName", "CompanyName"},
        {"Customer.SalesPerson", "SalesPerson"},
        {"Customer.EmailAddress", "EmailAddress"}
    }
)
in
  #"Renamed columns1";
[BindToDefaultDestination = true]
shared DimFlags = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "FlagKey"},{"Sales.Status", "Status"},
        {"Sales.OnlineOrderFlag", "OnlineOrderFlag"},
        {"Sales.ShipMethod", "ShipMethod"}}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Renamed columns", {"FlagKey", "is_discounted", "Status", "OnlineOrderFlag", "ShipMethod"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Reordered columns 1", {{"is_discounted", "IsDiscounted"}})
in
  #"Renamed columns 1";
[BindToDefaultDestination = true]
shared DimProduct = let
  Source = SilverOBT,
  #"Choose columns" = Table.SelectColumns(Source, {"Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"Sales.ProductID", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "Product.Name", "Product.ProductNumber", "Product.Color", "Product.StandardCost", "Product.ListPrice", "Product.Size", "ProductCategory.Name", "ProductModel.Name"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "ProductKey"},{"Product.Name", "ProductName"},
        {"Product.ProductNumber", "ProductNumber"},
        {"Product.Color", "Color"},
        {"Product.StandardCost", "StandardCost"},
        {"Product.ListPrice", "ListPrice"},
        {"Product.Size", "Size"},
        {"ProductCategory.Name", "CategoryName"},
        {"ProductModel.Name", "ModelName"}
}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Renamed columns", {"ProductKey", "Sales.ProductID", "ProductName", "ProductNumber", "Color", "StandardCost", "ListPrice", "Size", "CategoryName", "ModelName"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Reordered columns 1", {{"Sales.ProductID", "ProductID"}})
in
  #"Renamed columns 1";
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
  #"Merged queries" = Table.NestedJoin(#"Choose columns", {"Sales.CustomerID"}, DimCustomer, {"CustomerID"}, "DimCustomer", JoinKind.LeftOuter),
  #"Merged queries 1" = Table.NestedJoin(#"Merged queries", {"is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod"}, DimFlags, {"IsDiscounted", "Status", "OnlineOrderFlag", "ShipMethod"}, "DimFlags", JoinKind.LeftOuter),
  #"Merged queries 2" = Table.NestedJoin(#"Merged queries 1", {"Sales.ProductID"}, DimProduct, {"ProductID"}, "DimProduct", JoinKind.LeftOuter),
  #"Merged queries 3" = Table.NestedJoin(#"Merged queries 2", {"ShipToAddressID"}, DimAddress, {"ShipAddressID"}, "DimAddress", JoinKind.LeftOuter),
  #"Merged queries 4" = Table.NestedJoin(#"Merged queries 3", {"BillToAddressID"}, DimAddress, {"BillAddressID"}, "DimAddress (2)", JoinKind.LeftOuter),
  #"Expanded DimCustomer" = Table.ExpandTableColumn(#"Merged queries 4", "DimCustomer", {"CustomerKey"}, {"CustomerKey"}),
  #"Expanded DimFlags" = Table.ExpandTableColumn(#"Expanded DimCustomer", "DimFlags", {"FlagKey"}, {"FlagKey"}),
  #"Expanded DimProduct" = Table.ExpandTableColumn(#"Expanded DimFlags", "DimProduct", {"ProductKey"}, {"ProductKey"}),
  #"Expanded DimAddress" = Table.ExpandTableColumn(#"Expanded DimProduct", "DimAddress", {"AddressKey"}, {"AddressKey"}),
  #"Expanded DimAddress (2)" = Table.ExpandTableColumn(#"Expanded DimAddress", "DimAddress (2)", {"AddressKey"}, {"AddressKey.1"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded DimAddress (2)", {{"AddressKey", "ShipAddressKey"}, {"AddressKey.1", "BillAddressKey"}}),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"CustomerKey", "FlagKey", "ProductKey", "ShipAddressKey", "BillAddressKey", "Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "is_discounted", "Sales.Status", "Sales.OnlineOrderFlag", "Sales.ShipMethod", "Sales.ProductID", "price_vs_list", "Sales.CustomerID", "ShipToAddressID", "BillToAddressID", "silver_processed_date"}),
  #"Choose columns 1" = Table.SelectColumns(#"Reordered columns", {"CustomerKey", "FlagKey", "ProductKey", "ShipAddressKey", "BillAddressKey", "Sales.SalesOrderID", "Sales.SalesOrderDetailID", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "price_vs_list", "silver_processed_date"}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Choose columns 1", {"Sales.SalesOrderID", "Sales.SalesOrderDetailID", "CustomerKey", "FlagKey", "ProductKey", "ShipAddressKey", "BillAddressKey", "Sales.OrderDate", "Sales.DueDate", "Sales.ShipDate", "Sales.OrderQty", "Sales.UnitPrice", "Sales.UnitPriceDiscount", "Sales.LineTotal", "days_to_ship", "days_to_due", "price_vs_list", "silver_processed_date"}),
  #"Renamed columns1" = Table.RenameColumns(
    #"Reordered columns 1",
    {
        {"Sales.SalesOrderID", "SalesOrderID"},
        {"Sales.SalesOrderDetailID", "SalesOrderDetailID"},
        {"Sales.OrderDate", "OrderDate"},
        {"Sales.DueDate", "DueDate"},
        {"Sales.ShipDate", "ShipDate"},
        {"Sales.OrderQty", "OrderQty"},
        {"Sales.UnitPrice", "UnitPrice"},
        {"Sales.UnitPriceDiscount", "UnitPriceDiscount"},
        {"Sales.LineTotal", "LineTotal"}
    }
),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns1", "gold_processed_date", each DateTime.FixedLocalNow()), {{"gold_processed_date", type datetime}})
in
  #"Added custom";
