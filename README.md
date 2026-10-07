# Server — Rails API (PostgreSQL, Heroku)

Rails 8 API-only app exposing JSON CRUD for these tables:

| Table      | Columns                                                                 | Endpoint     |
|------------|-------------------------------------------------------------------------|--------------|
| `scripts`  | `name`, `content`, `language`, `owner_id`, `visibility`, `version`, `priority`, `compiled`, `shared`, `project_name`, timestamps | `/scripts` |
| `users`    | `name` (unique), `email` (unique, optional), timestamps                 | none yet     |
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
| `shared`     | `true` or `false` (default)                                         |
| `project_name` | the project the script belongs to, or null                        |
| `compiled`   | compiled code, JSON text. The crumb client calls it `compiled_code`: both names are accepted when saving, and records are returned with both |

`GET /scripts` takes `?name=`, `?language=`, `?owner_id=` and `?visibility=`
filters. The body's key is `script`: `{"script":{"name":"hello","language":"basic","content":"..."}}`.

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

`users` has no endpoint and no credentials yet. Until there is sign-in,
naming an owner who does not exist creates that user, and nothing checks
who is asking or an app's `visibility`: any client can still read and
change any record in any space.

`viewport` holds saved FastBlip screens: the JSON a program's Viewport writes
(`vp.save("name")` / `vp.load("name")`). `content` must be a JSON object with
`"format": "fastblip-viewport"`; it is sent and returned as an object, not a
string.

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
bin/rails server         # http://localhost:3000
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

Heroku sets `DATABASE_URL` and `SECRET_KEY_BASE` automatically. Optional config vars:
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
