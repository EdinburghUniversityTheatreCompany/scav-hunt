# Bulk user import — design

**Date:** 2026-08-08
**Status:** approved, ready for an implementation plan

## Goal

Create many users at once from a CSV, instead of filling in `/users/new` per team. The
immediate need is standing up a hunt's teams before an event.

## Context that constrains the design

- **No mailer is configured.** Every `config.action_mailer.*` setting in
  `config/environments/production.rb` is commented out, and the encrypted credentials hold only
  `secret_key_base` — no SMTP. Emailed invites and "forgot password" flows are therefore not
  available, and standing up mail is explicitly out of scope. Passwords must travel out-of-band.
- **`activerecord-import` cannot be used here**, even though `ChallengesController#import` uses
  it. Bulk insert writes columns directly and never runs Devise's `password=` setter, so
  passwords would be stored unhashed or blank. Users must be built and saved individually.
- **`User` validates uniqueness on `name` as well as `email`** (`app/models/user.rb`), so two
  rows sharing a team name collide. The report has to make that legible.
- **Devise's password floor is 6 characters** (`config.password_length = 6..128`).
- `Ability` grants `User` management only through the admin's `can :manage, :all`; neither
  `team` nor `scorer` has any `User` rule.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Where passwords come from | A `Password` column in the uploaded CSV | No mailer, and hand-chosen credentials are memorable enough to hand a team on a slip. Accepted cost: a plaintext file exists on the operator's machine. |
| Existing email | **Skip**, and report it | Re-running the same file is then harmless. Never silently resets a live password mid-hunt. |
| `Role` column | Optional, defaults to `team` | Most rows are teams. Defaulting to the least-privileged role means a missing or misspelled value can never mint an admin. |
| Invalid row | Skip it, import the rest, report the reason | Matches the hardened `ChallengesController#import`. A single bad row should not block the batch. |
| Placement | `UserImport` service object | It creates credentials, so it deserves tests that need neither a browser nor a controller. Keeps `UsersController` thin. |

## CSV format

Required headers: `Name`, `Email`, `Password`. Optional: `Role`.

```csv
Name,Email,Role,Password
Team 1,team1@bedlamtheatre.co.uk,team,pineapple24
Team 2,team2@bedlamtheatre.co.uk,,viking24
Judge Alex,alex@bedlamtheatre.co.uk,scorer,sphinx24
```

`Role` accepts the enum names `team` / `scorer` / `admin`; blank means `team`. An unrecognised
value is a rejected row, not a silent fallback.

## Behaviour

Given an uploaded file, in order:

1. **No file** → `422`, "Please select a file to import."
2. **Missing required headers** → `422`, naming exactly which are missing. Nothing imported.
   (Guards the failure mode already fixed in the challenges importer, where a misspelled header
   silently imported nothing while reporting success.)
3. **Unreadable CSV** (`CSV::MalformedCSVError`) → `422`, naming the parse error.
4. Otherwise, per row:
   - email already belongs to a user → **skipped**, recorded
   - fails validation → **rejected**, recorded with its reason and row number
   - otherwise → **created**
5. **Outcome:**
   - Everything created → redirect to `/users` with a notice: `Imported 8 users.`
   - Anything skipped or rejected → render `import_form` with `422` and `flash.now[:alert]`,
     summarising all three counts. `422` matters: Turbo discards a `200` response to a form
     submission, which is what made the challenges importer's errors invisible.

Report wording, with the rejected list capped (as the challenges importer caps it) so one
malformed file cannot produce an unbounded flash:

```
Created 8. Skipped 2 (already exist): team3@…, scorer@….
1 rejected — row 4: Password is too short (minimum is 6 characters).
```

## Architecture

**`app/services/user_import.rb`** — the whole of the logic.

- `UserImport.new(file)` / `#call` returning a result object exposing `created`, `skipped`,
  `rejected` and `missing_headers`, plus a `success?` predicate.
- Builds each user with `User.new(name:, email:, role:, password:)` so Devise hashes the
  password, and `save` (non-bang) so a validation failure is a recorded rejection rather than an
  exception.
- Row numbers in the report are the CSV's own, counting the header as row 1, so they match what
  the operator sees in their spreadsheet.

**`UsersController`** — two thin actions mirroring `ChallengesController`:
`import_form` (sets `@title`) and `import` (delegates to `UserImport`, branches on the result).
Both are already covered by the controller's existing `load_and_authorize_resource`, so they
inherit admin-only access with no extra code.

**Routes** — mirror the challenges block exactly:

```ruby
resources :users do
  collection do
    get :import_form
    post :import
  end
end
```

**Views** — `app/views/users/import_form.html.erb`, modelled on
`challenges/import_form.html.erb` (`simple_form_for :import`, `multipart: true`, a file input
accepting `text/csv`, Import and Back buttons). It documents the headers and states plainly that
existing emails are skipped, not updated. An "Import Users" button joins "New User" on
`users/index.html.erb`.

## Security constraints

These are requirements, not nice-to-haves:

- The report **never** echoes a password, in any branch, including rejection reasons.
- The upload is read from the request `Tempfile` and never written into the application.
- `config/initializers/filter_parameter_logging.rb` already filters `:passw`, so the parameter
  does not reach the logs; nothing in this feature may log a row verbatim.
- Admin-only, enforced by the existing `load_and_authorize_resource`.
- No plaintext password is stored anywhere after the request — only Devise's digest.

## Testing

**Service** (`test/services/user_import_test.rb`) — the substance, no browser needed:
creates valid rows; defaults a blank `Role` to `team`; rejects an unknown role; skips an
existing email without altering that user's `encrypted_password`; rejects a short password, a
duplicate name, and a malformed email; reports missing headers; handles a malformed CSV. Plus
the security property: **a created user's password verifies with `valid_password?` and the
digest is not the plaintext.**

**Controller** (`test/controllers/users_controller_test.rb`) — admin reaches `import_form`; a
`scorer` and a `team` are denied; a clean import redirects with the notice; a partial import
returns `422`; no file returns `422`.

**System** (`test/system/user_import_test.rb`) — upload through the form and see the flash,
mirroring `challenge_import_export_test.rb`.

Per rails-core rule 1, no existing fixture is mutated; any new fixture is added.

## Out of scope

- Configuring a mailer, and any invite or password-reset flow.
- Updating existing users in bulk (the chosen behaviour is skip; edit by hand).
- Exporting users. The challenges importer has a matching `export`; nothing has asked for the
  user equivalent, and it would produce a file of account data with no current use.
- Assigning group permissions during import.
