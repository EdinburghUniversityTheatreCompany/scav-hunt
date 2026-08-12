# Off-topic improvements

Things noticed while working on something else. Nothing here was in scope at the time it was
found, so nothing here has been fixed. Delete an entry when it lands.

## Found while wiring up the dev-env standard (mise / hk / CI), 2026-08-07

Every item below is a **pre-existing** issue: each was verified to predate that work. Together
they are why six of the sixteen hk gates are currently red.

### App bugs

- **`app/views/layouts/_navbar.html.erb:1` — stray comma between HTML attributes.**
  `<nav class="navbar bg-dark navbar-expand-lg bg-body-tertiary", data-bs-theme="dark">`.
  Invalid markup: browsers recover, but it is the *only* thing failing both
  `bundle exec herb analyze app/` and `bundle exec herb lint app/`. Deleting the comma makes
  `herb analyze` report 43/43 files clean (verified).

- **`app/services/statistics_service.rb:36` — `NoMethodError: undefined method 'min' for nil`.**
  `generate_time_intervals` assumes a non-nil `start_time`; it is nil when the `chart_start_time`
  setting is absent. Causes 3 of the 4 errors in `bin/rails test`
  (`test/services/statistics_service_test.rb`).

- **`test/channels/application_cable/connection_test.rb` — 1 error.** The fourth of the four
  pre-existing test errors.

### Security findings

- **`app/controllers/users_controller.rb:56` — Mass Assignment (brakeman `PermitAttributes`).**
  `params.require(:user).permit(:email, :name, :role, ...)` lets a user set their own `:role`
  if the action is reachable without an authorisation check. Worth confirming CanCanCan blocks
  it, and dropping `:role` from the permit list for non-admins either way.

- **`app/services/statistics_service.rb:22` — possible SQL injection (brakeman).**
  `team.results.where("#{time_column} <= ?", interval)` interpolates a column name. Low risk if
  `time_column` is derived internally, but it should be validated against an allowlist of
  column names rather than interpolated.

- **`bundle exec bundle-audit check` — CVEs across ~21 gems**, including rails/actionpack/
  activerecord/activesupport, rack, nokogiri, puma, devise, loofah, rexml and websocket-driver.
  The tree is well behind (Rails 7.2.1). Owned by a dedicated dependency-upgrade pass; do not
  chip at it piecemeal.

### Code quality

- **`bin/rubocop` — 201 offences (198 autocorrectable)** in four files:
  `config/initializers/devise.rb`, `config/initializers/simple_form.rb`,
  `config/initializers/simple_form_bootstrap.rb` and
  `db/migrate/20240828214914_update_users_to_challenges.rb`. Almost all `Style/StringLiterals`
  (single vs. double quotes) in generator-produced files. `bin/rubocop -A` fixes them; the hk
  pre-commit hook will do it automatically on the next commit that stages those files.

- **`.herb.yml` holds an adoption baseline of 11 parked rules.** Written by
  `herb lint app/ --disable-failing` so herb could be adopted without blocking every commit.
  It is a to-do list, not a policy. 48 of the 64 original offences are
  `herb lint app/ --fix`-able. Highest-value ones to re-enable first:
  `erb-no-instance-variables-in-partials` (7 offences — partials reaching for `@ivars` instead
  of locals) and `html-input-require-autocomplete` (3 — an a11y/UX win on the login form).

- **`.jscpd.json` sets `threshold: 1.1` instead of the standard's `0`.** Two pre-existing
  clones: `app/assets/stylesheets/login.css:1-7` ~ `scoreboard.css:3-9`, and
  `test/system/home_test.rb:40-60` ~ `80-100` (the guest and team-user table assertions, which
  differ only in an extra navbar check). De-duplicate both, then put the threshold back
  to `0` so any new duplication fails the gate.

- **`config/initializers/simple_form_bootstrap.rb` is excluded from jscpd** — it is
  simple_form generator boilerplate with three internal clones. Excluded rather than
  refactored, in the same spirit as `db/schema.rb`.

- **`bundle exec debride` — ~140 suspect LOC.** Notably
  `Result#ensure_zero_points`, `User#clear_scoreboard_cache`, and the `new`/`edit`/`show`
  actions on `UsersController`. Advisory — debride cannot see calls from views, ActionCable or
  routes, so verify before deleting anything.

- **`bundle exec flay` — total score 375.** Largest: the near-identical
  `app/views/devise/passwords/new.html.erb` and `devise/unlocks/new.html.erb` (mass 118, a
  shared partial waiting to happen), a 3-way repeat in `challenges/index.html.erb:56-64`, and
  duplicated blocks in `challenges_controller.rb:40/55` and `:43/58`.

- **`bundle exec database_consistency` — 21 model/schema mismatches** (run it with a DB up).
  The substantive ones: `Setting#value`, `Challenge#number`, `#description`, `#points` and
  `#group_id` should be `NOT NULL`; `Result` and `GroupPermission` lack `dependent:` /
  `on_delete` on their `user` association, so deleting a user orphans rows; and
  `index_results_on_user_id` / `index_group_permissions_on_user_id` are redundant, each fully
  covered by a composite index.

### Tooling / environment

- **The `bin/brakeman` binstub injects `--ensure-latest`.** Combined with `./bin` on `$PATH`
  (as on the author's machine) it shadows the gem for `bundle exec brakeman`, so the step fails
  on "not the latest version" instead of on the scan — and CI, which has no `./bin` on `$PATH`,
  would not reproduce it. Worked around in `hk.pkl` and `ci.yml` by loading the executable via
  `Gem.bin_path`. The tidier fix is to drop the `--ensure-latest` line from `bin/brakeman` and
  let bundler-audit/Dependabot handle staying current.

- **Upstream, in the `dev-hooks:dev-env-setup` skill:** the Ruby template's
  `database_consistency` step probes with `bin/rails runner "ActiveRecord::Base.connection"`,
  which is **lazy on Rails 7.2** — it returns a connection object without contacting the
  server, so the probe exits 0 with no database running and database_consistency then dies on
  its first checker. It needs `.execute('SELECT 1')` to force the connection. Fixed locally in
  `hk.pkl`; worth pushing back to the template.

- **Upstream, in `writing:github-readme`'s `github_readme_audit.py`:** its "exactly one H1"
  check counts `#`-prefixed lines inside fenced code blocks. The nginx sample in `README.md`
  legitimately contains `# New server block ...`, which the audit reports as a second H1. The
  check should skip fenced blocks.

## Found while moving the app onto Turbo, 2026-08-07

### App bugs

- **`app/javascript/controllers/statistics_controller.js` logs the whole dataset to the
  console** on every render (`console.log("StatisticsController:", title, data)`). It is the
  last `console.log` left in the app now that the channel plumbing is gone; the two charts on
  `/statistics` dump their full point series into the browser console in production.

  `ScoringController#update` (server side) has the matching gap: it takes both columns from
  the request and overwrites unconditionally, so it cannot detect a stale write either.
  Fixes worth considering: send only the changed field, serialise per (challenge, user) on
  the client, or add optimistic locking (`lock_version` / `updated_at` precondition) so a
  stale update is rejected rather than applied. The system test now works around it by
  committing one field at a time and waiting for each save to land.
## Found during the dependency-upgrade pass, 2026-08-07

- **The Node pin (22.4.1) is now holding dependencies back.** `sass` 1.100.0+ requires
  `chokidar` 5, which is ESM-only, so `yarn build:css` dies with `ERR_REQUIRE_ESM` — `require(esm)`
  only landed in Node 22.12. `package.json` therefore caps sass at `<1.100.0`. Bumping the Node
  pin (mise.toml + `.node-version` + `Dockerfile` `ARG NODE_VERSION`, all in lockstep) to a
  current 22.x LTS would let that cap go. The same pin also blocks `esbuild` 0.25+, which
  requires Node >= 18 but ships transitive tooling assuming newer.

- **CI never installs Node or Yarn for the `test` job.** `.github/workflows/ci.yml` sets up Ruby
  via `ruby/setup-ruby` and then runs `bin/rails db:test:prepare test test:system`, which invokes
  `yarn install` through jsbundling/cssbundling — on whatever Node the runner image happens to
  ship, not the 22.4.1 that `mise.toml`, `.node-version` and the `Dockerfile` all pin. After this
  upgrade the lockfile contains `brace-expansion@5`, whose `engines` field requires
  `20 || >=22`, so a runner image that regressed to Node 18 would break the build. The `lint`
  and `actions-lint` jobs already use `jdx/mise-action`; the `test` job should too (or add
  `actions/setup-node` with `node-version-file: .node-version`).

- **`mise exec -- <cmd>` does not put mise's Node on `PATH` for grandchildren.**
  `mise exec -- node --version` reports 22.4.1 but `mise exec -- which node` reports
  `/usr/bin/node` (18.19.1), so `mise exec -- bin/rails test` runs the yarn asset build on the
  *system* Node. It happens to work today; it silently defeats the pin. Anyone driving this repo
  non-interactively should prepend the mise install dirs to `PATH` explicitly rather than rely on
  `mise exec`.

- **`Gemfile.lock` was resolved with Bundler 2.5.13, which predates the `cooldown:` feature.**
  The cooldown is nevertheless applied (it is set in `~/.bundle/config`), and it held Rails back
  from 7.2.3.2 to 7.2.3 even though 7.2.3.2 was nine days old at the time — well outside the
  4-day window. Worth re-checking once `BUNDLED WITH` moves to a Bundler that implements
  cooldown natively; until then, security floors need to be spelled out in the `Gemfile`.

- **`Dockerfile:49` still runs `bundle exec bootsnap precompile --gemfile`, but bootsnap is gone.**
  Commit 9ea25e5 ("Remove bootsnap because it doesn't play nice") dropped the gem —
  `rg bootsnap Gemfile Gemfile.lock` finds nothing, and `config/boot.rb` has
  `require "bootsnap/setup"` commented out — but the Dockerfile's precompile step was left
  behind. `bundle exec bootsnap` with the gem absent exits non-zero, which should fail the image
  build. Not verified with an actual `docker build` (too slow for this pass), but it looks like a
  real break on a branch named `fix-portainer-deployment`. Delete the line.

- **`rubocop-rails-omakase` is held at 1.0.0.** 1.1.0 registers rubocop-minitest via `plugins:`
  instead of `require:`, which enables several more Minitest cops. The only resulting offence is
  `Minitest/RefuteFalse` at `test/system/settings_test.rb:36` (`assert_equal false, ...` should be
  `refute ...`) — autocorrectable with `bin/rubocop -A`. Fix it and drop the hold.
- **`ChallengesController#index` assigns `@challenges` twice.** `load_and_authorize_resource`
  has already set it to `Challenge.accessible_by(current_ability)` by the time the action body
  overwrites it with `Challenge.visible_to(current_user).includes(:results)`, so the first
  relation is built and thrown away. Harmless (it is lazy) but confusing; `skip_load_resource
  only: :index` would say what is meant.

- **Completion stats on `/challenges` are still not live** (the FIXME at the top of the view).
  They are per-challenge rather than per-team, so they need a challenge-wide stream rather than
  the per-user one the scores use — `Result` would broadcast to `[challenge, :stats]` and the
  scorer view would subscribe. Small, and now that the scores go over Turbo it is a five-line
  addition rather than a fourth channel.

- **`Challenge#completion_stats` and `User#stats` are N+1s.** Both are called once per row while
  rendering (`challenges/_challenge_row`, `home/index`), and each runs two or three COUNT
  queries. Fine at scavenger-hunt scale, but they are the reason a broadcast re-render of the
  scorer's challenge list is the most expensive thing the app does.

- **CI never pins Node, so asset builds use whatever the runner ships.**
  `.github/workflows/ci.yml` pins Ruby properly (`ruby-version: .ruby-version` on every job) but
  the `test` job runs `yarn install --frozen-lockfile` and `bin/rails test:system` with no
  `actions/setup-node` and no `jdx/mise-action` step, so esbuild/sass run on the runner's default
  Node rather than the 22.4.1 pinned in `mise.toml` / `.node-version`. That contradicts
  CLAUDE.md's own rule that mise.toml is the single source of truth for ruby/node/yarn. It is
  green today, which is exactly why it is easy to miss — a runner image bump could change the
  Node major under the build without any commit. Deliberately left alone during the Rails 8.1
  load_defaults work: the upgrade did not change the Node requirement, and the CI-sync workflow
  says not to touch a dimension the upgrade did not move. Add `jdx/mise-action` (already used by
  the `gitleaks` and `actions-lint` jobs) to the `test` job, or `actions/setup-node` with
  `node-version-file: .node-version`.

- **Sprockets-era `config.assets.*` keys survive under Propshaft.**
  The app moved to Propshaft (`Gemfile:9`, propshaft 1.3.2) but
  `config/environments/development.rb:65-69` still sets `config.assets.quiet`,
  `config.assets.debug`, `config.assets.compile` and `config.assets.digest`. Propshaft implements
  none of those — there is no compilation step, no debug mode and digests are unconditional — so
  they are dead config that reads as if it does something. (`config.assets.paths` and
  `config.assets.version` in `config/initializers/assets.rb` are real and Propshaft honours them;
  keep those.) Harmless because `config.assets` is an OrderedOptions that swallows unknown keys,
  which is also why nothing has flagged it. Delete the four dead lines.

- **CLAUDE.md's "Known pre-existing issues" section is stale.**
  It claims `bin/rails test` is "26 runs, 4 errors", `bin/rubocop` has "201 offences" and
  `herb analyze` fails on a stray comma in `_navbar.html.erb`. As of this pass all three are
  clean: 48 runs / 0 failures / 0 errors, 76 files / no offences, 43/43 files clean. Items 1, 2
  and 3 should be struck so the list stops describing regressions that no longer exist.

- **Rails' own `new_framework_defaults` templates ship two lines that are silent no-ops.**
  Found while working through the 8.0 and 8.1 defaults. Both
  `Rails.application.config.action_dispatch.strict_freshness = true` (8.0 template) and
  `Rails.configuration.active_support.escape_js_separators_in_json = false` (8.1 template) are
  copied out of `config.*` by railtie initializers — `action_dispatch.configure` at position 26
  and `active_support.set_configs` at position 20 — both of which run before
  `load_config_initializers` at position 113 loads `config/initializers/*`. Uncommenting either
  line in the generated file changes nothing; the consuming attribute keeps its old value. Anyone
  using these files to trial defaults one at a time needs to set those two in
  `config/application.rb` instead, and should read the value back from the consuming object
  (`ActionDispatch::Http::Cache::Request.strict_freshness`,
  `ActiveSupport.escape_js_separators_in_json`) rather than trusting the assignment. Worth an
  upstream Rails issue.

- **`plans/repo-review-2026-08-07.md` predates the Turbo Stream rewrite.**
  Line 77 raises a leak in `GroupUpdatesChannel` and line 175 asks for the duplication between
  `ScoringController#update` and `ScoringChannel#receive` to be factored out. Both channels were
  deleted by commits `6a85c83` and `562b5c1`, so those two items are already closed and should be
  struck rather than re-investigated.
