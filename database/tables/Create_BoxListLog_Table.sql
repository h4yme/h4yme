USE [ELMI]
GO

/****** Object:  Table [dbo].[BoxListLog]    Script Date: 11/20/2025 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================
-- Create Box List Log Table
-- ============================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[BoxListLog](
        [LogID] [int] IDENTITY(1,1) NOT NULL,
        [LogDate] [datetime2](7) NOT NULL DEFAULT(GETDATE()),
        [Tag] [nvarchar](100) NULL,
        [OperationType] [nvarchar](50) NULL,  -- INSERT, UPDATE, DELETE, SELECT, ERROR
        [RecID] [int] NULL,
        [ItemID] [nvarchar](max) NULL,
        [ItemDescription] [nvarchar](max) NULL,
        [Brand] [nvarchar](max) NULL,
        [Category] [nvarchar](100) NULL,
        [Active] [int] NULL,
        [OldActive] [int] NULL,
        [NewActive] [int] NULL,
        [OldItemDescription] [nvarchar](max) NULL,
        [NewItemDescription] [nvarchar](max) NULL,
        [OldBrand] [nvarchar](max) NULL,
        [NewBrand] [nvarchar](max) NULL,
        [UserID] [nvarchar](250) NULL,
        [SearchTerm] [nvarchar](250) NULL,
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
        CONSTRAINT [PK_BoxListLog] PRIMARY KEY CLUSTERED ([LogID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

-- Create indexes for better query performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND name = N'IX_BoxListLog_LogDate')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_BoxListLog_LogDate]
    ON [dbo].[BoxListLog] ([LogDate] DESC)
    INCLUDE ([Tag], [OperationType], [RecID], [UserID])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND name = N'IX_BoxListLog_RecID')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_BoxListLog_RecID]
    ON [dbo].[BoxListLog] ([RecID])
    INCLUDE ([LogDate], [OperationType], [UserID], [Active])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND name = N'IX_BoxListLog_UserID')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_BoxListLog_UserID]
    ON [dbo].[BoxListLog] ([UserID])
    INCLUDE ([LogDate], [Tag], [OperationType], [RecID])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND name = N'IX_BoxListLog_OperationType')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_BoxListLog_OperationType]
    ON [dbo].[BoxListLog] ([OperationType])
    INCLUDE ([LogDate], [Tag], [RecID], [UserID])
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BoxListLog]') AND name = N'IX_BoxListLog_ItemID')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_BoxListLog_ItemID]
    ON [dbo].[BoxListLog] ([ItemID])
    INCLUDE ([LogDate], [OperationType], [UserID])
END
GO

PRINT 'BoxListLog table and indexes created successfully.'
GO
