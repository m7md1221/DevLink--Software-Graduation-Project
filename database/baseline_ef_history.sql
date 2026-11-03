/* ============================================================================
   DevLink - record the EF Core baseline (baseline step 2)
   ----------------------------------------------------------------------------
   Run ONLY after database/align_schema_for_ef_baseline.sql succeeded on the same
   database. It tells EF Core that the schema created by scrip_23_10.sql already
   equals migration 20261028125753_InitialCreate, so EF will never try to create
   those tables again. No table or row of application data is touched.
   Idempotent.
   ========================================================================== */
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.__EFMigrationsHistory') IS NULL
BEGIN
    CREATE TABLE dbo.__EFMigrationsHistory (
        MigrationId nvarchar(150) NOT NULL,
        ProductVersion nvarchar(32) NOT NULL,
        CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY (MigrationId)
    );
END

IF NOT EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory
               WHERE MigrationId = N'20261028125753_InitialCreate')
BEGIN
    INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES (N'20261028125753_InitialCreate', N'9.0.0');
    PRINT 'Baseline recorded: 20261028125753_InitialCreate';
END
ELSE
    PRINT 'Baseline already recorded.';
