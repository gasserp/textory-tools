import { setTheme } from "./theme.svelte";
import { openHelp, openAdmin, openSettings } from "./overlay.svelte";
import { showList, showNew, viewState } from "./view.svelte";
import { session } from "./stores.svelte";
import { focusSearch } from "./search.svelte";
import { runClassify } from "./classify.svelte";

export type Command = {
  id: string;
  title: string;
  keywords: string[];
  run: () => void;
};

export function getCommands(): Command[] {
  const commands: Command[] = [
    { id: "theme:dark", title: "theme: dark", keywords: ["theme", "dark"], run: () => setTheme("dark") },
    { id: "theme:light", title: "theme: light", keywords: ["theme", "light"], run: () => setTheme("light") },
    {
      id: "theme:dark-hc",
      title: "theme: dark high contrast",
      keywords: ["theme", "dark", "hc", "high", "contrast"],
      run: () => setTheme("dark-hc"),
    },
    {
      id: "theme:light-hc",
      title: "theme: light high contrast",
      keywords: ["theme", "light", "hc", "high", "contrast"],
      run: () => setTheme("light-hc"),
    },
    {
      id: "new-snippet",
      title: "new snippet",
      keywords: ["new", "snippet", "create"],
      run: showNew,
    },
    {
      id: "search-snippets",
      title: "search snippets",
      keywords: ["search", "find", "filter", "fuzzy"],
      run: () => {
        showList();
        focusSearch();
      },
    },
    {
      id: "sign-out",
      title: "sign out",
      keywords: ["sign", "out", "logout"],
      run: () => {
        window.location.href = "/logout";
      },
    },
    { id: "help", title: "help", keywords: ["help", "keys", "shortcuts"], run: openHelp },
    { id: "settings", title: "settings", keywords: ["settings", "key", "anthropic", "api"], run: openSettings },
    {
      id: "classify-snippet",
      title: "classify snippet",
      keywords: ["classify", "tag", "summary", "category", "llm"],
      run: () => runClassify(viewState.selectedId),
    },
  ];

  if (session.user?.role === "admin") {
    commands.push({ id: "admin", title: "admin", keywords: ["admin", "users", "approve", "quota"], run: openAdmin });
  }

  return commands;
}
