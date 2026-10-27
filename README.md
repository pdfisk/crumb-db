# Server — Rails API (PostgreSQL, Heroku)

Rails 8 API-only app exposing JSON CRUD for these tables:

| Table      | Columns                                                                 | Endpoint     |
|------------|-------------------------------------------------------------------------|--------------|
| `scripts`  | `name`, `content`, `language`, `owner_id`, `visibility`, `version`, `priority`, `compiled`, timestamps | `/scripts` |
| `projects` | `name`, `description`, `owner_id`, `shared`, `scripts`, timestamps               | `/projects`  |
| `users`    | `name` (unique), `email` (unique, optional), `password_digest`, timestamps | `POST /users`, `/session` |
| `api_tokens` | `user_id`, `token_digest`, `expires_at`, `last_used_at`               | (sign-in tokens) |
| `viewport` | `name:string` (unique), `content:jsonb`, timestamps                     | `/viewports` |

`scripts` holds every program, whatever its language. The table was called
`apps`, its model `App` and its address `/apps` until they were renamed.
It replaces the `basic_source` and `python_source` tables, whose rows were
copied into it (those two tables are still in the database, unused, as a backup).

| Column       | Values                                                              |
|--------------|---------------------------------------------------------------------|
| `language`   | `basic` or `python`; required                                       |
| `owner_id`   | a `users` id, or null (every app copied from the old tables)        |
| `visibility` | `public` (default), `unlisted` or `private`                         |
| `version`    | starts at 1 and goes up by one each time `content` changes          |
| `priority`   | 1 to 5, default 3                                                   |
| `compiled`   | compiled code, JSON text. The crumb client calls it `compiled_code`: both names are accepted when saving, and records are returned with both |

`GET /scripts` takes `?name=`, `?language=`, `?owner_id=`, and
`?visibility=` filters. The body's key is `script`: `{"script":{"name":"hello","language":"basic","content":"..."}}`.

`/basic_sources` and `/python_sources` still answer: each is `/scripts`
limited to one language, with the body's key `basic_source` or
`python_source`. Records have new ids.

## Namespaces

Scripts, screens and composites belong to a user's space, and a name is unique
within it: two users can each have a `login`, one user cannot have two. A
record with no owner is in the **shared space**, where everything was before
there were users. (Shared scripts may still repeat a name, as the old tables
allowed; shared screens may not.)

Records are returned with `"owner"`: the user's name, or `null` when shared.

| Request | Does |
|---|---|
| `GET /scripts?owner=peter` | the scripts in peter's space (none if there is no such user) |
| `GET /scripts?owner=` | the scripts in the shared space |
| `GET /scripts` | every script |
| `POST /scripts` body `{"script":{"owner":"peter", ...}}` | creates it in peter's space |
| `PATCH /scripts/:id` body `{"script":{"owner":""}}` | moves it to the shared space |

`/viewports` takes `owner` the same way. User names match whatever their
case.

`POST /users` registers a user: body `{"user":{"name":"peter","password":"...","email":"..."}}`
(the e-mail is optional; the password is 8 to 72 characters). It answers 201 with `id`,
`name`, `email`, `created_at` and a sign-in `token`, or 422 with the errors, e.g. a name
already taken. `GET /users/:name` answers the registered user (`id`, `name`; the name
matches whatever its case) or 404, which is how a client checks whether a name is taken.
See **Sign-in and permissions** below.

`viewport` holds saved FastBlip screens: the JSON a program's Viewport writes
(`vp.save("name")` / `vp.load("name")`). `content` must be a JSON object with
`"format": "fastblip-viewport"`; it is sent and returned as an object, not a
string.

## Sign-in and permissions

`POST /session` body `{"session":{"name":"peter","password":"..."}}` answers 201 with
`{"token": "...", "user": {"id", "name", "admin"}}`, or 401 `wrong name or password` (the
same answer whether the name or the password is wrong). A client sends the token with every
request as `Authorization: Bearer <token>`. `GET /session` says who the token belongs to;
`DELETE /session` signs out (204). Tokens last 30 days; only a SHA-256 digest of each is
stored. A request with no `Authorization` header is anonymous; one with a token that is
unknown, expired or signed out gets 401 whatever it asks, so a client knows to sign in again.
Signing in and registering are limited to ten tries in three minutes from one address
(this counts in `Rails.cache`, so it is per server process).

| | Anonymous | Signed in | The owner |
|---|---|---|---|
| Read a **script** | public; unlisted by `?owner=&name=` or by id | the same | also private |
| Read a **project** | shared ones, and ones in the shared space | the same | also unshared |
| Read a **screen/composite** | all | all | all |
| Create | no (401) | in your own space; a body with no `owner` means you | |
| Change or delete | no (401) | no (403) | yes |

- A body's `"owner"` may only be your own name (case does not matter), or `""` for the shared
  space if you are an administrator; anything else is 403. An unknown name no longer creates
  that user. `owner_id` in a script body is ignored.
- Records you may not see are answered 404, as if they did not exist, including for PATCH and DELETE.
- The **shared space** (records with no owner) can be read by anyone but changed only by
  administrators: set the `ADMIN_USERS` config var to a comma-separated list of user names.
- Users from before sign-in have no password and cannot sign in until you set one:
  `bin/rails "users:set_password[peter]"` (it asks twice and signs them out everywhere);
  `bin/rails users:without_password` lists them.
- **Local server, no sign-in.** In development (`bin/rails server`), a request from this machine
  with no token (or a stale one) is treated as a local user who can read and change anything, so
  the IDE works against `?db=local` without signing in. A name used as `owner` gets a space on first use.
  It never applies in production or to requests from another address. Set `LOCAL_REQUIRE_LOGIN=1` in
  `.env` to test the real sign-in flow locally.

- Clients (the IDE's database client, sign-in window and `sync-db`) must now send the token to
  write anything. Until they do, writes get 401.

## Projects

A project is a named, ordered list of scripts, with a description. A name is
unique within a space. The list is the project's `scripts` column: a text column holding JSON (`"[]"` by default), a list
of `"<owner>/<name>"` strings in order (`"peter/snake"`; an empty owner,
`"/snake"`, is a script in the shared space). There are no foreign keys between
projects and scripts: a script can be in any number of projects, and deleting or
renaming one leaves its name in the lists that have it (clients report it as
missing). A project can list the owner's scripts and scripts in the shared
space. (Sharing is a property of the project, not of a script.)

A record is `{ id, name, description, owner, shared, scripts, created_at, updated_at }`,
where `shared` is `true` when the owner has shared the project and `false` (the default) if not, and `scripts` is `["peter/snake", ...]`, in
order.

| Request | Does |
|---|---|
| `GET /projects` | every project; `?name=` and `?owner=` filter, as for scripts |
| `GET /projects/:id` | one project |
| `POST /projects` body `{"project":{"name":"...","description":"...","owner":"peter","shared":false,"scripts":["peter/a","/b"]}}` | creates it |
| `PATCH /projects/:id` body `{"project":{"scripts":["peter/b","peter/a"]}}` | makes those its scripts, in that order, and no others |
| `DELETE /projects/:id` | deletes it (204); its scripts are kept |

Each `scripts` entry must be one of the project owner's scripts or one in the
shared space (the script need not exist yet).

## Synchronize the local and remote databases

`../sync/sync-db.mjs` (or `../sync/sync-db.ps1`) copies scripts and projects
between the local server and the remote one through their JSON APIs, so it
needs no database credentials. Run `bin/rails server` first.

```bash
node ../sync/sync-db.mjs --dry-run            # list what would change
node ../sync/sync-db.mjs                      # both ways, asking first
node ../sync/sync-db.mjs --direction push     # local -> remote only (pull: the reverse)
node ../sync/sync-db.mjs --prefer local       # local always wins a conflict (default: newer)
node ../sync/sync-db.mjs --only projects --owner peter --yes
```

Records are matched by owner and name. One that only one side has is copied
to the other; when both have it and they differ, the one updated last wins
(or `--prefer`). A project's scripts are matched by owner and name too.
Nothing is deleted, so a record deleted on one side returns at the next sync.
Test it with `node --test ../sync/sync-db.test.js`.

Health check: `GET /up`

## Run locally

Prereqs: Ruby 3.2+, Bundler, PostgreSQL running with the `admin` user.

```bash
cd server
bundle install
copy .env.example .env     # then set DATABASE_URL in .env
bin/rails db:create      # skip if cobol_studio already exists
bin/rails db:migrate
bin/rails db:seed        # optional sample rows
bin/rails "users:set_password[peter]"   # for users that existed before sign-in
bin/rails server         # http://localhost:3000
```

Tests (the test database is `TEST_DATABASE_URL`, default
`postgres://admin@localhost:5432/cobol_studio_test`; Rails creates and loads it from `db/schema.rb`):

```bash
RAILS_ENV=test bin/rails db:create
bin/rails test
```

To point your local app at the remote database, change `DATABASE_URL` in `.env` to the Heroku URL (`heroku config:get DATABASE_URL`).

## Deploy to Heroku

```bash
cd server
git init && git add . && git commit -m "Initial Rails API"

# Gemfile.lock must include Heroku's Linux platform (important if you're on Windows)
bundle lock --add-platform x86_64-linux
git commit -am "Add linux platform to Gemfile.lock"

heroku create                     # or: heroku git:remote -a <existing-app>
heroku addons:create heroku-postgresql:essential-0   # skip if the app already has Postgres
git push heroku main              # Procfile release phase runs db:migrate
```

Heroku sets `DATABASE_URL` and `SECRET_KEY_BASE` automatically. Set `ADMIN_USERS` (see
Sign-in and permissions) to the names allowed to change the shared space. Optional config vars:
`CORS_ORIGINS` (comma-separated, default `*`), `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `RAILS_LOG_LEVEL`.

Migrations use `if_not_exists`, so they're safe on a database where the tables already exist.

## API examples

```bash
curl http://localhost:3000/python_sources
curl http://localhost:3000/python_sources?name=hello.py
curl http://localhost:3000/python_sources/1
curl -X POST http://localhost:3000/basic_sources \
  -H "Content-Type: application/json" \
  -d '{"basic_source":{"name":"loop.bas","content":"10 FOR I=1 TO 10\n20 PRINT I\n30 NEXT I"}}'
curl -X PATCH http://localhost:3000/basic_sources/1 -H "Content-Type: application/json" \
  -d '{"basic_source":{"content":"10 PRINT \"HI\""}}'
curl -X DELETE http://localhost:3000/basic_sources/1
curl "http://localhost:3000/scripts?language=python"
curl -X POST http://localhost:3000/scripts -H "Content-Type: application/json" \
  -d '{"script":{"name":"hello","language":"basic","content":"Print \"Hello\""}}'
curl http://localhost:3000/viewports?name=main
curl -X POST http://localhost:3000/viewports -H "Content-Type: application/json" \
  -d '{"viewport":{"name":"main","content":{"format":"fastblip-viewport","version":1,"widgets":[],"windows":[]}}}'
```

## Secrets

`.env` and `config.txt` are git-ignored — never commit them.
