<div class="terms">
  <h2>terms of use &amp; acceptable use policy</h2>
  <p class="version">version 2026-06-12</p>

  <h3>1. beta service</h3>
  <p>
    Textory is a beta service, provided "as is" without warranty of any kind. There is no guarantee of
    availability, durability, or continuity of service. Access is admin-approved and may be revoked at any time,
    for any reason, without notice.
  </p>

  <h3>2. acceptable use</h3>
  <p>You may not store or process content that:</p>
  <ul>
    <li>is illegal under applicable law;</li>
    <li>is harmful, hateful, racist, or otherwise discriminatory;</li>
    <li>is harassing, violent, or threatening;</li>
    <li>is sexually exploitative, especially regarding minors;</li>
    <li>is malware or exploit code intended to cause harm; or</li>
    <li>infringes the intellectual property or other rights of others.</li>
  </ul>
  <p>Violation of this policy leads to account suspension and removal of the offending content.</p>

  <h3>3. llm features</h3>
  <p>
    Classification sends snippet content to Anthropic using <strong>your own API key</strong>. All resulting
    costs are billed to your Anthropic account — the operator never reimburses LLM costs. You are responsible
    for safeguarding the use of your key.
  </p>

  <h3>4. data</h3>
  <p>
    Snippets and your encrypted API key are stored in Azure (Cosmos DB). Snippets are private to your account.
    Admins can see account metadata (login, quota, usage) but not snippet content in the app. See the
    <a href="/privacy.html">privacy policy</a> for full details on what we collect and share.
  </p>

  <h3>5. termination</h3>
  <p>
    You can stop using the service at any time. Contact the admin to delete your account and data.
  </p>
</div>

<style>
  .terms {
    font-size: 0.9em;
    color: var(--fg);
  }

  h2 {
    margin: 0 0 var(--sp-1);
    font-size: 1em;
    color: var(--accent);
  }

  h3 {
    margin: var(--sp-3) 0 var(--sp-1);
    font-size: 0.95em;
    color: var(--accent);
  }

  p {
    margin: var(--sp-1) 0;
    color: var(--fg);
  }

  .version {
    margin: 0 0 var(--sp-2);
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  ul {
    margin: var(--sp-1) 0;
    padding-left: var(--sp-4);
  }

  li {
    margin: var(--sp-1) 0;
  }

  strong {
    color: var(--accent);
  }

  a {
    color: var(--accent);
  }
</style>
