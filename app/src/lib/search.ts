import Fuse from "fuse.js";
import { snippetsState, type SnippetDoc } from "./snippets.svelte";

const fuseOptions: ConstructorParameters<typeof Fuse<SnippetDoc>>[1] = {
  keys: [
    { name: "title", weight: 0.4 },
    { name: "tags", weight: 0.25 },
    { name: "summary", weight: 0.2 },
    { name: "content", weight: 0.1 },
    { name: "category", weight: 0.05 },
  ],
  threshold: 0.35,
  ignoreLocation: true,
};

let fuse: Fuse<SnippetDoc> | undefined;
let indexedItems: SnippetDoc[] | undefined;

function getFuse(): Fuse<SnippetDoc> {
  if (!fuse || indexedItems !== snippetsState.items) {
    indexedItems = snippetsState.items;
    fuse = new Fuse(indexedItems, fuseOptions);
  }
  return fuse;
}

export type ParsedQuery = {
  tags: string[];
  categories: string[];
  text: string;
};

/** Extract `#tag` and `@category` tokens from a query; the remainder is the fuzzy text. */
export function parseQuery(query: string): ParsedQuery {
  const tags: string[] = [];
  const categories: string[] = [];
  const rest: string[] = [];

  for (const token of query.trim().split(/\s+/)) {
    if (token.startsWith("#") && token.length > 1) {
      tags.push(token.slice(1).toLowerCase());
    } else if (token.startsWith("@") && token.length > 1) {
      categories.push(token.slice(1).toLowerCase());
    } else if (token !== "") {
      rest.push(token);
    }
  }

  return { tags, categories, text: rest.join(" ") };
}

/** Search the in-memory snippet set, applying `#tag`/`@category` pre-filters and fuzzy text matching. */
export function searchSnippets(query: string): SnippetDoc[] {
  const { tags, categories, text } = parseQuery(query);

  let pool = snippetsState.items;
  if (tags.length > 0) {
    pool = pool.filter((s) => tags.every((t) => s.tags.some((tag) => tag.toLowerCase() === t)));
  }
  if (categories.length > 0) {
    pool = pool.filter((s) => s.category !== undefined && categories.includes(s.category.toLowerCase()));
  }

  if (text === "") return pool;

  if (pool === snippetsState.items) {
    return getFuse()
      .search(text)
      .map((r) => r.item);
  }

  // Pre-filtered pool differs from the full index — run fuse over just that subset.
  const scoped = new Fuse(pool, fuseOptions);
  return scoped.search(text).map((r) => r.item);
}
