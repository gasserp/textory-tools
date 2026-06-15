# Textory Desktop

A native desktop wrapper around the [textory.dev](https://textory.dev) Svelte
app, built with [Tauri v2](https://v2.tauri.app/). It loads the same UI used
in the browser, but runs as a standalone window against the production API
(`https://textory.dev/api`) using token-based login instead of the browser's
GitHub/SWA cookie auth.

## Requirements

- Node 20+ (npm workspaces, used to build the Svelte frontend)
- [Rust toolchain](https://rustup.rs/) (stable) — required by Tauri
- Platform build tools for Tauri (on Windows: the Visual Studio Build Tools /
  WebView2; see the [Tauri prerequisites guide](https://v2.tauri.app/start/prerequisites/))

## Dev

From the `desktop/` directory:

```sh
npm install
npm run tauri dev
```

This runs `npm run dev -w app` (the normal Vite dev server) and opens it in a
Tauri window. To exercise the native/token login flow during dev, set
`VITE_NATIVE=1` and `VITE_API_BASE=https://textory.dev/api` when running the
app dev server (or point `VITE_API_BASE` at a local API instance).

You can also run everything via `npx`:

```sh
cd desktop
npx tauri dev
```

## Build (Windows installer)

```sh
cd desktop
npm run build
```

This runs `npm run build:native -w app` (which builds the Svelte app with
`VITE_NATIVE=1` and `VITE_API_BASE=https://textory.dev/api`) and then bundles
it into a Tauri app. On Windows this produces an `.msi` and an NSIS `.exe`
installer under `desktop/src-tauri/target/release/bundle/`.

## Login

The desktop app shows the same username/password login screen as the web
app's native mode (`app/src/components/Login.svelte`) — not browser cookie
auth. Sign in with your textory.dev username and password, or register a new
account from the same screen (new accounts are pending admin approval).

On submit, the app calls `/api/auth/login` (or `/api/auth/register`) to
obtain a `txs_...` session token, which is stored in `localStorage` and sent
on subsequent requests via the `x-textory-token` header.

If you don't have a password yet:

- **Register directly in the app** — the login screen has a "need an
  account? register" link, or
- **Set a password for an existing GitHub-based account** — sign in to
  textory.dev in a browser (GitHub SSO) and set a password from Settings,
  then use that username/password here.

## Security

The app's Content-Security-Policy only allows network requests to
`https://textory.dev` (`connect-src 'self' https://textory.dev`), in addition
to the usual `'self'` script/style/image restrictions.

## Release

Pushing a `desktop-v*` tag triggers
[`.github/workflows/desktop-release.yml`](../.github/workflows/desktop-release.yml),
which builds the Windows installer on `windows-latest` and attaches it to a
GitHub release for that tag.
