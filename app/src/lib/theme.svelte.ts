const STORAGE_KEY = "textory-theme";

export type Theme = "dark" | "light" | "dark-hc" | "light-hc";

export const THEMES: Theme[] = ["dark", "light", "dark-hc", "light-hc"];

function isTheme(value: string | null): value is Theme {
  return THEMES.includes(value as Theme);
}

function systemTheme(): Theme {
  const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const highContrast = window.matchMedia("(prefers-contrast: more)").matches;
  if (dark) return highContrast ? "dark-hc" : "dark";
  return highContrast ? "light-hc" : "light";
}

function initialTheme(): Theme {
  const stored = localStorage.getItem(STORAGE_KEY);
  return isTheme(stored) ? stored : systemTheme();
}

export const themeState = $state<{ current: Theme }>({ current: initialTheme() });

export function setTheme(theme: Theme): void {
  themeState.current = theme;
  document.documentElement.dataset.theme = theme;
  localStorage.setItem(STORAGE_KEY, theme);
}

export function initTheme(): void {
  document.documentElement.dataset.theme = themeState.current;
}
