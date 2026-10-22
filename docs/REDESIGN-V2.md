# BuildTrack mobile — Premium Redesign V2 ("Blueprint Noir")

Branch: `feat/premium-redesign-v2` (built on `feat/ui-redesign-v3`, which already contains `origin/main`).
Rule for this redesign: **design only — no features added or removed, no API / permission / route changes.**
Every screen was checked against `origin/main` (API calls, routes + arguments, permission checks and tour
keys compared before/after) and screenshot-tested against a local backend with seeded data.

## What changed for the user

| Area | Change |
|---|---|
| Look | Noir header with a blueprint grid + soft accent glow, bone page, white floating cards. Fonts: Bricolage Grotesque (titles, money), Instrument Sans (UI), JetBrains Mono (small labels). |
| Theme colour | The App Theme colour is now the **accent** (+ button, progress, highlights). Default: brass. Presets Brass / Ember / Cobalt / Jade + the existing colour list + custom picker. Buttons/text stay ink so everything stays readable. No dark mode (none existed). |
| Bottom bar | Floating dark dock: **Home · Projects · + · Insights · Reports** (still role-filtered). |
| Inbox | Left the bottom bar. Opened from the **bell on Home** (unread badge). Same To approve / Activity tabs. |
| Approvals | **Now on Home** for anyone allowed to approve: count + ₹ waiting, top 2 with Approve / Reject… (confirm), See all → Inbox. Uses the exact same approve/reject calls. |
| Insights tab (new page, same content) | Pick any project at the top → its Overview / Phases / Money insights show right below. Charts and numbers untouched (colours only). The per-project entry on Project detail still exists. |
| Reports | The **Excel-style sheet is the first thing on the tab** (pinned item column, sticky header, sort arrows, zebra rows, horizontal + vertical scroll, paging, full-screen rotate). Ask AI / By type / Efficiency report / CSV import moved below it. |
| Motion | Count-up money, brick progress bars, drawn rings, staggered entrances, press feedback, spring sheets. Success moments: **bags drop & stack** (entry saved), **notes slide into a wallet** (payment / money in), **check draws** (approved, created, signed). Brick-wall loader instead of spinners. All respect "reduce motion". |

## Performance

- No blur filters anywhere. No idle animation loops — loops only run while voice is listening and while a loader is visible; each loop sits in a RepaintBoundary.
- Entrance animations run once per mount and keep the same widget tree afterwards (no remounts).
- The report sheet builds only visible rows; cells are plain boxes (no per-cell animation).

## Feature checklist (origin/main → V2)

**Sign in / onboarding** — login (cached email, show/hide password, forgot password, create workspace), create workspace (all fields, 8 name fonts, logo, email OTP verify/resend, password), forgot password (email → token + new password). ✅
**Home** — Admin / Supervisor / Mason dashboards; project switcher incl. Global Financial Overview; total cost, budget left, upcoming/planned, work done, revenue, net cash flow; Speak Update; record/edit money in/out with receipt, cash e-sign + polling, revenue history, receipt detail, share, delete; recent activity; team approval history; supervisor Pending/Approved/Rejected lists, assign task, refresh, tasks; mason daily update / add material / tasks / recent entries; welcome tour dialog + all tour keys; company name in its chosen font. ✅
**Logging (+)** — Material / Labour / Equipment (same permission gates as the Add Entry page) → Where (project/floor/phase/activity with the same validation) → How (voice / manual); bulk CSV import (template, customise columns, upload, results). ✅
**Entry forms** — material / labour / equipment: every field, units, GST, overtime, recent entries, autocomplete, edit / repeat / delete, record payment while adding, payment sheet (status, method, date, proof, cash e-sign), bill upload, more details, Save vs Submit to Supervisor. ✅
**Voice** — listening (timer, transcript, understood-so-far), AI follow-up chat (common options, typed answers, voice answers), review + edit, saved screen (Add another / View all). ✅
**Entries & money** — entry detail (payments, receipts, invoice, details, record/settle payment, edit, delete), record payment (status, amount, method, date, reference, proof, cash e-sign + waiting screen), receipt viewer (zoom, open full view), client signing page, transaction logs, inventory (tabs, filters, search, history, add more, record payment, edit). ✅
**Projects** — list (photo card for the first project), detail with Overview / Phases / Money / Details (execution tracker, activity details + photos, budget allocation, CSV budget import/export, financial overview, documents, site photo, insights entry), daily update, assign task, new project wizard (4 steps), edit project. ✅
**Reports** — sheet first; search; filters (project, floor/phase/activity, period presets + custom, payment status); sort; customise columns per tab (saved); 10/20/50 rows; full screen + rotate; export CSV/PDF; row → entry details (Add More / Record Payment / Edit / Delete); Ask AI; report insights + PDF export; CSV import / revert last import. ✅
**Account & team** — profile, photo, workspace, subscription card, team overview, assign roles (roles, project access, roles to oversee, permission groups, plan limit), plans & billing (real prices, Most popular, cancel plan), app theme, notifications toggle, change password, guidelines, web portal, logout, delete account. ✅
**Inbox** — To approve (approve / reject with confirm), Activity (mark all read, clear all, load more). ✅

### Small behaviour notes (reviewer-approved)
- Inbox reached from the Home bell instead of the bottom bar; approvals also on Home.
- Supervisor Home: pull-to-refresh added (the empty state already said "Pull down to refresh"; it calls the same refresh as the button).
- Receipt viewer: Share button uses the existing (previously unreachable) share path.
- Revert last CSV import asked to confirm twice in V3 — now once (original wording).
- Voice: the mic orb is display-only while listening (same as origin); use Stop & Analyze / Cancel.
- Success snackbars on saves/payments became full-screen success moments (auto-close, then the same navigation).

## Pre-existing bugs found during the review (NOT fixed — logic was frozen)
- Reports: Qty column = Amount ÷ Rate instead of the saved quantity (wrong when GST/overtime is included).
- Reports: "Generate report" state is unreachable (`_reportGenerated` never resets); full-screen view shows stale rows after an edit; delete doesn't reload report entries.
- Voice: save errors are set but never shown on the review screen; edit mode writes the project *name* into `projectId`.
- E-sign polling loops (record money, payment sheet) keep running if the sheet is closed mid-wait. *(record money: fixed in the testing round)*
- Payment section e-sign switch only takes effect in the add-and-pay route.
- ~~Project detail: `_RecentEntriesSection` hard-codes `isAdmin = true`~~ — fixed in the testing round.
- Daily update resolves the project as `provider.selectedProject ?? picked` (can target the wrong project).
- Material history screen is hard-coded demo data (2023 "Portland Type II").
- Subscription card: active seats hard-coded to 1. Profile version string hard-coded "2.4.0 (2024)".
- Record Payment is not gated by `canApprovePayments` on the transaction log / inventory cards (it is on entry detail).
- Signature page: hard-coded 1×1 PNG as the signature; no `mounted` checks after awaits.
- Unused files: `voice_confirmation_sheet.dart`, `voice_review_widgets.dart`, `review_*.dart` wrappers, `PremiumCtaButton`.

## Fixes from the 15–16 Oct UI testing report (on V2)

| Report item | Status |
|---|---|
| Logout shows "Session expired" twice | Fixed — the alert shows once, only when a signed-in token is rejected; never on logout or a wrong password |
| Dashboard logo too small / no "Powered by Nurofin" | Fixed — 40px logo tile; Powered by Nurofin footer on Home |
| Guidelines (tour) not proper | Fixed — Home, Projects, Add Entry, Reports tours run in screen order, skip steps not on screen, hand off to the next tab the user can open, never to Inventory. Found: showcaseview 5 never attaches keys to widgets, so on-screen checks use the showcase registry (`lib/common/tour_targets.dart`) |
| Revenue card/history/edit don't show the uploaded image | Fixed — image loaded from the entry detail; editing no longer wipes it |
| Recent activity logs empty by default | Fixed — latest group opens by default |
| "Used in" column empty | Fixed |
| Empty-state "New Entry" opens wrong page | Fixed — opens the log sheet |
| Cash + E-sign client email box not visible | Fixed; e-sign polling stops when the sheet closes |
| Project recent activity layout / empty state | Fixed |
| Phases need Update Progress + Add Entry (prefilled) | Added on each activity; Add Entry prefills project / phase / activity |
| Budget field shows "0" | Fixed — blank when 0 |
| Assign Task title/description blanking | Fixed |
| Progress update date pickers + Mark as Done & Submit | Fixed (pickers were behind an IgnorePointer; submit resolves the project by id and shows errors) |
| Project without floor can't continue | Fixed |
| Standalone "Request E-signature" in Add/Repeat entry | Removed (still available in payments) |
| Record Payment colours differ | Fixed |
| New payment prefilled with previous invoice | Fixed — new payments start clean; Repeat resets payment history |
| Standalone inbox unnecessary | Bell on Home → Notifications; "See all" approvals → Approvals list |
| "Entry Approved" notification opens logs | Fixed — opens the entry |
| By Type / Entries layout | By type defaults to the 3-column card grid (list is a toggle); Entries already defaults to the sheet |
| Reports guidelines should explain all options | Fixed — tour walks every control |
| Remove Efficiency Report | Removed from Reports |
| Create Workspace unclear | Fixed — row says "A separate company account"; tapping it first explains a workspace is a separate company (own admin, projects, team, plan) and points to Assign Role for adding people |
| App Guidelines option doesn't work | Fixed — restarts the whole app tour from Home |
| Tour shows Inventory after login | Fixed |
| CSV templates differ between Add Entry and Reports | One template, one column picker, one parser (`csv_import_helper.dart`); accepts old templates and Reports exports, dd/mm/yyyy dates, Excel BOM |
| User restrictions not working | Fixed where the backend restricts: routes `/logs` `/reports` `/assign-role` `/create-workspace` now guarded; Mason buttons, Supervisor Approve and the To approve tab need the permission; project entries list uses the real role; Edit needs entry permission |
| Budget hidden for non-admins + Assign Role option | Added "Project budget" permission (`view_project_budget`); budgets and Insights hidden without it (UI only — the API still returns the numbers) |
| Mason recent entries only own | Fixed |
| Invoice Kannada/Tamil transliterated | Fixed in backend branch `fix/esign-receipt-native-script` (core) — needs native-speaker review |
| Profile page not opening (teammate) | Not reproducible on V2, main or V3 for any role. Hardened: profile fetch times out after 20 s and falls back to cached data; profile tour no longer starts while loading |

**Create Workspace (Account, admins only):** opens the public sign-up flow and creates a brand-new, separate company + admin account. It does not add anything to the current workspace.

**Backend notes (core, not changed):** POST `/tasks` has no permission check; DELETE `/transactions/:id` only checks project access; approve/reject accept `add_entries` as an approval permission; PUT `/projects/:id` (daily update) returns 403 for users without the listed permissions or a task on that project.

## Local testing (never against live)
`flutter run --dart-define=API_BASE_URL=http://localhost:5001/api` points the app at a local backend.
Without the flag the app uses the live API exactly as before.
