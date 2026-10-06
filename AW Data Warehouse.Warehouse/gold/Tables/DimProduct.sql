CREATE TABLE [gold].[DimProduct] (
    [ProductID]     INT             NOT NULL,
    [ProductName]   VARCHAR (100)   NULL,
    [ProductNumber] VARCHAR (50)    NULL,
    [Color]         VARCHAR (30)    NULL,
    [Size]          VARCHAR (10)    NULL,
    [Weight]        DECIMAL (10, 2) NULL,
    [StandardCost]  DECIMAL (19, 4) NULL,
    [ListPrice]     DECIMAL (19, 4) NULL,
    [ModelName]     VARCHAR (100)   NULL,
    [Subcategory]   VARCHAR (100)   NULL,
    [Category]      VARCHAR (100)   NULL,
    [IsActive]      BIT             NULL
);


GO