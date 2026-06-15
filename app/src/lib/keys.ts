export type KeyBinding = {
  key: string;
  ctrl?: boolean;
  shift?: boolean;
  /** Run even when a text input/textarea/contenteditable is focused. */
  allowInInput?: boolean;
  when?: () => boolean;
  run: () => void;
};

const bindings = new Set<KeyBinding>();

export function isTextInput(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;
}

function handleKeydown(e: KeyboardEvent): void {
  for (const binding of bindings) {
    if (binding.key.toLowerCase() !== e.key.toLowerCase()) continue;
    if (!!binding.ctrl !== (e.ctrlKey || e.metaKey)) continue;
    // Punctuation keys like "?" already encode shift in e.key (and may or may
    // not need shift depending on keyboard layout), so only check shift when
    // the key has distinct cases.
    const hasCase = binding.key.toLowerCase() !== binding.key.toUpperCase();
    if (hasCase && !!binding.shift !== e.shiftKey) continue;
    if (isTextInput(e.target) && !binding.allowInInput) continue;
    if (binding.when && !binding.when()) continue;

    e.preventDefault();
    binding.run();
    return;
  }
}

export function registerKey(binding: KeyBinding): () => void {
  bindings.add(binding);
  return () => bindings.delete(binding);
}

export function initKeys(): void {
  window.addEventListener("keydown", handleKeydown);
}
