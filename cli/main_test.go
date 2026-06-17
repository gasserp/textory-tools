package main

import (
	"os"
	"strings"
	"testing"
)

// withStdin temporarily replaces os.Stdin with a regular file (not a char
// device) holding content, so resolveContent takes its piped-input path.
func withStdin(t *testing.T, content string, fn func()) {
	t.Helper()
	f, err := os.CreateTemp(t.TempDir(), "stdin")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString(content); err != nil {
		t.Fatal(err)
	}
	if _, err := f.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	orig := os.Stdin
	os.Stdin = f
	defer func() {
		os.Stdin = orig
		f.Close()
	}()
	fn()
}

func TestResolveContent(t *testing.T) {
	t.Run("args joined with spaces", func(t *testing.T) {
		got, err := resolveContent([]string{"hello", "world"}, false)
		if err != nil || got != "hello world" {
			t.Fatalf("got %q, err %v; want %q", got, err, "hello world")
		}
	})

	t.Run("piped stdin read in full", func(t *testing.T) {
		withStdin(t, "piped body\n", func() {
			got, err := resolveContent(nil, false)
			if err != nil || got != "piped body\n" {
				t.Fatalf("got %q, err %v; want %q", got, err, "piped body\n")
			}
		})
	})

	t.Run("lone dash reads stdin", func(t *testing.T) {
		withStdin(t, "dash body", func() {
			got, err := resolveContent([]string{"-"}, false)
			if err != nil || got != "dash body" {
				t.Fatalf("got %q, err %v; want %q", got, err, "dash body")
			}
		})
	})
}

func TestExtractTitle(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    string
	}{
		{"single line", "hello world", "hello world"},
		{"first non-empty line", "\n\n  hello\nworld", "hello"},
		{"trims whitespace", "  hello  \nworld", "hello"},
		{"all blank", "   \n\n  ", ""},
		{"long line truncated to 200 runes", strings.Repeat("a", 250), strings.Repeat("a", 200)},
		{"truncates by runes not bytes", strings.Repeat("é", 250), strings.Repeat("é", 200)},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := extractTitle(tc.content)
			if got != tc.want {
				t.Errorf("extractTitle(%q) = %q (len %d), want %q (len %d)", tc.content, got, len([]rune(got)), tc.want, len([]rune(tc.want)))
			}
		})
	}
}

func TestPrepareSnippet(t *testing.T) {
	t.Run("trims trailing newline", func(t *testing.T) {
		title, body, err := prepareSnippet("hello\n")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if title != "hello" {
			t.Errorf("title = %q, want %q", title, "hello")
		}
		if body != "hello" {
			t.Errorf("body = %q, want %q", body, "hello")
		}
	})

	t.Run("trims trailing crlf", func(t *testing.T) {
		_, body, err := prepareSnippet("hello\r\n")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if body != "hello" {
			t.Errorf("body = %q, want %q", body, "hello")
		}
	})

	t.Run("rejects empty content", func(t *testing.T) {
		if _, _, err := prepareSnippet(""); err == nil {
			t.Error("expected error for empty content")
		}
		if _, _, err := prepareSnippet("\n"); err == nil {
			t.Error("expected error for whitespace-only content")
		}
	})

	t.Run("rejects content over max length", func(t *testing.T) {
		long := strings.Repeat("a", maxContentLen+1)
		if _, _, err := prepareSnippet(long); err == nil {
			t.Error("expected error for over-long content")
		}
	})

	t.Run("multiline content keeps full body with truncated title", func(t *testing.T) {
		raw := strings.Repeat("a", 250) + "\nsecond line\n"
		title, body, err := prepareSnippet(raw)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len([]rune(title)) != maxTitleLen {
			t.Errorf("title length = %d, want %d", len([]rune(title)), maxTitleLen)
		}
		wantBody := strings.Repeat("a", 250) + "\nsecond line"
		if body != wantBody {
			t.Errorf("body = %q, want %q", body, wantBody)
		}
	})
}
