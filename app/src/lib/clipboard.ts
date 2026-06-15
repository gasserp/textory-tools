import { render } from "./markdown";
import { showToast } from "./toast.svelte";

async function writeRichAndPlain(html: string, plain: string): Promise<void> {
  if (typeof ClipboardItem !== "undefined" && navigator.clipboard?.write) {
    try {
      const item = new ClipboardItem({
        "text/html": new Blob([html], { type: "text/html" }),
        "text/plain": new Blob([plain], { type: "text/plain" }),
      });
      await navigator.clipboard.write([item]);
      return;
    } catch {
      // fall through to plain text
    }
  }
  await navigator.clipboard.writeText(plain);
}

export async function copyRich(content: string): Promise<void> {
  await writeRichAndPlain(render(content), content);
  showToast("✓ copied");
}

export async function copyPlain(content: string): Promise<void> {
  await navigator.clipboard.writeText(content);
  showToast("✓ copied");
}
