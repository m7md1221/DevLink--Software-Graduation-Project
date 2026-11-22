/* ============================================================================
   KI-68 data fix (PROPOSAL, not run anywhere): mark Google-only accounts that were
   created by the partner's original code (origin/main) as having no password.

   Run ONLY on a database where migration AddUserHasPassword is already applied,
   after a verified COPY_ONLY backup, with sqlcmd -I (QUOTED_IDENTIFIER ON).

   What the original Google sign-up stored (origin/main, AuthController google-login):
       PasswordHash = Guid.NewGuid().ToString()
   i.e. a PLAINTEXT 36-character lowercase GUID ("d" format), not a hash. Nobody was
   shown that value, so the row is never rehashed (rehash happens only on a successful
   password login), and it still looks exactly like that today.

   Rule: PasswordHash is exactly a GUID string in "d" format. A real user would have
   had to type a 36-character GUID as their password to match; step 1 lists the rows
   so a person reviews them before step 2.

   Not covered (cannot be identified reliably):
   - Google sign-ups made on feature/m1-foundation between M1 (2026-11-03) and M2.9
     (2026-11-10): a PBKDF2 hash of a random value, no GoogleSubject, no event.
   - Google sign-ups from M2.9 until M2.11b: GoogleSubject set; their creation event
     has no user id. See the optional step 3.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @guid varchar(300) =   -- 32 x "[0-9a-f]" + 4 dashes = 260 characters
      REPLICATE('[0-9a-f]', 8) + '-' + REPLICATE('[0-9a-f]', 4) + '-' + REPLICATE('[0-9a-f]', 4) + '-'
    + REPLICATE('[0-9a-f]', 4) + '-' + REPLICATE('[0-9a-f]', 12);

/* ---- Step 1 (read-only): candidates for review. Shows no password values. ---- */
SELECT u.Id, u.Email, u.UserType, u.Status, u.HasPassword,
       CASE WHEN u.GoogleSubject IS NULL THEN 0 ELSE 1 END AS HasGoogleSubject
FROM dbo.Users AS u
WHERE LEN(u.PasswordHash) = 36
  AND u.PasswordHash LIKE @guid
  AND u.UserType <> 'Admin'
ORDER BY u.Id;

/* ---- Step 2 (write): only after the list above was reviewed and approved. ----
   Sets HasPassword = 0, so change-password answers PASSWORD_NOT_SET ("use Forgot
   password"), and replaces the plaintext GUID with a fresh random value (64 hex
   characters, never stored anywhere else) so the old GUID, visible to anyone who
   can read the database or its backups, no longer signs in. Password reset still
   works and sets a real PBKDF2 hash and HasPassword = 1.
   Remove the leading -- from the lines below to enable it. */

-- BEGIN TRANSACTION;
-- UPDATE u
--    SET u.HasPassword  = 0,
--        u.PasswordHash = CONVERT(varchar(64), CRYPT_GEN_RANDOM(32), 2),
--        u.SecurityStamp = LOWER(REPLACE(CONVERT(nvarchar(36), NEWID()), '-', ''))
--   FROM dbo.Users AS u
--  WHERE LEN(u.PasswordHash) = 36
--    AND u.PasswordHash LIKE @guid
--    AND u.UserType <> 'Admin';
-- SELECT @@ROWCOUNT AS AccountsMarked;   -- must equal the count reviewed in step 1
-- COMMIT TRANSACTION;                    -- or ROLLBACK TRANSACTION if the count differs

/* ---- Step 3 (optional, read-only; only for databases that ran feature/m1-foundation
   between 2026-11-10 and M2.11b): GoogleSubject set and no record of the account ever
   having a password. Reliable only while the events are kept (90 days, so until about
   2027-02-08). Linking (Auth.GoogleLinked) needs the current password, so a linked
   account always has a real one. ---- */
SELECT u.Id, u.Email, u.UserType
FROM dbo.Users AS u
WHERE u.GoogleSubject IS NOT NULL
  AND u.HasPassword = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.SecurityEvents AS e
                  WHERE e.UserId = u.Id
                    AND e.Outcome = 'Success'
                    AND e.EventType IN ('Auth.GoogleLinked', 'Auth.PasswordReset', 'Auth.PasswordChanged'))
ORDER BY u.Id;
