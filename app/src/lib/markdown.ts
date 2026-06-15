import { marked } from "marked";
import DOMPurify from "dompurify";
import hljs from "highlight.js/lib/common";

marked.use({
  renderer: {
    code({ text, lang }) {
      const result = lang && hljs.getLanguage(lang) ? hljs.highlight(text, { language: lang }) : hljs.highlightAuto(text);
      const langClass = result.language ? ` language-${result.language}` : "";
      return `<pre><code class="hljs${langClass}">${result.value}</code></pre>`;
    },
  },
});

export function render(md: string): string {
  const html = marked.parse(md, { async: false }) as string;
  return DOMPurify.sanitize(html);
}
