---
name: review-board
description: >
  Multi-LLM review board. Sends any document (architecture docs, design docs,
  RFCs, API specs, runbooks) to external LLM CLIs (Codex, Gemini, GitHub Copilot)
  for independent review, synthesizes feedback, then optionally drives rebuttal
  rounds and consensus building. Multi-round, each round is opt-in.
  Trigger phrases include "review this doc", "get external review",
  "send to chatgpt and gemini", "review board", or any request to have a
  document reviewed by other LLMs.
---

# Review Board

Multi-round document review process using external LLMs as independent reviewers and Claude as the synthesizer and moderator. Works with any technical document -- architecture docs, design docs, RFCs, API specs, runbooks, proposals. Each round after Round 1 is optional -- the user advances when they want to go deeper.

## Supported Reviewers

| Reviewer | CLI Binary | Display Name |
|----------|-----------|--------------|
| ChatGPT | `codex` | ChatGPT (Codex) |
| Gemini | `gemini` | Gemini |
| GitHub Copilot | `gh copilot` | GitHub Copilot |

## Prerequisites

At least one reviewer CLI must be installed. Check with:
```bash
which codex 2>/dev/null; which gemini 2>/dev/null; gh copilot --version 2>/dev/null
```

If none are found, report the error and stop. If only some are available, proceed with those.

## Reviewer Selection

### Auto-detect (default)
At startup, detect all available CLIs. Use all that are found. This is the default -- no user prompt needed.

### User override
If the user specifies reviewers in their request (e.g., "just send to gemini" or "use codex and copilot"), respect that choice. Only use the specified reviewers.

### Minimum reviewers
The skill requires at least 1 reviewer. With a single reviewer, skip the "Agreed Issues" and "Contradictions" categories in synthesis -- everything becomes "Unique Insights" from that reviewer.

With 2+ reviewers, the full synthesis categories apply. More reviewers increase the chance of catching issues but also increase noise. The synthesis step handles any number of reviewers.

## File Organization

All intermediate files go in a temp working directory. Only the final deliverable(s) are saved next to the source document.

**Temp directory:** `<doc_dir>/.review-board-<docname>/`

Create this directory at the start of the workflow. All raw reviews, rebuttals, and intermediate files go here.

**Final deliverables** (saved next to the source doc):
- `<docname>-review-consolidated.md` -- always produced (Round 1)
- `<docname>-consensus.md` -- only if Round 3 runs
- `<docname>-decisions.md` -- only if Round 4 runs

**Temp files** (in the working directory, cleaned up at the end):
- `context-preamble.md` -- project context prepended to doc for reviewers
- `review-<reviewer>.md` -- raw review from each reviewer (e.g., `review-chatgpt.md`, `review-gemini.md`, `review-copilot.md`)
- `rebuttal.md` -- Claude's rebuttal
- `rebuttal-<reviewer>.md` -- each reviewer's response to the rebuttal

**Cleanup:** When the workflow completes (user chooses to stop or finishes all rounds), ask the user whether to keep or delete the temp working directory. Default: delete.

### Setup Commands

At the start of the workflow, run:
```bash
mkdir -p "<doc_dir>/.review-board-<docname>"
```

## CLI Invocation Details

These apply to all rounds that send content to external LLMs.

**Important shell details:**
- Use `printf '%s\n\n%s'` instead of `echo` to handle large documents safely.
- For Gemini, embed all content inside the `-p` argument via `$(cat "$FILE")` command substitution. Do NOT pipe via stdin -- Gemini CLI does not reliably read stdin with `-p`.
- For Codex, pipe the combined prompt+content via stdin and use `-` to read from stdin.
- Set `timeout: 600000` on all Bash calls (reviews can take a few minutes).
- Run both as background Bash tasks (`run_in_background: true`) so they execute concurrently.
- Use `TaskOutput` with `block: true` and `timeout: 300000` to wait for completion of each.
- Suppress stderr with `2>/dev/null` on both CLIs.

### Working Directory

Give reviewers access to the project codebase so they can browse source code, not just the document text. Determine the project root: walk up from the document's directory looking for `.git`, `go.mod`, `package.json`, or similar project markers. If found, use that as `$PROJECT_DIR`. If not found, use the document's parent directory.

**ChatGPT (Codex) pattern:**
```bash
cd "$PROJECT_DIR" && printf '%s\n\n%s' "$PROMPT" "$(cat "$INPUT_FILE")" | codex exec -C "$PROJECT_DIR" --skip-git-repo-check -o "$OUTPUT_FILE" - 2>/dev/null
```
`-C` sets the working root so Codex can read project files. `cd` also ensures CWD matches. The review prompt should include the explicit path `$PROJECT_DIR` so the model knows where to look.

**Gemini pattern:**
```bash
cd "$PROJECT_DIR" && gemini --include-directories "$PROJECT_DIR" -p "${PROMPT}

$(cat "$INPUT_FILE")" -o text > "$OUTPUT_FILE" 2>/dev/null
```
`--include-directories` adds the project to Gemini's workspace. `cd` sets CWD for file resolution. The review prompt should include the explicit path `$PROJECT_DIR`.

**GitHub Copilot pattern:**
```bash
cd "$PROJECT_DIR" && gh copilot -- -p "${PROMPT}

$(cat "$PREAMBLE_FILE")

$(cat "$INPUT_FILE")" --model "claude-sonnet-4.5" --add-dir "$PROJECT_DIR" --allow-all-tools --no-custom-instructions -s > "$OUTPUT_FILE" 2>/dev/null
```
`cd "$PROJECT_DIR"` sets CWD so the model's file tools resolve relative paths correctly. `--add-dir` whitelists the directory for file access. `--allow-all-tools` and `-s` (silent) are required for non-interactive mode. The review prompt should include the explicit path `$PROJECT_DIR` so the model knows where to look.

---

## Round 1: Initial Review + Synthesis

This round always runs. It is the minimum viable review.

### Step 1: Ask for the File

Always ask the user which file to review using `AskUserQuestion`. Do not auto-detect or assume. If the user provides a file path as an argument, confirm it and proceed.

### Step 2: Validate and Setup

1. Read the file with the `Read` tool. If it does not exist or is empty, report the error and stop.
2. Detect available reviewer CLIs:
   ```bash
   which codex 2>/dev/null; which gemini 2>/dev/null; gh copilot --version 2>/dev/null
   ```
   Report which reviewers are available. If the user specified reviewers in their request, use only those. Otherwise use all available.
   If zero reviewers are available, report the error and stop.
3. Create the temp working directory: `mkdir -p "<doc_dir>/.review-board-<docname>"`
4. Tell the user: "Sending to: <list of reviewers>". No confirmation needed -- just inform.

### Step 2.5: Build Context Preamble

External reviewers receive only the document text -- they have no knowledge of the project, repo, codebase, or team constraints. Claude DOES have this context from the current session. Use it.

**Generate a context preamble** and write it to `<workdir>/context-preamble.md`. This file gets prepended to the document content before sending to each reviewer.

Build the preamble by gathering what you know from the conversation and the filesystem. Run `ls` on the project root to discover structure. Check for README, go.mod, package.json, etc. to identify tech stack.

Use this template:

```markdown
## Context for Reviewers

> This context helps you understand the technical environment. Focus your review
> on engineering quality, not business strategy.

**System/Tool:** <what is this? e.g., "Kubernetes operator for DICOM VNA", "CLI for prompt engineering", "REST API for image processing">

**Problem Being Solved:** <1-2 sentences about the technical problem>

**Technology/Domain:** <e.g., "K8s operator (Go, controller-runtime)", "Python CLI", "REST API (Node.js, Express)", "ML pipeline (Python, PyTorch)">

**Environment:** <where it runs: AWS EKS, local CLI, edge devices, Docker, etc.>

**Key Integrations:** <external systems this interacts with: APIs, databases, services>

**Known Constraints:**
- <technical or business constraints that are non-negotiable>
- <e.g., "must use PostgreSQL", "cannot require root", "must handle 10K req/sec">
- <e.g., "must comply with HIPAA", "must work offline", "GitHub API rate limits">

**Current State:** <what exists in production vs. what's proposed>

**Recent Context:** <optional: recent incidents, similar tools, previous attempts>

---
```

**Rules:**
- Keep it under 30 lines.
- Only include facts you're confident about.
- Omit sections you have no information for -- a shorter, accurate preamble beats a padded one.
- If you have minimal context (standalone file, no project), write a minimal preamble or skip it.
- The constraints section is the most important -- it guides what reviewers focus on.
- The preamble is a temp file -- it's never delivered as a final artifact.

### Step 3: Collect Reviews

Send the context preamble + doc to all selected reviewers in parallel using this review prompt (replace `$PROJECT_DIR` with the actual absolute path):

```
You are a principal engineer reviewing this technical document.

The document is preceded by a "Context for Reviewers" section that describes the technical
environment and constraints. Use this context to calibrate your review -- do not flag things
that are explicitly listed as known constraints or out of scope.

IMPORTANT: The project source code is in your current working directory ($PROJECT_DIR).
You MUST browse the codebase to verify claims in the document. Start by listing the
top-level directory contents, then read key source files referenced in the document.
Check if referenced code, configs, or infrastructure actually exist and match what the
document describes. Cross-reference the doc against the implementation.

Focus on engineering quality and production readiness:

1) **Technical Correctness**
   - Will this design/approach actually work for the stated problem?
   - Are there fundamental flaws or wrong assumptions?
   - Are dependencies, integrations, and prerequisites correctly identified?

2) **Failure Modes & Recovery**
   - What breaks under failure scenarios? (Network, disk, API, service down)
   - How does the system recover? Retry logic? Degraded mode?
   - What's the blast radius of failures?
   - Rollback/rollforward strategy?

3) **Implementation Gaps**
   - What's missing to actually build this? (Configs, schemas, APIs, libraries)
   - Are error handling paths specified?
   - Edge cases or boundary conditions not addressed?

4) **Security & Safety**
   - Authentication, authorization, input validation
   - Secrets/credentials handling
   - Privilege levels, access control
   - Data exposure risks

5) **Observability & Operations**
   - Monitoring, logging, metrics, alerting
   - How do you debug "why didn't X work?"
   - Health checks, status reporting
   - Operational runbooks or procedures

6) **Production Readiness**
   - Testing strategy (unit, integration, end-to-end)
   - Deployment/upgrade approach
   - Resource requirements (if relevant to design)
   - Performance characteristics (if relevant)

7) **Design Quality**
   - Is this over-engineered? Under-engineered? Right-sized?
   - Does it follow established patterns for the domain?
   - Are there simpler alternatives that achieve the same goals?

Be direct about flaws. Reference specific sections. Suggest concrete improvements.

If the document mentions strategic concerns (cost, team structure, training), note them
briefly but don't deep-dive unless they impact technical feasibility.
```

When building the input for each reviewer, concatenate: context preamble + blank line + document content. Use `printf '%s\n\n%s\n\n%s'` with three parts: prompt, preamble content, document content.

Run all reviewers as background Bash tasks concurrently. Save each to temp directory: `<workdir>/review-<reviewer>.md` (e.g., `review-chatgpt.md`, `review-gemini.md`, `review-copilot.md`).

If a reviewer fails, log the error and proceed with the others.

### Step 4: Synthesize

Read all review files and the original doc. Classify every finding into one engineering-centric category. Note which reviewers flagged each finding and how many agree.

With a single reviewer, all findings are single-source. With 2+ reviewers, note agreement counts -- findings flagged by multiple reviewers have higher confidence. With 3 reviewers, "all three agree" is stronger than "two of three."

Write the consolidated review to the **final location** (next to source doc): `<docname>-review-consolidated.md`

Use this structure (adapt reviewer names to actual reviewers used):

```markdown
# Consolidated Review: <docname>

Reviewed by: <list of reviewer display names>
Synthesized by: Claude

## Summary
<2-3 sentences: what type of document, total findings, key themes>

## Critical Issues (Must Fix Before Implementation)
Design flaws, missing components, or unhandled failure modes that will cause production incidents.

| # | Issue | Severity | Flagged By | Affected Sections | Technical Risk |
|---|-------|----------|-----------|-------------------|----------------|

### Details
#### 1. <Issue title>
**<Reviewer A> said:** <quote or paraphrase>
**<Reviewer B> said:** <quote or paraphrase> (if multiple flagged)
**Affected sections:** <section names>
**Technical risk:** <what breaks if not fixed>
**Recommended action:** <specific fix>

## Implementation Gaps
Missing pieces needed to actually build/deploy this: configs, schemas, error handling, integrations.

| # | Gap | Flagged By | Affected Sections | What's Needed |
|---|-----|-----------|-------------------|---------------|

### Details
(same format -- what's missing and what's needed to fill it)

## Risk Factors (Edge Cases & Failure Scenarios)
Things that work in happy path but could break under load, network issues, or edge conditions.

| # | Risk | Flagged By | Failure Scenario | Mitigation |
|---|------|-----------|------------------|-----------|

## Operational Concerns
Gaps in monitoring, debugging, incident response, or operational procedures.

| # | Concern | Flagged By | Impact on Operations |
|---|---------|-----------|---------------------|

## Security Issues
Authentication, authorization, secrets, privilege escalation, data exposure risks.

| # | Issue | Flagged By | Security Impact |
|---|-------|-----------|-----------------|

## Design Improvements
Better patterns, simpler alternatives, or refactoring suggestions.

| # | Suggestion | Flagged By | Benefit |
|---|-----------|-----------|---------|

## Contradictions (Models Disagree)
Technical disagreements requiring engineering judgment.

| # | Topic | Positions | Recommendation |
|---|-------|-----------|----------------|

### Details
(For each contradiction, present technical arguments from each reviewer)

## False Positives (Already Addressed)
| # | Flagged Issue | Reviewer | Already Covered In |
|---|---------------|----------|--------------------|

## Action Items (Priority Order)
- [ ] <action> -- [Critical/Gap/Risk/Operational/Security/Design] -- Section: <x>
```

### Step 5: Present and Ask

Report the summary to the user in chat. Then ask:

```
Round 1 complete. You have three options:
1) Stop here -- work from the action items list
2) Round 2: Rebuttal -- I'll respond to each finding (accept/reject/partial), send rebuttals back to the reviewers, and see if they hold their positions
3) Skip to updating the doc -- I'll apply the accepted changes directly
```

Use `AskUserQuestion` with these three options.

If the user stops here, proceed to **Cleanup**.

---

## Round 2: Rebuttal (Optional)

Only runs if the user chooses to continue. The goal is to challenge the reviewers' findings and let them defend or withdraw.

### Step 6: Claude Writes Rebuttal

Read the consolidated review and original doc. For EACH finding (agreed, unique, contradiction), write one of:

- **Accept** -- the finding is valid, state what will change
- **Reject** -- the finding is wrong, explain why with specific references to the doc
- **Partially Accept** -- the core concern is valid but the suggested fix is wrong or the scope is different than claimed
- **Defer** -- valid but out of scope for this version, explain why

Write to temp directory: `<workdir>/rebuttal.md`

Use this structure:

```markdown
# Rebuttal: <docname>

## Accepted (will fix)
| # | Original Finding | Response | Planned Change |
|---|-----------------|----------|----------------|

## Rejected (disagree)
| # | Original Finding | Rejection Rationale |
|---|-----------------|---------------------|

### Details
#### <Finding title>
**Original claim:** <what was said>
**Why it's wrong:** <specific reference to doc section, technical argument>

## Partially Accepted
| # | Original Finding | What We Accept | What We Reject |
|---|-----------------|----------------|----------------|

## Deferred (valid, not now)
| # | Original Finding | Why Deferred | When to Address |
|---|-----------------|--------------|-----------------|
```

### Step 7: Send Rebuttal to Reviewers

Send the rebuttal + original doc back to all reviewers in parallel with this prompt:

```
You previously reviewed a technical document and provided feedback.
The document author has responded to your findings with a rebuttal.

For each item in the rebuttal:
- If ACCEPTED: acknowledge, no further action needed
- If REJECTED: do you still hold your position? If yes, explain why the rebuttal is insufficient. If the rebuttal convinced you, withdraw your finding.
- If PARTIALLY ACCEPTED: is the partial acceptance sufficient? What's still missing?
- If DEFERRED: is deferral reasonable or is this a risk that must be addressed now?

Be direct. If you were wrong, say so. If you still disagree, strengthen your argument.
```

Append the rebuttal file content after the prompt. Save responses to temp directory: `<workdir>/rebuttal-<reviewer>.md` for each reviewer.

### Step 8: Present and Ask

Summarize the second-round responses in chat. Highlight:
- Findings where reviewers withdrew (resolved)
- Findings where reviewers pushed back (still contested)
- New concerns raised in response to the rebuttal

Then ask:

```
Round 2 complete. Options:
1) Stop here -- work from accepted items + contested items for your judgment
2) Round 3: Consensus -- I'll classify everything as Consensus/Resolved/Deadlocked and present deadlocked items for your decision
```

If the user stops here, proceed to **Cleanup**.

---

## Round 3: Consensus (Optional)

Only runs if the user chooses to continue. The goal is to reach final decisions.

### Step 9: Build Consensus Document

Read all files produced so far. Two tasks: classify findings and detect holdouts.

#### 9a: Reviewer Flexibility Scorecard

Before classifying findings, compute each reviewer's flexibility score from their rebuttal responses:

For each reviewer, count:
- **Withdrew** -- reviewer conceded or withdrew a finding after rebuttal
- **Held** -- reviewer maintained their position
- **Escalated** -- reviewer raised new concerns in rebuttal response

Compute: `flexibility_rate = withdrew / (withdrew + held)`

Flag a reviewer as a **potential holdout** if:
- `flexibility_rate == 0` (withdrew nothing) AND they had 3+ findings challenged
- OR they escalated more items than they withdrew

This does NOT auto-dismiss their findings. It adds context for the user's decision-making. Include the scorecard in the consensus document.

#### 9b: Classify Findings

Classify every original finding into:

- **Consensus** -- all parties agree (accepted findings + reviewer withdrawals)
- **Resolved** -- rebuttal was accepted by reviewers, finding withdrawn
- **Deadlocked** -- still disagreeing after rebuttal round

For deadlocked items:
1. Note how many reviewers hold the position vs. disagree. A single holdout against Claude + all other reviewers is weaker than multiple reviewers holding firm.
2. Run a **pre-mortem**: "It's 6 months from now and this system failed in production because we ignored this concern. How did it fail? How bad was it?"
3. If the holdout reviewer was flagged in the scorecard, add a note: "Note: <Reviewer> withdrew 0 of N challenged findings. Consider whether this position reflects genuine technical concern or a pattern of inflexibility."

Write to **final location** (next to source doc): `<docname>-consensus.md`

Use this structure:

```markdown
# Consensus: <docname>

## Reviewer Flexibility Scorecard
| Reviewer | Findings Challenged | Withdrew | Held | Escalated | Flexibility Rate | Flag |
|----------|-------------------|----------|------|-----------|-----------------|------|
| <name>   | N                 | N        | N    | N         | N%              | --/Holdout |

(If any reviewer is flagged: "Holdout flag does not invalidate findings -- it provides
context for weighting contested positions.")

## Consensus Items (agreed by all)
| # | Item | Resolution | Owner |
|---|------|-----------|-------|

## Resolved Items (rebuttal accepted)
| # | Item | Original Concern | Why Resolved |
|---|------|-----------------|--------------|

## Deadlocked Items (needs human decision)

### DL-X: <Technical Issue Title>

**The technical problem:** <what will break or what's missing>

**Model positions:**
- **<Reviewer A>:** <technical argument with specifics>
- **<Reviewer B>:** <technical argument with specifics>
- **<Reviewer C>:** <technical argument with specifics>

**Support:** X reviewers support position A, Y reviewers support position B

**Held by:** <which reviewer(s)> <holdout flag if applicable>

**Blast radius if wrong:** <what breaks in production -- concrete failure scenario>

**Technical options:**
  A) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>
  B) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>
  C) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>

**Recommendation:** <which option and why -- based on engineering judgment, not ROI>

## Final Action Items
- [ ] <item> -- [Consensus/Resolved/Deadlocked-decided] -- Section: <x>
```

### Step 10: Present Deadlocked Items

Present each deadlocked item to the user with the options. Use `AskUserQuestion` for each one (or batch them if there are few). The user makes the final call.

After decisions are made, update the consensus doc with the decisions.

Then ask:

```
Round 3 complete. Options:
1) Stop here -- work from the final action items
2) Round 4: Decision Records -- I'll generate formal decision records for every significant decision
```

If the user stops here, proceed to **Cleanup**.

---

## Round 4: Decision Records (Optional)

Only runs if the user chooses to continue. Produces a formal record of what was decided and why.

### Step 11: Generate Decision Records

For every significant decision (accepted changes, rejected concerns, deadlocked items that were decided), write a decision record.

Write to **final location** (next to source doc): `<docname>-decisions.md`

Use this structure:

```markdown
# Decision Records: <docname>

## DR-001: <Decision Title>
**Status:** Accepted
**Context:** <why this decision was needed>
**Options Considered:**
1. <option A> -- <pros/cons>
2. <option B> -- <pros/cons>
**Decision:** <what was decided>
**Consequences:** <what changes, what risks are accepted>
**Reviewed by:** <list of reviewers>, Claude, <user>

(repeat for each significant decision)
```

### Step 12: Final Report

Present the complete set of output files to the user. Summarize the journey:
- How many findings were raised
- How many were accepted, rejected, deferred
- How many went to deadlock, how they were resolved
- The final list of changes to make to the document

Proceed to **Cleanup**.

---

## Handling Strategic/Business Concerns

If models raise cost, training, capacity planning, or other strategic concerns:

1. **Acknowledge briefly** in consolidated review: "Note: Models flagged potential cost/training concerns. See individual reviews for details."

2. **Do NOT elevate to deadlock** unless the concern makes the solution technically infeasible:
   - Elevate: "This requires 500TB RAM per node" (when max is 100TB) -- blocks implementation
   - Don't elevate: "This might cost $10K/month more" -- business decision, not technical blocker

3. **Do NOT include** in pre-mortem analysis or final action items.

The review board focuses on engineering quality. Strategic concerns belong in separate business case analysis.

---

## Cleanup

At the end of the workflow (regardless of which round the user stopped at):

1. Ask the user: "Delete the intermediate review files in `<workdir>/`? The final deliverables next to your doc are kept either way."
2. If yes (default): `rm -rf "<workdir>"`
3. If no: tell the user the path so they can review the raw files later.

Use `AskUserQuestion` with two options: "Delete temp files (Recommended)" and "Keep temp files".

---

## Tools Used

| Tool | Purpose |
|------|---------|
| `AskUserQuestion` | Ask for file, present round options, resolve deadlocks, cleanup |
| `Read` | Validate source doc, read all review/rebuttal files |
| `Bash` | Check CLI prerequisites, create/delete temp directory |
| `Bash` (background) | Run reviewer CLIs in parallel |
| `TaskOutput` | Wait for background task completion |
| `Write` | Save all output files |

## Error Handling

- If a file path is invalid, ask the user to correct it
- If a reviewer CLI is missing, skip it and proceed with available reviewers (note in consolidated output)
- If a reviewer fails during any round, proceed with the others (note the gap in output)
- If all reviewers fail, report errors and stop that round
- Suppress stderr with `2>/dev/null` on all CLIs
- GitHub Copilot CLI syntax may change across versions -- if `gh copilot explain` fails, try `gh copilot` with alternative flags or skip with a warning
