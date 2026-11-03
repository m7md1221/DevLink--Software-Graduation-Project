using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DotnetAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddAuthSecurity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "FailedLoginCount",
                table: "Users",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "GoogleSubject",
                table: "Users",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastLoginAt",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LockoutEndAt",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SecurityStamp",
                table: "Users",
                type: "varchar(64)",
                unicode: false,
                maxLength: 64,
                nullable: false,
                defaultValueSql: "lower(replace(convert(nvarchar(36), newid()), '-', ''))");

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "Users",
                type: "varchar(16)",
                unicode: false,
                maxLength: 16,
                nullable: false,
                defaultValue: "Active");

            migrationBuilder.AddColumn<DateTime>(
                name: "SuspendedAt",
                table: "Users",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SuspendedReason",
                table: "Users",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ContactShareConsentAt",
                table: "PostApplications",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AuthSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    ClientType = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    Status = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastRefreshedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    AbsoluteExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RevokedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RevokeReason = table.Column<string>(type: "varchar(32)", unicode: false, maxLength: 32, nullable: true),
                    DownloadBindingHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuthSessions", x => x.Id);
                    table.CheckConstraint("CK_AuthSessions_ClientType", "[ClientType]='mobile' OR [ClientType]='web'");
                    table.CheckConstraint("CK_AuthSessions_Status", "[Status]='Expired' OR [Status]='Revoked' OR [Status]='Active'");
                    table.ForeignKey(
                        name: "FK_AuthSessions_Users",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "OneTimeCodes",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Purpose = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    EmailKey = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: false),
                    CodeHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    FailedAttempts = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsumedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    InvalidatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ProofTokenHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: true),
                    ProofExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ProofConsumedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OneTimeCodes", x => x.Id);
                    table.CheckConstraint("CK_OneTimeCodes_FailedAttempts", "[FailedAttempts]>=0");
                    table.CheckConstraint("CK_OneTimeCodes_Purpose", "[Purpose]='Reset' OR [Purpose]='Signup'");
                });

            migrationBuilder.CreateTable(
                name: "SecurityEvents",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    OccurredAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EventType = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false),
                    Outcome = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: true),
                    ActorUserId = table.Column<int>(type: "int", nullable: true),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    TargetType = table.Column<string>(type: "varchar(32)", unicode: false, maxLength: 32, nullable: true),
                    TargetId = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: true),
                    EmailKey = table.Column<string>(type: "char(12)", unicode: false, fixedLength: true, maxLength: 12, nullable: true),
                    IpPrefix = table.Column<string>(type: "varchar(49)", unicode: false, maxLength: 49, nullable: true),
                    ClientType = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    TraceId = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: true),
                    Details = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SecurityEvents", x => x.Id);
                    table.CheckConstraint("CK_SecurityEvents_Outcome", "[Outcome]='Blocked' OR [Outcome]='Failure' OR [Outcome]='Success'");
                });

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TokenHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: false),
                    Status = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ConsumedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RevokedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ParentTokenId = table.Column<long>(type: "bigint", nullable: true),
                    ReplacedByTokenId = table.Column<long>(type: "bigint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                    table.CheckConstraint("CK_RefreshTokens_Status", "[Status]='Revoked' OR [Status]='Rotated' OR [Status]='Active'");
                    table.ForeignKey(
                        name: "FK_RefreshTokens_AuthSessions",
                        column: x => x.SessionId,
                        principalTable: "AuthSessions",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RefreshTokens_Parent",
                        column: x => x.ParentTokenId,
                        principalTable: "RefreshTokens",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RefreshTokens_ReplacedBy",
                        column: x => x.ReplacedByTokenId,
                        principalTable: "RefreshTokens",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_GoogleSubject",
                table: "Users",
                column: "GoogleSubject",
                unique: true,
                filter: "[GoogleSubject] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Users_SecurityStamp",
                table: "Users",
                column: "SecurityStamp",
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_Status",
                table: "Users",
                sql: "[Status]='Suspended' OR [Status]='Active'");

            migrationBuilder.CreateIndex(
                name: "IX_AuthSessions_User_Status",
                table: "AuthSessions",
                columns: new[] { "UserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_OneTimeCodes_Email_Purpose_Created",
                table: "OneTimeCodes",
                columns: new[] { "EmailKey", "Purpose", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_OneTimeCodes_ProofTokenHash",
                table: "OneTimeCodes",
                column: "ProofTokenHash",
                unique: true,
                filter: "[ProofTokenHash] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_OneActivePerSession",
                table: "RefreshTokens",
                column: "SessionId",
                unique: true,
                filter: "[Status] = 'Active'");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_ParentTokenId",
                table: "RefreshTokens",
                column: "ParentTokenId");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_ReplacedByTokenId",
                table: "RefreshTokens",
                column: "ReplacedByTokenId");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_Session_Status",
                table: "RefreshTokens",
                columns: new[] { "SessionId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_TokenHash",
                table: "RefreshTokens",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SecurityEvents_OccurredAt",
                table: "SecurityEvents",
                column: "OccurredAt");

            migrationBuilder.CreateIndex(
                name: "IX_SecurityEvents_User_OccurredAt",
                table: "SecurityEvents",
                columns: new[] { "UserId", "OccurredAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OneTimeCodes");

            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.DropTable(
                name: "SecurityEvents");

            migrationBuilder.DropTable(
                name: "AuthSessions");

            migrationBuilder.DropIndex(
                name: "IX_Users_GoogleSubject",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_SecurityStamp",
                table: "Users");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_Status",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "FailedLoginCount",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "GoogleSubject",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LastLoginAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LockoutEndAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SecurityStamp",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SuspendedAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SuspendedReason",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ContactShareConsentAt",
                table: "PostApplications");
        }
    }
}
