## React Native / Expo Code Standards

- **Expo SDK 57** (React Native 0.86, React 19.2) — run the app on a phone with Expo Go or in an emulator; no EAS build is needed to develop
- **Node.js 24 LTS** — the version CI uses
- **TypeScript strict mode** — `noImplicitReturns` and `noUncheckedIndexedAccess` are on, so an unchecked `items[0]` or a missing return path fails `npm run typecheck`. No `any`.
- **Biome** for linting and formatting — `npx biome ci --error-on-warnings .` must be clean before pushing
- **Biome warnings fail CI** — Biome 2 reports several recommended rules (for example `useConst`, `noNonNullAssertion`, unused variables and imports) as warnings, so CI runs `biome ci --error-on-warnings`. `noExplicitAny` is set to error in `biome.json`, so `any` fails even without the flag.
- **Global types are listed** — TypeScript 6 no longer loads every installed `@types` package, so `tsconfig.json` lists them in `types` (`jest` by default). Add any you install.
- **jest-expo** preset for unit and component tests, with **React Native Testing Library** (`@testing-library/react-native`) for components — minimum 80% line coverage enforced in CI. Its `render` is async: `await render(<App />)`.
- **Versions come from the SDK.** `expo`, `react`, `react-native`, `jest`, `jest-expo`, `@types/react`, `@types/jest` and `typescript` must be the versions Expo SDK 57 expects. Add Expo and React Native libraries with `npx expo install <package>`, which picks the version that matches the SDK, then pin it exactly in `package.json`. `npx expo install --check` lists any that do not match (it asks Expo's servers, so it needs network access).
- **StyleSheet** for styles — `StyleSheet.create`, no inline style objects. No tool checks this; it is for review.
- **No hardcoded values** — environment-specific config via `.env` (gitignored), read in app code as `process.env.EXPO_PUBLIC_*`. Anything with that prefix is built into the app bundle and readable by anyone who has the app, so never put a secret there.
- **Platform guards** — use `Platform.OS` or `.ios.tsx` / `.android.tsx` file extensions for platform-specific behaviour
- **Error handling** — always type-narrow errors; never `catch (e: any)`
- **Imports** — relative imports within the project; no barrel files unless justified

### Project layout

Root files come straight from the pack (`package.json`, `tsconfig.json`, `biome.json`, `app.json`). The pack's `starter/` folder mirrors the project: copy `starter/src/` to `src/`.

- `src/index.ts` is the entry point (`"main"` in `package.json`). It only registers the root component, so it is excluded from the coverage gate. Keep logic out of it.
- `src/App.tsx` is the starter root component, with its tests in `src/App.test.tsx`. They keep CI green on day one; replace them with your own app.
- Tests sit next to the code they test, named `*.test.ts` or `*.test.tsx`. Everything else under `src/` counts towards the coverage gate.
- Keep calculations and other logic in plain modules that do not render anything, so they are tested without a component.

The starter has no navigation library. If the app needs more than one screen, add one (for example `npx expo install expo-router`, then follow its setup) in its own change.

`app.json` holds placeholders only: set `name` and `slug` before the first `npx expo start`. Icons and a splash screen are not included; add them to `app.json` together with the image files when the app has them.

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

# Start the dev server (scan the QR code with Expo Go on the phone)
npx expo start

# Unit and component tests with coverage
npx jest --coverage

# Type check
npm run typecheck

# Lint and format check
npx biome ci --error-on-warnings .

# Format (auto-fix)
npx biome format --write .

# Everything CI runs, in order
npm run ci
```

### What CI does not check

CI runs the lint and format check, the type check, and the unit and component tests with the coverage gate, all in Node on a Linux runner. It does not:

- build the app for Android or iOS, or run it on a device, emulator or simulator. Those builds need Android or Xcode tooling (Xcode only runs on macOS), and EAS builds need an Expo account. Try the app on a device with Expo Go before merging a change the tests cannot see, such as layout.
- bundle the JavaScript with Metro. `npx expo export --platform android` does this locally without a device and catches imports that only fail at bundle time.
- check that dependency versions match the SDK (`npx expo install --check`) or run `npx expo-doctor`, because both need Expo's servers. Run them locally after adding a dependency. `expo-doctor` reports the `[project-slug]` placeholder in `app.json` as invalid until you set a real slug.
- check the StyleSheet rule above.

### Pre-commit equivalent

React Native projects use Biome's CI command in the CI pipeline rather than pre-commit hooks. Optionally add `lint-staged` + `husky` for local pre-commit enforcement — not included by default.
