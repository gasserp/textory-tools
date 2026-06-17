<div class="privacy">
  <h2>privacy policy</h2>
  <p class="version">version 2026-06-17</p>

  <p>
    This policy explains what data the Textory apps (web, iOS, macOS, Windows, and CLI) collect, how it is used,
    and who it is shared with. Textory is operated by the developer reachable at
    <a href="mailto:privacy@gasserp.ch">privacy@gasserp.ch</a>, who is the controller of your data.
  </p>

  <h3>1. what we collect</h3>
  <ul>
    <li><strong>Account</strong> — a username and password you choose at registration (or via GitHub sign-in on the
      web). Passwords are stored only as a salted hash, never in plain text. On native apps, a session token is
      stored securely in the device keychain.</li>
    <li><strong>Snippets</strong> — the title, content, tags, category, and summary of snippets you create. This is
      content you provide; we do not scan it for advertising or profiling.</li>
    <li><strong>Anthropic API key</strong> — optional. If you use the LLM classification or image text-extraction
      (OCR) features, you supply your own Anthropic API key. It is encrypted at rest (AES-256-GCM) and used only to
      make requests on your behalf.</li>
    <li><strong>Images</strong> — when you capture or import an image for text extraction, it is sent to the OCR
      endpoint for processing and is not retained after the text is returned.</li>
  </ul>
  <p>
    We do not use third-party analytics, advertising, or tracking SDKs. We do not collect your location, contacts,
    or device identifiers for tracking.
  </p>

  <h3>2. how we use it</h3>
  <p>
    Data is used solely to provide the service: to authenticate you, store and sync your snippets, enforce your
    storage quota, and run the LLM features you explicitly invoke. We do not sell your data.
  </p>

  <h3>3. who we share it with</h3>
  <ul>
    <li><strong>Microsoft Azure</strong> — hosting and storage. Account metadata and snippet content are stored in
      Azure (Cosmos DB) as our data processor.</li>
    <li><strong>Anthropic</strong> — when you use the classification or OCR features, the relevant snippet text or
      image is sent to Anthropic's API using your own API key. Anthropic processes it under its own terms.</li>
  </ul>
  <p>Admins can see account metadata (login, quota, usage) but not your snippet content in the app.</p>

  <h3>4. device permissions</h3>
  <p>
    On iOS/macOS, the camera and photo library are accessed only when you choose to capture or import an image for
    text extraction. No image is uploaded unless you initiate it.
  </p>

  <h3>5. retention &amp; deletion</h3>
  <p>
    Your data is retained while your account is active. You can stop using the service at any time and contact
    <a href="mailto:privacy@gasserp.ch">privacy@gasserp.ch</a> to have your account and associated data deleted.
  </p>

  <h3>6. children</h3>
  <p>Textory is not directed to children and is not intended for use by anyone under 16.</p>

  <h3>7. changes</h3>
  <p>
    We may update this policy; the version date above reflects the latest revision. Material changes will be
    surfaced in the app.
  </p>

  <h3>8. contact</h3>
  <p>Questions or requests: <a href="mailto:privacy@gasserp.ch">privacy@gasserp.ch</a>.</p>
</div>

<style>
  .privacy {
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
