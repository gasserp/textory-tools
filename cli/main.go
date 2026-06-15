// Command txt is a tiny, fast CLI for adding text snippets to textory.dev.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	maxContentLen = 32768
	maxTitleLen   = 200
)

const usage = `txt - add a text snippet to textory.dev

Usage:
  txt [flags] [text...]
  txt login

If text arguments are given, they are joined with spaces and used as the
snippet content. Otherwise, content is read from stdin: piped/redirected
input is read in full, or (on a terminal) read interactively until EOF.

The title is the first non-empty line of the content, truncated to 200
characters.

Flags:
  -b, --background   re-run in the background and return immediately
  -t <token>          API token (overrides config file and TEXTORY_TOKEN)
  -u <url>            base URL (overrides config file and TEXTORY_URL,
                      default https://textory.dev)
  -q, --quiet         suppress success output

Config:
  Run "txt login" to save a token and base URL to
  $XDG_CONFIG_HOME/textory/config.json (or the OS equivalent).
  Environment variables TEXTORY_TOKEN and TEXTORY_URL override the config
  file; flags override everything.

Examples:
  macOS / zsh:
    txt Buy milk and eggs
    echo "some text" | txt
    txt -b "note to self: ship it"
    git log -1 | txt -q

  Windows / PowerShell:
    txt Buy milk and eggs
    "some text" | txt
    txt -b "note to self: ship it"
    git log -1 | txt -q
`

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) > 0 && args[0] == "login" {
		return cmdLogin()
	}

	fs := flag.NewFlagSet("txt", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	fs.Usage = func() { fmt.Fprint(os.Stderr, usage) }

	var background, quiet bool
	var tokenFlag, urlFlag string
	fs.BoolVar(&background, "b", false, "run in the background")
	fs.BoolVar(&background, "background", false, "run in the background")
	fs.StringVar(&tokenFlag, "t", "", "API token")
	fs.StringVar(&urlFlag, "u", "", "base URL")
	fs.BoolVar(&quiet, "q", false, "suppress success output")
	fs.BoolVar(&quiet, "quiet", false, "suppress success output")

	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return 0
		}
		return 2
	}

	if background {
		content, err := resolveContent(fs.Args())
		if err != nil {
			fmt.Fprintln(os.Stderr, "error:", err)
			return 1
		}
		spawnBackground(content, tokenFlag, urlFlag)
		return 0
	}

	content, err := resolveContent(fs.Args())
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}

	title, body, err := prepareSnippet(content)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}

	token, baseURL, err := resolveCredentials(tokenFlag, urlFlag)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}

	created, err := postSnippet(baseURL, token, title, body)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}

	if !quiet {
		fmt.Printf("%s (%s)\n", created.Title, created.ID)
	}
	return 0
}

// resolveContent determines the raw snippet content from args or stdin,
// per the priority order: args, piped stdin, interactive stdin.
func resolveContent(args []string) (string, error) {
	if len(args) > 0 {
		return strings.Join(args, " "), nil
	}

	stat, err := os.Stdin.Stat()
	if err == nil && (stat.Mode()&os.ModeCharDevice) == 0 {
		// stdin is piped or redirected: read it all.
		data, err := io.ReadAll(os.Stdin)
		if err != nil {
			return "", fmt.Errorf("read stdin: %w", err)
		}
		return string(data), nil
	}

	// Interactive terminal: prompt and read until EOF.
	fmt.Fprintln(os.Stderr, "Enter snippet, finish with Ctrl-D (macOS/Linux) or Ctrl-Z then Enter (Windows):")
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return "", fmt.Errorf("read stdin: %w", err)
	}
	return string(data), nil
}

// prepareSnippet derives the title and final content body from raw input,
// validating length constraints.
func prepareSnippet(raw string) (title, body string, err error) {
	body = strings.TrimSuffix(raw, "\r\n")
	body = strings.TrimSuffix(body, "\n")

	if strings.TrimSpace(body) == "" {
		return "", "", errors.New("content is empty")
	}
	if len(body) > maxContentLen {
		return "", "", fmt.Errorf("content too long: %d characters (max %d)", len([]rune(body)), maxContentLen)
	}

	title = extractTitle(body)
	if title == "" {
		return "", "", errors.New("content is empty")
	}
	return title, body, nil
}

// extractTitle returns the first non-empty line of content, trimmed and
// truncated to maxTitleLen runes.
func extractTitle(content string) string {
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		runes := []rune(line)
		if len(runes) > maxTitleLen {
			runes = runes[:maxTitleLen]
		}
		return string(runes)
	}
	return ""
}

// resolveCredentials determines the token and base URL to use, applying
// flag > env > config-file precedence.
func resolveCredentials(tokenFlag, urlFlag string) (token, baseURL string, err error) {
	cfg, cfgErr := loadConfig()
	// Ignore config load errors (e.g. malformed file) unless we actually
	// need values from it and have nothing else.

	token = cfg.Token
	if v := os.Getenv("TEXTORY_TOKEN"); v != "" {
		token = v
	}
	if tokenFlag != "" {
		token = tokenFlag
	}

	baseURL = cfg.URL
	if v := os.Getenv("TEXTORY_URL"); v != "" {
		baseURL = v
	}
	if urlFlag != "" {
		baseURL = urlFlag
	}
	if baseURL == "" {
		baseURL = defaultBaseURL
	}

	if token == "" {
		if cfgErr != nil {
			return "", "", fmt.Errorf("no API token configured (run 'txt login'): %w", cfgErr)
		}
		return "", "", errors.New("no API token configured; run 'txt login' or set TEXTORY_TOKEN")
	}

	return token, strings.TrimRight(baseURL, "/"), nil
}

type snippetResponse struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

type errorResponse struct {
	Error string `json:"error"`
}

// postSnippet sends the snippet to the API and returns the created
// snippet on success.
func postSnippet(baseURL, token, title, content string) (*snippetResponse, error) {
	reqBody, err := json.Marshal(map[string]string{
		"title":   title,
		"content": content,
	})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest(http.MethodPost, baseURL+"/api/snippets", bytes.NewReader(reqBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	// Azure Static Web Apps strips the Authorization header before it
	// reaches the API, so the token travels in a custom header; the Bearer
	// form is kept for direct API access (local dev).
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Textory-Token", token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusCreated {
		msg := strings.TrimSpace(string(respBody))
		var errResp errorResponse
		if json.Unmarshal(respBody, &errResp) == nil && errResp.Error != "" {
			msg = errResp.Error
		}
		switch resp.StatusCode {
		case http.StatusUnauthorized:
			return nil, fmt.Errorf("%d unauthorized: %s (check your token, run 'txt login')", resp.StatusCode, msg)
		case http.StatusForbidden:
			return nil, fmt.Errorf("%d forbidden: %s", resp.StatusCode, msg)
		case http.StatusTooManyRequests:
			return nil, fmt.Errorf("%d rate limited: %s", resp.StatusCode, msg)
		default:
			return nil, fmt.Errorf("%d: %s", resp.StatusCode, msg)
		}
	}

	var created snippetResponse
	if err := json.Unmarshal(respBody, &created); err != nil {
		return nil, fmt.Errorf("parse response: %w", err)
	}
	return &created, nil
}

// cmdLogin runs the interactive `txt login` flow, prompting for a token
// and optional base URL and saving them to the config file.
func cmdLogin() int {
	reader := bufio.NewReader(os.Stdin)

	fmt.Fprint(os.Stderr, "API token: ")
	token, err := reader.ReadString('\n')
	if err != nil && !errors.Is(err, io.EOF) {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}
	token = strings.TrimSpace(token)
	if token == "" {
		fmt.Fprintln(os.Stderr, "error: token must not be empty")
		return 1
	}

	fmt.Fprintf(os.Stderr, "Base URL [%s]: ", defaultBaseURL)
	url, err := reader.ReadString('\n')
	if err != nil && !errors.Is(err, io.EOF) {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}
	url = strings.TrimSpace(url)
	if url == "" {
		url = defaultBaseURL
	}

	cfg := config{Token: token, URL: url}
	if err := saveConfig(cfg); err != nil {
		fmt.Fprintln(os.Stderr, "error: save config:", err)
		return 1
	}

	path, _ := configPath()
	fmt.Printf("Saved config to %s\n", path)
	return 0
}
