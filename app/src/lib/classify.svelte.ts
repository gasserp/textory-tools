import { classifySnippet } from "./snippets.svelte";
import { showToast } from "./toast.svelte";

export const classifyState = $state<{ inFlightId: string | null }>({ inFlightId: null });

export async function runClassify(id: string | null | undefined): Promise<void> {
  if (!id || classifyState.inFlightId) return;
  classifyState.inFlightId = id;
  try {
    await classifySnippet(id);
    showToast("classification updated");
  } catch (e) {
    showToast(e instanceof Error ? e.message : "classification failed");
  } finally {
    classifyState.inFlightId = null;
  }
}
