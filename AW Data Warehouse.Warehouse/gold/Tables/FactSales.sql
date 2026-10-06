CREATE TABLE [gold].[FactSales] (
    [SalesOrderID]         INT             NOT NULL,
    [SalesOrderDetailID]   INT             NOT NULL,
    [CustomerID]           INT             NULL,
    [ProductID]            INT             NULL,
    [ShipAddressID]        INT             NULL,
    [BillAddressID]        INT             NULL,
    [FlagKey]              INT             NULL,
    [OrderDate]            DATE            NULL,
    [ShipDate]             DATE            NULL,
    [DueDate]              DATE            NULL,
    [OrderQty]             INT             NULL,
    [UnitPrice]            DECIMAL (19, 4) NULL,
    [UnitPriceDiscount]    DECIMAL (19, 4) NULL,
    [LineTotal]            DECIMAL (38, 6) NULL,
    [LineTotalAtListPrice] DECIMAL (38, 6) NULL,
    [LineCost]             DECIMAL (38, 6) NULL,
    [DaysToShip]           INT             NULL,
    [DaysToDue]            INT             NULL
);


GO