# textory-tools

A fast, console-style snippet manager. Live at **https://textory.dev**.

```
textory ▌
> classify snippet
```

## Backend

The API (`/api/*`), database, and infrastructure that power textory are closed-source and maintained in a private repository. This repo contains only the client applications:

- **Web SPA** (`app/`) — Svelte frontend
- **CLI** (`cli/`) — Go command-line tool
- **Desktop** (`desktop/`) — Tauri-based Windows app
- **Apple** (`apple/`) — SwiftUI app for iOS and macOS

All client applications call the production API at `https://textory.dev/api`.

## Features

- GitHub SSO (Azure Static Web Apps auth) — admin-approved beta signups
- Username/password login with `txs_...` session tokens — for native/desktop
  clients that can't use SWA's GitHub SSO cookies
- Snippets CRUD with Markdown content, rich/plain copy
- LLM classify/tag/summary using **your own Anthropic API key** (claude-haiku-4-5)
- Camera/image capture → OCR → snippet (Claude vision, using your own
  Anthropic key)
- Fuzzy search (`fuse.js`) with `#tag` and `@category` filters
- Command palette (`ctrl+k`) and full keyboard navigation
- Four themes: dark, light, dark-hc, light-hc (high contrast)
- Per-user storage quota, admin-adjustable
- Terms of Use & Acceptable Use Policy acceptance at signup
- Native iOS/macOS app and Windows desktop app — see [Apps](#apps) below

## CLI

A tiny `txt` CLI for quickly adding snippets from macOS and Windows terminals. Generate a token in Settings, run `txt login`, then pipe text with `txt your text`, `echo x | txt`, or `txt -i` for interactive multiline (end with Ctrl-D on macOS or Ctrl-Z+Enter on Windows). Binaries are available from [GitHub releases](https://github.com/gasserp/textory-tools/releases) (tagged `cli-v*`) or build locally with `go build` in `cli/`. See [cli/README.md](cli/README.md) for full details.

## Apps

Native apps for iOS/macOS and Windows, for when a browser tab isn't handy.
Both authenticate with a username/password (set one in Settings on the web,
or register directly in the app) and talk to the production API using
`txs_...` session tokens — no GitHub SSO cookies required.

- **iOS / macOS**: a SwiftUI app (iOS 17+ / macOS 14+) for browsing, adding,
  and deleting snippets, plus camera capture (iOS) / image import (macOS) →
  OCR → snippet. Build from source with Xcode — see
  [apple/README.md](apple/README.md).
- **Windows desktop**: a Tauri-based wrapper around the same Svelte app used
  on the web, running as a standalone window against `https://textory.dev`.
  Installers (`.msi` / NSIS `.exe`) are published to
  [GitHub releases](https://github.com/gasserp/textory-tools/releases) (tagged
  `desktop-v*`) — see [desktop/README.md](desktop/README.md).

## Keyboard cheatsheet

| Key | Action |
|---|---|
| `ctrl+k` | open command palette |
| `?` | open help (this cheatsheet) |
| `esc` | close overlay / cancel confirm / clear search |
| `/` | focus search |
| `#tag` | (in search) filter to snippets with tag |
| `@category` | (in search) filter to snippets in category |
| `j` / `↓` | move selection down |
| `k` / `↑` | move selection up |
| `enter` | open selected snippet (list) / run command (palette) |
| `n` | new snippet |
| `e` | edit selected/open snippet |
| `c` | copy plain text |
| `shift+c` | copy rich (formatted) |
| `space` | toggle multi-select (for bulk delete) |
| `d` | delete selected (or multi-selected) snippet |
| `y` / `n` | confirm / cancel delete |
| `ctrl+s` | save (editor) |
| paste (in list view) | create a new snippet from clipboard content |

Commands available via the palette include theme switching (dark / light /
dark-hc / light-hc), new snippet, search, settings, classify snippet, sign
out, help, and (for admins) the admin panel.

## Local development

### Web SPA and desktop app

```bash
npm install        # at repo root (workspaces: app, desktop)
npm run dev -w app # Svelte dev server
```

For full-stack local development with the backend API, see the private `gasserp/textory` repository. Most contributors will instead build and run the client applications in "native mode" against the production API:

```bash
VITE_NATIVE=1 VITE_API_BASE=https://textory.dev/api npm run dev -w app
```

This is the same approach used by the desktop and Apple apps.

Type-checking and production builds:

```bash
npm run check -w app   # type-check
npm run build -w app   # production build
```

### CLI

Build the Go CLI locally:

```bash
cd cli
go build
```

See [cli/README.md](cli/README.md) for full details.

### Apple app

Build with Xcode — see [apple/README.md](apple/README.md).

### Desktop app

See [desktop/README.md](desktop/README.md).

## Security & cost

- **LLM calls use each user's own Anthropic API key**: every user enters
  their own key, stored encrypted at rest (AES-256-GCM) and billed to
  their own Anthropic account — the app operator never pays for or sees
  any user's classification costs.
- **Security headers** (`app/public/staticwebapp.config.json`): a strict
  Content-Security-Policy (`default-src 'self'`, no inline scripts),
  `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`,
  `X-Frame-Options: DENY`, and a minimal `Permissions-Policy`.

## Bundle size

Production build of `app` (gzip):

| Asset | Size (gzip) |
|---|---|
| `index-*.js` | ~115 KB |
| `index-*.css` | ~2.7 KB |
| **Total** | **~118 KB** |

Well under the ~150 KB target. `highlight.js/lib/common` (the slim build with
only common languages) is used for syntax highlighting — nothing imports the
full `highlight.js`.

## Beta limitations

- Snippets are private to your account — there is no cross-user sharing yet.
- New accounts require admin approval (`pending` → `approved`/`rejected`).
- Single Anthropic key per user; no support for other LLM providers.

## Roadmap

- Cross-user / team sharing of snippets
- Paid plans (higher quota, shared workspaces)

## License

MIT — see LICENSE.
