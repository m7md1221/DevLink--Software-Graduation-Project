/* ============================================================================
   DevLink - align an existing database with the EF Core model (baseline step 1)
   ----------------------------------------------------------------------------
   For databases created from database/scrip_23_10.sql. Run it while connected
   to the target database (e.g. sqlcmd -d DevLink -i ...), AFTER taking a backup.

   What it does (metadata only - no table, column or row is changed):
     1. Gives the three primary keys that SQL Server named randomly
        (PK__Users__..., PK__Customer__..., PK__Programm__...) stable names.
     2. Replaces the randomly named UNIQUE constraint on Users.Email with the
        unique index IX_Users_Email that EF Core expects (the index is created
        first, so uniqueness is enforced at every moment).
     3. Drops the redundant randomly named UNIQUE constraints on
        CustomerProfiles.UserId / ProgrammerProfiles.UserId - each column is
        already covered by the unique index IX_<Table>_UserId.

   Idempotent: running it again changes nothing. All-or-nothing transaction.
   Step 2 (recording the baseline migration) is database/baseline_ef_history.sql.
   ========================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @name sysname;
DECLARE @target sysname;
DECLARE @table sysname;
DECLARE @sql nvarchar(400);

-- ---------------------------------------------------------------------------
-- 1. Primary keys -> PK_<Table>
-- ---------------------------------------------------------------------------
DECLARE pk_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.name
    FROM (VALUES (N'Users'), (N'CustomerProfiles'), (N'ProgrammerProfiles')) AS t(name);

OPEN pk_cursor;
FETCH NEXT FROM pk_cursor INTO @table;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @name = NULL;
    SET @target = N'PK_' + @table;

    SELECT @name = kc.name
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'dbo.' + @table) AND kc.type = 'PK';

    IF @name IS NULL
        THROW 50001, 'Primary key not found - is this a DevLink database?', 1;

    IF @name <> @target
    BEGIN
        DECLARE @qualified nvarchar(300) = N'dbo.' + QUOTENAME(@name);
        EXEC sp_rename @objname = @qualified, @newname = @target, @objtype = N'OBJECT';
        PRINT 'Renamed primary key of ' + @table + ' to ' + @target;
    END

    FETCH NEXT FROM pk_cursor INTO @table;
END

CLOSE pk_cursor;
DEALLOCATE pk_cursor;

-- ---------------------------------------------------------------------------
-- 2. Users.Email: UNIQUE constraint -> unique index IX_Users_Email
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'IX_Users_Email')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users (Email);
    PRINT 'Created unique index IX_Users_Email';
END

SET @name = NULL;
SELECT @name = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE kc.parent_object_id = OBJECT_ID(N'dbo.Users') AND kc.type = 'UQ' AND c.name = N'Email';

IF @name IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(@name);
    EXEC sp_executesql @sql;
    PRINT 'Dropped UNIQUE constraint on Users.Email (replaced by IX_Users_Email)';
END

-- ---------------------------------------------------------------------------
-- 3. Profile tables: drop the redundant UNIQUE constraint on UserId
-- ---------------------------------------------------------------------------
DECLARE uq_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.name
    FROM (VALUES (N'CustomerProfiles'), (N'ProgrammerProfiles')) AS t(name);

OPEN uq_cursor;
FETCH NEXT FROM uq_cursor INTO @table;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @target = N'IX_' + @table + N'_UserId';

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.' + @table) AND name = @target AND is_unique = 1)
    BEGIN
        SET @sql = N'CREATE UNIQUE NONCLUSTERED INDEX ' + QUOTENAME(@target) + N' ON dbo.' + QUOTENAME(@table) + N' (UserId)';
        EXEC sp_executesql @sql;
        PRINT 'Created unique index ' + @target;
    END

    SET @name = NULL;
    SELECT @name = kc.name
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'dbo.' + @table) AND kc.type = 'UQ';

    IF @name IS NOT NULL
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@table) + N' DROP CONSTRAINT ' + QUOTENAME(@name);
        EXEC sp_executesql @sql;
        PRINT 'Dropped redundant UNIQUE constraint on ' + @table + '.UserId';
    END

    FETCH NEXT FROM uq_cursor INTO @table;
END

CLOSE uq_cursor;
DEALLOCATE uq_cursor;

COMMIT TRANSACTION;
PRINT 'Alignment complete.';

/* ---------------------------------------------------------------------------
   NOT executed - pending decision S7 (docs/PLANNING_REPORT.md section 5.2):
   the column default Posts.Status = 'Approved' lets rows inserted directly with
   SQL skip moderation. The application always sets Status itself.

   DECLARE @df sysname = (SELECT dc.name FROM sys.default_constraints dc
                          JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
                          WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Posts') AND c.name = N'Status');
   DECLARE @dropDefault nvarchar(300) = N'ALTER TABLE dbo.Posts DROP CONSTRAINT ' + QUOTENAME(@df);
   IF @df IS NOT NULL EXEC sp_executesql @dropDefault;
   --------------------------------------------------------------------------- */
