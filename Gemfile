source "https://rubygems.org", cooldown: 3

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
# >= 8.1.3.1 is a security floor: it is the release that fixes the Active
# Storage variant-processing RCE. Declaring it explicitly also stops the 3-day
# `cooldown:` above from resolving back to an older, vulnerable 8.1.x.
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use mysql as the database for Active Record
gem "mysql2", "~> 0.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
# Held at 1.4.1 on purpose. 1.4.2+ adds yarn.lock to the *bun* lock-file list,
# so on any machine that has bun on PATH `css:install` / `css:build` silently
# switch from yarn to `bun install` / `bun run build:css` and drop a stray
# bun.lock in the repo - even though mise.toml, the Dockerfile and CI all pin
# yarn 1. Unpin once the toolchain is deliberately moved to bun.
gem "cssbundling-rails", "= 1.4.1"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "devise", "~> 5.0", ">= 5.0.4"
gem "cancancan"

gem "simple_form"
gem "csv"
gem "activerecord-import"

# Held at 5.x on purpose. Action Cable's Redis subscription adapter - the
# production `adapter: redis` in config/cable.yml, which every live scoreboard
# and scoring broadcast goes through - does `gem "redis", ">= 4", "< 6"` at
# require time (actioncable/lib/action_cable/subscription_adapter/redis.rb).
# redis 6 therefore raises Gem::LoadError the moment that adapter loads, and
# nothing in the test suite catches it because config/cable.yml uses the test
# adapter in test. Revisit when Rails relaxes the bound.
gem "redis", "~> 5.3"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "better_errors"
  gem "factory_bot_rails"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  # Minitest-specific cops. Omakase already bundles (and deliberately disables)
  # rubocop-rails + rubocop-performance, so those are not re-declared here.
  gem "rubocop-minitest", require: false
  # House cops that omakase cannot express, e.g. Mick/ParamsMutation.
  gem "rubocop-mick", github: "mickzijdel/rubocop-mick", require: false

  # --- dev-env standard audit tooling (dev-hooks:dev-env-setup) ---------------
  # All are glob-gated in hk.pkl and mirrored by .github/workflows/ci.yml.
  gem "herb", require: false                   # HTML-aware ERB parser + linter
  gem "bundler-audit", require: false          # gem CVE / insecure-source scan
  gem "debride", require: false                # dead-method detection
  gem "flay", require: false                   # Ruby structural duplication (advisory)
  gem "fasterer", require: false               # performance anti-patterns (advisory)
  gem "database_consistency", require: false   # models vs. schema consistency
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # View test coverage
  gem "simplecov", require: false
  gem "simplecov-rcov", require: false

  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara", require: false
  # Playwright rather than Selenium as the Capybara driver: Playwright's per-action
  # actionability checks (visible / stable / enabled / hit-testable, retried until the
  # timeout) eliminate the silent no-op click that made the suite flaky under Selenium.
  # Rails 7.2 knows `driven_by :playwright` natively — see test/application_system_test_case.rb.
  # Needs the matching `playwright` npm package; the version pairing is pinned in
  # package.json and must be kept in lockstep with Playwright::COMPATIBLE_PLAYWRIGHT_VERSION.
  gem "capybara-playwright-driver", require: false
end
