CREATE TABLE [gold].[DimFlags] (
    [FlagKey]         INT          NOT NULL,
    [Status]          INT          NULL,
    [StatusName]      VARCHAR (20) NULL,
    [OnlineOrderFlag] INT          NULL,
    [OrderChannel]    VARCHAR (10) NULL,
    [ShipMethod]      VARCHAR (50) NULL,
    [IsDiscounted]    INT          NULL,
    [PriceType]       VARCHAR (12) NULL
);


GO