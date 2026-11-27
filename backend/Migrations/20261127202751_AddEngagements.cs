using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DotnetAPI.Migrations
{
    /// <summary>
    /// Engagements: the agreement an accepted application starts, its copied criteria, deliveries,
    /// review decisions and timeline, plus Posts.CompletedAt. Idempotent, like the previous
    /// migrations: each object is created only when missing, and an existing one with a different
    /// definition stops the migration.
    /// </summary>
    public partial class AddEngagements : Migration
    {
        // (name, SQL type, nullable) in table order.
        private static readonly (string Name, string Type, bool Null)[] EngagementColumns =
        {
            ("Id", "int", false), ("PostId", "int", false), ("ApplicationId", "int", false), ("CustomerId", "int", false),
            ("ProgrammerId", "int", false), ("ProjectTitle", "nvarchar(120)", false), ("AgreedAmount", "decimal(12,2)", true),
            ("DurationDays", "int", true), ("DeadlineAt", "datetime2", true), ("Status", "nvarchar(20)", false),
            ("RevisionsUsed", "int", false), ("CriteriaTotal", "int", false), ("CriteriaMet", "int", true),
            ("CancellationRequestedBy", "int", true), ("CancellationReason", "nvarchar(500)", true),
            ("CancellationRequestedAt", "datetime2", true), ("CreatedAt", "datetime2", false), ("UpdatedAt", "datetime2", true),
            ("CompletedAt", "datetime2", true), ("CancelledAt", "datetime2", true), ("RowVersion", "rowversion", false),
        };

        private static readonly (string Name, string Type, bool Null)[] CriterionColumns =
        {
            ("Id", "int", false), ("EngagementId", "int", false), ("SortOrder", "int", false), ("Text", "nvarchar(300)", false),
            ("Status", "nvarchar(20)", false), ("Waived", "bit", false), ("AcceptedAt", "datetime2", true),
        };

        private static readonly (string Name, string Type, bool Null)[] DeliveryColumns =
        {
            ("Id", "int", false), ("EngagementId", "int", false), ("Round", "int", false), ("Note", "nvarchar(1000)", false),
            ("CreatedAt", "datetime2", false), ("ReviewedAt", "datetime2", true),
        };

        private static readonly (string Name, string Type, bool Null)[] ItemColumns =
        {
            ("DeliveryId", "int", false), ("CriterionId", "int", false), ("Claim", "nvarchar(10)", false),
            ("Evidence", "nvarchar(500)", false), ("Decision", "nvarchar(10)", true), ("ReviewNote", "nvarchar(500)", true),
            ("Waived", "bit", false),
        };

        private static readonly (string Name, string Type, bool Null)[] EventColumns =
        {
            ("Id", "int", false), ("EngagementId", "int", false), ("ActorId", "int", true), ("Type", "nvarchar(40)", false),
            ("Message", "nvarchar(500)", false), ("CreatedAt", "datetime2", false),
        };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
IF COL_LENGTH(N'dbo.Posts', N'CompletedAt') IS NULL
    ALTER TABLE [dbo].[Posts] ADD [CompletedAt] datetime2 NULL;
ELSE IF NOT EXISTS (SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'dbo.Posts') AND name = N'CompletedAt'
                      AND system_type_id = TYPE_ID(N'datetime2') AND is_nullable = 1)
    THROW 50131, 'Posts.CompletedAt exists but is not datetime2 NULL.', 1;");

            Table(migrationBuilder, "Engagements", EngagementColumns, "PRIMARY KEY ([Id])", identity: true);
            Table(migrationBuilder, "EngagementCriteria", CriterionColumns, "PRIMARY KEY ([Id])", identity: true);
            Table(migrationBuilder, "EngagementDeliveries", DeliveryColumns, "PRIMARY KEY ([Id])", identity: true);
            Table(migrationBuilder, "EngagementDeliveryItems", ItemColumns, "PRIMARY KEY ([DeliveryId], [CriterionId])", identity: false);
            Table(migrationBuilder, "EngagementEvents", EventColumns, "PRIMARY KEY ([Id])", identity: true);

            ForeignKey(migrationBuilder, "Engagements", "FK_Engagements_Posts", "PostId", "Posts", cascade: true);
            ForeignKey(migrationBuilder, "Engagements", "FK_Engagements_PostApplications", "ApplicationId", "PostApplications", cascade: false);
            ForeignKey(migrationBuilder, "Engagements", "FK_Engagements_Users_Customer", "CustomerId", "Users", cascade: false);
            ForeignKey(migrationBuilder, "Engagements", "FK_Engagements_Users_Programmer", "ProgrammerId", "Users", cascade: false);
            ForeignKey(migrationBuilder, "EngagementCriteria", "FK_EngagementCriteria_Engagements", "EngagementId", "Engagements", cascade: true);
            ForeignKey(migrationBuilder, "EngagementDeliveries", "FK_EngagementDeliveries_Engagements", "EngagementId", "Engagements", cascade: true);
            ForeignKey(migrationBuilder, "EngagementDeliveryItems", "FK_EngagementDeliveryItems_EngagementDeliveries", "DeliveryId", "EngagementDeliveries", cascade: true);
            ForeignKey(migrationBuilder, "EngagementDeliveryItems", "FK_EngagementDeliveryItems_EngagementCriteria", "CriterionId", "EngagementCriteria", cascade: false);
            ForeignKey(migrationBuilder, "EngagementEvents", "FK_EngagementEvents_Engagements", "EngagementId", "Engagements", cascade: true);

            Index(migrationBuilder, "Engagements", "IX_Engagements_PostId", "[PostId]", unique: true);
            Index(migrationBuilder, "Engagements", "IX_Engagements_ApplicationId", "[ApplicationId]", unique: true);
            Index(migrationBuilder, "Engagements", "IX_Engagements_CustomerId", "[CustomerId]", unique: false);
            Index(migrationBuilder, "Engagements", "IX_Engagements_ProgrammerId", "[ProgrammerId]", unique: false);
            Index(migrationBuilder, "EngagementCriteria", "IX_EngagementCriteria_EngagementId_SortOrder", "[EngagementId], [SortOrder]", unique: true);
            Index(migrationBuilder, "EngagementDeliveries", "IX_EngagementDeliveries_EngagementId_Round", "[EngagementId], [Round]", unique: true);
            Index(migrationBuilder, "EngagementDeliveryItems", "IX_EngagementDeliveryItems_CriterionId", "[CriterionId]", unique: false);
            Index(migrationBuilder, "EngagementEvents", "IX_EngagementEvents_EngagementId", "[EngagementId]", unique: false);
        }

        // One sys.columns test per column: system type, byte length for nvarchar, precision and scale for decimal, nullability.
        private static string ColumnMatch((string Name, string Type, bool Null) c)
        {
            var nullable = c.Null ? 1 : 0;
            var type = c.Type switch
            {
                "rowversion" => "system_type_id = 189",
                "decimal(12,2)" => "system_type_id = TYPE_ID(N'decimal') AND precision = 12 AND scale = 2",
                var t when t.StartsWith("nvarchar(") =>
                    $"system_type_id = TYPE_ID(N'nvarchar') AND max_length = {2 * int.Parse(t[9..^1])}",
                var t => $"system_type_id = TYPE_ID(N'{t}')"
            };
            return $"(name = N'{c.Name}' AND {type} AND is_nullable = {nullable})";
        }

        private static void Table(MigrationBuilder migrationBuilder, string table, (string Name, string Type, bool Null)[] columns, string key, bool identity)
        {
            var definitions = string.Join(",\n        ", columns.Select(c =>
                $"[{c.Name}] {c.Type}{(identity && c.Name == "Id" ? " IDENTITY(1,1)" : "")} {(c.Null ? "NULL" : "NOT NULL")}"));
            var matches = string.Join("\n             OR ", columns.Select(ColumnMatch));
            migrationBuilder.Sql($@"
IF OBJECT_ID(N'dbo.{table}', N'U') IS NULL
    CREATE TABLE [dbo].[{table}] (
        {definitions},
        CONSTRAINT [PK_{table}] {key}
    );
ELSE IF (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.{table}')) <> {columns.Length}
     OR (SELECT COUNT(*) FROM sys.columns
         WHERE object_id = OBJECT_ID(N'dbo.{table}')
           AND ({matches})) <> {columns.Length}
    THROW 50132, '{table} exists but its columns differ from the model.', 1;");
        }

        private static void ForeignKey(MigrationBuilder migrationBuilder, string table, string name, string column, string principal, bool cascade)
        {
            var action = cascade ? 1 : 0;
            var onDelete = cascade ? " ON DELETE CASCADE" : "";
            migrationBuilder.Sql($@"
IF OBJECT_ID(N'dbo.{name}', N'F') IS NULL
    ALTER TABLE [dbo].[{table}] ADD CONSTRAINT [{name}]
        FOREIGN KEY ([{column}]) REFERENCES [dbo].[{principal}] ([Id]){onDelete};
ELSE IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys fk
                    JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
                    WHERE fk.object_id = OBJECT_ID(N'dbo.{name}')
                      AND fk.parent_object_id = OBJECT_ID(N'dbo.{table}')
                      AND fk.referenced_object_id = OBJECT_ID(N'dbo.{principal}')
                      AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = N'{column}'
                      AND fk.delete_referential_action = {action}
                      AND fk.is_disabled = 0 AND fk.is_not_trusted = 0)
    THROW 50133, '{name} exists but differs from the model.', 1;");
        }

        private static void Index(MigrationBuilder migrationBuilder, string table, string name, string columns, bool unique)
        {
            var keyColumns = columns.Replace("[", "").Replace("]", "").Replace(" ", "");
            migrationBuilder.Sql($@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.{table}') AND name = N'{name}')
    CREATE {(unique ? "UNIQUE " : "")}INDEX [{name}] ON [dbo].[{table}] ({columns});
ELSE IF NOT EXISTS (SELECT 1 FROM sys.indexes i
                    WHERE i.object_id = OBJECT_ID(N'dbo.{table}') AND i.name = N'{name}' AND i.is_unique = {(unique ? 1 : 0)}
                      AND N'{keyColumns}' = STUFF((SELECT N',' + COL_NAME(ic.object_id, ic.column_id)
                                                   FROM sys.index_columns ic
                                                   WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
                                                   ORDER BY ic.key_ordinal
                                                   FOR XML PATH('')), 1, 1, N''))
    THROW 50134, '{name} exists but differs from the model.', 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            foreach (var table in new[] { "EngagementDeliveryItems", "EngagementEvents", "EngagementCriteria", "EngagementDeliveries", "Engagements" })
                migrationBuilder.Sql($"IF OBJECT_ID(N'dbo.{table}', N'U') IS NOT NULL DROP TABLE [dbo].[{table}];");
            migrationBuilder.Sql("IF COL_LENGTH(N'dbo.Posts', N'CompletedAt') IS NOT NULL ALTER TABLE [dbo].[Posts] DROP COLUMN [CompletedAt];");
        }
    }
}
