CREATE TABLE [gold].[DimDate] (
    [Date]            DATE         NOT NULL,
    [Year]            INT          NOT NULL,
    [Quarter]         VARCHAR (2)  NOT NULL,
    [MonthNumber]     INT          NOT NULL,
    [MonthName]       VARCHAR (10) NOT NULL,
    [MonthShort]      VARCHAR (3)  NOT NULL,
    [YearMonthNumber] INT          NOT NULL,
    [YearMonth]       VARCHAR (7)  NOT NULL,
    [Day]             INT          NOT NULL,
    [WeekdayNumber]   INT          NOT NULL,
    [DayName]         VARCHAR (10) NOT NULL,
    [IsWeekend]       BIT          NOT NULL
);


GO