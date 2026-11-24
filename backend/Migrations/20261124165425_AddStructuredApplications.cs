using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DotnetAPI.Migrations
{
    /// <summary>
    /// Duration in days on applications and one answer per acceptance criterion. Idempotent,
    /// like the previous migrations: each object is created only when missing, and an existing
    /// one with a different definition stops the migration. Existing applications keep working.
    /// </summary>
    public partial class AddStructuredApplications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
IF COL_LENGTH(N'dbo.PostApplications', N'DurationDays') IS NULL
    ALTER TABLE [dbo].[PostApplications] ADD [DurationDays] int NULL;
ELSE IF NOT EXISTS (SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'dbo.PostApplications') AND name = N'DurationDays'
                      AND system_type_id = TYPE_ID(N'int') AND is_nullable = 1)
    THROW 50121, 'PostApplications.DurationDays exists but is not int NULL.', 1;");

            migrationBuilder.Sql(@"
IF OBJECT_ID(N'dbo.ApplicationCriterionResponses', N'U') IS NULL
    CREATE TABLE [dbo].[ApplicationCriterionResponses] (
        [ApplicationId] int NOT NULL,
        [CriterionId] int NOT NULL,
        [Response] nvarchar(20) NOT NULL,
        [Note] nvarchar(300) NULL,
        CONSTRAINT [PK_ApplicationCriterionResponses] PRIMARY KEY ([ApplicationId], [CriterionId])
    );
ELSE IF (SELECT COUNT(*) FROM sys.columns
         WHERE object_id = OBJECT_ID(N'dbo.ApplicationCriterionResponses')
           AND ((name = N'ApplicationId' AND system_type_id = TYPE_ID(N'int')      AND is_nullable = 0)
             OR (name = N'CriterionId'   AND system_type_id = TYPE_ID(N'int')      AND is_nullable = 0)
             OR (name = N'Response'      AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 40  AND is_nullable = 0)
             OR (name = N'Note'          AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 600 AND is_nullable = 1))) <> 4
    THROW 50122, 'ApplicationCriterionResponses exists but its columns differ from the model.', 1;");

            ForeignKey(migrationBuilder, "FK_ApplicationCriterionResponses_PostApplications", "ApplicationId", "PostApplications", cascade: true);
            ForeignKey(migrationBuilder, "FK_ApplicationCriterionResponses_AcceptanceCriteria", "CriterionId", "AcceptanceCriteria", cascade: false);

            migrationBuilder.Sql(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.ApplicationCriterionResponses') AND name = N'IX_ApplicationCriterionResponses_CriterionId')
    CREATE INDEX [IX_ApplicationCriterionResponses_CriterionId] ON [dbo].[ApplicationCriterionResponses] ([CriterionId]);");
        }

        private static void ForeignKey(MigrationBuilder migrationBuilder, string name, string column, string principal, bool cascade)
        {
            var action = cascade ? 1 : 0;
            var onDelete = cascade ? " ON DELETE CASCADE" : "";
            migrationBuilder.Sql($@"
IF OBJECT_ID(N'dbo.{name}', N'F') IS NULL
    ALTER TABLE [dbo].[ApplicationCriterionResponses] ADD CONSTRAINT [{name}]
        FOREIGN KEY ([{column}]) REFERENCES [dbo].[{principal}] ([Id]){onDelete};
ELSE IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys fk
                    JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
                    WHERE fk.object_id = OBJECT_ID(N'dbo.{name}')
                      AND fk.parent_object_id = OBJECT_ID(N'dbo.ApplicationCriterionResponses')
                      AND fk.referenced_object_id = OBJECT_ID(N'dbo.{principal}')
                      AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = N'{column}'
                      AND fk.delete_referential_action = {action}
                      AND fk.is_disabled = 0 AND fk.is_not_trusted = 0)
    THROW 50123, '{name} exists but differs from the model.', 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF OBJECT_ID(N'dbo.ApplicationCriterionResponses', N'U') IS NOT NULL DROP TABLE [dbo].[ApplicationCriterionResponses];");
            migrationBuilder.Sql("IF COL_LENGTH(N'dbo.PostApplications', N'DurationDays') IS NOT NULL ALTER TABLE [dbo].[PostApplications] DROP COLUMN [DurationDays];");
        }
    }
}
