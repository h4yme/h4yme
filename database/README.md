# Database Stored Procedures - Logging Implementation

This directory contains updated stored procedures with comprehensive logging capabilities.

## Overview

The database system has been enhanced with a robust logging mechanism that tracks all database operations, including SELECT, INSERT, UPDATE, DELETE operations, and errors.

## Implemented Stored Procedures

1. **SP_InvenMonitoringHeader** - Inventory monitoring operations (Receiving, Issuance, Transfer)
2. **SP_BoxList** - Box masterfile management (CRUD operations)

## Files

### Inventory Monitoring

#### `/tables/Create_InvenMonitoringLog_Table.sql`
Creates the logging table that stores all audit trail information for inventory operations.

#### `/stored_procedures/SP_InvenMonitoringHeader_WithLogging.sql`
The updated stored procedure with comprehensive logging functionality for inventory monitoring.

### Box List Management

#### `/tables/Create_BoxListLog_Table.sql`
Creates the logging table for Box masterfile operations.

#### `/stored_procedures/SP_BoxList_WithLogging.sql`
The updated stored procedure with comprehensive logging for box CRUD operations.

---

## Logging Table Structure

### `InvenMonitoringLog` Table

| Column | Type | Description |
|--------|------|-------------|
| `LogID` | int (PK, Identity) | Unique log entry identifier |
| `LogDate` | datetime2(7) | Timestamp of the log entry |
| `Tag` | nvarchar(100) | The operation tag (e.g., 'InsertInvenMonitoringHeader') |
| `OperationType` | nvarchar(50) | Type of operation: INSERT, UPDATE, DELETE, SELECT, POST, ERROR |
| `TranID` | nvarchar(50) | Transaction ID being operated on |
| `TranType` | nvarchar(250) | Transaction type: Receiving, Issuance, Transfer |
| `RecID` | int | Record ID being operated on |
| `UserID` | nvarchar(250) | User performing the operation |
| `Warehouse` | nvarchar(250) | Source warehouse |
| `ToWhse` | nvarchar(250) | Destination warehouse (for transfers) |
| `ItemID` | nvarchar(250) | Item ID being operated on |
| `Quantity` | decimal(18,4) | Quantity involved in the operation |
| `Status` | nvarchar(50) | Current status |
| `OldStatus` | nvarchar(50) | Previous status (for updates) |
| `NewStatus` | nvarchar(50) | New status (for updates) |
| `ErrorMessage` | nvarchar(max) | Error message if operation failed |
| `ErrorNumber` | int | SQL error number |
| `ErrorSeverity` | int | SQL error severity level |
| `ErrorState` | int | SQL error state |
| `ErrorProcedure` | nvarchar(250) | Procedure where error occurred |
| `ErrorLine` | int | Line number where error occurred |
| `AdditionalInfo` | nvarchar(max) | Additional contextual information |
| `IPAddress` | nvarchar(50) | Client IP address (reserved for future use) |
| `HostName` | nvarchar(250) | Client host name |
| `AppName` | nvarchar(250) | Application name |
| `RowsAffected` | int | Number of rows affected by the operation |
| `ExecutionTime` | int | Execution time in milliseconds |

### Indexes

The logging table includes optimized indexes for common query patterns:

- **IX_InvenMonitoringLog_LogDate**: Index on LogDate (DESC) for time-based queries
- **IX_InvenMonitoringLog_TranID**: Index on TranID for transaction-specific queries
- **IX_InvenMonitoringLog_UserID**: Index on UserID for user activity auditing
- **IX_InvenMonitoringLog_OperationType**: Index on OperationType for operation-based queries

---

## Logged Operations

### 1. **SELECT Operations**
All data retrieval operations are logged with:
- Tag name
- Search parameters
- Number of rows returned
- Execution time
- User context

**Logged Tags:**
- `GetInvenMonitoringHeader`
- `GetReceiving`
- `GetTransfer`
- `GetOnhand`
- `SearchOnhandByLocation`
- `GetAvailableItems`
- `getHistory`
- `SearchHistory`
- `GetInvenMonitoringHeaderByRecID`
- `GetInvenMonitoringHeaderByTranID`
- `GetInvenMonitoringDetailsByTranID`
- `getItemID`
- `getWarehouse`
- `GetLocation`
- `UserBranch`
- `Branch`
- `getVendorID`

### 2. **INSERT Operations**
All record creation operations are logged with:
- Generated TranID
- Transaction type
- Warehouse information
- Number of detail records inserted
- User who created the record
- Complete audit trail

**Logged Tags:**
- `InsertInvenMonitoringHeader` - Creates new inventory transaction with details
- `UpdateInsertInvenMonitoringDetails` - Adds new detail lines to existing transaction

### 3. **UPDATE Operations**
All modification operations are logged with:
- Old and new status values
- Modified fields
- User who made the change
- Timestamp of modification
- Number of rows updated

**Logged Tags:**
- `UpdateInvenMonitoringHeader` - Updates header information
- `UpdateInvenMonitoringHeaderStatus` - Updates only status field
- `UpdateInvenMonitoringDetails` - Updates detail line items

### 4. **DELETE Operations**
All deletion operations (soft deletes via REMOVED status) are logged with:
- Record being removed
- Transaction and item information
- User who performed the deletion
- Timestamp of deletion

**Logged Tags:**
- `MarkDetailsRemoved` - Marks detail records as REMOVED

### 5. **GENERATE Operations**
Transaction ID generation is logged with:
- Transaction type
- Generated TranID
- Prefix used

**Logged Tags:**
- `GenerateTranID` - Generates new transaction ID

### 6. **ERROR Operations**
All errors are automatically logged with:
- Complete error details
- Error number, severity, state
- Procedure and line number where error occurred
- Full error message
- Context information (parameters, user, etc.)
- Execution time before failure

---

## Error Handling

The stored procedure uses SQL Server's TRY-CATCH mechanism:

```sql
BEGIN TRY
    -- All operations
END TRY
BEGIN CATCH
    -- Capture error details
    -- Log error to InvenMonitoringLog
    -- Re-throw error to caller
END CATCH
```

### Error Logging Details

When an error occurs, the following information is captured:

1. **Error Context**
   - Tag that was being executed
   - Operation type
   - All input parameters
   - User information

2. **Error Details**
   - Error Number (ERROR_NUMBER())
   - Error Severity (ERROR_SEVERITY())
   - Error State (ERROR_STATE())
   - Error Procedure (ERROR_PROCEDURE())
   - Error Line (ERROR_LINE())
   - Error Message (ERROR_MESSAGE())

3. **Performance Metrics**
   - Execution time before error
   - Timestamp of error

4. **System Context**
   - Host name (HOST_NAME())
   - Application name (APP_NAME())

---

## Performance Tracking

Every operation tracks:
- **Start Time**: Captured at procedure entry
- **End Time**: Captured at procedure exit or error
- **Execution Time**: Calculated in milliseconds

This allows for:
- Performance monitoring
- Identifying slow operations
- Optimization opportunities
- Service level agreement (SLA) tracking

---

## Implementation Details

### Logging Variables

Each procedure execution initializes these logging variables:

```sql
DECLARE @LogStartTime DATETIME2 = GETDATE();
DECLARE @LogEndTime DATETIME2;
DECLARE @LogExecutionTime INT;
DECLARE @LogRowsAffected INT = 0;
DECLARE @LogOperationType NVARCHAR(50) = NULL;
DECLARE @LogAdditionalInfo NVARCHAR(MAX) = NULL;
DECLARE @LogErrorMessage NVARCHAR(MAX) = NULL;
-- ... and more
```

### Logging Pattern

For each operation:

1. **Set operation type**:
   ```sql
   SET @LogOperationType = 'INSERT';
   ```

2. **Perform the operation**:
   ```sql
   INSERT INTO dbo.InvenMonitoringHeader (...) VALUES (...);
   ```

3. **Capture results**:
   ```sql
   SET @LogRowsAffected = @@ROWCOUNT;
   SET @LogAdditionalInfo = 'Details about the operation';
   ```

4. **Write log entry**:
   ```sql
   INSERT INTO dbo.InvenMonitoringLog (...) VALUES (...);
   ```

---

## Usage Examples

### Query Recent Activity
```sql
SELECT TOP 100
    LogDate,
    Tag,
    OperationType,
    TranID,
    UserID,
    RowsAffected,
    ExecutionTime
FROM dbo.InvenMonitoringLog
ORDER BY LogDate DESC;
```

### Find All Errors
```sql
SELECT
    LogDate,
    Tag,
    ErrorMessage,
    ErrorNumber,
    ErrorProcedure,
    ErrorLine,
    UserID,
    AdditionalInfo
FROM dbo.InvenMonitoringLog
WHERE OperationType = 'ERROR'
ORDER BY LogDate DESC;
```

### Track Specific Transaction
```sql
SELECT
    LogDate,
    Tag,
    OperationType,
    UserID,
    Status,
    OldStatus,
    NewStatus,
    AdditionalInfo,
    RowsAffected
FROM dbo.InvenMonitoringLog
WHERE TranID = 'INV-R-000001'
ORDER BY LogDate ASC;
```

### User Activity Audit
```sql
SELECT
    LogDate,
    Tag,
    OperationType,
    TranID,
    TranType,
    Warehouse,
    RowsAffected
FROM dbo.InvenMonitoringLog
WHERE UserID = 'john.doe'
    AND LogDate >= DATEADD(DAY, -7, GETDATE())
ORDER BY LogDate DESC;
```

### Performance Analysis
```sql
SELECT
    Tag,
    OperationType,
    AVG(ExecutionTime) AS AvgExecutionTime_MS,
    MAX(ExecutionTime) AS MaxExecutionTime_MS,
    MIN(ExecutionTime) AS MinExecutionTime_MS,
    COUNT(*) AS ExecutionCount
FROM dbo.InvenMonitoringLog
WHERE LogDate >= DATEADD(DAY, -1, GETDATE())
    AND OperationType != 'ERROR'
GROUP BY Tag, OperationType
ORDER BY AvgExecutionTime_MS DESC;
```

### Daily Activity Summary
```sql
SELECT
    CAST(LogDate AS DATE) AS ActivityDate,
    OperationType,
    COUNT(*) AS OperationCount,
    SUM(RowsAffected) AS TotalRowsAffected,
    AVG(ExecutionTime) AS AvgExecutionTime_MS
FROM dbo.InvenMonitoringLog
WHERE LogDate >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(LogDate AS DATE), OperationType
ORDER BY ActivityDate DESC, OperationType;
```

### Error Analysis
```sql
SELECT
    CAST(LogDate AS DATE) AS ErrorDate,
    ErrorNumber,
    COUNT(*) AS ErrorCount,
    STRING_AGG(DISTINCT Tag, ', ') AS AffectedTags
FROM dbo.InvenMonitoringLog
WHERE OperationType = 'ERROR'
    AND LogDate >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(LogDate AS DATE), ErrorNumber
ORDER BY ErrorDate DESC, ErrorCount DESC;
```

---

## Installation Instructions

### Step 1: Create the Log Table
Execute the table creation script first:

```sql
-- Run this script in SSMS or your preferred SQL client
-- File: database/tables/Create_InvenMonitoringLog_Table.sql
```

### Step 2: Verify Table Creation
```sql
-- Verify the table exists
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'InvenMonitoringLog';

-- Verify indexes
SELECT * FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.InvenMonitoringLog');
```

### Step 3: Update the Stored Procedure
Execute the updated stored procedure script:

```sql
-- Run this script in SSMS or your preferred SQL client
-- File: database/stored_procedures/SP_InvenMonitoringHeader_WithLogging.sql
```

### Step 4: Test the Implementation
```sql
-- Test a simple SELECT operation
EXEC SP_InvenMonitoringHeader
    @Tag = 'getItemID';

-- Verify it was logged
SELECT TOP 1 * FROM dbo.InvenMonitoringLog
ORDER BY LogDate DESC;
```

---

## Benefits

### 1. **Complete Audit Trail**
- Track all database operations
- Know who did what and when
- Compliance and regulatory requirements
- Security auditing

### 2. **Error Tracking**
- Automatic error logging
- Detailed error context
- Easier troubleshooting
- Proactive issue detection

### 3. **Performance Monitoring**
- Execution time tracking
- Identify slow operations
- Optimize based on real data
- Capacity planning

### 4. **User Activity**
- Track user actions
- Identify usage patterns
- Training needs identification
- Security monitoring

### 5. **Change Tracking**
- Before/after values for updates
- Complete history of changes
- Data recovery assistance
- Change analysis

---

## Maintenance

### Log Retention Policy

Consider implementing a retention policy to manage log table size:

```sql
-- Archive logs older than 90 days
-- Run this as a scheduled job
INSERT INTO dbo.InvenMonitoringLog_Archive
SELECT * FROM dbo.InvenMonitoringLog
WHERE LogDate < DATEADD(DAY, -90, GETDATE());

DELETE FROM dbo.InvenMonitoringLog
WHERE LogDate < DATEADD(DAY, -90, GETDATE());
```

### Performance Optimization

Monitor index fragmentation:

```sql
SELECT
    i.name AS IndexName,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(
    DB_ID(), OBJECT_ID('dbo.InvenMonitoringLog'), NULL, NULL, 'LIMITED'
) s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 10
ORDER BY s.avg_fragmentation_in_percent DESC;
```

Rebuild fragmented indexes:

```sql
-- If fragmentation > 30%, rebuild
ALTER INDEX IX_InvenMonitoringLog_LogDate
ON dbo.InvenMonitoringLog REBUILD;

-- If fragmentation between 10-30%, reorganize
ALTER INDEX IX_InvenMonitoringLog_LogDate
ON dbo.InvenMonitoringLog REORGANIZE;
```

---

## Security Considerations

### Access Control

Grant appropriate permissions:

```sql
-- Grant read access to auditors
GRANT SELECT ON dbo.InvenMonitoringLog TO AuditorRole;

-- Only the application should insert
GRANT INSERT ON dbo.InvenMonitoringLog TO InventoryAppRole;

-- Prevent unauthorized deletions
DENY DELETE ON dbo.InvenMonitoringLog TO PUBLIC;
```

### Sensitive Data

The log table captures:
- User IDs
- Operation details
- System information

Ensure compliance with:
- Data privacy regulations (GDPR, CCPA, etc.)
- Internal security policies
- Access control requirements

---

## Troubleshooting

### Common Issues

**Issue**: Log table filling up quickly
- **Solution**: Implement retention policy and archiving

**Issue**: Performance degradation
- **Solution**: Check index fragmentation, update statistics

**Issue**: Missing log entries
- **Solution**: Verify TRY-CATCH blocks are not suppressing errors

**Issue**: Incorrect execution times
- **Solution**: Ensure @LogStartTime is set at procedure entry

---

## Future Enhancements

Potential improvements to consider:

1. **IP Address Tracking**: Capture client IP address (currently reserved column)
2. **JSON Details**: Store complex operation details as JSON
3. **Real-time Alerts**: Trigger alerts for specific error patterns
4. **Dashboard Integration**: Build monitoring dashboards
5. **Predictive Analytics**: Use log data for predictive maintenance
6. **Automated Archiving**: Scheduled jobs for log archiving
7. **Data Masking**: Implement for sensitive information

---

## Support and Documentation

For questions or issues:
1. Review the query examples above
2. Check the troubleshooting section
3. Examine recent error logs
4. Contact the database team

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-20 | Initial implementation with comprehensive logging for SP_InvenMonitoringHeader |
| 1.1 | 2025-11-20 | Added comprehensive logging for SP_BoxList |

---

# Box List (SP_BoxList) Logging Implementation

## Overview

The `SP_BoxList` stored procedure manages the Box masterfile with full CRUD operations. This section documents the logging implementation for box management operations.

---

## BoxListLog Table Structure

### `BoxListLog` Table

| Column | Type | Description |
|--------|------|-------------|
| `LogID` | int (PK, Identity) | Unique log entry identifier |
| `LogDate` | datetime2(7) | Timestamp of the log entry |
| `Tag` | nvarchar(100) | The operation tag (e.g., 'insertBox', 'updateBox') |
| `OperationType` | nvarchar(50) | Type of operation: INSERT, UPDATE, DELETE, SELECT, ERROR |
| `RecID` | int | Record ID being operated on |
| `ItemID` | nvarchar(max) | Item ID (box identifier) |
| `ItemDescription` | nvarchar(max) | Item description |
| `Brand` | nvarchar(max) | Brand name |
| `Category` | nvarchar(100) | Category (always 'BOX') |
| `Active` | int | Current active status (1=Active, 0=Inactive) |
| `OldActive` | int | Previous active status (for updates) |
| `NewActive` | int | New active status (for updates) |
| `OldItemDescription` | nvarchar(max) | Previous item description (for updates) |
| `NewItemDescription` | nvarchar(max) | New item description (for updates) |
| `OldBrand` | nvarchar(max) | Previous brand (for updates) |
| `NewBrand` | nvarchar(max) | New brand (for updates) |
| `UserID` | nvarchar(250) | User performing the operation |
| `SearchTerm` | nvarchar(250) | Search term used (for SELECT operations) |
| `ErrorMessage` | nvarchar(max) | Error message if operation failed |
| `ErrorNumber` | int | SQL error number |
| `ErrorSeverity` | int | SQL error severity level |
| `ErrorState` | int | SQL error state |
| `ErrorProcedure` | nvarchar(250) | Procedure where error occurred |
| `ErrorLine` | int | Line number where error occurred |
| `AdditionalInfo` | nvarchar(max) | Additional contextual information |
| `IPAddress` | nvarchar(50) | Client IP address (reserved for future use) |
| `HostName` | nvarchar(250) | Client host name |
| `AppName` | nvarchar(250) | Application name |
| `RowsAffected` | int | Number of rows affected by the operation |
| `ExecutionTime` | int | Execution time in milliseconds |

### Indexes

The BoxListLog table includes optimized indexes:

- **IX_BoxListLog_LogDate**: Index on LogDate (DESC) for time-based queries
- **IX_BoxListLog_RecID**: Index on RecID for record-specific queries
- **IX_BoxListLog_UserID**: Index on UserID for user activity auditing
- **IX_BoxListLog_OperationType**: Index on OperationType for operation-based queries
- **IX_BoxListLog_ItemID**: Index on ItemID for item-specific tracking

---

## Logged Operations for BoxList

### 1. **SELECT Operations**

**Tag: ItemsGetList**
- Retrieves paginated list of boxes with filtering
- Logs: search term, offset, fetch size, rows returned, execution time

**Tag: getBoxBrand**
- Retrieves distinct list of box brands
- Logs: rows returned, execution time

### 2. **INSERT Operations**

**Tag: insertBox**
- Creates new box masterfile record
- Validates: All required fields present, ItemID uniqueness
- Logs: New RecID, ItemID, ItemDescription, Brand, User, timestamp
- Error logging: Validation failures, duplicate ItemID errors

**Logged Information:**
```sql
- RecID (newly generated)
- ItemID
- ItemDescription
- Brand
- Category ('BOX')
- Active status (default: 1)
- CreatedBy (user)
- CreatedOn (timestamp)
```

### 3. **UPDATE Operations**

**Tag: updateBox**
- Updates existing box record
- Tracks before/after values for: ItemDescription, Brand, Active status
- Logs: All changed fields with old and new values
- Detailed change summary in AdditionalInfo

**Change Tracking:**
```sql
- Old ItemDescription → New ItemDescription
- Old Brand → New Brand
- Old Active status → New Active status
```

### 4. **DELETE Operations (Soft Delete)**

**Tag: deleteBox**
- Soft delete by setting Active = 0
- Logs: RecID, ItemID, ItemDescription, Brand being deactivated
- Records: Old active status (1) → New active status (0)

---

## BoxList Usage Examples

### Query Recent Box Operations
```sql
SELECT TOP 50
    LogDate,
    Tag,
    OperationType,
    RecID,
    ItemID,
    ItemDescription,
    Brand,
    UserID,
    RowsAffected,
    ExecutionTime
FROM dbo.BoxListLog
ORDER BY LogDate DESC;
```

### Track Changes to Specific Box
```sql
SELECT
    LogDate,
    Tag,
    OperationType,
    UserID,
    OldItemDescription,
    NewItemDescription,
    OldBrand,
    NewBrand,
    OldActive,
    NewActive,
    AdditionalInfo
FROM dbo.BoxListLog
WHERE RecID = 123
ORDER BY LogDate ASC;
```

### Find All Box Insertions
```sql
SELECT
    LogDate,
    RecID,
    ItemID,
    ItemDescription,
    Brand,
    UserID,
    AdditionalInfo
FROM dbo.BoxListLog
WHERE Tag = 'insertBox'
    AND OperationType = 'INSERT'
ORDER BY LogDate DESC;
```

### User Activity - Box Management
```sql
SELECT
    LogDate,
    Tag,
    OperationType,
    RecID,
    ItemID,
    CASE
        WHEN Tag = 'insertBox' THEN 'Created new box: ' + ItemDescription
        WHEN Tag = 'updateBox' THEN 'Updated box: ' + AdditionalInfo
        WHEN Tag = 'deleteBox' THEN 'Deleted box: ' + ItemDescription
        ELSE 'Viewed boxes'
    END AS Action,
    RowsAffected
FROM dbo.BoxListLog
WHERE UserID = 'john.doe'
    AND LogDate >= DATEADD(DAY, -7, GETDATE())
ORDER BY LogDate DESC;
```

### Find Validation Errors
```sql
SELECT
    LogDate,
    Tag,
    ItemID,
    ItemDescription,
    Brand,
    UserID,
    ErrorMessage,
    AdditionalInfo
FROM dbo.BoxListLog
WHERE Tag = 'insertBox'
    AND ErrorMessage IS NOT NULL
ORDER BY LogDate DESC;
```

### Find Deleted (Deactivated) Boxes
```sql
SELECT
    LogDate,
    RecID,
    ItemID,
    ItemDescription,
    Brand,
    UserID,
    AdditionalInfo
FROM dbo.BoxListLog
WHERE Tag = 'deleteBox'
    AND OldActive = 1
    AND NewActive = 0
ORDER BY LogDate DESC;
```

### Performance Analysis - Box Operations
```sql
SELECT
    Tag,
    OperationType,
    COUNT(*) AS OperationCount,
    AVG(ExecutionTime) AS AvgExecutionTime_MS,
    MAX(ExecutionTime) AS MaxExecutionTime_MS,
    MIN(ExecutionTime) AS MinExecutionTime_MS,
    SUM(RowsAffected) AS TotalRowsAffected
FROM dbo.BoxListLog
WHERE LogDate >= DATEADD(DAY, -30, GETDATE())
    AND OperationType != 'ERROR'
GROUP BY Tag, OperationType
ORDER BY AvgExecutionTime_MS DESC;
```

### Search Activity Report
```sql
SELECT
    CAST(LogDate AS DATE) AS SearchDate,
    COUNT(*) AS SearchCount,
    COUNT(DISTINCT UserID) AS UniqueUsers,
    AVG(RowsAffected) AS AvgResultsReturned
FROM dbo.BoxListLog
WHERE Tag = 'ItemsGetList'
    AND LogDate >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(LogDate AS DATE)
ORDER BY SearchDate DESC;
```

### Audit Trail - Complete Box History
```sql
WITH BoxHistory AS (
    SELECT
        LogDate,
        Tag,
        OperationType,
        UserID,
        CASE
            WHEN Tag = 'insertBox' THEN 'CREATED'
            WHEN Tag = 'updateBox' AND OldActive = NewActive THEN 'MODIFIED'
            WHEN Tag = 'updateBox' AND NewActive = 0 THEN 'DEACTIVATED VIA UPDATE'
            WHEN Tag = 'deleteBox' THEN 'DEACTIVATED'
            ELSE 'VIEWED'
        END AS ActionType,
        AdditionalInfo,
        ROW_NUMBER() OVER (ORDER BY LogDate ASC) AS EventNumber
    FROM dbo.BoxListLog
    WHERE ItemID = 'BOX-001'
)
SELECT * FROM BoxHistory
ORDER BY EventNumber;
```

---

## BoxList Installation Instructions

### Step 1: Create the BoxListLog Table
```sql
-- Run this script in SSMS or your preferred SQL client
-- File: database/tables/Create_BoxListLog_Table.sql
```

### Step 2: Verify Table Creation
```sql
-- Verify the table exists
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'BoxListLog';

-- Verify indexes
SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('dbo.BoxListLog')
ORDER BY i.name;
```

### Step 3: Update the Stored Procedure
```sql
-- Run this script in SSMS or your preferred SQL client
-- File: database/stored_procedures/SP_BoxList_WithLogging.sql
```

### Step 4: Test the Implementation
```sql
-- Test a SELECT operation
EXEC SP_BoxList
    @tag = 'ItemsGetList',
    @SearchTerm = '';

-- Verify it was logged
SELECT TOP 1 * FROM dbo.BoxListLog
ORDER BY LogDate DESC;

-- Test an INSERT operation
EXEC SP_BoxList
    @tag = 'insertBox',
    @ItemId = 'TEST-001',
    @ItemDesc = 'Test Box Description',
    @Brand = 'Test Brand',
    @CreatedBy = 'test.user';

-- Verify the insert was logged
SELECT TOP 1 * FROM dbo.BoxListLog
WHERE Tag = 'insertBox'
ORDER BY LogDate DESC;
```

---

## BoxList Error Handling

The SP_BoxList procedure validates:

1. **Required Fields Validation**
   - ItemID must not be NULL
   - ItemDescription must not be NULL
   - Brand must not be NULL
   - Logs validation failures with specific error details

2. **Duplicate Detection**
   - Checks for existing ItemID before insert
   - Logs duplicate attempts with ItemID details

3. **Category Safety**
   - Update and Delete operations include `Category = 'Box'` check
   - Prevents accidental modification of non-box items

4. **Error Logging**
   - All errors are automatically captured
   - Full error context preserved
   - Includes user information and attempted values

---

## BoxList Security and Compliance

### Audit Capabilities

The BoxListLog provides:

- **Who**: UserID tracks which user performed the action
- **What**: Complete record of changes (before/after values)
- **When**: Precise timestamp of each operation
- **Where**: HostName and AppName for source tracking
- **Why**: AdditionalInfo provides change context

### Data Retention

Consider implementing retention policies:

```sql
-- Archive old box logs (example: 1 year retention)
INSERT INTO dbo.BoxListLog_Archive
SELECT * FROM dbo.BoxListLog
WHERE LogDate < DATEADD(YEAR, -1, GETDATE());

DELETE FROM dbo.BoxListLog
WHERE LogDate < DATEADD(YEAR, -1, GETDATE());
```

### Access Control

```sql
-- Grant read access to auditors
GRANT SELECT ON dbo.BoxListLog TO AuditorRole;

-- Only the application should insert
GRANT INSERT ON dbo.BoxListLog TO BoxManagementAppRole;

-- Prevent unauthorized deletions
DENY DELETE ON dbo.BoxListLog TO PUBLIC;
```

---

## BoxList Maintenance

### Monitor Log Growth

```sql
-- Check log table size
SELECT
    t.NAME AS TableName,
    p.rows AS RowCount,
    SUM(a.total_pages) * 8 AS TotalSpaceKB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB,
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.NAME = 'BoxListLog'
GROUP BY t.Name, p.Rows
ORDER BY t.Name;
```

### Index Maintenance

```sql
-- Check index fragmentation
SELECT
    i.name AS IndexName,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(
    DB_ID(), OBJECT_ID('dbo.BoxListLog'), NULL, NULL, 'LIMITED'
) s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 10
ORDER BY s.avg_fragmentation_in_percent DESC;

-- Rebuild fragmented indexes
ALTER INDEX ALL ON dbo.BoxListLog REBUILD;
```

---

## BoxList Reporting Examples

### Monthly Box Creation Report
```sql
SELECT
    YEAR(LogDate) AS Year,
    MONTH(LogDate) AS Month,
    COUNT(*) AS BoxesCreated,
    COUNT(DISTINCT UserID) AS UniqueCreators,
    COUNT(DISTINCT Brand) AS UniqueBrands
FROM dbo.BoxListLog
WHERE Tag = 'insertBox'
    AND OperationType = 'INSERT'
GROUP BY YEAR(LogDate), MONTH(LogDate)
ORDER BY Year DESC, Month DESC;
```

### Most Active Users
```sql
SELECT
    UserID,
    COUNT(*) AS TotalOperations,
    SUM(CASE WHEN Tag = 'insertBox' THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN Tag = 'updateBox' THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN Tag = 'deleteBox' THEN 1 ELSE 0 END) AS Deletes,
    SUM(CASE WHEN Tag = 'ItemsGetList' THEN 1 ELSE 0 END) AS Searches
FROM dbo.BoxListLog
WHERE LogDate >= DATEADD(MONTH, -1, GETDATE())
GROUP BY UserID
ORDER BY TotalOperations DESC;
```

### Brand Usage Statistics
```sql
SELECT
    Brand,
    COUNT(DISTINCT RecID) AS BoxCount,
    COUNT(*) AS TotalOperations,
    MAX(LogDate) AS LastModified
FROM dbo.BoxListLog
WHERE Tag IN ('insertBox', 'updateBox')
    AND Brand IS NOT NULL
GROUP BY Brand
ORDER BY BoxCount DESC;
```

---

## License

Internal use only. Proprietary to your organization.
