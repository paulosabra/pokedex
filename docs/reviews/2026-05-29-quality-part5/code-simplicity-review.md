# Code Simplicity Review — T-32: Final docs & CHANGELOG

**PR:** feature/quality-part5 (docs-only)
**Reviewer:** Code Simplicity Agent
**Date:** 2026-05-29
**Files reviewed:** `README.md`, `cliff.toml`, `CHANGELOG.md`, `docs/adr/0001-…`, `docs/adr/0002-…`, `docs/adr/0003-…`

---

## Simplification Analysis

### Core Purpose

Allow a new developer to clone, run, test, and deploy the project; record the three non-obvious decisions (deploy topology, observability split, COOP/COEP) as permanent searchable references; and produce a machine-generated CHANGELOG from the Conventional-Commit history. The README is the operational document; the ADRs are the decision archive; `cliff.toml` is a generator config.

---

### Unnecessary Complexity Found

#### README.md

**1. `Purpose` section duplicates the tagline (lines 9–15)**
The opening paragraph ("Pokédex is a simple and beautiful way…") is the product tagline. The `Purpose` section immediately below restates the same marketing copy at greater length. A new dev opening the runbook skips both; the information carries zero operational value. The section exists in a typical open-source README but is pure padding here.

**2. "Active sinks by context" table duplicates the `--dart-define` flag table (lines 155–162)**
The flags table at lines 139–145 already documents every flag and its effect. The "Active sinks by context" table below it re-derives the same four scenarios that are fully implied by reading the flags. A dev who understands the flags table needs nothing more. The sinks table answers a question ("what happens in each context?") that can be answered by reading the flags — it adds no new facts.

**3. `ANALYTICS_ENABLED` `fromEnvironment` caveat repeated twice (lines 149–151 and the inline note in the flags table)**
The note that `fromEnvironment` cannot vary by build mode and that "on in production" is achieved by the deploy workflow is stated once in the flags table column (already informative) and then re-stated as a paragraph below the table (lines 149–151). One occurrence is enough.

**4. Observability section intro paragraph duplicates the Architecture section (lines 125–131)**
Lines 125–131 re-describe the two seams, that they are dark by default, and the console/debug behaviour. The Architecture section (lines 48–49) already links to ADR 0002 and describes the seam. The Observability intro can be reduced to a single sentence referencing the flag table that follows.

**5. `vercel link` instruction in "First-time setup" re-explains the secret values already named (lines 222–231)**
The inline parentheticals `(from vercel.com/account/tokens)` and `(from .vercel/project.json)` (twice) are noise that any dev can discover in 10 seconds. Comments inside a bash block should be removed unless they explain a non-obvious step. The `--token` callout note below the block (lines 234–235) is load-bearing (quirky CLI behaviour) — keep it.

**6. "Web build & WASM assets" cross-origin isolation note (lines 282–289) overlaps with ADR 0003**
The final paragraph of that subsection restates the COOP/COEP mechanism, the `credentialless` fallback, and the "headers only on the host" caveat — all of which are fully covered in ADR 0003. The README note can be shortened to a single sentence plus the ADR link (the link is already there on line 288).

---

#### cliff.toml

**7. `footer = ""` is the git-cliff default — dead config (line 32)**
git-cliff's default footer is already an empty string. Explicitly setting `footer = ""` adds no information and exists as a no-op line. Remove it.

**8. `split_commits = false` is the git-cliff default — dead config (line 42)**
The default for `split_commits` is `false`. Explicitly declaring it documents nothing a reader of the git-cliff docs would not already know, and it will silently lag behind any future default change they might want to pick up.

**9. `filter_commits = false` is the git-cliff default — dead config (line 55)**
Same pattern as above. git-cliff defaults `filter_commits` to `false`. Removing it loses nothing.

**10. `{ message = "^chore\\(release\\)", skip = true }` is a dead commit_parser (line 51)**
This rule skips `chore(release)` commits that are produced by release automation tools (semantic-release, release-please). The repo has no such automation (the CHANGELOG is generated manually via `git-cliff -o CHANGELOG.md`). The commit history contains zero `chore(release)` messages. This parser exists for a workflow that does not and is not planned to exist — a YAGNI violation in a config file.

**11. `{ message = "^Merge", skip = true }` warrants a comment; the pattern is silent (line 52)**
This is the one non-default rule in the skip group and it is not a YAGNI violation, but it has no comment. A reader without git-cliff context will not know whether it is skipping GitHub's "Merge pull request" messages or the project's own merge commit messages. A one-line comment — `# Skip "Merge pull request #N" messages from GitHub` — turns an opaque regex into self-documenting config. This is a suggestion, not a removal.

---

#### ADR 0001

**12. "Rejected alternative" paragraph (lines 61–64) restates the Context section**
The Context section (lines 13–22) already explains why a Vercel-side `build.sh` is undesirable (no Flutter runtime, floating SDK version, slow). The "Rejected alternative" paragraph at the end says exactly the same thing in three lines. In an ADR the context and decision together already implicitly reject the alternative; an explicit section restating it without adding new information is padding. Either merge the new detail into the Context or remove the paragraph.

---

#### ADR 0002

**13. Last sentence of "Negative / trade-offs" (lines 65–67) is premature generalisation**
"A future need for a third capability… means a third interface rather than a method on an existing one." This is speculation about a future that does not exist; the sentence is a defensive disclaimer for a decision that already has a clean rationale. It does not help a reader decide whether the ADR is sound; it only hedges. Remove it.

---

#### ADR 0003

**14. "Rejected alternative" paragraph (lines 80–82) restates the negative trade-off already listed above it**
The "Negative / trade-offs" section (lines 74–78) already notes that dropping isolation would degrade the database backend. The rejected-alternative paragraph one line later says the same thing ("forfeit `SharedArrayBuffer` and degrade the database backend"). Exact repetition; remove the rejected-alternative paragraph.

---

### CHANGELOG.md

The generated file itself is machine-produced and should not be hand-edited. No simplification findings — this file is correct as-is.

---

### Code to Remove

| Location | Removal | Estimated LOC |
|---|---|---|
| `README.md` lines 9–15 | `Purpose` section (marketing copy, no runbook value) | 8 |
| `README.md` lines 155–162 | "Active sinks by context" table (derived from flags table above) | 9 |
| `README.md` lines 149–151 | Second `fromEnvironment` caveat paragraph | 3 |
| `README.md` lines 125–131 (trim to 2 lines) | Observability intro — cut duplication with Architecture section | ~5 |
| `README.md` lines 226–231 (clean up parentheticals) | Source comments inside the bash block | ~2 |
| `README.md` lines 282–289 (trim to 1 sentence + link) | COEP note duplicating ADR 0003 | ~6 |
| `cliff.toml` line 32 | `footer = ""` (default, no-op) | 1 |
| `cliff.toml` line 42 | `split_commits = false` (default, no-op) | 1 |
| `cliff.toml` line 55 | `filter_commits = false` (default, no-op) | 1 |
| `cliff.toml` line 51 | `{ message = "^chore\\(release\\)", skip = true }` (dead rule, no release automation) | 1 |
| `docs/adr/0001-…` lines 61–64 | "Rejected alternative" paragraph (repeats Context) | 4 |
| `docs/adr/0002-…` lines 65–67 | Last speculative sentence in Negative trade-offs | 2 |
| `docs/adr/0003-…` lines 80–82 | "Rejected alternative" paragraph (repeats Negative trade-offs) | 3 |

**Total estimated removable lines: ~46 LOC across 5 files.**

---

### Simplification Recommendations

**1. Remove `Purpose` section from README (Critical — highest reader cost)**
- Current: A seven-line product description that duplicates the tagline and adds no developer-facing information.
- Proposed: Delete lines 9–15 entirely. The opening tagline (`Pokédex is a simple and beautiful way…`) on line 5 is sufficient.
- Impact: 8 LOC removed; the runbook starts at `Architecture` which is where a dev needs to begin.

**2. Drop the "Active sinks by context" table (Important)**
- Current: A five-row table repeating the consequence of the flags already documented in the table directly above it.
- Proposed: Remove the table and its heading. If the pattern "no console in production" is considered important to call out explicitly, add a single sentence after the flags table: "In production only the non-console adapters are active; previews are always analytics-dark."
- Impact: 9 LOC removed; no information lost.

**3. Remove three default no-ops from `cliff.toml` (Important)**
- Current: `footer = ""`, `split_commits = false`, `filter_commits = false` each state the git-cliff default explicitly.
- Proposed: Delete all three lines. The file becomes shorter and only contains non-default decisions.
- Impact: 3 LOC removed; config is easier to read because every remaining line is a deliberate override.

**4. Remove dead `chore(release)` commit_parser from `cliff.toml` (Important)**
- Current: `{ message = "^chore\\(release\\)", skip = true }` exists for release-automation tooling the project does not use.
- Proposed: Delete the line and its preceding comment `# Drop noisy housekeeping commits from the changelog.` (that comment applies equally to the `^Merge` rule that follows; keep the comment on the `^Merge` line). If release automation is ever added, the rule can be re-introduced at that point.
- Impact: 1 LOC removed; removes a YAGNI rule that never fires.

**5. Merge the "Rejected alternative" from ADR 0001 into its Context section (Suggestion)**
- Current: The Consequences section ends with a three-sentence paragraph that restates the Context section's rationale for not using a Vercel-side `build.sh`.
- Proposed: Remove the "Rejected alternative" paragraph. The Context + Decision already record the rejection with full reasoning.
- Impact: 4 LOC removed; the ADR reads more crisply.

**6. Remove speculative trade-off sentence from ADR 0002 (Suggestion)**
- Current: "A future need for a third capability…" hedges against an unplanned scenario.
- Proposed: Delete the sentence. The trade-off above it ("Two interfaces and two providers instead of one — slightly more surface area") already acknowledges the cost honestly.
- Impact: 2 LOC removed; ADR stops defending against hypotheticals.

**7. Trim the cross-origin isolation note in README "Web build & WASM assets" (Suggestion)**
- Current: A full paragraph restating COOP/COEP mechanics and the `credentialless` fallback — information fully covered in ADR 0003.
- Proposed: Replace with: "Cross-origin isolation headers are required for `SharedArrayBuffer`; if images break on a preview, fall back to `credentialless` ([ADR 0003](docs/adr/0003-coop-coep-and-image-cross-origin.md))."
- Impact: ~5 LOC removed; the ADR link is preserved and sufficient.

---

### YAGNI Violations

**V-1: `chore(release)` skip rule in `cliff.toml`**
The rule exists for a release-automation workflow (semantic-release, release-please) that this project has never had and has no near-term plans to adopt. Including it "just in case" is a classic YAGNI violation in a config file. When/if release automation is added, this is a one-line addition.

**V-2: Speculative "third capability" sentence in ADR 0002**
Documenting a hypothetical future requirement in an ADR clouds the record of what was actually decided and why. ADRs capture decisions made; they are not architecture forecasts.

---

### Final Assessment

**Total potential LOC reduction: ~46 lines across 5 files (~15% of reviewed prose)**
**Complexity score: Low** — the documentation is well-structured and the issues are surface-level redundancy, not structural problems.
**Recommended action: Minor tweaks only**

The documents are clear, well-organised, and cover everything specified in §8 of the plan. None of the issues above block the PR or represent missing information. The critical finding (the `Purpose` section) and the two important findings (sinks table, cliff.toml defaults + dead rule) are each small edits. The ADR suggestions are cosmetic. The PR is mergeable as-is; the simplifications are worth a quick pass but do not gate merging.
