## Web App Code Standards (static, single-file)

Everything in the Node/TypeScript standards applies, plus the web rules below.

- **Node.js 22 LTS** — use modern ES2022+ features
- **TypeScript strict mode** — `noImplicitReturns` and `noUncheckedIndexedAccess` are on, so an unchecked `items[0]` or a missing return path fails `npm run typecheck`. No `any`.
- **Biome** for linting and formatting — `npx biome ci .` must be clean before pushing
- **Jest + ts-jest** for unit tests — minimum 80% line coverage enforced in CI
- **Playwright** for browser tests — they run against the built file, not the dev server
- **No hardcoded values** — everything configurable via constants or config files
- **Error handling** — always type-narrow errors; never `catch (e: any)`
- **Imports** — relative imports within the project; no barrel files unless justified

### Web rules

- **One self-contained file.** `npm run build` produces `dist/index.html` with all script and style inlined. No CDN scripts, web fonts, images or other external requests. The browser test fails if the page requests anything besides its own document.
- **Logic in pure modules, wiring in `src/main.ts`.** Calculations and other logic live in `src/*.ts` modules that do not touch the DOM; test them with Jest. `src/main.ts` only wires that logic to the page. It is excluded from the coverage gate and is covered by the Playwright tests.
- **Phone first.** Design for 375px width first. The page must not scroll sideways at 375px or at 1280px.
- **Light and dark.** Support `prefers-color-scheme`. Every browser test runs in both.
- **Clean console.** Any console error or uncaught error fails the browser tests.
- **Inline favicon.** `index.html` declares `<link rel="icon" href="data:," />` so real browsers do not request `/favicon.ico`, which the site has no file for and would answer with a 404. The browser tests cannot catch a missing line: headless Chromium does not request a favicon, so keep it in place by convention.
- **File names.** Unit tests are `src/*.test.ts`. Browser tests are `e2e/*.e2e.ts`. Jest ignores `e2e/`, Playwright only runs `*.e2e.ts`.

### Project layout

Root files come straight from the pack (`package.json`, `tsconfig.json`, `biome.json`, `vite.config.mts`, `playwright.config.ts`, `index.html`). The pack's `starter/` folder mirrors the project: copy `starter/src/` to `src/` and `starter/e2e/` to `e2e/`. The starter example (`src/example.ts` and its test) keeps CI green on day one; replace it with real code.

### First-time setup

CI installs with `npm ci`, which fails unless a `package-lock.json` is committed. On a new project, run this once and commit the lockfile:

```bash
npm install
npx playwright install chromium
git add package-lock.json
```

### Running the project

```bash
# Install dependencies
npm ci

# Develop with live reload
npm run dev

# Unit tests with coverage
npx jest --coverage

# Type check
npm run typecheck

# Lint and format check
npx biome ci .

# Format (auto-fix)
npx biome format --write .

# Build the single file (dist/index.html)
npm run build

# Build, then run the browser tests (phone and desktop, light and dark)
npm run test:e2e

# Everything CI runs, in order
npm run ci
```

### Deploying (GitHub Pages)

`deploy.yml` (copy to `.github/workflows/deploy.yml`) builds on every push to `main` and publishes `dist/` to GitHub Pages. It is optional: skip it if the page is served some other way. It does not re-run the tests, because `main` is protected and only takes merges with CI green.

One-off setup, done by the repo owner in GitHub (not something an agent can do):

1. Repository Settings, Pages, Source: **GitHub Actions**.
2. Pages, Custom domain: enter the address, for example `sonar.example.se`.
3. At the DNS provider, add a `CNAME` record from that name to `<github-user>.github.io`.
4. Once GitHub has issued the certificate, tick **Enforce HTTPS**.

### Pre-commit equivalent

Web projects use Biome's CI command in the CI pipeline rather than pre-commit hooks. Optionally add `lint-staged` + `husky` for local pre-commit enforcement — not included by default.
