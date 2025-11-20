USE [ELMI]
GO
/****** Object:  StoredProcedure [dbo].[SP_BoxList]    Script Date: 11/20/2025 8:47:10 am ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		JAIMES ALDRICH MANICAR
-- Create date: NOVEMBER 03, 2025
-- Description: BOX MASTERFILE AND CREATION
-- Updated:     NOVEMBER 20, 2025 - Added comprehensive logging
-- =============================================
ALTER PROCEDURE [dbo].[SP_BoxList]
    @tag NVARCHAR(MAX) = NULL,
    @Offset INT = 0,
    @Fetch INT = 1000,
    @PageSize INT = 1000,
    @SearchTerm VARCHAR(100) = '',
    @ItemId NVARCHAR(MAX) = NULL,
    @ItemDesc NVARCHAR(MAX) = NULL,
    @Brand NVARCHAR(MAX) = NULL,
    @RecID INT = NULL,
    @Active INT = NULL,
    @CreatedBy NVARCHAR(MAX) = NULL
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

    -- Variables for tracking old values (for updates)
    DECLARE @OldItemDescription NVARCHAR(MAX) = NULL;
    DECLARE @OldBrand NVARCHAR(MAX) = NULL;
    DECLARE @OldActive INT = NULL;
    DECLARE @NewRecID INT = NULL;

    BEGIN TRY

        -- ============================================
        -- GET BOX LIST
        -- ============================================
        IF @tag = 'ItemsGetList'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT
                RecID,
                CompanyID,
                ItemID,
                ItemDescription,
                Brand,
                Category,
                SubCategory,
                Serialized,
                CASE
                    WHEN Active = 1 THEN 'Yes'
                    ELSE 'No'
                END AS ActiveStatus,
                Type,
                FilterType,
                ISNULL(CreatedBy, 'ADMIN') AS CreatedBy,
                CASE
                    WHEN CreatedOn IS NULL THEN 'ADMIN'
                    ELSE CONVERT(VARCHAR(10), CreatedOn, 101)
                END AS CreatedOn
            FROM BoxMF
            WHERE Category = 'Box'
              AND (
                    @SearchTerm = ''
                    OR ItemDescription LIKE '%' + @SearchTerm + '%'
                    OR ItemID LIKE '%' + @SearchTerm + '%'
                    OR Brand LIKE '%' + @SearchTerm + '%'
                  )
            ORDER BY RecID DESC
            OFFSET @Offset ROWS
            FETCH NEXT @Fetch ROWS ONLY;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'SearchTerm: ' + ISNULL(@SearchTerm, 'NULL') +
                                     ', Offset: ' + CAST(@Offset AS VARCHAR) +
                                     ', Fetch: ' + CAST(@Fetch AS VARCHAR);
        END

        -- ============================================
        -- GET BOX BRANDS
        -- ============================================
        ELSE IF @tag = 'getBoxBrand'
        BEGIN
            SET @LogOperationType = 'SELECT';

            SELECT DISTINCT Brand
            FROM BoxBrand
            ORDER BY Brand;

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'Retrieved distinct brands from BoxBrand table';
        END

        -- ============================================
        -- INSERT NEW BOX
        -- ============================================
        ELSE IF @tag = 'insertBox'
        BEGIN
            SET @LogOperationType = 'INSERT';

            -- Validation
            IF @ItemId IS NULL OR @ItemDesc IS NULL OR @Brand IS NULL
            BEGIN
                SET @LogAdditionalInfo = 'Validation failed: Missing required fields - ItemId: ' +
                                         ISNULL(@ItemId, 'NULL') + ', ItemDesc: ' +
                                         ISNULL(@ItemDesc, 'NULL') + ', Brand: ' +
                                         ISNULL(@Brand, 'NULL');

                -- Log validation error
                INSERT INTO dbo.BoxListLog (
                    LogDate, Tag, OperationType, ItemID, ItemDescription, Brand,
                    UserID, ErrorMessage, AdditionalInfo, HostName, AppName
                )
                VALUES (
                    GETDATE(), @tag, @LogOperationType, @ItemId, @ItemDesc, @Brand,
                    @CreatedBy, 'All fields are required', @LogAdditionalInfo,
                    @LogHostName, @LogAppName
                );

                RAISERROR('All fields are required', 16, 1);
                RETURN;
            END

            -- Check for duplicate
            IF EXISTS (SELECT 1 FROM BoxMF WHERE ItemID = @ItemId)
            BEGIN
                SET @LogAdditionalInfo = 'Duplicate ItemID detected: ' + @ItemId;

                -- Log duplicate error
                INSERT INTO dbo.BoxListLog (
                    LogDate, Tag, OperationType, ItemID, ItemDescription, Brand,
                    UserID, ErrorMessage, AdditionalInfo, HostName, AppName
                )
                VALUES (
                    GETDATE(), @tag, @LogOperationType, @ItemId, @ItemDesc, @Brand,
                    @CreatedBy, 'Item ID already exists', @LogAdditionalInfo,
                    @LogHostName, @LogAppName
                );

                RAISERROR('Item ID already exists', 16, 1);
                RETURN;
            END

            -- Insert the new box
            INSERT INTO BoxMF (
                CompanyID,
                ItemID,
                ItemDescription,
                Brand,
                Category,
                SubCategory,
                Serialized,
                Active,
                Type,
                FilterType,
                CreatedBy,
                CreatedOn
            )
            VALUES (
                'EATI',
                @ItemId,
                @ItemDesc,
                @Brand,
                'BOX',
                'NONE',
                'N',
                1,
                'NULL',
                'NULL',
                @CreatedBy,
                GETDATE()
            );

            SET @NewRecID = SCOPE_IDENTITY();
            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'New box created - ItemID: ' + @ItemId +
                                     ', ItemDesc: ' + @ItemDesc +
                                     ', Brand: ' + @Brand +
                                     ', RecID: ' + CAST(@NewRecID AS VARCHAR);

            -- Log successful insert
            INSERT INTO dbo.BoxListLog (
                LogDate, Tag, OperationType, RecID, ItemID, ItemDescription, Brand,
                Category, Active, UserID, AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @tag, @LogOperationType, @NewRecID, @ItemId, @ItemDesc, @Brand,
                'BOX', 1, @CreatedBy, @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );

            -- Return the new RecID
            SELECT @NewRecID AS NewRecID;
        END

        -- ============================================
        -- UPDATE BOX
        -- ============================================
        ELSE IF @tag = 'updateBox'
        BEGIN
            SET @LogOperationType = 'UPDATE';
            SET NOCOUNT OFF;

            -- Get old values before update
            SELECT
                @OldItemDescription = ItemDescription,
                @OldBrand = Brand,
                @OldActive = Active
            FROM BoxMF
            WHERE RecID = @RecID AND Category = 'Box';

            -- Perform update
            UPDATE BoxMF
            SET ItemDescription = @ItemDesc,
                Brand = @Brand,
                Active = @Active
            WHERE RecID = @RecID
              AND Category = 'Box';

            SET @LogRowsAffected = @@ROWCOUNT;

            -- Build change log
            DECLARE @Changes NVARCHAR(MAX) = '';

            IF @OldItemDescription != @ItemDesc
                SET @Changes = @Changes + 'ItemDescription changed from "' + ISNULL(@OldItemDescription, 'NULL') +
                               '" to "' + ISNULL(@ItemDesc, 'NULL') + '"; ';

            IF @OldBrand != @Brand
                SET @Changes = @Changes + 'Brand changed from "' + ISNULL(@OldBrand, 'NULL') +
                               '" to "' + ISNULL(@Brand, 'NULL') + '"; ';

            IF @OldActive != @Active
                SET @Changes = @Changes + 'Active changed from ' + CAST(@OldActive AS VARCHAR) +
                               ' to ' + CAST(@Active AS VARCHAR) + '; ';

            SET @LogAdditionalInfo = 'RecID: ' + CAST(@RecID AS VARCHAR) + ' - ' +
                                     CASE WHEN @Changes = '' THEN 'No changes detected' ELSE @Changes END;

            -- Log the update
            INSERT INTO dbo.BoxListLog (
                LogDate, Tag, OperationType, RecID, ItemDescription, Brand,
                Category, Active, OldActive, NewActive,
                OldItemDescription, NewItemDescription, OldBrand, NewBrand,
                UserID, AdditionalInfo, HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @tag, @LogOperationType, @RecID, @ItemDesc, @Brand,
                'BOX', @Active, @OldActive, @Active,
                @OldItemDescription, @ItemDesc, @OldBrand, @Brand,
                @CreatedBy, @LogAdditionalInfo, @LogHostName, @LogAppName, @LogRowsAffected
            );
        END

        -- ============================================
        -- DELETE BOX (Soft Delete)
        -- ============================================
        ELSE IF @tag = 'deleteBox'
        BEGIN
            SET @LogOperationType = 'DELETE';
            SET NOCOUNT OFF;

            -- Get current item info before deletion
            DECLARE @DeletedItemID NVARCHAR(MAX);
            DECLARE @DeletedItemDesc NVARCHAR(MAX);
            DECLARE @DeletedBrand NVARCHAR(MAX);

            SELECT
                @DeletedItemID = ItemID,
                @DeletedItemDesc = ItemDescription,
                @DeletedBrand = Brand,
                @OldActive = Active
            FROM BoxMF
            WHERE RecID = @RecID AND Category = 'Box';

            -- Soft delete by setting Active = 0
            UPDATE BoxMF
            SET Active = 0
            WHERE RecID = @RecID
              AND Category = 'Box';

            SET @LogRowsAffected = @@ROWCOUNT;
            SET @LogAdditionalInfo = 'Soft delete (Active set to 0) - RecID: ' + CAST(@RecID AS VARCHAR) +
                                     ', ItemID: ' + ISNULL(@DeletedItemID, 'NULL') +
                                     ', ItemDesc: ' + ISNULL(@DeletedItemDesc, 'NULL') +
                                     ', Brand: ' + ISNULL(@DeletedBrand, 'NULL');

            -- Log the deletion
            INSERT INTO dbo.BoxListLog (
                LogDate, Tag, OperationType, RecID, ItemID, ItemDescription, Brand,
                Category, OldActive, NewActive, UserID, AdditionalInfo,
                HostName, AppName, RowsAffected
            )
            VALUES (
                GETDATE(), @tag, @LogOperationType, @RecID, @DeletedItemID, @DeletedItemDesc, @DeletedBrand,
                'BOX', @OldActive, 0, @CreatedBy, @LogAdditionalInfo,
                @LogHostName, @LogAppName, @LogRowsAffected
            );
        END

        -- ============================================
        -- LOG SUCCESSFUL COMPLETION
        -- ============================================
        SET @LogEndTime = GETDATE();
        SET @LogExecutionTime = DATEDIFF(MILLISECOND, @LogStartTime, @LogEndTime);

        -- Log successful operation (for SELECT operations and others not explicitly logged above)
        IF @tag IN ('ItemsGetList', 'getBoxBrand')
        BEGIN
            INSERT INTO dbo.BoxListLog (
                LogDate, Tag, OperationType, RecID, ItemID, ItemDescription, Brand,
                Active, UserID, SearchTerm, AdditionalInfo, HostName, AppName,
                RowsAffected, ExecutionTime
            )
            VALUES (
                @LogStartTime, @tag, @LogOperationType, @RecID, @ItemId, @ItemDesc, @Brand,
                @Active, @CreatedBy, @SearchTerm, @LogAdditionalInfo, @LogHostName, @LogAppName,
                @LogRowsAffected, @LogExecutionTime
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

        -- Build additional error context
        IF @LogAdditionalInfo IS NULL
        BEGIN
            SET @LogAdditionalInfo = 'Tag: ' + ISNULL(@tag, 'NULL') +
                                     ', RecID: ' + ISNULL(CAST(@RecID AS VARCHAR), 'NULL') +
                                     ', ItemID: ' + ISNULL(@ItemId, 'NULL') +
                                     ', SearchTerm: ' + ISNULL(@SearchTerm, 'NULL');
        END

        -- Log the error
        INSERT INTO dbo.BoxListLog (
            LogDate, Tag, OperationType, RecID, ItemID, ItemDescription, Brand,
            Active, UserID, SearchTerm, ErrorMessage, ErrorNumber, ErrorSeverity,
            ErrorState, ErrorProcedure, ErrorLine, AdditionalInfo, HostName,
            AppName, ExecutionTime
        )
        VALUES (
            @LogStartTime, @tag, ISNULL(@LogOperationType, 'ERROR'), @RecID, @ItemId, @ItemDesc, @Brand,
            @Active, @CreatedBy, @SearchTerm, @LogErrorMessage, @LogErrorNumber, @LogErrorSeverity,
            @LogErrorState, @LogErrorProcedure, @LogErrorLine, @LogAdditionalInfo, @LogHostName,
            @LogAppName, @LogExecutionTime
        );

        -- Re-throw the error
        THROW;
    END CATCH
END
GO
