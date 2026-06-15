export type ViewMode = "list" | "view" | "edit" | "new";

export const viewState = $state<{ mode: ViewMode; selectedId: string | null }>({
  mode: "list",
  selectedId: null,
});

export function showList(): void {
  viewState.mode = "list";
  viewState.selectedId = null;
}

export function showView(id: string): void {
  viewState.mode = "view";
  viewState.selectedId = id;
}

export function showEdit(id: string): void {
  viewState.mode = "edit";
  viewState.selectedId = id;
}

export function showNew(): void {
  viewState.mode = "new";
  viewState.selectedId = null;
}

let pendingContent: string | null = null;

export function showNewWithContent(content: string): void {
  pendingContent = content;
  viewState.mode = "new";
  viewState.selectedId = null;
}

export function takePendingContent(): string | null {
  const content = pendingContent;
  pendingContent = null;
  return content;
}
