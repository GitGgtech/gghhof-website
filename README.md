# GREAT GOD HELPING HANDS OUTREACH FOUNDATION (GGHHOF) — Website V7

A responsive, bilingual (English/French) public website and a separate administrator portal. The frontend uses plain HTML, CSS and JavaScript and can be hosted on a free static-hosting tier. Supabase provides authentication, database, role checks and media storage.

## Included

- Public Foundation information, programmes, leadership, impact, church projects, gallery, donation information and selected legal/governance documents.
- English/French language switch.
- Responsive layout for phones and desktop.
- Public CMS rendering for approved impact figures, team profiles, church projects and outreach media.
- Separate administrator portal at `/admin/` (also available at `/admin.html`).
- Invitation-only administrator registration; invitations are bound to one email, expire after seven days and can be used once.
- New accounts remain pending until the existing Super Administrator approves them. Approval grants Editor access, not Super Administrator access.
- Administrator can issue invitations and approve/reject requests.
- Dashboard modules for impact figures, leadership/trustees, church projects, outreach photos/videos, partners and news/announcements.
- Uploads to a public-media bucket, with write/delete access restricted to authorised admin/editor roles.
- Financial expenditure is intentionally excluded and remains in the Foundation's separate Lovable application.

## Important security notes

- `supabase-config.js` contains only the project URL and browser publishable key. A publishable key is intended for browser use; it is not a substitute for Row Level Security.
- Never place a Supabase secret/service-role key, database password, donor bank credentials or payment-provider secret in this project.
- Existing `public.admin_roles` and the Foundation owner's `admin` role are preserved by the V7 migration.
- Existing administrator roles: `admin` = Super Administrator; `editor` = approved content administrator; `viewer` = read-only.
- The SQL migration expects the earlier setup's `public.admin_roles` table and `public.is_site_admin()` helper to exist. Do not run it against a different/empty Supabase project without adapting the schema first.
- Only the Super Administrator can issue invitations and approve/reject requests. New approved accounts receive `editor` role.
- The public gallery is intentionally public for items marked published. Obtain informed consent before posting identifiable beneficiaries, especially minors.
- Do not enter individual student sensitive details or individual pastor allowance amounts. Only aggregate public counts are supported here. Financial expenditure stays in Lovable.
- The public site does not process card payments. Donation instructions are requested directly from the Foundation; confirm Zenith Bank inward-remittance/SWIFT/correspondent details before publishing any account details.
- Supabase Free plan limits, backups and inactivity pausing should be reviewed before relying on this for critical records. Keep independent backups.

## Supabase setup — V7 migration

The Foundation has already created its Supabase project, initial tables and `admin_roles` row for the owner, and has run the first administrator-access SQL setup. Do not recreate the project or delete existing roles.

1. Open the existing GGHHOF project in Supabase.
2. Open **SQL Editor → New query**.
3. Open `admin-access-setup.sql` from this package, copy all contents and paste into the editor.
4. Run it. It is designed as an additive migration and preserves the existing administrator row. If Supabase reports an error, stop and share the exact error; do not repeatedly rerun partial fragments.
5. The migration creates the public impact row, content-manager role helper, one-time invitation table/functions, signup trigger, approval functions and the `gghhof-public-media` storage bucket/policies.

## Invite and approve additional administrators

1. Publish the website over HTTPS.
2. Open `https://YOUR-SITE/admin/` and sign in with the existing Super Administrator account.
3. In **Administrator access control**, enter the exact email address of the staff member and create an invitation link.
4. Share the link privately with that person only. The link is email-bound, expires after seven days and is single-use.
5. The invitee opens the link, registers with the invited email and confirms their email if Supabase email confirmation is enabled.
6. The request appears in the Super Administrator's pending requests list.
7. Approve only after verifying the person's identity and authority. Approval grants `editor` role. Reject untrusted requests.

## Publish free with GitHub Pages

1. Create a GitHub repository, for example `gghhof-website`.
2. Extract the ZIP and upload the **contents** of the `gghhof-website` folder to the repository root (including `admin/`, `documents/` and `assets/`).
3. In repository **Settings → Pages**, select **Deploy from a branch**, branch `main`, folder `/(root)`, then save.
4. Wait for GitHub Pages to publish. Test the public URL and `/admin/` on a phone.
5. Use a custom domain only if/when the Foundation is ready to pay for domain registration.

A free Netlify or Cloudflare Pages tier is also possible; check current usage limits and terms before selecting a provider.

## Before public launch

- Confirm official postal address, email, phone numbers, Facebook page and any public social links.
- Confirm the leadership titles and names are correct. Treasurer and CEO/Executive Director remain unassigned until formally confirmed. Use the admin portal to maintain the flexible team list.
- Enter only verified impact totals and approved project information.
- Upload real outreach photographs/videos and ensure consent/guardian permission is documented before publishing identifiable beneficiaries or children.
- The SCUML certificate and Foundation constitution are included for public display. The full CAC status report and signed trustees' minutes are intentionally not published because they contain personal details/signatures.
- Confirm international inward-remittance capability, supported currencies, SWIFT/BIC and correspondent bank instructions with Zenith Bank before advertising specific transfer details.

## Files

- `index.html` — public website.
- `admin/index.html` and `admin.html` — administrator portal (the former is the clean `/admin/` route).
- `admin-access-setup.sql` — V7 Supabase migration.
- `supabase-config.js` — browser-safe project URL and publishable key.
- `public-cms.js` — loads approved public CMS content.
- `styles.css`, `script.js` — site styling and language/menu/contact interactions.
- `documents/` — selected public documents.
- `privacy.html` — privacy and safeguarding information.

## Current implementation boundary

This is a static frontend connected to Supabase. The database migration must be applied to the existing project before the administrator portal's invitation and content-management functions will work. The package has not been deployed to a public host or live-tested against the Foundation's Supabase project from this environment. Complete the migration and test sign-in, invitation, approval, uploads and public rendering before announcing the site as operational.
