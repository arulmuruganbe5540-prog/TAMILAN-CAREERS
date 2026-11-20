# Security Policy — TAMILAN CAREERS

## Reporting a security issue

Please do not publish suspected vulnerabilities, private user information, credentials, access tokens, or exploit details in public issues or discussions.

Report suspected security issues privately to the project maintainer through a private project contact channel. Include the affected page or endpoint, the impact you observed, and safe reproduction steps. Do not access, modify, download, or disclose another person's data while testing.

## Important architecture facts

- This repository contains the static website's browser-delivered source code. HTML, CSS, and browser JavaScript are public by design and can be inspected by visitors.
- Hiding browser source code is not a security control. Sensitive authorization decisions and privileged operations must be enforced by trusted server-side code and database policies.
- Supabase publishable keys may appear in browser code. They are not secrets; access must be constrained by authentication, grants, and Row Level Security (RLS).
- Supabase secret keys, legacy service-role keys, database passwords, signing secrets, private keys, recovery codes, and personal data must never be committed to this repository or placed in browser-delivered files.
- Admin pages must verify the authenticated user's server-side role for every privileged operation. Hiding a link or page is not authorization.
- All exposed database tables must have reviewed RLS policies. Security-definer functions must use a fixed safe search path, narrowly scoped execution grants, and explicit authorization checks where appropriate.

## Supported security baseline

- Use MFA for Super Admin access and sensitive administrative actions.
- Keep public/anonymous access limited to intentionally public information.
- Apply ownership checks to user and employer data.
- Rate-limit authentication and sensitive public endpoints.
- Keep backups and test restoration procedures.
- Review Supabase Security Advisor findings and test both allowed and denied access paths after changes.

## Scope and limitations

A public static website cannot prevent visitors from viewing its delivered HTML, CSS, JavaScript, network requests, or public API identifiers. The security objective is to ensure that inspecting these materials does not grant access to private records, secret credentials, or privileged operations.
