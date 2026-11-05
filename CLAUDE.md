# CLAUDE.md

## What this app is

Scoring website for the Bedlam Theatre / EUTC scavenger hunt. Teams are `User` records
(`role` enum: `team` / `scorer` / `admin`, Devise-authenticated, CanCanCan-authorised via
`app/models/ability.rb`); scorers award `regular_points` and `bonus_points` per
`Challenge` through a `Result` join model, and the live scoreboard, per-team scoring screen
and challenge list update over **Turbo Streams** — `broadcasts_to` / `broadcast_refresh_to`
from the models, with `turbo_stream_from` in the views. There are no bespoke Action Cable
channels and no polling; Action Cable is present only as the transport Turbo rides on.

Main surfaces (`config/routes.rb`): `home#index` (scoreboard, also `format.json`),
`scoring#index` / `scoring#score` / `POST scoring/update`, `challenges` (with CSV
`import_form` / `import` / `export`), `users`, `group_permissions`, `settings`,
`statistics`, and `ActionCable` mounted at `/cable`.

## Key package versions

Read from the manifests in this repo. Do not take versions from memory — re-read the file.

| Package | Version | Source |
| --- | --- | --- |
| Ruby | 3.4.10 | `.ruby-version`, `mise.toml`, `Dockerfile` `ARG RUBY_VERSION` |
| Rails | 8.1.4 | `Gemfile.lock` (`Gemfile` pins `~> 8.1.3` with a `>= 8.1.3.1` security floor) |
| mysql2 | 0.5.7 | `Gemfile.lock` (`Gemfile`: `~> 0.5`) |
| Devise | 5.0.4 | `Gemfile.lock` |
| CanCanCan | 3.7.0 | `Gemfile.lock` |
| Simple Form | 5.4.1 | `Gemfile.lock` |
| turbo-rails (gem) | 2.0.23 | `Gemfile.lock` |
| stimulus-rails (gem) | 1.3.4 | `Gemfile.lock` |
| Propshaft | 1.3.2 | `Gemfile.lock` |
| Puma | 8.0.2 | `Gemfile.lock` |
| redis | 5.4.1 (`Gemfile`: `~> 5.3`, capped below 6 - see comment) | `Gemfile.lock` |
| jbuilder | 2.15.1 | `Gemfile.lock` |
| activerecord-import | 3.0.0 | `Gemfile.lock` |
| RuboCop | 1.92.1 (+ rubocop-rails-omakase 1.1.0; rubocop-minitest 0.41.0; rubocop-mick 0.1.0 from git) | `Gemfile.lock` |
| Brakeman | 8.1.0 | `Gemfile.lock` |
| herb | 0.11.1 | `Gemfile.lock`, `.herb.yml` `version:` |
| Capybara | 3.40.0 | `Gemfile.lock` |
| capybara-playwright-driver / playwright-ruby-client | 0.5.13 / 1.64.0 | `Gemfile.lock` |
| playwright (npm) | 1.64.0 — must equal `Playwright::COMPATIBLE_PLAYWRIGHT_VERSION` | `package.json` (exact pin, no caret) |
| Bundler | 4.0.23 | `Gemfile.lock` (`BUNDLED WITH`) |
| Node | 22.23.4 | `.node-version`, `mise.toml`, `Dockerfile` `ARG NODE_VERSION` |
| Yarn | 1.22.19 | `mise.toml`, `Dockerfile` `ARG YARN_VERSION` |
| @hotwired/turbo-rails | 8.0.23 (spec `^8.0.9`) | `yarn.lock` / `package.json` |
| @hotwired/stimulus | 3.2.2 | `yarn.lock` / `package.json` |
| @rails/actioncable | 8.1.400 | `yarn.lock` / `package.json` |
| Bootstrap | 5.3.8 (+ bootstrap-icons 1.13.2, @popperjs/core 2.11.8) | `yarn.lock` / `package.json` |
| esbuild | 0.28.2 | `yarn.lock` / `package.json` |
| sass | 1.106.1 | `yarn.lock` / `package.json` |
| billboard.js | 4.1.3 | `yarn.lock` / `package.json` |
| d3 | 7.9.0 | `yarn.lock` / `package.json` |
| postcss / postcss-cli / autoprefixer | 8.5.31 / 12.0.0 / 10.6.1 | `yarn.lock` / `package.json` |

`mise.toml` is the single source of truth for ruby/node/yarn and must stay in lockstep with
`.ruby-version`, `.node-version` and the `Dockerfile` ARGs (`RUBY_VERSION`, `NODE_VERSION`,
`YARN_VERSION`). Change all of them together.

Also pinned in `mise.toml` (spec `latest`, resolved versions recorded in `mise.lock`):
`hk`, `pkl`, `gitleaks`, `zizmor`, `actionlint`.

## Running the app

```sh
mise install          # provisions ruby, node, yarn and the dev-env tooling
bundle install
yarn install
bin/rails db:setup    # or bin/setup
bin/dev               # foreman -f Procfile.dev
```

`Procfile.dev` runs three processes:

- `web`: `env RUBY_DEBUG_OPEN=true bin/rails server` (port 3000, `bin/dev` exports `PORT` default 3000)
- `js`: `yarn build --watch` (esbuild → `app/assets/builds`)
- `css`: `yarn watch:css` (nodemon → `yarn build:css` = sass + postcss/autoprefixer)

Database: MySQL, adapter `mysql2`. `config/database.yml` development/test connect to
`localhost` as user `scav_hunt` with an **empty password**, databases
`scav_hunt_development` / `scav_hunt_test`. Run MySQL in a Docker container publishing
3306 on localhost. Note `docker-compose.yml` is the **production** stack (`rails` +
`database` = `mysql:8.3` + `redis` = `redis:7.4`) and its `database` service does *not*
publish 3306 to the host, so it is not a drop-in dev database; the production Rails
container maps host `2024` → container `3000` and reads `SCAV_HUNT_DATABASE_*`,
`RAILS_MASTER_KEY`, `REDIS_URL`, `ACTION_CABLE_*` from the environment.

## Testing

```sh
bin/rails test          # models, services, channels
bin/rails test:system   # Capybara + Playwright (Chromium)
```

System tests use `driven_by :playwright` (native in Rails 7.2) — the Capybara DSL is
unchanged, only the driver. The browser binary is a separate download from the npm package:
`npx playwright install chromium`. The `playwright` npm version in `package.json` is an
**exact** pin that must equal `Playwright::COMPATIBLE_PLAYWRIGHT_VERSION` from the
`playwright-ruby-client` gem; bump the two together or the driver refuses to start.

`test/application_system_test_case.rb` sets `Capybara.save_path = "tmp/screenshots"`. That is
load-bearing, not cosmetic: the driver's `download` handler does an unconditional
`FileUtils.mkdir_p(Capybara.save_path)`, and Rails leaves that setting nil, so leaving it out
hangs the whole run the moment a response carries `Content-Disposition` (the CSV export test).


Fixtures in `test/fixtures/*.yml` are loaded for every test (`test/test_helper.rb`, `fixtures :all`),
tests run parallelised with **processes**, and SimpleCov writes `coverage/index.html`.
Do not switch that back to `with: :threads`: Rails' threads executor sets `lock_threads =
false`, so every test thread shares one pinned unlocked connection and mysql2 aborts the
process — `bin/rails test` segfaults once the suite passes ~50 tests.
CI runs `bin/rails db:test:prepare test test:system` against a `mysql:8.4` service.

## Lint / pre-commit

```sh
hk install            # installs the git pre-commit hook
hk run check --all    # run every gate over the whole repo
hk run fix            # autofix what can be autofixed
```

Gates defined in `hk.pkl` (all three hooks — `pre-commit`, `fix`, `check` — run the same
`linters` mapping; most are glob-gated):

| Step | Command |
| --- | --- |
| `rubocop` | `bin/rubocop` / fix `bin/rubocop -A` |
| `test` | `bin/rails test` |
| `herb-analyze` | `bundle exec herb analyze app/` |
| `herb-lint` | `bundle exec herb lint app/` / fix `--fix` |
| `exec-bit-scripts` | shebang files must be mode 100755 in the git index |
| `debride` | `bundle exec debride --exclude vendor,node_modules,tmp,log .` |
| `flay` | `bundle exec flay app lib` (advisory) |
| `jscpd` | `bash scripts/run-jscpd.sh ruby,erb,javascript,typescript,css,scss,sass,vue` |
| `brakeman` | `bundle exec brakeman -q --no-pager --exit-on-warn` |
| `bundler-audit` | `bundle exec bundle-audit check` (best-effort `update` first) |
| `importmap-audit` | skipped — no `bin/importmap` (this app bundles with esbuild) |
| `fasterer` | `bundle exec fasterer \|\| true` (advisory) |
| `database_consistency` | `bundle exec database_consistency`, skipped when no DB is reachable |
| `actionlint` | `actionlint -shellcheck= {{ files }}` |
| `zizmor`, `gitleaks`, `check-added-large-files` | hk builtins |

`.github/workflows/ci.yml` mirrors these gates across the `lint`, `test`, `scan`,
`gitleaks`, `actions-lint` and `audit` jobs, so local and CI checks cannot drift. Keep them
in sync when changing either. CI triggers on push to `master` (the default branch) and on
every pull request.

## Known pre-existing issues

These gates are currently red for reasons that predate the tooling. Do not treat them as
regressions caused by a change you are making.

1. **`bundle exec database_consistency` — 20 findings.** The only genuinely red gate left.
   Missing `NOT NULL` on `challenges` number/description/points/group_id and `settings.value`,
   missing length validators, two redundant indexes, and a missing unique index on
   `challenges.number`. The `NOT NULL` ones are migrations against populated tables, so they
   need the nullable → backfill → constrain pattern rather than one migration.
2. ~~**`bin/rails test` — 26 runs, 4 errors.**~~ **Fixed.** Both suites are green: unit
   **58 runs, 0 failures, 0 errors**; system **53 runs, 0 failures, 0 errors**. The cause was
   `chart_start_time` never being seeded or fixtured, so `Setting.get` returned nil in
   `StatisticsService`, plus a cable test that authenticated via a cookie the connection
   never reads.
3. ~~**`bin/rubocop` — 201 offences.**~~ **Fixed** with `bin/rubocop -A`; now zero.
4. ~~**herb analyze/lint fail on a stray comma.**~~ **Fixed.** `herb analyze` is 53/53 clean
   and `herb lint` exits 0.
5. ~~**brakeman — 2 warnings.**~~ **Fixed.** The SQL-injection one was removed by construction
   (hash condition instead of interpolating the column name); the `:role` mass-assignment one
   is intentional and recorded with its reasoning in `config/brakeman.ignore`.
6. ~~**`bundle exec bundle-audit check` — many CVEs.**~~ **Cleared.** The dependency-upgrade
   pass took the tree to Rails 8.1.3.1 (via 8.0.5.1), puma 8.0.2, devise 5.0.4 and the
   transitive rack/nokogiri/rexml/addressable/bcrypt/websocket-driver fixes.
   `bundle exec bundler-audit check` now reports **No vulnerabilities found**. Keep it that way.
7. **`.herb.yml` carries an adoption baseline**: 11 herb rules with pre-existing offences are
   parked with `enabled: false`. That is a to-do list, not a policy — fix the offences (many
   are `herb lint app/ --fix`-able) and delete the entry to re-enable each rule.
8. **`.jscpd.json` sets `threshold: 1.1`** rather than the standard's `0`, because of two
   pre-existing clones: `app/assets/stylesheets/login.css` ~ `app/assets/stylesheets/scoreboard.css`,
   and two blocks of `test/system/home_test.rb`. Return the threshold to `0` once those are
   de-duplicated.

## Deliberate version holds

Two dependencies are pinned *below* their latest release on purpose. Each carries the reason
inline in the `Gemfile`; do not "helpfully" unpin them without dealing with the
cause.

| Held | At | Why |
| --- | --- | --- |
| `redis` (gem) | `~> 5.3` | Action Cable's Redis subscription adapter does `gem "redis", ">= 4", "< 6"` at require time, so redis 6 raises `Gem::LoadError` the moment production's `adapter: redis` loads. Still true on Rails 8.1. The test suite cannot catch it — `config/cable.yml` uses the test adapter. |
| `cssbundling-rails` | `= 1.4.1` | 1.4.2+ lists `yarn.lock` as a **bun** lock file and checks bun first, so on any machine with bun installed `css:build` silently switches to `bun run build:css` and drops an untracked `bun.lock`, despite yarn 1 being pinned in `mise.toml`, the `Dockerfile` and CI. |

## Supply-chain seasoning

`Gemfile` line 1 pins `source "https://rubygems.org", cooldown: 3` and `mise.toml` sets
`minimum_release_age = "3d"`. Both are deliberate: a newly published version must age three
days before it can be resolved. Do not remove them.

`BUNDLED WITH` is Bundler 4.0.23, which enforces `cooldown:` natively (Bundler before 4.0.13
ignored it). Earlier the cooldown over-filtered: it held Rails at 7.2.3 when 7.2.3.2 was
already nine days old. That is why the `Gemfile` spells
security floors out explicitly (`gem "rails", "~> 8.1.3", ">= 8.1.3.1"`) rather than trusting
the resolver to pick the newest allowed version.

## Secrets

`config/master.key` and `.env` (`/.env*` in `.gitignore`) are gitignored and must never be
committed. Production reads `RAILS_MASTER_KEY`, `DATABASE_PASSWORD`, `DATABASE_NAME` and
`HOST_URL` from the environment (see README.md).
