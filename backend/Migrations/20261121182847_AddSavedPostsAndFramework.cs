using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DotnetAPI.Migrations
{
    /// <summary>
    /// Saved posts and the Framework columns (partner feature, 2026-11-21).
    ///
    /// Idempotent, because there are two kinds of database:
    ///   - ours (created by migrations): nothing exists yet, everything is created;
    ///   - the partner's (created by docs/partner-schema/partner_schema_2026-11-21.sql, then the alignment
    ///     and baseline scripts): the columns, the table, both foreign keys and
    ///     IX_SavedPosts_UserId already exist, and the (PostId, UserId) uniqueness is a
    ///     UNIQUE constraint named UQ_SavedPosts_Post_User.
    ///
    /// Each object is created only when it is missing. An object that exists with a
    /// different definition stops the migration (THROW), so it is never silently accepted.
    /// The partner's UNIQUE constraint is replaced by the unique index the EF model names
    /// (IX_SavedPosts_PostId_UserId): the index is created first and the constraint is
    /// dropped after, so uniqueness holds at every moment, no row is touched, and both
    /// kinds of database end with the same schema (a later migration that drops or
    /// renames the index then works on both).
    /// </summary>
    public partial class AddSavedPostsAndFramework : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            foreach (var table in new[] { "Posts", "PostApplications" })
            {
                migrationBuilder.Sql($@"
IF COL_LENGTH(N'dbo.{table}', N'Framework') IS NULL
    ALTER TABLE [dbo].[{table}] ADD [Framework] nvarchar(50) NULL;
ELSE IF NOT EXISTS (SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'dbo.{table}') AND name = N'Framework'
                      AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 100 AND is_nullable = 1)
    THROW 50101, '{table}.Framework exists but is not nvarchar(50) NULL.', 1;");
            }

            migrationBuilder.Sql(@"
IF OBJECT_ID(N'dbo.SavedPosts', N'U') IS NULL
    CREATE TABLE [dbo].[SavedPosts] (
        [Id] int NOT NULL IDENTITY,
        [PostId] int NOT NULL,
        [UserId] int NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_SavedPosts] PRIMARY KEY ([Id])
    );
ELSE IF (SELECT COUNT(*) FROM sys.columns
         WHERE object_id = OBJECT_ID(N'dbo.SavedPosts')
           AND ((name = N'Id'        AND system_type_id = TYPE_ID(N'int')       AND is_nullable = 0 AND is_identity = 1)
             OR (name = N'PostId'    AND system_type_id = TYPE_ID(N'int')       AND is_nullable = 0)
             OR (name = N'UserId'    AND system_type_id = TYPE_ID(N'int')       AND is_nullable = 0)
             OR (name = N'CreatedAt' AND system_type_id = TYPE_ID(N'datetime2') AND is_nullable = 0))) <> 4
    THROW 50102, 'SavedPosts exists but its columns differ from the model.', 1;");

            ForeignKey(migrationBuilder, "FK_SavedPosts_Posts", "PostId", "Posts", cascade: true);
            ForeignKey(migrationBuilder, "FK_SavedPosts_Users", "UserId", "Users", cascade: false);

            migrationBuilder.Sql(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.SavedPosts') AND name = N'IX_SavedPosts_PostId_UserId')
    CREATE UNIQUE INDEX [IX_SavedPosts_PostId_UserId] ON [dbo].[SavedPosts] ([PostId], [UserId]);");

            // The partner's UNIQUE constraint on exactly (PostId, UserId), whatever its name:
            // redundant once the unique index above exists.
            migrationBuilder.Sql(@"
DECLARE @uq sysname = (
    SELECT TOP (1) kc.name
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'dbo.SavedPosts') AND kc.type = 'UQ'
      AND (SELECT STRING_AGG(c.name, N',') WITHIN GROUP (ORDER BY ic.key_ordinal)
           FROM sys.index_columns ic
           JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
           WHERE ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
             AND ic.is_included_column = 0) = N'PostId,UserId');
IF @uq IS NOT NULL
BEGIN
    DECLARE @drop nvarchar(400) = N'ALTER TABLE [dbo].[SavedPosts] DROP CONSTRAINT ' + QUOTENAME(@uq);
    EXEC sp_executesql @drop;
END");

            migrationBuilder.Sql(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.SavedPosts') AND name = N'IX_SavedPosts_UserId')
    CREATE INDEX [IX_SavedPosts_UserId] ON [dbo].[SavedPosts] ([UserId]);");
        }

        private static void ForeignKey(MigrationBuilder migrationBuilder, string name, string column, string principal, bool cascade)
        {
            // delete_referential_action: 0 = NO ACTION, 1 = CASCADE
            var action = cascade ? 1 : 0;
            var onDelete = cascade ? " ON DELETE CASCADE" : "";
            migrationBuilder.Sql($@"
IF OBJECT_ID(N'dbo.{name}', N'F') IS NULL
    ALTER TABLE [dbo].[SavedPosts] ADD CONSTRAINT [{name}]
        FOREIGN KEY ([{column}]) REFERENCES [dbo].[{principal}] ([Id]){onDelete};
ELSE IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys fk
                    JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
                    WHERE fk.object_id = OBJECT_ID(N'dbo.{name}')
                      AND fk.parent_object_id = OBJECT_ID(N'dbo.SavedPosts')
                      AND fk.referenced_object_id = OBJECT_ID(N'dbo.{principal}')
                      AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = N'{column}'
                      AND fk.delete_referential_action = {action}
                      AND fk.is_disabled = 0 AND fk.is_not_trusted = 0)
    THROW 50103, '{name} exists but differs from the model.', 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF OBJECT_ID(N'dbo.SavedPosts', N'U') IS NOT NULL DROP TABLE [dbo].[SavedPosts];");
            foreach (var table in new[] { "Posts", "PostApplications" })
            {
                migrationBuilder.Sql($"IF COL_LENGTH(N'dbo.{table}', N'Framework') IS NOT NULL ALTER TABLE [dbo].[{table}] DROP COLUMN [Framework];");
            }
        }
    }
}
