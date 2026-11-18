# Company Member Management

The live Supabase Edge Function is `company-members` (JWT verification enabled). The repository now tracks the same source at `supabase/functions/company-members/index.ts`.

## Website pages

- `company-members.html` — select a company, list members and pending invitations, invite by email, change a member role, remove a member, or cancel an invitation.
- `accept-invitation.html` — accepts a token from an invitation email after the invited user signs in and confirms the same email address.

The Dashboard, Company Profile, and Company Applicants pages link to team management.

## Supported actions

`list_companies`, `list_members`, `list_invitations`, `invite_member`, `accept_invitation`, `cancel_invitation`, `update_member`, and `remove_member`.

Owners can invite HR Managers, Recruiters, and Viewers. Active HR Managers can invite/manage Recruiters and Viewers. Members cannot remove or change the owner or their own membership.

Invitation tokens are random, stored as SHA-256 hashes, expire after seven days, and are never returned by list endpoints. Acceptance requires a valid signed-in user with a confirmed email matching the invitation. The invitation acceptance RPC is service-role-only and uses an empty search path.

## Required Supabase Function Secrets

Email invitations require these Function Secrets:

- `RESEND_API_KEY` — Resend API key.
- `APP_BASE_URL` — `https://tamilancareers.in` (HTTPS URL; no trailing slash required).
- `RESEND_FROM_EMAIL` — optional; use a sender verified in Resend. If omitted, the test sender `TAMILAN CAREERS <onboarding@resend.dev>` is used and may be restricted by Resend.

Do not put these secrets in HTML, JavaScript, GitHub source, or chat. The function supports the current Supabase publishable/secret key environment variables and legacy anon/service-role environment variables.

## Verification status

The function is deployed and the pages are committed. Static JavaScript, Deno type-check, and browser smoke tests are included in CI. A real invitation email/acceptance and role-change test still requires a second confirmed account and the Resend secrets above. Current live data has one company and one active owner member, with no invitations or job applications.
