export const searchState = $state<{ query: string; active: boolean }>({
  query: "",
  active: false,
});

let inputEl: HTMLInputElement | undefined;

export function registerSearchInput(el: HTMLInputElement | undefined): void {
  inputEl = el;
}

export function focusSearch(): void {
  searchState.active = true;
  queueMicrotask(() => inputEl?.focus());
}

export function clearSearch(): void {
  searchState.query = "";
  searchState.active = false;
}
