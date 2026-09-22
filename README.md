# Server — Rails API (PostgreSQL, Heroku)

Rails 8 API-only app exposing JSON CRUD for two tables:

| Table           | Columns                                          | Endpoint          |
|-----------------|--------------------------------------------------|-------------------|
| `python_source` | `name:string`, `content:text`, timestamps        | `/python_sources` |
| `basic_source`  | `name:string`, `content:text`, timestamps        | `/basic_sources`  |

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
```

## Secrets

`.env` and `config.txt` are git-ignored — never commit them.
