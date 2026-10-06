/* ---------------------------------------------------------------------
   PART 2 — the load procedure (called by the pipeline)
   --------------------------------------------------------------------- */

CREATE   PROCEDURE gold.usp_load_gold
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------
    -- DimProduct — with category hierarchy
    -------------------------------------------------------------------
    TRUNCATE TABLE gold.DimProduct;
    INSERT INTO gold.DimProduct
        (ProductID, ProductName, ProductNumber, Color, Size, Weight,
         StandardCost, ListPrice, ModelName, Subcategory, Category, IsActive)
    SELECT
        p.ProductID,
        p.Name,
        p.ProductNumber,
        p.Color,
        p.Size,
        p.Weight,
        p.StandardCost,
        p.ListPrice,
        m.Name,
        sc.Name,
        COALESCE(pc.Name, sc.Name),
        CASE WHEN p.SellEndDate IS NULL THEN 1 ELSE 0 END
    FROM AW_Data_Product.silver.product              AS p
    LEFT JOIN AW_Data_Product.silver.productmodel    AS m  ON m.ProductModelID     = p.ProductModelID
    LEFT JOIN AW_Data_Product.silver.productcategory AS sc ON sc.ProductCategoryID = p.ProductCategoryID
    LEFT JOIN AW_Data_Product.silver.productcategory AS pc ON pc.ProductCategoryID = sc.ParentProductCategoryID;

    -------------------------------------------------------------------
    -- DimCustomer — all customers, not only those with orders
    -------------------------------------------------------------------
    TRUNCATE TABLE gold.DimCustomer;
    INSERT INTO gold.DimCustomer (CustomerID, FullName, Gender, CompanyName, SalesPerson)
    SELECT
        CustomerID,
        CONCAT_WS(' ', FirstName, LastName),
        CASE
            WHEN Title IN ('Mr.', 'Sr.')          THEN 'Male'
            WHEN Title IN ('Ms.', 'Mrs.', 'Sra.') THEN 'Female'
            ELSE 'Unknown'
        END,
        CompanyName,
        SalesPerson
    FROM AW_Data_Product.silver.customer;

    -------------------------------------------------------------------
    -- DimAddress — 1 row = 1 address (role-playing: ship / bill)
    -------------------------------------------------------------------
    TRUNCATE TABLE gold.DimAddress;
    INSERT INTO gold.DimAddress (AddressID, City, StateProvince, CountryRegion, PostalCode)
    SELECT AddressID, City, StateProvince, CountryRegion, PostalCode
    FROM AW_Data_Product.silver.address;

    -------------------------------------------------------------------
    -- DimDate — dynamic range: full years covering all order/ship/due dates
    -------------------------------------------------------------------
    DECLARE @StartDate date, @EndDate date;

    SELECT
        @StartDate = DATEFROMPARTS(YEAR(MIN(OrderDate)), 1, 1),
        @EndDate   = DATEFROMPARTS(YEAR(MAX(CASE
                         WHEN DueDate  >= ISNULL(ShipDate, OrderDate) AND DueDate >= OrderDate THEN DueDate
                         WHEN ShipDate >= OrderDate THEN ShipDate
                         ELSE OrderDate END)), 12, 31)
    FROM AW_Data_Product.silver.salesorderheader;

    TRUNCATE TABLE gold.DimDate;
    INSERT INTO gold.DimDate
        ([Date], [Year], [Quarter], MonthNumber, MonthName, MonthShort,
         YearMonthNumber, YearMonth, [Day], WeekdayNumber, DayName, IsWeekend)
    SELECT
        d.[Date],
        YEAR(d.[Date]),
        CAST(CONCAT('Q', DATEPART(quarter, d.[Date])) AS varchar(2)),
        MONTH(d.[Date]),
        CAST(DATENAME(month, d.[Date]) AS varchar(10)),
        CAST(LEFT(DATENAME(month, d.[Date]), 3) AS varchar(3)),
        YEAR(d.[Date]) * 100 + MONTH(d.[Date]),
        CAST(FORMAT(d.[Date], 'yyyy-MM') AS varchar(7)),
        DAY(d.[Date]),
        (DATEDIFF(day, '19000101', d.[Date]) % 7) + 1,           -- 1900-01-01 was a Monday
        CAST(DATENAME(weekday, d.[Date]) AS varchar(10)),
        CASE WHEN (DATEDIFF(day, '19000101', d.[Date]) % 7) >= 5 THEN 1 ELSE 0 END
    FROM (
        SELECT DATEADD(day, n.n, @StartDate) AS [Date]
        FROM (
            SELECT a.v + b.v * 10 + c.v * 100 + e.v * 1000 AS n
            FROM       (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS a(v)
            CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS b(v)
            CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS c(v)
            CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS e(v)
        ) AS n
        WHERE n.n <= DATEDIFF(day, @StartDate, @EndDate)
    ) AS d;

    -------------------------------------------------------------------
    -- DimFlags — junk dimension: low-cardinality order/line attributes
    -------------------------------------------------------------------
    TRUNCATE TABLE gold.DimFlags;
    INSERT INTO gold.DimFlags
        (FlagKey, Status, StatusName, OnlineOrderFlag, OrderChannel, ShipMethod, IsDiscounted, PriceType)
    SELECT
        ROW_NUMBER() OVER (ORDER BY f.Status, f.OnlineOrderFlag, f.ShipMethod, f.IsDiscounted),
        f.Status,
        CASE f.Status
            WHEN 1 THEN 'In process'
            WHEN 2 THEN 'Approved'
            WHEN 3 THEN 'Backordered'
            WHEN 4 THEN 'Rejected'
            WHEN 5 THEN 'Shipped'
            WHEN 6 THEN 'Cancelled'
            ELSE 'Unknown'
        END,
        f.OnlineOrderFlag,
        CASE WHEN f.OnlineOrderFlag = 1 THEN 'Online' ELSE 'Offline' END,
        f.ShipMethod,
        f.IsDiscounted,
        CASE WHEN f.IsDiscounted = 1 THEN 'Discounted' ELSE 'Full price' END
    FROM (
        SELECT DISTINCT
            CAST(h.Status AS int)                                AS Status,
            CAST(h.OnlineOrderFlag AS int)                       AS OnlineOrderFlag,
            COALESCE(h.ShipMethod, 'Unknown')                    AS ShipMethod,
            CASE WHEN d.UnitPriceDiscount > 0 THEN 1 ELSE 0 END  AS IsDiscounted
        FROM AW_Data_Product.silver.salesorderdetail AS d
        JOIN AW_Data_Product.silver.salesorderheader AS h ON h.SalesOrderID = d.SalesOrderID
    ) AS f;

    -------------------------------------------------------------------
    -- FactSales — grain: order line; only keys + numeric measures
    -------------------------------------------------------------------
    TRUNCATE TABLE gold.FactSales;
    INSERT INTO gold.FactSales
        (SalesOrderID, SalesOrderDetailID, CustomerID, ProductID, ShipAddressID, BillAddressID,
         FlagKey, OrderDate, ShipDate, DueDate, OrderQty, UnitPrice, UnitPriceDiscount,
         LineTotal, LineTotalAtListPrice, LineCost, DaysToShip, DaysToDue)
    SELECT
        s.SalesOrderID,
        s.SalesOrderDetailID,
        s.CustomerID,
        s.ProductID,
        s.ShipAddressID,
        s.BillAddressID,
        fl.FlagKey,
        s.OrderDate,
        s.ShipDate,
        s.DueDate,
        s.OrderQty,
        s.UnitPrice,
        s.UnitPriceDiscount,
        s.LineTotal,
        s.LineTotalAtListPrice,
        s.LineCost,
        s.DaysToShip,
        s.DaysToDue
    FROM (
        SELECT
            d.SalesOrderID,
            d.SalesOrderDetailID,
            h.CustomerID,
            d.ProductID,
            h.ShipToAddressID                                   AS ShipAddressID,
            h.BillToAddressID                                   AS BillAddressID,
            h.OrderDate,
            h.ShipDate,
            h.DueDate,
            CAST(h.Status AS int)                               AS Status,
            CAST(h.OnlineOrderFlag AS int)                      AS OnlineOrderFlag,
            COALESCE(h.ShipMethod, 'Unknown')                   AS ShipMethod,
            CASE WHEN d.UnitPriceDiscount > 0 THEN 1 ELSE 0 END AS IsDiscounted,
            d.OrderQty,
            d.UnitPrice,
            d.UnitPriceDiscount,
            d.LineTotal,
            d.OrderQty * p.ListPrice                            AS LineTotalAtListPrice,
            d.OrderQty * p.StandardCost                         AS LineCost,
            DATEDIFF(day, h.OrderDate, h.ShipDate)              AS DaysToShip,
            DATEDIFF(day, h.OrderDate, h.DueDate)               AS DaysToDue
        FROM AW_Data_Product.silver.salesorderdetail      AS d
        JOIN AW_Data_Product.silver.salesorderheader      AS h ON h.SalesOrderID = d.SalesOrderID
        LEFT JOIN AW_Data_Product.silver.product          AS p ON p.ProductID    = d.ProductID
    ) AS s
    JOIN gold.DimFlags AS fl
      ON  fl.Status          = s.Status
      AND fl.OnlineOrderFlag = s.OnlineOrderFlag
      AND fl.ShipMethod      = s.ShipMethod
      AND fl.IsDiscounted    = s.IsDiscounted;

    -------------------------------------------------------------------
    -- Data quality gate — fail the pipeline instead of serving bad data
    -------------------------------------------------------------------
    DECLARE @fact_rows   int = (SELECT COUNT(*) FROM gold.FactSales);
    DECLARE @silver_rows int = (SELECT COUNT(*) FROM AW_Data_Product.silver.salesorderdetail);
    IF @fact_rows <> @silver_rows
        THROW 50001, 'Gold check failed: FactSales row count differs from silver.salesorderdetail.', 1;

    IF EXISTS (SELECT 1 FROM gold.FactSales f
               LEFT JOIN gold.DimProduct p ON p.ProductID = f.ProductID
               WHERE p.ProductID IS NULL)
        THROW 50002, 'Gold check failed: FactSales has ProductID not found in DimProduct.', 1;

    IF EXISTS (SELECT 1 FROM gold.FactSales f
               LEFT JOIN gold.DimCustomer c ON c.CustomerID = f.CustomerID
               WHERE c.CustomerID IS NULL)
        THROW 50003, 'Gold check failed: FactSales has CustomerID not found in DimCustomer.', 1;

    IF EXISTS (SELECT 1 FROM gold.FactSales f
               LEFT JOIN gold.DimDate d ON d.[Date] = f.OrderDate
               WHERE d.[Date] IS NULL)
        THROW 50004, 'Gold check failed: FactSales has OrderDate outside DimDate range.', 1;
END;

GO