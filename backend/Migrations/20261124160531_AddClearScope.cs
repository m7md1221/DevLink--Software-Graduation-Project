using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DotnetAPI.Migrations
{
    /// <summary>
    /// Project fields on Posts and the AcceptanceCriteria table. Idempotent, like
    /// AddSavedPostsAndFramework: each object is created only when missing, and an
    /// existing one with a different definition stops the migration.
    /// </summary>
    public partial class AddClearScope : Migration
    {
        private static readonly (string Name, string Type, string Check)[] Columns =
        {
            ("Title", "nvarchar(120)", "system_type_id = TYPE_ID(N'nvarchar') AND max_length = 240"),
            ("ProblemStatement", "nvarchar(2000)", "system_type_id = TYPE_ID(N'nvarchar') AND max_length = 4000"),
            ("TargetUsers", "nvarchar(1000)", "system_type_id = TYPE_ID(N'nvarchar') AND max_length = 2000"),
            ("BudgetMin", "decimal(12,2)", "system_type_id = TYPE_ID(N'decimal') AND precision = 12 AND scale = 2"),
            ("BudgetMax", "decimal(12,2)", "system_type_id = TYPE_ID(N'decimal') AND precision = 12 AND scale = 2"),
            ("DeadlineDays", "int", "system_type_id = TYPE_ID(N'int')"),
        };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            foreach (var (name, type, check) in Columns)
            {
                migrationBuilder.Sql($@"
IF COL_LENGTH(N'dbo.Posts', N'{name}') IS NULL
    ALTER TABLE [dbo].[Posts] ADD [{name}] {type} NULL;
ELSE IF NOT EXISTS (SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'dbo.Posts') AND name = N'{name}' AND is_nullable = 1 AND {check})
    THROW 50111, 'Posts.{name} exists but is not {type} NULL.', 1;");
            }

            migrationBuilder.Sql(@"
IF OBJECT_ID(N'dbo.AcceptanceCriteria', N'U') IS NULL
    CREATE TABLE [dbo].[AcceptanceCriteria] (
        [Id] int NOT NULL IDENTITY,
        [PostId] int NOT NULL,
        [SortOrder] int NOT NULL,
        [Text] nvarchar(300) NOT NULL,
        CONSTRAINT [PK_AcceptanceCriteria] PRIMARY KEY ([Id])
    );
ELSE IF (SELECT COUNT(*) FROM sys.columns
         WHERE object_id = OBJECT_ID(N'dbo.AcceptanceCriteria')
           AND ((name = N'Id'        AND system_type_id = TYPE_ID(N'int')      AND is_nullable = 0 AND is_identity = 1)
             OR (name = N'PostId'    AND system_type_id = TYPE_ID(N'int')      AND is_nullable = 0)
             OR (name = N'SortOrder' AND system_type_id = TYPE_ID(N'int')      AND is_nullable = 0)
             OR (name = N'Text'      AND system_type_id = TYPE_ID(N'nvarchar') AND max_length = 600 AND is_nullable = 0))) <> 4
    THROW 50112, 'AcceptanceCriteria exists but its columns differ from the model.', 1;");

            migrationBuilder.Sql(@"
IF OBJECT_ID(N'dbo.FK_AcceptanceCriteria_Posts', N'F') IS NULL
    ALTER TABLE [dbo].[AcceptanceCriteria] ADD CONSTRAINT [FK_AcceptanceCriteria_Posts]
        FOREIGN KEY ([PostId]) REFERENCES [dbo].[Posts] ([Id]) ON DELETE CASCADE;
ELSE IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
                    WHERE object_id = OBJECT_ID(N'dbo.FK_AcceptanceCriteria_Posts')
                      AND parent_object_id = OBJECT_ID(N'dbo.AcceptanceCriteria')
                      AND referenced_object_id = OBJECT_ID(N'dbo.Posts')
                      AND delete_referential_action = 1 AND is_disabled = 0 AND is_not_trusted = 0)
    THROW 50113, 'FK_AcceptanceCriteria_Posts exists but differs from the model.', 1;");

            migrationBuilder.Sql(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.AcceptanceCriteria') AND name = N'IX_AcceptanceCriteria_PostId_SortOrder')
    CREATE UNIQUE INDEX [IX_AcceptanceCriteria_PostId_SortOrder] ON [dbo].[AcceptanceCriteria] ([PostId], [SortOrder]);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF OBJECT_ID(N'dbo.AcceptanceCriteria', N'U') IS NOT NULL DROP TABLE [dbo].[AcceptanceCriteria];");
            foreach (var (name, _, _) in Columns)
            {
                migrationBuilder.Sql($"IF COL_LENGTH(N'dbo.Posts', N'{name}') IS NOT NULL ALTER TABLE [dbo].[Posts] DROP COLUMN [{name}];");
            }
        }
    }
}
