export type Toast = { id: number; text: string };

const DURATION_MS = 3000;

export const toastState = $state<{ current: Toast | null }>({ current: null });

let nextId = 0;
let timer: ReturnType<typeof setTimeout> | undefined;

export function showToast(text: string): void {
  const id = ++nextId;
  toastState.current = { id, text };
  if (timer !== undefined) clearTimeout(timer);
  timer = setTimeout(() => {
    if (toastState.current?.id === id) toastState.current = null;
  }, DURATION_MS);
}
