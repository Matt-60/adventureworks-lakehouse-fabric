CREATE TABLE [gold].[DimAddress] (
    [AddressID]     INT           NOT NULL,
    [City]          VARCHAR (60)  NULL,
    [StateProvince] VARCHAR (100) NULL,
    [CountryRegion] VARCHAR (100) NULL,
    [PostalCode]    VARCHAR (30)  NULL
);


GO