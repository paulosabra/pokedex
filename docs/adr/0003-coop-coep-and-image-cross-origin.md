# 3. COOP/COEP cross-origin isolation and cross-origin artwork

- **Status:** Accepted
- **Date:** 2026-05-29
- **Deciders:** Paulo Sabra
- **Context task:** T-31 (Quality & Release epic)

## Context

The app stores its Pokémon catalogue in a client-side **Drift (SQLite)**
database. On the web, Drift's performant backend runs SQLite in a Web Worker and
shares memory with the main thread via `SharedArrayBuffer`. Browsers only expose
`SharedArrayBuffer` when the document is **cross-origin isolated**, which
requires two response headers on the served page:

```
Cross-Origin-Opener-Policy:   same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without them, `crossOriginIsolated` is `false`, `SharedArrayBuffer` is
unavailable, and Drift silently falls back to a slower/degraded web backend.

The catch: **`require-corp` is strict.** Every cross-origin subresource the page
loads must opt in by sending `Cross-Origin-Resource-Policy` (CORP), or the
browser blocks it. Official Pokémon artwork is served from
`raw.githubusercontent.com` (via `cached_network_image`) — a cross-origin host
we do not control and which does not send CORP. Under `require-corp` those
images would be **blocked**, breaking the core visual experience.

## Decision

Set the isolation headers in `vercel.json` for all routes:

```json
{ "key": "Cross-Origin-Opener-Policy",   "value": "same-origin" },
{ "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
```

`require-corp` is the **default**. If the preview deploy shows broken artwork
under it, **fall back to `credentialless`** (D-9):

```json
{ "key": "Cross-Origin-Embedder-Policy", "value": "credentialless" }
```

`credentialless` still establishes cross-origin isolation (so `SharedArrayBuffer`
/ Drift's fast backend keep working) but loads cross-origin subresources
**without credentials** instead of demanding CORP — so the GitHub-hosted images
render. The trade-off is acceptable here: the artwork is public and needs no
cookies.

**Verification is on the preview deploy, not locally.** `flutter run` and the
`flutter drive` web-server do not emit COOP/COEP, so this interaction is only
observable once Vercel serves the headers. The PR-preview pipeline therefore
acts as the early-warning system (O-4): the E2E suite runs the same Drift-WASM
stack, and the preview URL is checked for **(a)** `SharedArrayBuffer` present and
**(b)** artwork rendering before promoting to production.

## Consequences

**Positive**

- Drift gets its fast, `SharedArrayBuffer`-backed web executor in production.
- A single header flip (`require-corp` → `credentialless`) resolves the
  image-vs-isolation tension without touching application code or moving image
  hosting.
- The preview deploy surfaces the problem before `main`, so production never
  ships broken isolation or broken artwork.

**Negative / trade-offs**

- Cross-origin isolation imposes ongoing discipline: any **new** cross-origin
  subresource (fonts, scripts, third-party embeds) must be CORP-compatible or
  survive `credentialless`, or it will be blocked. Future integrations must be
  checked against this constraint.
- The behaviour cannot be fully validated in local dev — it depends on the
  hosting layer's headers, adding a preview-deploy step to the verification loop.

**Rejected alternative:** dropping COOP/COEP to load images freely — this would
forfeit `SharedArrayBuffer` and degrade the database backend, trading the app's
core data path for convenience.
