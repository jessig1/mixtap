## Vinylhound — Copilot / AI agent instructions

This file gives focused, actionable knowledge for an AI coding assistant to be immediately productive in this monorepo.

- Project layout (high level):
  - `Vinylhound-Backend/` — Go microservices and shared libraries.
    - Services live in `Vinylhound-Backend/services/<service-name>/` and each contains `cmd/main.go`, `go.mod` and a `Dockerfile`.
    - Shared Go packages live in `Vinylhound-Backend/shared/go/` (auth, database, models, middleware).
  - `Vinylhound-Infrastructure/` — docker-compose, DB schema and infra artifacts (see `docker-compose.yml` and `db/schema.sql`).
  - `vinylhound-frontend/` — Svelte app (npm scripts, `package.json`, `vite.config.js`).

- Quick dev commands (use these, they are the canonical workflows):
  - Start infra: `docker-compose -f Vinylhound-Infrastructure/docker-compose.yml up -d`
  - Run migrations: `make migrate-up` (invokes `Vinylhound-Backend/shared/go/database/migrate.go`).
  - Start services (dev): `make dev` or `make dev-services` which runs `go run` per service and `npm run dev` for the frontend.
  - Build all: `make build` (builds Go binaries and runs frontend build).
  - Run tests: `make test` (runs `go test ./...` per service and `npm test`).

- Service conventions and patterns to follow (concrete examples):
  - Each service uses a `cmd/main.go` entry that wires dependencies (e.g. `Vinylhound-Backend/services/user-service/cmd/main.go`).
  - Business logic lives under `internal/service` and repositories under `internal/repository`. Example: `user-service/internal/service/user_service.go` uses `repository.UserRepository` and `shared/auth`.
  - Shared utilities: prefer `Vinylhound-Backend/shared/go/*` for cross-service code (auth, database, models). Import paths typically reference the monorepo package names.
  - Config & secrets: quick-start uses `config/local.env` and `SETUP.md` environment variables; do not hard-code secrets (see TODO in `user_service.go` where `auth.NewTokenManager("your-secret-key")` should load from config).

- APIs & ports (useful anchors for tests/examples):
  - User service: `http://localhost:8001` — routes under `/api/v1/auth/*` and `/api/v1/users/*` (see `SETUP.md` and `README.md`).
  - Catalog: `http://localhost:8002`; Rating: `http://localhost:8003`; Frontend: `http://localhost:3000`; Gateway: `http://localhost:8080`.

- Patterns for PRs and edits the agent should respect:
  - Small, focused changes per service. Update only the service and shared packages touched.
  - When adding a new service: add a directory under `Vinylhound-Backend/services/`, add `go.mod`, `cmd/main.go`, a `Dockerfile`, and update `Vinylhound-Infrastructure/docker-compose.yml` and the root `Makefile` targets if needed.
  - When modifying DB schema, add migration SQL files under `Vinylhound-Backend/migrations/` and ensure `make migrate-up` covers them.

- Testing, linting and formatting
  - `make test` runs unit tests per service. Unit tests live next to packages (e.g. `store/albums_test.go`).
  - Lint: `make lint` (calls `golangci-lint` for Go services and `npm run lint` for frontend).
  - Format: `make format` (runs `go fmt` and frontend format scripts).

- Integration points & gotchas
  - Services depend on the shared DB schema in `Vinylhound-Infrastructure/db/schema.sql` and the migrations in `Vinylhound-Backend/migrations/`.
  - Many modules use local module paths; run `go mod tidy` inside a service if imports are changed.
  - Database ports / credentials are often set in `config/local.env` or environment variables referenced in `SETUP.md` — prefer reading those instead of assuming defaults.

- When uncertain, prefer these actions (in priority order):
  1. Read `Makefile`, `SETUP.md` and `Vinylhound-Infrastructure/docker-compose.yml` for canonical commands.
 2. Inspect `Vinylhound-Backend/services/<service>/cmd/main.go` to see how dependencies are wired.
 3. Check `Vinylhound-Backend/shared/go/` for types and utility functions (auth, db connectors).

If anything in this summary is unclear or you'd like more examples (sample requests, test snippets, or a checklist for adding a new service), tell me which section to expand and I will iterate.
