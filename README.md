# Bedlam Theatre Scavenger Hunt

Welcome to the Bedlam Theatre Scavenger Hunt scoring website. Teams complete numbered
challenges, scorers award regular and bonus points, and the scoreboard, scoring screen and
statistics charts update live over ActionCable.

Code by [Mick Zijdel](https://github.com/mickzijdel), styling and specification by [Lewis Eggeling](https://github.com/BasalShark/ )

**IMPORTANT NOTE**: The Rails server is accessible within _the Docker container or in development*_ on port `3000`. However, the server is accessible within _the Docker Host/outside of the Docker container_ on port `2024` by default. Set `APP_PORT` in `.env` to publish it somewhere else — which is what lets you run more than one instance on the same Docker host (see [Running several instances on one host](#running-several-instances-on-one-host)).

## Contents

- [Built with](#built-with)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Linting](#linting)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## Built with

Versions below are the ones actually resolved in `Gemfile.lock` / `yarn.lock`.

**Backend**

| | Version |
| --- | --- |
| Ruby | 3.3.3 |
| Rails | 8.1.3.1 |
| mysql2 (MySQL adapter) | 0.5.7 |
| Devise (authentication) | 5.0.4 |
| CanCanCan (authorisation) | 3.6.1 |
| Simple Form | 5.4.1 |
| Propshaft (asset pipeline) | 1.3.2 |
| Puma | 8.0.2 |
| redis (ActionCable backend in production) | 5.4.1 |
| turbo-rails / stimulus-rails | 2.0.23 / 1.3.4 |

**Frontend**

| | Version |
| --- | --- |
| Node | 22.4.1 |
| Yarn | 1.22.19 |
| esbuild | 0.28.1 |
| sass | 1.99.0 |
| Bootstrap (+ bootstrap-icons) | 5.3.8 (1.13.1) |
| @hotwired/turbo-rails | 8.0.23 |
| @hotwired/stimulus | 3.2.2 |
| @rails/actioncable | 8.1.301 |
| billboard.js / d3 (statistics charts) | 4.0.3 / 7.9.0 |

The Ruby, Node and Yarn versions live in `mise.toml`, which is the single source of truth —
`.ruby-version`, `.node-version` and the `Dockerfile` ARGs must match it.

## Installation

The toolchain is provisioned by [mise](https://mise.jdx.dev), so you do not need to install
Ruby, Node or Yarn by hand — only [Docker](https://docs.docker.com/get-docker/) (for MySQL)
and mise itself.

1. Create a MySQL database user with the username `scav_hunt` and an empty password who has
   access to all schemas matching the pattern `scav\_hunt\_%`, or just all schemas using `%`.
   You can set the access restriction to `localhost` for extra security. The easiest way is a
   local MySQL 8 container publishing port `3306` on `localhost`.
2. Clone this repository and change into it.
3. Copy the `master.key` file into `config/`. Ask someone who already has it for a copy. It is
   gitignored and must never be committed — the same goes for `.env`.
4. Install the toolchain and the dependencies, then create the database:

```bash
mise install       # ruby 3.3.3, node 22.4.1, yarn 1.22.19 + the lint tooling
bundle install
yarn install
bin/rails db:setup
```

5. Install the git pre-commit hook so the linters run before every commit:

```bash
hk install
```

## Usage

Start the app (Rails server, the esbuild JS watcher and the sass/postcss CSS watcher, all via
`Procfile.dev`):

```bash
./bin/dev
```

The site is then at <http://localhost:3000>. If your changes are not picked up automatically,
rebuild the assets by hand:

```bash
yarn build
yarn build:css
```

## Testing

```bash
bin/rails test         # models, services, channels
bin/rails test:system  # Capybara + Playwright system tests (needs Chromium, see below)
```

System tests drive Chromium through Playwright. `yarn install` brings in the `playwright` npm
package, but the browser binary is a separate download — do it once per machine:

```bash
npx playwright install chromium
```

The `playwright` npm version is pinned exactly to the version
`playwright-ruby-client` reports as `COMPATIBLE_PLAYWRIGHT_VERSION`; the two are a matched
pair, not a range. After bumping either, re-check them:

```bash
bundle exec ruby -e 'require "playwright"; puts Playwright::COMPATIBLE_PLAYWRIGHT_VERSION'
```

`bin/rails test -h` lists the options, for example how to run a single test file. Test
coverage is written to `coverage/index.html` — open it in a browser.

A handful of tests and lint gates are currently failing for reasons that predate the current
tooling; see the "Known pre-existing issues" section of [`CLAUDE.md`](CLAUDE.md) before you go
hunting for a regression you did not cause.

## Linting

The linters are orchestrated by [hk](https://hk.jdx.dev), configured in [`hk.pkl`](hk.pkl):

```bash
hk run check --all   # run every gate over the whole repo
hk run fix           # autofix what can be autofixed
```

The gates are RuboCop, `bin/rails test`, herb (ERB parsing + linting), debride, flay, jscpd,
Brakeman, bundler-audit, fasterer, database_consistency, actionlint, zizmor, gitleaks and a
large-file check. [`.github/workflows/ci.yml`](.github/workflows/ci.yml) mirrors them, so the
local hook and CI cannot drift. CI runs on pushes to `master` and on every pull request.

## Deployment

See the [Bedlam Theatre Wiki](https://wiki.bedlamtheatre.co.uk) for EUTC-specific deployment things.

**I would strongly advise first deploying it to Docker locally before deploying**. You will not be able to access the locally-deployed website once it is up because of SSL certificates, but at least you can check for issues in the deploy process.

### Deploying
The deploy steps (first-time only) are:  
1) Clone this repository.
2) Navigate into the repository.
3) Add a `.env` file with the contents below.
4) Run `sudo docker compose -f docker-compose.yml up -d`  
    a) This will create new containers and start them detached so it will still run when you log out.
5) Setup your Nginx configuration file using the options below.  
    a) If you're not using Nginx (or an alternative) as a reverse proxy, everything should just work if you connect to port `2024` (set `APP_PORT` in `.env` to publish it elsewhere, for example the default http port `80` or https port `443`). This is untested though. Feel free to let Mick know and he might be able to help, but it's probably easiest if you just run Nginx as a reverse proxy.
7) That's it! You can check if the containers are running using `sudo docker ps`

Note: the Dockerfile already carries `RUN bundle config set frozen false` before the `bundle install` step, which works around the minor lockfile inconsistencies you can get when developing on Windows and deploying on Linux. It is not best practice — your deployed packages might not exactly match development — so remove it once the lockfile is reliably in sync.

### Upgrading
To upgrade:
1) Navigate into the repository
2) Pull the updates from the repo from source using `git pull`
3) Run `sudo docker compose down` to stop the current stack/containers.  
4) Run `sudo docker compose -f docker-compose.yml up -d`  
    a) You might need to add the `--build rails` or `--force-recreate` options when upgrading.

If you run into any issues here, please check the deploy instructions above.

### Environment Variables
Ensure that the environment variables are specified in Portainer or in an `.env` file as follows:
```
RAILS_MASTER_KEY=<the master key>
DATABASE_NAME=scav_hunt_production
DATABASE_PASSWORD=<Anything you want>
HOST_URL=<host website, like scavhunt.bedlamtheatre.co.uk. Do not include the scheme. You only need to include the port if you need to specify it when connecting to the website in the browser>
APP_PORT=<optional; host port to publish the app on. Defaults to 2024>
```

`.env` is gitignored, and so is `config/master.key`. Neither may ever be committed.

### Running several instances on one host

Two things used to make a second instance on the same Docker host impossible: the app
published a hardcoded `2024`, and Redis published `6379`. Redis is no longer published at
all — only the `rails` service talks to it, over the compose network — and the app's host
port now comes from `APP_PORT`.

Give each instance its own directory, its own `.env` with a distinct `APP_PORT`, and its
own Compose project name. The project name is what keeps the containers, network and
volumes apart; without it the second instance would reuse the first one's database volume.

```sh
# first instance
cd /srv/scav-hunt-2026
echo "APP_PORT=2024" >> .env
COMPOSE_PROJECT_NAME=scav-hunt-2026 docker compose up -d

# second instance, same host
cd /srv/scav-hunt-test
echo "APP_PORT=2025" >> .env
COMPOSE_PROJECT_NAME=scav-hunt-test docker compose up -d
```

Compose derives the project name from the directory name if you don't set it, so two
differently-named directories already get separate volumes — setting it explicitly just
makes that guarantee visible rather than incidental. Point a separate Nginx server block
at each `APP_PORT`, and give each instance its own `HOST_URL` so ActionCable's allowed
origins match the hostname it is actually served on.

### Websockets / ActionCable setup
In production, this website uses Redis as an [ActionCable](https://guides.rubyonrails.org/action_cable_overview.html) backend. The main consequences are
1) The `action_cable.allowed_request_origins` config needs to be set in `production.rb`, which is done based on the `HOST_URL` env variable.
2) You need to add a location to your Nginx config file within the server for the scav-hunt website. See the sample Nginx config below.

`HOST_URL` is a bare `host[:port]`, so `docker-compose.yml` is what wraps it into the two
shapes ActionCable actually wants, and both of them need a scheme:

| Variable | Built as | Why the scheme matters |
| --- | --- | --- |
| `ACTION_CABLE_FRONTEND_URL` | `wss://${HOST_URL}/cable` | It is emitted verbatim into `<meta name="action-cable-url">`. A scheme-less value is a *relative* URL, so the browser resolves it against the page it is on and dials `/scoring/<hostname>` instead — no live updates, and a routing error per reconnect in the logs. |
| `ACTION_CABLE_ALLOWED_REQUEST_ORIGINS` | `https://${HOST_URL}` | Compared against the browser's `Origin` header, which always carries a scheme. |

Both are asserted by `test/deployment/action_cable_env_test.rb`, because nothing else in
the suite can catch them: `config/cable.yml` uses the test adapter, so a broken endpoint
only ever shows up in production.

### Nginx Config
Add this server to your Nginx config file. You might need to change the domain and SSL certificate locations.

```
# New server block for scavhunt.bedlamtheatre.co.uk
server { listen 443 ssl; server_name scavhunt.bedlamtheatre.co.uk;
    ssl_certificate /opt/nginx/certs/bedlamtheatre.co.uk.pem;
    ssl_certificate_key /opt/nginx/certs/bedlamtheatre.co.uk.key;

    location / {
        proxy_pass http://127.0.0.1:2024;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Need to explicitly define the /cable location (the upgrade part is the essential part) for websockets to work.
    location /cable {
        proxy_pass http://127.0.0.1:2024;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}

```

### Useful Docker commands
- `docker ps`, for a list of all containers and their IDs 
- `docker logs <container_id> --tail 100`, to view the logs
- `docker exec <container_id> <command>`, to run an arbitrary command within the container
- `docker exec -it <container_id> /bin/bash`, to run an interactive shell in a container (keep in mind Docker containers are very slim and don't even have nano)

## Contributing

Run `hk install` once so the pre-commit hook is active, then work on a branch and open a pull
request against `master`. `hk run check --all` must be green before you push — CI runs the same
gates. Agent-facing notes on the codebase, the pinned versions and the known-failing gates live
in [`CLAUDE.md`](CLAUDE.md).

The Gemfile pins a 4-day RubyGems `cooldown:` and `mise.toml` a 4-day `minimum_release_age`.
Both are deliberate supply-chain seasoning — please leave them in place.

## License

No licence file is present in this repository. Ask [Mick Zijdel](https://github.com/mickzijdel)
or the [Edinburgh University Theatre Company](https://github.com/EdinburghUniversityTheatreCompany)
before reusing the code.
