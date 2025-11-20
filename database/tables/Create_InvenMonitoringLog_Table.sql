USE [ELMI]
GO

/****** Object:  Table [dbo].[InvenMonitoringLog]    Script Date: 11/20/2025 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================
-- Create Inventory Monitoring Log Table
-- ============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InvenMonitoringLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[InvenMonitoringLog](
        [LogID] [int] IDENTITY(1,1) NOT NULL,
        [LogDate] [datetime2](7) NOT NULL DEFAULT(GETDATE()),
        [Tag] [nvarchar](100) NULL,
        [OperationType] [nvarchar](50) NULL,  -- INSERT, UPDATE, DELETE, SELECT, POST, ERROR
        [TranID] [nvarchar](50) NULL,
        [TranType] [nvarchar](250) NULL,      -- Receiving, Issuance, Transfer
        [RecID] [int] NULL,
        [UserID] [nvarchar](250) NULL,
        [Warehouse] [nvarchar](250) NULL,
        [ToWhse] [nvarchar](250) NULL,
        [ItemID] [nvarchar](250) NULL,
        [Quantity] [decimal](18,4) NULL,
        [Status] [nvarchar](50) NULL,
        [OldStatus] [nvarchar](50) NULL,
        [NewStatus] [nvarchar](50) NULL,
        [ErrorMessage] [nvarchar](max) NULL,
        [ErrorNumber] [int] NULL,
        [ErrorSeverity] [int] NULL,
        [ErrorState] [int] NULL,
        [ErrorProcedure] [nvarchar](250) NULL,
        [ErrorLine] [int] NULL,
        [AdditionalInfo] [nvarchar](max) NULL,
        [IPAddress] [nvarchar](50) NULL,
        [HostName] [nvarchar](250) NULL,
        [AppName] [nvarchar](250) NULL,
        [RowsAffected] [int] NULL,
        [ExecutionTime] [int] NULL,  -- in milliseconds
        CONSTRAINT [PK_InvenMonitoringLog] PRIMARY KEY CLUSTERED ([LogID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

-- Create indexes for better query performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InvenMonitoringLog]') AND name = N'IX_InvenMonitoringLog_LogDate')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_InvenMonitoringLog_LogDate]
    ON [dbo].[InvenMonitoringLog] ([LogDate] DESC)
    INCLUDE ([Tag], [OperationType], [TranID], [UserID])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InvenMonitoringLog]') AND name = N'IX_InvenMonitoringLog_TranID')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_InvenMonitoringLog_TranID]
    ON [dbo].[InvenMonitoringLog] ([TranID])
    INCLUDE ([LogDate], [OperationType], [UserID], [Status])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InvenMonitoringLog]') AND name = N'IX_InvenMonitoringLog_UserID')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_InvenMonitoringLog_UserID]
    ON [dbo].[InvenMonitoringLog] ([UserID])
    INCLUDE ([LogDate], [Tag], [OperationType], [TranID])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InvenMonitoringLog]') AND name = N'IX_InvenMonitoringLog_OperationType')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_InvenMonitoringLog_OperationType]
    ON [dbo].[InvenMonitoringLog] ([OperationType])
    INCLUDE ([LogDate], [Tag], [TranID], [UserID])
END
GO

PRINT 'InvenMonitoringLog table and indexes created successfully.'
GO
