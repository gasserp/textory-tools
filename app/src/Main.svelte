<script lang="ts">
  import { onMount } from "svelte";
  import { loadSnippets } from "./lib/snippets.svelte";
  import { viewState } from "./lib/view.svelte";
  import SnippetList from "./components/SnippetList.svelte";
  import SnippetView from "./components/SnippetView.svelte";
  import SnippetEditor from "./components/SnippetEditor.svelte";

  onMount(loadSnippets);
</script>

{#if viewState.mode === "list"}
  <SnippetList />
{:else if viewState.mode === "view"}
  {#key viewState.selectedId}
    <SnippetView />
  {/key}
{:else}
  {#key `${viewState.mode}:${viewState.selectedId}`}
    <SnippetEditor />
  {/key}
{/if}
