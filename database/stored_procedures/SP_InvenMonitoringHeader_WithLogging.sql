USE [ELMI]
GO
/****** Object:  StoredProcedure [dbo].[SP_InvenMonitoringHeader]    Script Date: 11/20/2025 8:28:09 am ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_InvenMonitoringHeader]
    @Tag NVARCHAR(50) = NULL,
    @RecID INT = NULL,
    @TranID NVARCHAR(50) = NULL,
    @TranType NVARCHAR(250) = NULL,
    @Vendor NVARCHAR(250) = NULL,
    @Customer NVARCHAR(250) = NULL,
    @Warehouse NVARCHAR(250) = NULL,
    @CreatedBy NVARCHAR(250) = NULL,
    @CreatedDate DATETIME = NULL,
    @ModifiedBy NVARCHAR(250) = NULL,
    @ModifiedDate DATE = NULL,
    @Status NVARCHAR(50) = NULL,
    @Remarks NVARCHAR(550) = NULL,
    @Quantity NVARCHAR(250) = NULL,
    @CompanyID NVARCHAR(250) = NULL,
    @ItemID NVARCHAR(250) = NULL,
    @Location NVARCHAR(250) = NULL,
    @UserID NVARCHAR(250) = NULL,
    @ItemDescription NVARCHAR(250) = NULL,
    @BranchID NVARCHAR(250) = NULL,
    @SearchTerm VARCHAR(100) = '',
    @Offset INT = 0,
    @Fetch INT = 1000,
    @PageSize INT = 1000,
    @RefNo NVARCHAR(MAX) = NULL,
    @LocationID NVARCHAR(MAX) = NULL,
    @ToWhse NVARCHAR(MAX) = NULL,
    @WhseID nvarchar(50) = NULL,
    @FromDate date = NULL,
    @ToDate date = NULL,
    @IMDetails AS [dbo].[IMDetails] ReadOnly,
    @IMDetails_Update AS [dbo].[IMDetails_Update] ReadOnly,
    @IMDetails_InsertUpdate AS [dbo].[IMDetails_InsertUpdate] ReadOnly,
    @TransactionID nvarchar(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ============================================
    -- LOGGING VARIABLES
    -- ============================================
    DECLARE @LogStartTime DATETIME2 = GETDATE();
    DECLARE @LogEndTime DATETIME2;
    DECLARE @LogExecutionTime INT;
    DECLARE @LogRowsAffected INT = 0;
    DECLARE @LogErrorMessage NVARCHAR(MAX) = NULL;
    DECLARE @LogErrorNumber INT = NULL;
    DECLARE @LogErrorSeverity INT = NULL;
    DECLARE @LogErrorState INT = NULL;
    DECLARE @LogErrorProcedure NVARCHAR(250) = NULL;
    DECLARE @LogErrorLine INT = NULL;
    DECLARE @LogOperationType NVARCHAR(50) = NULL;
    DECLARE @LogAdditionalInfo NVARCHAR(MAX) = NULL;
    DECLARE @LogHostName NVARCHAR(250) = HOST_NAME();
    DECLARE @LogAppName NVARCHAR(250) = APP_NAME();

    -- ============================================
    -- TRANSACTION VARIABLES
    -- ============================================
    DECLARE @TranIDPrefix NVARCHAR(10) = NULL;
    DECLARE @NextRefID NVARCHAR(150) = NULL;
    DECLARE @NextRefWidth NVARCHAR(150) = NULL;
    DECLARE @SetTranID NVARCHAR(150) = NULL;
    DECLARE @GeneratedTranID NVARCHAR(150) = NULL;
    DECLARE @NewTranID NVARCHAR(150) = NULL;

    BEGIN TRY
        -- ============================================
        -- GET INVENTORY MONITORING HEADER with Paging
        -- ============================================
        IF @Tag = 'GetInvenMonitoringHeader'
        BEGIN
            SET @LogOperationType = 'SELECT';

            ;WITH UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            )
            SELECT
                RecID, TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            FROM dbo.InvenMonitoringHeader
            WHERE (
                @SearchTerm IS NULL OR @SearchTerm = '' OR
                CAST(RecID AS VARCHAR) LIKE '%' + @SearchTerm + '%' OR
                TranID LIKE '%' + @SearchTerm + '%' OR
                Vendor LIKE '%' + @SearchTerm + '%' OR
                CONVERT(VARCHAR, CreatedDate, 120) LIKE '%' + @SearchTerm + '%' OR
                CreatedBy LIKE '%' + @SearchTerm + '%'
            )
            AND (@Status IS NULL OR @Status = '' OR UPPER(Status) = UPPER(@Status))
            AND TranType = 'Issuance'
            AND NOT [Status] = 'DELETED'
            AND (
                (SELECT IsMain FROM HasMainAccess) = 1
                OR Warehouse IN (SELECT WhseID FROM AccessibleWarehouses)
            )
            ORDER BY RecID DESC
            OFFSET @Offset ROWS
            FETCH NEXT @Fetch ROWS ONLY;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'SearchTerm: ' + ISNULL(@SearchTerm, 'NULL') + ', Status: ' + ISNULL(@Status, 'NULL') + ', Offset: ' + CAST(@Offset AS VARCHAR);
        END

        -- ============================================
        -- ITEM ID DROPDOWN
        -- ============================================
        ELSE IF @Tag = 'getItemID'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT ItemID, ItemDescription
            FROM [dbo].[BoxMF]
            WHERE Active = 1;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET WAREHOUSE
        -- ============================================
        ELSE IF @Tag = 'getWarehouse'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT W.CompanyID, W.WhseID AS Warehouse
            FROM dbo.Warehouse AS W
            WHERE W.CompanyID = 'EATI'
            GROUP BY W.CompanyID, W.WhseID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET LOCATION
        -- ============================================
        ELSE IF @Tag = 'GetLocation'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT TOP 1
                WhseID     = COALESCE(@Warehouse, ''),
                LocationID = 'WHSE1';

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'Warehouse: ' + ISNULL(@Warehouse, 'NULL');
        END

        -- ============================================
        -- USER BRANCH
        -- ============================================
        ELSE IF @Tag = 'UserBranch'
        BEGIN
            SET @LogOperationType = 'SELECT';

            IF EXISTS (
                SELECT 1
                FROM Branch
                INNER JOIN UserBranch
                    ON UserBranch.BranchID = Branch.BranchID
                    AND UserBranch.CompanyID = Branch.CompanyID
                WHERE Branch.CompanyID = @CompanyID
                  AND UserBranch.UserID = @UserID
                  AND Branch.BranchDesc = 'Main'
            )
            BEGIN
                SELECT BranchDesc, BranchID
                FROM UserBranch
                WHERE CompanyID = @CompanyID
                  AND UserBranch.BranchDesc IS NOT NULL
                GROUP BY BranchDesc, BranchID
                ORDER BY CASE WHEN BranchDesc = 'Main' THEN 0 ELSE 1 END;
            END
            ELSE
            BEGIN
                SELECT DISTINCT Branch.BranchDesc, Branch.BranchID
                FROM UserBranch
                LEFT JOIN Branch
                    ON UserBranch.BranchID = Branch.BranchID
                    AND UserBranch.CompanyID = Branch.CompanyID
                WHERE Branch.CompanyID = @CompanyID
                  AND UserBranch.UserID = @UserID;
            END

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'CompanyID: ' + ISNULL(@CompanyID, 'NULL');
        END

        -- ============================================
        -- BRANCH
        -- ============================================
        ELSE IF @Tag = 'Branch'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT DISTINCT [BranchID], [BranchDesc]
            FROM [ELMI].[dbo].[Branch]
            WHERE CompanyID = @CompanyID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET RECEIVING
        -- ============================================
        ELSE IF @Tag = 'GetReceiving'
        BEGIN
            SET @LogOperationType = 'SELECT';

            ;WITH UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            )
            SELECT
                RecID, TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            FROM dbo.InvenMonitoringHeader
            WHERE (
                @SearchTerm IS NULL OR @SearchTerm = '' OR
                CAST(RecID AS VARCHAR) LIKE '%' + @SearchTerm + '%' OR
                TranID LIKE '%' + @SearchTerm + '%' OR
                Vendor LIKE '%' + @SearchTerm + '%' OR
                CONVERT(VARCHAR, CreatedDate, 120) LIKE '%' + @SearchTerm + '%' OR
                CreatedBy LIKE '%' + @SearchTerm + '%'
            )
            AND (@Status IS NULL OR @Status = '' OR UPPER(Status) = UPPER(@Status))
            AND TranType = 'Receiving'
            AND NOT [STATUS] = 'DELETED'
            AND (
                (SELECT IsMain FROM HasMainAccess) = 1
                OR Warehouse IN (SELECT WhseID FROM AccessibleWarehouses)
            )
            ORDER BY RecID DESC
            OFFSET @Offset ROWS
            FETCH NEXT @Fetch ROWS ONLY;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'TranType: Receiving, SearchTerm: ' + ISNULL(@SearchTerm, 'NULL');
        END

        -- ============================================
        -- GET ONHAND
        -- ============================================
        ELSE IF @Tag = 'GetOnhand'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'WhseID: ' + ISNULL(@WhseID, 'NULL') + ', ItemID: ' + ISNULL(@ItemID, 'NULL') + ', FromDate: ' + ISNULL(CAST(@FromDate AS VARCHAR), 'NULL') + ', ToDate: ' + ISNULL(CAST(@ToDate AS VARCHAR), 'NULL');

            ;WITH W AS (
                SELECT WhseID, WarehouseName = MAX(WarehouseName)
                FROM dbo.Warehouse
                GROUP BY WhseID
            ),
            IU AS (
                SELECT ItemID, ItemDescription = MAX(ItemDescription)
                FROM dbo.BoxMF
                GROUP BY ItemID
            ),
            ReceivingMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Receiving'
                  AND (@WhseID IS NULL OR h.Warehouse = @WhseID)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            IssuanceMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Issuance'
                  AND (@WhseID IS NULL OR h.Warehouse = @WhseID)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            TransferOutMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.Warehouse IS NOT NULL
                  AND (@WhseID IS NULL OR h.Warehouse = @WhseID)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            TransferInMovements AS (
                SELECT
                    h.ToWhse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.ToWhse IS NOT NULL
                  AND (@WhseID IS NULL OR h.ToWhse = @WhseID)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            AllMovements AS (
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate FROM ReceivingMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate FROM IssuanceMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate FROM TransferOutMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate FROM TransferInMovements
            ),
            OnHand AS (
                SELECT WhseID, ItemID, SUM(Qty) AS TotalQty
                FROM AllMovements
                WHERE WhseID IS NOT NULL AND WhseID <> ''
                GROUP BY WhseID, ItemID
                HAVING SUM(Qty) > 0
            ),
            LatestIncoming AS (
                SELECT
                    WhseID, ItemID, RefNum, CreatedDate,
                    ROW_NUMBER() OVER (PARTITION BY WhseID, ItemID ORDER BY CreatedDate DESC) AS rn
                FROM AllMovements
                WHERE Qty > 0
            )
            SELECT
                oh.WhseID AS [Warehouse Code],
                w.WarehouseName AS [Warehouse Name],
                oh.ItemID AS [Item ID],
                CASE
                    WHEN CHARINDEX('/', iu.ItemDescription) > 0
                    THEN LTRIM(SUBSTRING(iu.ItemDescription, CHARINDEX('/', iu.ItemDescription)+1, LEN(iu.ItemDescription)))
                    ELSE iu.ItemDescription
                END AS [Item],
                'WHSE1' AS [Location],
                li.RefNum AS [Reference #],
                CAST(li.CreatedDate AS date) AS [Reference Date],
                oh.TotalQty AS [Quantity]
            FROM OnHand oh
            LEFT JOIN W w ON w.WhseID = oh.WhseID
            LEFT JOIN IU iu ON iu.ItemID = oh.ItemID
            LEFT JOIN LatestIncoming li ON li.WhseID = oh.WhseID AND li.ItemID = oh.ItemID AND li.rn = 1
            ORDER BY w.WarehouseName, oh.ItemID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- SEARCH ONHAND BY LOCATION
        -- ============================================
        ELSE IF @Tag = 'SearchOnhandByLocation'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'Warehouse: ' + ISNULL(@Warehouse, 'NULL') + ', ItemID: ' + ISNULL(@ItemID, 'NULL') + ', RefNo: ' + ISNULL(@RefNo, 'NULL');

            ;WITH W AS (
                SELECT WhseID, WarehouseName = MAX(WarehouseName)
                FROM dbo.Warehouse
                GROUP BY WhseID
            ),
            IU AS (
                SELECT ItemID, ItemDescription = MAX(ItemDescription)
                FROM dbo.BoxMF
                GROUP BY ItemID
            ),
            UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            ),
            ReceivingMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    d.TranID, h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Receiving'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            IssuanceMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    d.TranID, h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Issuance'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            TransferOutMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    d.TranID, h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.Warehouse IS NOT NULL
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            TransferInMovements AS (
                SELECT
                    h.ToWhse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    d.TranID, h.CreatedDate
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.ToWhse IS NOT NULL
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.ToWhse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.ToWhse = @Warehouse)
                  AND (@ItemID IS NULL OR d.ItemID = @ItemID)
                  AND (@FromDate IS NULL OR CAST(h.CreatedDate AS date) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(h.CreatedDate AS date) <= @ToDate)
            ),
            AllMovements AS (
                SELECT WhseID, ItemID, Qty, RefNum, TranID, CreatedDate FROM ReceivingMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, TranID, CreatedDate FROM IssuanceMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, TranID, CreatedDate FROM TransferOutMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, TranID, CreatedDate FROM TransferInMovements
            ),
            OnHand AS (
                SELECT WhseID, ItemID, SUM(Qty) AS TotalQty
                FROM AllMovements
                WHERE WhseID IS NOT NULL AND WhseID <> ''
                GROUP BY WhseID, ItemID
                HAVING SUM(Qty) > 0
            ),
            LatestIncoming AS (
                SELECT
                    WhseID, ItemID, RefNum, TranID, CreatedDate,
                    ROW_NUMBER() OVER (PARTITION BY WhseID, ItemID ORDER BY CreatedDate DESC) AS rn
                FROM AllMovements
                WHERE Qty > 0
            )
            SELECT
                oh.WhseID AS [Warehouse Code],
                w.WarehouseName AS [Warehouse Name],
                oh.ItemID AS [Item ID],
                CASE
                    WHEN CHARINDEX('/', iu.ItemDescription) > 0
                    THEN LTRIM(SUBSTRING(iu.ItemDescription, CHARINDEX('/', iu.ItemDescription)+1, LEN(iu.ItemDescription)))
                    ELSE iu.ItemDescription
                END AS [Item],
                'WHSE1' AS [Location],
                li.RefNum AS [Reference #],
                CAST(li.CreatedDate AS date) AS [Reference Date],
                oh.TotalQty AS [Quantity]
            FROM OnHand oh
            LEFT JOIN W w ON w.WhseID = oh.WhseID
            LEFT JOIN IU iu ON iu.ItemID = oh.ItemID
            LEFT JOIN LatestIncoming li ON li.WhseID = oh.WhseID AND li.ItemID = oh.ItemID AND li.rn = 1
            WHERE (@RefNo IS NULL OR li.RefNum LIKE '%' + @RefNo + '%' OR li.TranID LIKE '%' + @RefNo + '%')
            ORDER BY w.WarehouseName, oh.ItemID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET TRANSFER
        -- ============================================
        ELSE IF @Tag = 'GetTransfer'
        BEGIN
            SET @LogOperationType = 'SELECT';

            ;WITH UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            )
            SELECT
                RecID, TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            FROM dbo.InvenMonitoringHeader
            WHERE (
                @SearchTerm IS NULL OR @SearchTerm = '' OR
                CAST(RecID AS VARCHAR) LIKE '%' + @SearchTerm + '%' OR
                TranID LIKE '%' + @SearchTerm + '%' OR
                Vendor LIKE '%' + @SearchTerm + '%' OR
                CONVERT(VARCHAR, CreatedDate, 120) LIKE '%' + @SearchTerm + '%' OR
                CreatedBy LIKE '%' + @SearchTerm + '%'
            )
            AND (@Status IS NULL OR @Status = '' OR UPPER(Status) = UPPER(@Status))
            AND TranType = 'Transfer'
            AND NOT [Status] = 'DELETED'
            AND (
                (SELECT IsMain FROM HasMainAccess) = 1
                OR Warehouse IN (SELECT WhseID FROM AccessibleWarehouses)
                OR ToWhse IN (SELECT WhseID FROM AccessibleWarehouses)
            )
            ORDER BY RecID DESC
            OFFSET @Offset ROWS
            FETCH NEXT @Fetch ROWS ONLY;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'TranType: Transfer, SearchTerm: ' + ISNULL(@SearchTerm, 'NULL');
        END

        -- ============================================
        -- GET AVAILABLE ITEMS
        -- ============================================
        ELSE IF @Tag = 'GetAvailableItems'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'Warehouse: ' + ISNULL(@Warehouse, 'NULL');

            CREATE TABLE #TempAvailableItems (
                [Warehouse Code] nvarchar(50),
                WarehouseName nvarchar(255),
                ItemID nvarchar(250),
                [Item] nvarchar(500),
                [Location] nvarchar(255),
                [Reference #] nvarchar(100),
                [Reference Date] date,
                [Available Qty] decimal(18,4)
            );

            ;WITH UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            ),
            W AS (
                SELECT WhseID, WarehouseName = MAX(WarehouseName)
                FROM dbo.Warehouse
                GROUP BY WhseID
            ),
            IU AS (
                SELECT ItemID, ItemDescription = MAX(ItemDescription)
                FROM dbo.BoxMF
                GROUP BY ItemID
            ),
            ReceivingMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate, d.[Location], h.RecID
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Receiving'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
            ),
            IssuanceMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate, d.[Location], h.RecID
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Issuance'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
            ),
            TransferOutMovements AS (
                SELECT
                    h.Warehouse AS WhseID, d.ItemID,
                    -TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate, d.[Location], h.RecID
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.Warehouse IS NOT NULL
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.Warehouse = @Warehouse)
            ),
            TransferInMovements AS (
                SELECT
                    h.ToWhse AS WhseID, d.ItemID,
                    TRY_CONVERT(decimal(18,4), ABS(d.Quantity)) AS Qty,
                    CASE WHEN h.RefNum IS NOT NULL AND h.RefNum <> '' THEN h.RefNum ELSE d.TranID END AS RefNum,
                    h.CreatedDate, d.[Location], h.RecID
                FROM dbo.InvenMonitoringDetails d
                JOIN dbo.InvenMonitoringHeader h ON h.TranID = d.TranID
                WHERE d.[Status] = 'ACTIVE' AND h.[Status] = 'POSTED' AND h.TranType = 'Transfer'
                  AND h.ToWhse IS NOT NULL
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR h.ToWhse IN (SELECT WhseID FROM AccessibleWarehouses))
                  AND (@Warehouse IS NULL OR h.ToWhse = @Warehouse)
            ),
            AllMovements AS (
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate, [Location], RecID FROM ReceivingMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate, [Location], RecID FROM IssuanceMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate, [Location], RecID FROM TransferOutMovements
                UNION ALL
                SELECT WhseID, ItemID, Qty, RefNum, CreatedDate, [Location], RecID FROM TransferInMovements
            ),
            LatestPerItemWhse AS (
                SELECT m.*,
                       ROW_NUMBER() OVER (PARTITION BY m.WhseID, m.ItemID ORDER BY m.RecID DESC, m.CreatedDate DESC) AS rn
                FROM AllMovements m
            ),
            OnHand AS (
                SELECT WhseID, ItemID, SUM(Qty) AS AvailableQty
                FROM AllMovements
                WHERE WhseID IS NOT NULL AND WhseID <> ''
                GROUP BY WhseID, ItemID
            )
            INSERT INTO #TempAvailableItems
            SELECT
                g.WhseID AS [Warehouse Code],
                w.WarehouseName,
                g.ItemID,
                iu.ItemDescription AS [Item],
                g.[Location],
                g.RefNum AS [Reference #],
                CAST(g.CreatedDate AS date) AS [Reference Date],
                oh.AvailableQty AS [Available Qty]
            FROM LatestPerItemWhse g
            JOIN OnHand oh ON oh.WhseID = g.WhseID AND oh.ItemID = g.ItemID
            LEFT JOIN W w ON w.WhseID = g.WhseID
            LEFT JOIN IU iu ON iu.ItemID = g.ItemID
            WHERE g.rn = 1 AND oh.AvailableQty > 0
              AND (@Warehouse IS NULL OR g.WhseID = @Warehouse);

            IF EXISTS (SELECT 1 FROM #TempAvailableItems)
            BEGIN
                SELECT * FROM #TempAvailableItems
                ORDER BY WarehouseName, ItemID;
                SET @LogRowsAffected = @@ROWCOUNT;
            END
            ELSE
            BEGIN
                SELECT '' AS [Warehouse Code], '' AS WarehouseName, 'NO AVAILABLE ITEMS' AS ItemID,
                       'No available items' AS [Item], '' AS [Location], '' AS [Reference #],
                       NULL AS [Reference Date], 0 AS [Available Qty];
                SET @LogRowsAffected = 0;
            END

            DROP TABLE #TempAvailableItems;
        END

        -- ============================================
        -- GET HISTORY
        -- ============================================
        ELSE IF @Tag = 'getHistory'
        BEGIN
            SET @LogOperationType = 'SELECT';

            ;WITH H AS (
                SELECT
                    CreatedDate = CAST(IM.ModifiedDate AS datetime2(0)),
                    ItemID = IR.ItemID, TranType = 'Receiving', TranSortKey = 1,
                    Warehouse = IM.Warehouse, [Location] = ISNULL(NULLIF(IR.[Location], ''), 'WHSE1'),
                    TranID = IM.TranID, CreatedBy = IM.CreatedBy,
                    Quantity = CAST(IR.Quantity AS decimal(18,2)),
                    [Status] = IR.[Status]
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenReceiving AS IR ON IR.TranID = IM.TranID
                WHERE IM.TranType = 'Receiving' AND IM.[Status] = 'POSTED' AND ISNULL(IR.[Status], '') != 'REMOVED'
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    INVS.ItemID, 'Issuance', 2,
                    IM.Warehouse, ISNULL(NULLIF(INVS.[Location], ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(-ABS(INVS.Quantity) AS decimal(18,2)),
                    INVS.[Status]
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenIssuance AS INVS ON INVS.TranID = IM.TranID
                WHERE IM.TranType = 'Issuance' AND IM.[Status] = 'POSTED' AND ISNULL(INVS.[Status], '') != 'REMOVED'
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    T.ItemID, 'Transfer-Out', 4,
                    IM.Warehouse, ISNULL(NULLIF(T.[Location], ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(-ABS(T.Quantity) AS decimal(18,2)),
                    T.[Status]
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenTransfer AS T ON T.TranID = IM.TranID
                WHERE IM.TranType = 'Transfer' AND IM.[Status] = 'POSTED' AND ISNULL(T.[Status], '') != 'REMOVED'
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    T.ItemID, 'Transfer-In', 3,
                    IM.ToWhse, ISNULL(NULLIF(T.ToLoc, ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(ABS(T.Quantity) AS decimal(18,2)),
                    T.[Status]
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenTransfer AS T ON T.TranID = IM.TranID
                WHERE IM.TranType = 'Transfer' AND IM.[Status] = 'POSTED' AND ISNULL(T.[Status], '') != 'REMOVED'
            )
            SELECT
                h.CreatedDate, h.ItemID AS [Item Code], iu.ItemDescription,
                h.TranType AS [Transaction Type], h.Warehouse,
                h.[Location] AS [Warehouse Code], h.TranID AS [Transaction ID],
                h.CreatedBy, h.Quantity, h.[Status]
            FROM H AS h
            OUTER APPLY (
                SELECT TOP (1) iu.ItemDescription
                FROM dbo.BoxMF AS iu
                WHERE iu.ItemID = h.ItemID
            ) AS iu
            ORDER BY h.CreatedDate ASC, h.TranID ASC, h.TranSortKey DESC;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- SEARCH HISTORY
        -- ============================================
        ELSE IF @Tag = 'SearchHistory'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'Warehouse: ' + ISNULL(@Warehouse, 'NULL') + ', ItemID: ' + ISNULL(@ItemID, 'NULL') + ', TransactionID: ' + ISNULL(@TransactionID, 'NULL');

            ;WITH UserBranches AS (
                SELECT DISTINCT BranchID
                FROM dbo.UserBranch
                WHERE UserID = @UserID
                  AND CompanyID IN ('EATI', 'AGDI')
            ),
            HasMainAccess AS (
                SELECT CASE WHEN EXISTS (
                    SELECT 1 FROM UserBranches WHERE BranchID = '000'
                ) THEN 1 ELSE 0 END AS IsMain
            ),
            AccessibleWarehouses AS (
                SELECT DISTINCT w.WhseID
                FROM dbo.Warehouse w
                WHERE w.BranchID IN (SELECT BranchID FROM UserBranches)
            ),
            H AS (
                SELECT
                    CreatedDate = CAST(IM.ModifiedDate AS datetime2(0)),
                    ItemID = IR.ItemID, TranType = 'Receiving', TranSortKey = 1,
                    Warehouse = IM.Warehouse, [Location] = ISNULL(NULLIF(IR.[Location], ''), 'WHSE1'),
                    TranID = IM.TranID, CreatedBy = IM.CreatedBy,
                    Quantity = CAST(IR.Quantity AS decimal(18,2)), [Status] = IR.[Status],
                    FromWarehouse = CAST(NULL AS NVARCHAR(250)), ToWarehouse = IM.Warehouse
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenReceiving AS IR ON IR.TranID = IM.TranID
                WHERE IM.TranType = 'Receiving' AND IM.[Status] = 'POSTED' AND ISNULL(IR.[Status], '') != 'REMOVED'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR IM.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    INVS.ItemID, 'Issuance', 2,
                    IM.Warehouse, ISNULL(NULLIF(INVS.[Location], ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(-ABS(INVS.Quantity) AS decimal(18,2)), INVS.[Status],
                    IM.Warehouse, CAST(NULL AS NVARCHAR(250))
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenIssuance AS INVS ON INVS.TranID = IM.TranID
                WHERE IM.TranType = 'Issuance' AND IM.[Status] = 'POSTED' AND ISNULL(INVS.[Status], '') != 'REMOVED'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR IM.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    T.ItemID, 'Transfer-Out', 4,
                    IM.Warehouse, ISNULL(NULLIF(T.[Location], ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(-ABS(T.Quantity) AS decimal(18,2)), T.[Status],
                    IM.Warehouse, ISNULL(NULLIF(IM.ToWhse, ''), ISNULL(NULLIF(T.ToWhse, ''), ''))
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenTransfer AS T ON T.TranID = IM.TranID
                WHERE IM.TranType = 'Transfer' AND IM.[Status] = 'POSTED' AND ISNULL(T.[Status], '') != 'REMOVED'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1 OR IM.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
                UNION ALL
                SELECT
                    CAST(IM.ModifiedDate AS datetime2(0)),
                    T.ItemID, 'Transfer-In', 3,
                    ISNULL(NULLIF(IM.ToWhse, ''), ISNULL(NULLIF(T.ToWhse, ''), IM.Warehouse)),
                    ISNULL(NULLIF(T.ToLoc, ''), 'WHSE1'),
                    IM.TranID, IM.CreatedBy,
                    CAST(ABS(T.Quantity) AS decimal(18,2)), T.[Status],
                    IM.Warehouse, ISNULL(NULLIF(IM.ToWhse, ''), ISNULL(NULLIF(T.ToWhse, ''), IM.Warehouse))
                FROM dbo.InvenMonitoringHeader AS IM
                JOIN dbo.InvenTransfer AS T ON T.TranID = IM.TranID
                WHERE IM.TranType = 'Transfer' AND IM.[Status] = 'POSTED' AND ISNULL(T.[Status], '') != 'REMOVED'
                  AND ((SELECT IsMain FROM HasMainAccess) = 1
                       OR ISNULL(NULLIF(IM.ToWhse, ''), ISNULL(NULLIF(T.ToWhse, ''), IM.Warehouse)) IN (SELECT WhseID FROM AccessibleWarehouses)
                       OR IM.Warehouse IN (SELECT WhseID FROM AccessibleWarehouses))
            )
            SELECT
                h.CreatedDate, h.ItemID AS [Item Code], iu.ItemDescription,
                h.TranType AS [Transaction Type], h.Warehouse,
                h.[Location] AS [Warehouse Code], h.TranID AS [Transaction ID],
                h.CreatedBy, h.Quantity, h.[Status],
                CASE WHEN h.TranType IN ('Transfer-Out', 'Transfer-In') THEN h.FromWarehouse ELSE NULL END AS [From Warehouse],
                CASE WHEN h.TranType IN ('Transfer-Out', 'Transfer-In') THEN h.ToWarehouse ELSE NULL END AS [To Warehouse]
            FROM H AS h
            OUTER APPLY (
                SELECT TOP (1) iu.ItemDescription
                FROM dbo.BoxMF AS iu
                WHERE iu.ItemID = h.ItemID
            ) AS iu
            WHERE (@Warehouse IS NULL OR @Warehouse = '' OR h.Warehouse = @Warehouse)
              AND (@ItemID IS NULL OR @ItemID = '' OR h.ItemID = @ItemID)
              AND (@TransactionID IS NULL OR @TransactionID = '' OR h.TranID LIKE '%'+@TransactionID+'%')
            ORDER BY h.CreatedDate ASC, h.TranID ASC, h.TranSortKey DESC;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET HEADER BY RecID
        -- ============================================
        ELSE IF @Tag = 'GetInvenMonitoringHeaderByRecID'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'RecID: ' + CAST(@RecID AS VARCHAR);

            SELECT
                RecID, TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            FROM dbo.InvenMonitoringHeader
            WHERE RecID = @RecID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET HEADER BY TranID
        -- ============================================
        ELSE IF @Tag = 'GetInvenMonitoringHeaderByTranID'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'TranID: ' + ISNULL(@TranID, 'NULL');

            SELECT
                RecID, TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            FROM dbo.InvenMonitoringHeader
            WHERE TranID = @TranID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET DETAILS BY TranID
        -- ============================================
        ELSE IF @Tag = 'GetInvenMonitoringDetailsByTranID'
        BEGIN
            SET @LogOperationType = 'SELECT';
            SET @LogAdditionalInfo = 'TranID: ' + ISNULL(@TranID, 'NULL');

            SELECT
                RecID, TranID, ItemID, ItemDescription, Quantity,
                Warehouse, Location, Remarks, Status
            FROM dbo.InvenMonitoringDetails
            WHERE TranID = @TranID
              AND ISNULL(Status, '') != 'REMOVED'
            ORDER BY RecID;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GET VENDOR LIST
        -- ============================================
        ELSE IF @Tag = 'getVendorID'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT DISTINCT Vendor
            FROM dbo.InvenMonitoringHeader
            WHERE Vendor IS NOT NULL AND Vendor != ''
            ORDER BY Vendor;

            SET @LogRowsAffected = @@ROWCOUNT;
        END

        -- ============================================
        -- GENERATE NEW TranID
        -- ============================================
        ELSE IF @Tag = 'GenerateTranID'
        BEGIN
            SET @LogOperationType = 'GENERATE';
            SET @LogAdditionalInfo = 'TranType: ' + ISNULL(@TranType, 'NULL');

            DECLARE @Prefix NVARCHAR(10);
            DECLARE @MaxNum INT;
            DECLARE @NewGeneratedTranID NVARCHAR(50);

            IF @TranType = 'Issuance'
                SET @Prefix = 'INV-I-';
            ELSE IF @TranType = 'Receiving'
                SET @Prefix = 'INV-R-';
            ELSE IF @TranType = 'Transfer'
                SET @Prefix = 'INV-TR-';
            ELSE
                SET @Prefix = 'INV-';

            SELECT @MaxNum = ISNULL(MAX(CAST(SUBSTRING(TranID, LEN(@Prefix) + 1, 10) AS INT)), 0)
            FROM dbo.InvenMonitoringHeader
            WHERE TranID LIKE @Prefix + '%';

            SET @NewGeneratedTranID = @Prefix + RIGHT('0000000000' + CAST(@MaxNum + 1 AS VARCHAR(10)), 6);

            SELECT @NewGeneratedTranID AS TranID;

            SET @LogRowsAffected = 1;
            SET @LogAdditionalInfo = @LogAdditionalInfo + ', Generated TranID: ' + @NewGeneratedTranID;
        END

        -- ============================================
        -- INSERT HEADER AND DETAILS
        -- ============================================
        ELSE IF @Tag = 'InsertInvenMonitoringHeader'
        BEGIN
            SET @LogOperationType = 'INSERT';

            DECLARE @NewRecID INT;
            DECLARE @PrefixInsert NVARCHAR(10);
            DECLARE @MaxNumInsert INT;

            IF @TranType = 'Issuance'
                SET @PrefixInsert = 'INV-I-';
            ELSE IF @TranType = 'Receiving'
                SET @PrefixInsert = 'INV-R-';
            ELSE IF @TranType = 'Transfer'
                SET @PrefixInsert = 'INV-TR-';
            ELSE
                SET @PrefixInsert = 'INV-';

            SELECT @MaxNumInsert = ISNULL(MAX(CAST(SUBSTRING(TranID, LEN(@PrefixInsert) + 1, 10) AS INT)), 0)
            FROM dbo.InvenMonitoringHeader
            WHERE TranID LIKE @PrefixInsert + '%';

            SET @NewTranID = @PrefixInsert + RIGHT('0000000000' + CAST(@MaxNumInsert + 1 AS VARCHAR(10)), 6);

            -- Insert Header
            INSERT INTO dbo.InvenMonitoringHeader (
                TranID, TranType, Vendor, Customer, Warehouse,
                CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
                Status, Remarks, RefNum, ToWhse
            )
            VALUES (
                @NewTranID, @TranType, @Vendor, @Customer, @Warehouse,
                @CreatedBy, @CreatedDate, @ModifiedBy, @ModifiedDate,
                @Status, @Remarks, @RefNo, @ToWhse
            );

            SET @NewRecID = SCOPE_IDENTITY();

            -- Insert Details from TVP
            IF @TranType = 'Receiving'
            BEGIN
                INSERT INTO dbo.InvenReceiving (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status)
                SELECT @NewTranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status
                FROM @IMDetails;
            END
            ELSE IF @TranType = 'Issuance'
            BEGIN
                INSERT INTO dbo.InvenIssuance (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status)
                SELECT @NewTranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status
                FROM @IMDetails;
            END
            ELSE IF @TranType = 'Transfer'
            BEGIN
                INSERT INTO dbo.InvenTransfer (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status, ToWhse, ToLoc)
                SELECT @NewTranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status, @ToWhse, 'WHSE1'
                FROM @IMDetails;
            END

            -- Insert into InvenMonitoringDetails
            INSERT INTO dbo.InvenMonitoringDetails (TranID, TranType, ItemID, ItemDescription, Quantity, Warehouse, Location, Remarks, Status)
            SELECT @NewTranID, @TranType, ItemID, ItemDescription, CAST(Quantity AS INT), @Warehouse, Location, Remarks, Status
            FROM @IMDetails;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'TranID: ' + @NewTranID + ', TranType: ' + ISNULL(@TranType, 'NULL') +
                                     ', Warehouse: ' + ISNULL(@Warehouse, 'NULL') + ', ToWhse: ' + ISNULL(@ToWhse, 'NULL') +
                                     ', Details Count: ' + CAST(@LogRowsAffected AS VARCHAR);

            -- Log the INSERT operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, RecID, UserID,
                Warehouse, ToWhse, Status, AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @NewTranID, @TranType, @NewRecID, @CreatedBy,
                @Warehouse, @ToWhse, @Status, @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );

            SELECT @NewRecID AS NewRecID, @NewTranID AS TranID;
        END

        -- ============================================
        -- UPDATE HEADER
        -- ============================================
        ELSE IF @Tag = 'UpdateInvenMonitoringHeader'
        BEGIN
            SET @LogOperationType = 'UPDATE';

            -- Get old status before update
            DECLARE @OldStatus NVARCHAR(50);
            SELECT @OldStatus = Status
            FROM dbo.InvenMonitoringHeader
            WHERE RecID = @RecID OR TranID = @TranID;

            UPDATE dbo.InvenMonitoringHeader
            SET
                TranType = @TranType,
                Vendor = @Vendor,
                Customer = @Customer,
                Warehouse = @Warehouse,
                ModifiedBy = @ModifiedBy,
                ModifiedDate = GETDATE(),
                Status = @Status,
                Remarks = @Remarks,
                RefNum = @RefNo,
                ToWhse = @ToWhse
            WHERE RecID = @RecID OR TranID = @TranID;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'RecID: ' + ISNULL(CAST(@RecID AS VARCHAR), 'NULL') +
                                     ', TranID: ' + ISNULL(@TranID, 'NULL') +
                                     ', TranType: ' + ISNULL(@TranType, 'NULL') +
                                     ', Warehouse: ' + ISNULL(@Warehouse, 'NULL') +
                                     ', ToWhse: ' + ISNULL(@ToWhse, 'NULL');

            -- Log the UPDATE operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, RecID, UserID,
                Warehouse, ToWhse, OldStatus, NewStatus, AdditionalInfo,
                HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @TranID, @TranType, @RecID, @ModifiedBy,
                @Warehouse, @ToWhse, @OldStatus, @Status, @LogAdditionalInfo,
                @LogHostName, @LogAppName, @LogRowsAffected
            );

            SELECT @LogRowsAffected AS RowsAffected;
        END

        -- ============================================
        -- UPDATE STATUS ONLY
        -- ============================================
        ELSE IF @Tag = 'UpdateInvenMonitoringHeaderStatus'
        BEGIN
            SET @LogOperationType = 'UPDATE_STATUS';

            -- Get old status before update
            DECLARE @OldStatusForStatusUpdate NVARCHAR(50);
            SELECT @OldStatusForStatusUpdate = Status
            FROM dbo.InvenMonitoringHeader
            WHERE TranID = @TranID;

            UPDATE dbo.InvenMonitoringHeader
            SET
                Status = @Status,
                Remarks = ISNULL(@Remarks, Remarks),
                ModifiedBy = @ModifiedBy,
                ModifiedDate = @ModifiedDate
            WHERE TranID = @TranID;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'TranID: ' + ISNULL(@TranID, 'NULL') +
                                     ', Old Status: ' + ISNULL(@OldStatusForStatusUpdate, 'NULL') +
                                     ', New Status: ' + ISNULL(@Status, 'NULL');

            -- Log the UPDATE STATUS operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, RecID, UserID,
                OldStatus, NewStatus, AdditionalInfo,
                HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @TranID, NULL, @ModifiedBy,
                @OldStatusForStatusUpdate, @Status, @LogAdditionalInfo,
                @LogHostName, @LogAppName, @LogRowsAffected
            );

            SELECT @LogRowsAffected AS RowsAffected;
        END

        -- ============================================
        -- UPDATE DETAILS
        -- ============================================
        ELSE IF @Tag = 'UpdateInvenMonitoringDetails'
        BEGIN
            SET @LogOperationType = 'UPDATE';

            DECLARE @DetailCount INT;
            SELECT @DetailCount = COUNT(*) FROM @IMDetails_Update;

            -- Update InvenMonitoringDetails
            UPDATE d
            SET
                d.ItemID = u.ItemID,
                d.ItemDescription = u.ItemDescription,
                d.Quantity = CAST(u.Quantity AS INT),
                d.Location = u.Location,
                d.Remarks = u.Remarks,
                d.Status = u.Status
            FROM dbo.InvenMonitoringDetails d
            INNER JOIN @IMDetails_Update u ON d.RecID = CAST(u.RecID AS INT)
            WHERE d.TranID = u.TranID;

            -- Update corresponding transaction table
            DECLARE @UpdateTranType NVARCHAR(50);
            SELECT TOP 1 @UpdateTranType = TranType FROM @IMDetails_Update;

            IF @UpdateTranType = 'Receiving'
            BEGIN
                UPDATE r
                SET
                    r.ItemID = u.ItemID,
                    r.ItemDescription = u.ItemDescription,
                    r.Quantity = CAST(u.Quantity AS INT),
                    r.Location = u.Location,
                    r.Remarks = u.Remarks,
                    r.Status = u.Status
                FROM dbo.InvenReceiving r
                INNER JOIN @IMDetails_Update u ON r.TranID = u.TranID AND r.ItemID = u.ItemID;
            END
            ELSE IF @UpdateTranType = 'Issuance'
            BEGIN
                UPDATE i
                SET
                    i.ItemID = u.ItemID,
                    i.ItemDescription = u.ItemDescription,
                    i.Quantity = CAST(u.Quantity AS INT),
                    i.Location = u.Location,
                    i.Remarks = u.Remarks,
                    i.Status = u.Status
                FROM dbo.InvenIssuance i
                INNER JOIN @IMDetails_Update u ON i.TranID = u.TranID AND i.ItemID = u.ItemID;
            END
            ELSE IF @UpdateTranType = 'Transfer'
            BEGIN
                UPDATE t
                SET
                    t.ItemID = u.ItemID,
                    t.ItemDescription = u.ItemDescription,
                    t.Quantity = CAST(u.Quantity AS INT),
                    t.Location = u.Location,
                    t.Remarks = u.Remarks,
                    t.Status = u.Status
                FROM dbo.InvenTransfer t
                INNER JOIN @IMDetails_Update u ON t.TranID = u.TranID AND t.ItemID = u.ItemID;
            END

            SET @LogRowsAffected = @@ROWCOUNT;

            DECLARE @UpdateTranIDForLog NVARCHAR(50);
            SELECT TOP 1 @UpdateTranIDForLog = TranID FROM @IMDetails_Update;

            SET @LogAdditionalInfo = 'TranID: ' + ISNULL(@UpdateTranIDForLog, 'NULL') +
                                     ', TranType: ' + ISNULL(@UpdateTranType, 'NULL') +
                                     ', Details Updated: ' + CAST(@DetailCount AS VARCHAR);

            -- Log the UPDATE DETAILS operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, UserID,
                AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @UpdateTranIDForLog, @UpdateTranType, @ModifiedBy,
                @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );
        END

        -- ============================================
        -- INSERT NEW DETAILS
        -- ============================================
        ELSE IF @Tag = 'UpdateInsertInvenMonitoringDetails'
        BEGIN
            SET @LogOperationType = 'INSERT';

            DECLARE @InsertTranType NVARCHAR(50);
            DECLARE @InsertTranID NVARCHAR(50);
            DECLARE @InsertDetailCount INT;

            SELECT TOP 1 @InsertTranType = TranType, @InsertTranID = TranID
            FROM @IMDetails_InsertUpdate;

            SELECT @InsertDetailCount = COUNT(*) FROM @IMDetails_InsertUpdate;

            -- Insert into InvenMonitoringDetails
            INSERT INTO dbo.InvenMonitoringDetails (TranID, TranType, ItemID, ItemDescription, Quantity, Warehouse, Location, Remarks, Status)
            SELECT TranID, TranType, ItemID, ItemDescription, CAST(Quantity AS INT), @Warehouse, Location, Remarks, Status
            FROM @IMDetails_InsertUpdate;

            -- Insert into specific transaction table
            IF @InsertTranType = 'Receiving'
            BEGIN
                INSERT INTO dbo.InvenReceiving (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status)
                SELECT TranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status
                FROM @IMDetails_InsertUpdate;
            END
            ELSE IF @InsertTranType = 'Issuance'
            BEGIN
                INSERT INTO dbo.InvenIssuance (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status)
                SELECT TranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status
                FROM @IMDetails_InsertUpdate;
            END
            ELSE IF @InsertTranType = 'Transfer'
            BEGIN
                INSERT INTO dbo.InvenTransfer (TranID, ItemID, ItemDescription, Quantity, Location, Remarks, Status, ToWhse, ToLoc)
                SELECT TranID, ItemID, ItemDescription, CAST(Quantity AS INT), Location, Remarks, Status, @ToWhse, 'WHSE1'
                FROM @IMDetails_InsertUpdate;
            END

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'TranID: ' + ISNULL(@InsertTranID, 'NULL') +
                                     ', TranType: ' + ISNULL(@InsertTranType, 'NULL') +
                                     ', New Details Count: ' + CAST(@InsertDetailCount AS VARCHAR);

            -- Log the INSERT DETAILS operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, UserID,
                Warehouse, ToWhse, AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @InsertTranID, @InsertTranType, @CreatedBy,
                @Warehouse, @ToWhse, @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );
        END

        -- ============================================
        -- MARK DETAILS AS REMOVED
        -- ============================================
        ELSE IF @Tag = 'MarkDetailsRemoved'
        BEGIN
            SET @LogOperationType = 'DELETE';

            DECLARE @RemovedTranID NVARCHAR(50);
            DECLARE @RemovedItemID NVARCHAR(250);
            DECLARE @RemovedTranType NVARCHAR(50);

            SELECT @RemovedTranID = TranID, @RemovedItemID = ItemID
            FROM dbo.InvenMonitoringDetails
            WHERE RecID = @RecID;

            -- Determine transaction type
            IF @RemovedTranID LIKE 'INV-I-%'
                SET @RemovedTranType = 'Issuance';
            ELSE IF @RemovedTranID LIKE 'INV-R-%'
                SET @RemovedTranType = 'Receiving';
            ELSE IF @RemovedTranID LIKE 'INV-TR-%'
                SET @RemovedTranType = 'Transfer';

            UPDATE dbo.InvenMonitoringDetails
            SET Status = 'REMOVED'
            WHERE RecID = @RecID;

            UPDATE dbo.InvenIssuance
            SET Status = 'REMOVED'
            WHERE TranID = @RemovedTranID
              AND ItemID = @RemovedItemID
              AND @RemovedTranID LIKE 'INV-I-%';

            UPDATE dbo.InvenReceiving
            SET Status = 'REMOVED'
            WHERE TranID = @RemovedTranID
              AND ItemID = @RemovedItemID
              AND @RemovedTranID LIKE 'INV-R-%';

            UPDATE dbo.InvenTransfer
            SET Status = 'REMOVED'
            WHERE TranID = @RemovedTranID
              AND ItemID = @RemovedItemID
              AND @RemovedTranID LIKE 'INV-TR-%';

            SET @LogRowsAffected = 1;
            SET @LogAdditionalInfo = 'RecID: ' + CAST(@RecID AS VARCHAR) +
                                     ', TranID: ' + ISNULL(@RemovedTranID, 'NULL') +
                                     ', ItemID: ' + ISNULL(@RemovedItemID, 'NULL') +
                                     ', TranType: ' + ISNULL(@RemovedTranType, 'NULL');

            -- Log the DELETE operation
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, RecID, ItemID,
                UserID, Status, AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @Tag, @LogOperationType, @RemovedTranID, @RemovedTranType, @RecID, @RemovedItemID,
                @ModifiedBy, 'REMOVED', @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );
        END

        -- ============================================
        -- LOG SUCCESSFUL COMPLETION
        -- ============================================
        SET @LogEndTime = GETDATE();
        SET @LogExecutionTime = DATEDIFF(MILLISECOND, @LogStartTime, @LogEndTime);

        -- Log successful operation (for non-logged operations above)
        IF @Tag NOT IN ('InsertInvenMonitoringHeader', 'UpdateInvenMonitoringHeader',
                        'UpdateInvenMonitoringHeaderStatus', 'UpdateInvenMonitoringDetails',
                        'UpdateInsertInvenMonitoringDetails', 'MarkDetailsRemoved')
        BEGIN
            INSERT INTO dbo.InvenMonitoringLog (
                LogDate, Tag, OperationType, TranID, TranType, RecID, UserID,
                Warehouse, ToWhse, ItemID, Status, AdditionalInfo,
                HostName, AppName, RowsAffected, ExecutionTime
            )
            VALUES (
                @LogStartTime, @Tag, @LogOperationType, @TranID, @TranType, @RecID, @UserID,
                @Warehouse, @ToWhse, @ItemID, @Status, @LogAdditionalInfo,
                @LogHostName, @LogAppName, @LogRowsAffected, @LogExecutionTime
            );
        END

    END TRY
    BEGIN CATCH
        -- ============================================
        -- ERROR HANDLING AND LOGGING
        -- ============================================
        SET @LogErrorNumber = ERROR_NUMBER();
        SET @LogErrorSeverity = ERROR_SEVERITY();
        SET @LogErrorState = ERROR_STATE();
        SET @LogErrorProcedure = ERROR_PROCEDURE();
        SET @LogErrorLine = ERROR_LINE();
        SET @LogErrorMessage = ERROR_MESSAGE();

        SET @LogEndTime = GETDATE();
        SET @LogExecutionTime = DATEDIFF(MILLISECOND, @LogStartTime, @LogEndTime);

        -- Log the error
        INSERT INTO dbo.InvenMonitoringLog (
            LogDate, Tag, OperationType, TranID, TranType, RecID, UserID,
            Warehouse, ToWhse, ItemID, Status, ErrorMessage, ErrorNumber,
            ErrorSeverity, ErrorState, ErrorProcedure, ErrorLine,
            AdditionalInfo, HostName, AppName, ExecutionTime
        )
        VALUES (
            @LogStartTime, @Tag, ISNULL(@LogOperationType, 'ERROR'), @TranID, @TranType, @RecID, @UserID,
            @Warehouse, @ToWhse, @ItemID, @Status, @LogErrorMessage, @LogErrorNumber,
            @LogErrorSeverity, @LogErrorState, @LogErrorProcedure, @LogErrorLine,
            @LogAdditionalInfo, @LogHostName, @LogAppName, @LogExecutionTime
        );

        -- Re-throw the error
        THROW;
    END CATCH
END
GO
