# TAMILAN CAREERS — Security Review

**Review date:** 2026-11-21  
**Scope:** Public GitHub repository and connected Supabase project.  
**Method:** Read-only repository/database inspection, Supabase Security Advisor, and post-change privilege verification.

## Important limitation: browser source visibility

The current repository is public. Visitors can inspect or copy the website's browser-delivered HTML, CSS, JavaScript, and public network requests. This is expected for a static website and cannot be prevented by JavaScript obfuscation or disabling browser tools.

The repository's current public visibility is a separate concern from the security of user records and administrative operations. Do not change repository visibility until the hosting and custom-domain deployment path has been verified; an unplanned visibility change can interrupt a GitHub Pages deployment. If private source hosting is required, migrate and verify the site on a host that supports a private source repository before changing the repository visibility.

## Verified baseline

- All inspected public database tables have Row Level Security enabled.
- No public-schema table without RLS was found.
- Two public tables have RLS enabled but no policies: `company_invitations` and `job_sources`. These are default-deny until an explicit policy is added. Do not add broad public policies merely to clear an advisory.
- One private rate-limit table has RLS enabled and no policies; it is intended to remain private/default-deny.
- No public SECURITY DEFINER function was executable by the `anon` role in the post-change catalog check.
- No private SECURITY DEFINER function was executable by the `anon` role in the post-change catalog check.
- Fifteen authenticated-callable SECURITY DEFINER RPCs remain flagged by Security Advisor. Source review found caller identity and ownership/company-role checks on candidate and employer actions, and Super Admin checks on privileged review/publish actions. Do not revoke them in bulk because that can break candidate, employer, and admin workflows. Add positive and negative integration tests for every RPC.
- The external-job-candidate review RPC was updated to call the shared `private.require_super_admin_mfa()` helper instead of maintaining a separate inline MFA check. Verification confirmed the RPC remains unavailable to `anon`, available to `authenticated` for its protected UI workflow, and uses the centralized MFA check.
- Supabase Security Advisor reports leaked-password protection disabled. The connected TAMILAN CAREERS organization is currently on the Free plan. Current Supabase documentation says leaked-password protection requires Pro or above, so this setting cannot be enabled on the current plan. No paid upgrade was made.
- The project currently has one Super Admin account and no verified MFA factor. Do not enforce mandatory MFA until the Super Admin has enrolled and tested a recovery authenticator; otherwise access may be locked out.

## Changes made on 2026-11-21

1. Revoked `EXECUTE` from `PUBLIC`, `anon`, and `authenticated` on `private.set_job_post_message_sender()`. It remains attached to its database trigger. Post-change verification confirmed:
   - anonymous EXECUTE: false
   - authenticated EXECUTE: false
   - trigger attachment: present
2. Expanded `.gitignore` to exclude local environment files, credentials, private keys, service-role key files, and local build/development artifacts.
3. Added this security policy and review record.
4. Updated the Admin Control Center to show a live MFA readiness warning and link to Admin Account Security.
5. Improved the MFA setup page to recommend a second authenticator on a separate device as a recovery option.
6. Standardized the external-job-candidate review RPC on the shared Super Admin MFA helper.

## Repository secret search limitations

The targeted GitHub code-search queries returned no matches for common service-role/secret-key markers and private-key PEM markers. However, the repository code-search index may be incomplete or unavailable, so this is **not proof that the repository contains no secrets**. It is not a complete scan of every current file, historical commit, GitHub Actions secret, external backup, or deployment environment.

A full review of repository files and Git history is still required. If any credential may ever have been committed, rotate it even if the current file has been removed. The `.gitignore` rules prevent accidental addition of future local secret files; they do not remove already tracked files or erase Git history.

The browser-facing Supabase publishable key is not a secret. Never put a Supabase secret key, legacy service-role key, database password, JWT signing secret, private key, or recovery code in browser code or source control.

## Required next actions

1. Enroll and test Super Admin MFA, including a recovery method, before making MFA mandatory for all admin access.
2. Leaked-password protection requires Supabase Pro or above according to current documentation. Do not upgrade automatically; the project owner must decide whether to pay for that plan. Keep strong password requirements and avoid password reuse in the meantime.
3. Review Auth rate limits and abuse protection in the Supabase Dashboard.
4. Test every authenticated SECURITY DEFINER RPC with an authorized user and an unauthorized user.
5. Confirm that company invitations and source-directory data remain inaccessible to anonymous and ordinary authenticated users. Their current RLS/no-grant configuration is default-deny; do not add broad policies just to silence the linter.
6. Review Git history and deployment secrets for any credential exposure; rotate any confirmed exposed credential.
7. If hiding repository source from casual public browsing is a requirement, migrate hosting to a verified private-repository-capable deployment before changing GitHub visibility.

## Security objective

The goal is not to hide browser source. The goal is to ensure that viewing source code does not grant access to private records, credentials, Super Admin functions, or unauthorized database changes.
