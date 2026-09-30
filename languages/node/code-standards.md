## Node/TypeScript Code Standards

- **Node.js 22 LTS** — use modern ES2022+ features
- **TypeScript strict mode** — no `any`, no implicit returns, no unchecked array access
- **Biome** for linting and formatting — `npx biome ci .` must be clean before pushing
- **Jest + ts-jest** for testing — minimum 80% line coverage enforced in CI
- **No hardcoded values** — everything configurable via environment variables or config files
- **Error handling** — always type-narrow errors; never `catch (e: any)`
- **Imports** — relative imports within the project; no barrel files unless justified

### First-time setup

CI installs with `npm ci`, which fails unless a `package-lock.json` is committed. On a new project, run this once and commit the lockfile:

```bash
npm install
git add package-lock.json
```

### Running the project

```bash
# Install dependencies
npm ci

# Run tests
npx jest --coverage

# Lint and format check
npx biome ci .

# Format (auto-fix)
npx biome format --write .

# Build
npx tsc
```

### Pre-commit equivalent

Node projects use Biome's CI command in the CI pipeline rather than pre-commit hooks. Optionally add `lint-staged` + `husky` for local pre-commit enforcement — not included by default.
