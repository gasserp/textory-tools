# txt

A tiny, fast command-line tool for adding text snippets to
[textory.dev](https://textory.dev).

## Build

Requires Go 1.22+. Stdlib only, no dependencies.

```sh
cd cli
go build -o txt .
```

Cross-compile for other platforms:

```sh
GOOS=darwin GOARCH=arm64 go build -o txt-darwin-arm64 .
GOOS=darwin GOARCH=amd64 go build -o txt-darwin-amd64 .
GOOS=windows GOARCH=amd64 go build -o txt-windows-amd64.exe .
```

## Login

Generate a CLI token from your textory.dev account settings, then run:

```sh
txt login
```

This prompts for the token and an optional base URL (default
`https://textory.dev`), and saves them to:

- macOS: `~/Library/Application Support/textory/config.json`
- Windows: `%AppData%\textory\config.json`

The file is created with restrictive permissions (0600).

Environment variables `TEXTORY_TOKEN` and `TEXTORY_URL` override the config
file, and the `-t` / `-u` flags override everything.

## Usage

### macOS / zsh

```sh
# Snippet from arguments
txt Buy milk and eggs

# Snippet from piped input
echo "some text" | txt

# Multiline, interactive (end with Ctrl-D)
txt -i

# Run in the background and return immediately
txt -b "note to self: ship it"

# Pipe command output, suppress success output
git log -1 | txt -q
```

### Windows / PowerShell

```powershell
# Snippet from arguments
txt Buy milk and eggs

# Snippet from piped input
"some text" | txt

# Multiline, interactive (end with Ctrl-Z then Enter)
txt -i

# Run in the background and return immediately
txt -b "note to self: ship it"

# Pipe command output, suppress success output
git log -1 | txt -q
```

## Distribution

In addition to the raw binaries on [GitHub releases](https://github.com/gasserp/textory/releases)
(tagged `cli-v*`), `txt` can be published to package managers so users can
`brew install` / `winget install` it directly.

### Homebrew (macOS)

Homebrew taps live in a separate repo named `homebrew-<tap>`, e.g.
`gasserp/homebrew-textory`.

1. Create the tap repo `github.com/gasserp/homebrew-textory` with a
   `Formula/txt.rb` formula:

   ```ruby
   class Txt < Formula
     desc "Tiny CLI for adding snippets to textory.dev"
     homepage "https://textory.dev"
     version "1.2.3"

     on_macos do
       if Hardware::CPU.arm?
         url "https://github.com/gasserp/textory/releases/download/cli-v1.2.3/txt-darwin-arm64"
         sha256 "<sha256 of txt-darwin-arm64>"
       else
         url "https://github.com/gasserp/textory/releases/download/cli-v1.2.3/txt-darwin-amd64"
         sha256 "<sha256 of txt-darwin-amd64>"
       end
     end

     def install
       bin.install Dir["txt-darwin-*"].first => "txt"
     end

     test do
       system "#{bin}/txt", "--help"
     end
   end
   ```

2. Users install with:

   ```sh
   brew tap gasserp/textory
   brew install txt
   ```

3. **Automation**: on each `cli-v*` release, bump `version`, the two `url`s,
   and recompute the `sha256` values (`shasum -a 256 txt-darwin-*`). This can
   be done with a short script in `cli-release.yml` that checks out the tap
   repo (with a PAT that has push access) and commits the updated formula, or
   with [`brew bump-formula-pr`](https://docs.brew.sh/Formula-Cookbook) run
   against the tap.

### winget (Windows)

winget packages are submitted as manifests to the community
[microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) repo, under
a `Publisher.Package` identifier (e.g. `gasserp.textory`).

1. One-time: install
   [`wingetcreate`](https://github.com/microsoft/winget-create) and generate
   the initial manifest:

   ```powershell
   winget install wingetcreate
   wingetcreate new https://github.com/gasserp/textory/releases/download/cli-v1.2.3/txt-windows-amd64.exe
   ```

   Fill in the prompts (publisher `gasserp`, package `textory`, identifier
   `gasserp.textory`, license, etc.) and submit the PR to `winget-pkgs` —
   this only needs to happen once to get the package accepted.

2. On every subsequent `cli-v*` release, update the manifest's `Version`,
   `InstallerUrl`, and `InstallerSha256`, then re-submit:

   ```powershell
   wingetcreate update gasserp.textory `
     --version 1.2.4 `
     --urls https://github.com/gasserp/textory/releases/download/cli-v1.2.4/txt-windows-amd64.exe `
     --submit
   ```

3. **Automation**: add the
   [`winget-releaser`](https://github.com/vedantmgoyal2009/winget-releaser)
   GitHub Action as a step in `cli-release.yml` (or a separate workflow
   triggered on the same `cli-v*` tags) to run `wingetcreate update --submit`
   automatically and open the PR against `winget-pkgs` for each release.

4. Once accepted, users install with:

   ```powershell
   winget install gasserp.textory
   ```

## Behavior notes

- The title is the first non-empty line of the content, trimmed and
  truncated to 200 characters (by rune, not byte).
- Content must be 1-32768 characters; a single trailing newline is trimmed.
- Content comes from arguments, then piped/redirected stdin. On an
  interactive terminal, `-i` / `--interactive` (or a lone `-` argument) reads
  the snippet until EOF; a bare `txt` on a terminal prints help and exits
  rather than blocking on input that may never arrive.
- `-b` / `--background` re-executes the binary detached with the resolved
  content piped to its stdin, so the shell returns instantly. Errors in
  background mode are silently dropped (there is no terminal to report
  them to).
- On success, prints `<title> (<id>)` unless `-q` / `--quiet` is set.
- On error, prints the HTTP status and server message to stderr and exits
  with status 1.
