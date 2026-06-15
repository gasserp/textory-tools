# Textory (Apple)

A native SwiftUI app for [textory.dev](https://textory.dev), sharing one
codebase across iOS (17+) and macOS (14+).

## Running

1. Open `Textory/Textory.xcodeproj` in Xcode (15.4+ recommended; built and
   verified with Xcode 26).
2. Select the **Textory** scheme.
3. Choose a run destination:
   - An iOS Simulator (e.g. iPhone 15) for the iOS build.
   - **My Mac** for the macOS build.
4. Run (⌘R).

## API base URL

By default the app talks to `https://textory.dev`. To point at a different
environment (e.g. a local `swa start` instance), set the `TEXTORY_BASE_URL`
environment variable in the scheme's **Run** action
(Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables),
e.g.:

```
TEXTORY_BASE_URL=http://localhost:4280
```

## Features

- **Sign in / register** — username/password auth against `/api/auth/login`
  and `/api/auth/register`. New accounts start in a "pending approval" state
  until an admin approves them; rejected accounts see an "access denied"
  message. Either state offers a sign-out action.
- **Snippet list** — the signed-in home screen lists the user's snippets
  newest-first, with pull-to-refresh, each row showing title, summary, and
  tags.
- **Snippet detail** — tap a row to view a snippet's full content.
- **Add snippet** — a sheet with a text editor, a **Paste** button (pastes
  from the system clipboard), and **Save**. The title is derived from the
  first non-empty line of the content.
- **Delete** — swipe-to-delete on the snippet list.
- **Scan / Import → OCR** — capture a photo with the camera (iOS, falling
  back to the photo library if no camera is available) or import an image
  file (macOS), send it to `/api/ocr` for text extraction, then open
  **Add Snippet** pre-filled with the extracted text for review and save. If
  the user hasn't configured an Anthropic API key (required server-side for
  OCR), the app shows a prompt to add one in Settings on textory.dev.
- **macOS menu commands** — ⌘N opens the new-snippet sheet, ⌘R refreshes the
  snippet list (wired via `NotificationCenter` to whichever view is showing
  the list).

## Architecture

- `APIClient.swift` — async/await HTTP client. Sends the session token via
  the `x-textory-token` header (Azure Static Web Apps strips the standard
  `Authorization` header before requests reach the API's managed functions,
  so this custom header is required — see `api/src/shared/auth.ts`).
- `Models.swift` — `Codable` types mirroring the API's JSON shapes
  (`User`, `Snippet`, `AuthResponse`).
- `Keychain.swift` — stores the session token (`txs_...`) in the Keychain.
- `AuthStore.swift` — `@Observable` session state (`loading`, `anonymous`,
  `pending`, `rejected`, `approved(User)`), with `bootstrap()`, `login()`,
  `register()`, and `logout()`.
- `RootView.swift` — switches on `AuthStore.state` to show the login flow,
  an "awaiting approval" / "access denied" message, or the signed-in snippet
  UI.
- `LoginView.swift` / `RegisterView.swift` — sign-in and account creation.
- `SnippetStore.swift` — `@Observable` snippet list state: `load()`, `add()`,
  `remove()`.
- `SnippetListView.swift` — the snippet list, with add/scan toolbar buttons,
  swipe-to-delete, pull-to-refresh, and (macOS) menu command handling.
- `SnippetDetailView.swift` — read-only view of a single snippet's content.
- `AddSnippetView.swift` — sheet for composing a new snippet (paste/type,
  derive title, save), reusable for both manual entry and OCR-prefilled
  content.
- `ScanView.swift` — the "scan to snippet" flow: camera capture (iOS) or
  image import (macOS) → `/api/ocr` → `AddSnippetView` prefilled with the
  extracted text.
- `ImageCapture.swift` — `ImagePickerView` (iOS camera/photo library wrapper)
  and `ImageFilePicker` (macOS `NSOpenPanel`), plus shared image downscaling
  and JPEG encoding for `/api/ocr`.
- `TextoryApp.swift` — app entry point; on macOS, defines the ⌘N (new
  snippet) and ⌘R (refresh) menu commands posted via `NotificationCenter`.
