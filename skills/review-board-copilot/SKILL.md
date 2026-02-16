---
name: review-board-copilot
description: >
  Multi-model review board powered by GitHub Copilot CLI. Sends any document to
  multiple AI models (GPT, Claude, Gemini) via a single Copilot CLI for independent
  review, synthesizes feedback, then optionally drives rebuttal rounds and consensus
  building. Uses Copilot subscription tokens instead of separate API keys.
  Trigger phrases include "copilot review", "review board copilot",
  "multi-model review", "debate this", "copilot debate", or any request
  for Copilot-powered document review or focused design debate.
---

# Review Board (Copilot Multi-Model)

Multi-round document review process using GitHub Copilot CLI with different models as independent reviewers and Claude as the synthesizer and moderator. Each model acts as a separate reviewer on the panel. Each round after Round 1 is optional.

## Why Copilot

- Single CLI, single subscription -- no separate API keys for OpenAI, Google, Anthropic
- Access to 16+ models across GPT, Claude, and Gemini families
- Token cost covered by Copilot subscription
- Consistent CLI interface regardless of model

## Available Models (Dynamic Discovery)

Models are discovered at runtime. Do NOT hardcode model lists.

**To get the current model list**, run:
```bash
gh copilot -- --help 2>&1 | tr '\n' ' ' | grep -o '"claude-[^"]*"\|"gpt-[^"]*"\|"gemini-[^"]*"\|"o[0-9][^"]*"' | tr -d '"' | sort
```

This parses `--model` choices from the help output. Models change over time as providers add/remove them.

**Categorize discovered models by provider:**
- `gpt-*` -- OpenAI
- `claude-*` -- Anthropic
- `gemini-*` -- Google
- `o*` (e.g. `o3`, `o4-mini`) -- OpenAI reasoning

**To build the default panel**, pick one model per provider using this preference order:
- OpenAI: largest `gpt-*-codex` variant > largest `gpt-*` > any `gpt-*`
- Anthropic: `claude-sonnet-*` (balanced) > `claude-opus-*` (if no sonnet)
- Google: any `gemini-*`

**To build the max depth panel**, pick the most capable model per provider:
- OpenAI: largest `gpt-*-codex` or `gpt-*-codex-max` variant
- Anthropic: `claude-opus-*` (non-fast variant)
- Google: any `gemini-*`

**To build the quick panel**, pick the fastest/cheapest:
- Any `gpt-*-mini` or `claude-haiku-*`

## Prerequisites

GitHub Copilot CLI must be installed:
```bash
gh copilot -- --version 2>/dev/null
```

If not available, report the error and stop.

## Model Selection

### Step 0: Discover Models and Choose the Panel

**First, discover available models** by running the discovery command from the "Available Models" section above. Parse the output into a list and categorize by provider (OpenAI/Anthropic/Google).

**Then, build the preset panels dynamically** from the discovered models using the preference rules in the "Available Models" section.

**Then ask** the user how they want to compose the review panel using `AskUserQuestion`. Show the actual model names in each preset (not hardcoded names):

```
How should I compose the review panel?
1) Default panel (<best-gpt>, <best-sonnet>, <best-gemini>) -- one from each provider (Recommended)
2) Pick models -- I'll show you the full list of <N> available models
3) All providers, max depth -- <best-codex>, <best-opus>, <best-gemini>
4) Quick review -- <best-mini>, <best-haiku> (fast, two models)
```

If the user chooses "Pick models", present the full discovered model list and let them select 2-4 models using a multi-select `AskUserQuestion`.

Store the selected models for use in all rounds.

## Mode Detection

This skill supports two modes. Detect the mode from the invocation arguments:

- **Review mode** (default): `/review-board-copilot <file>` -- full 7-category review with optional rebuttal/consensus rounds. Any invocation where the first argument is NOT `debate`.
- **Debate mode**: `/review-board-copilot debate <file> "question1" "question2"` -- focused design debate on specific questions against a reference document.

**Detection rule:** If the first argument is literally `debate`, enter debate mode and parse remaining arguments as `<file> "question1" "question2" ...`. Otherwise, enter review mode (the existing workflow starting at Round 1).

**If invoked as just `/review-board-copilot debate` with no further arguments**, ask for the file path and debate questions via `AskUserQuestion` (free-text input for questions).

Everything below the mode split -- CLI invocation, model discovery, directory access, background tasks, context preamble, cleanup -- is shared between both modes.

## File Organization

All intermediate files go in a temp working directory. Only the final deliverable(s) are saved next to the source document.

**Temp directory:** `<doc_dir>/.review-board-<docname>/`

Create this directory at the start of the workflow.

**Final deliverables** (saved next to the source doc):
- `<docname>-review-consolidated.md` -- always produced (review mode, Round 1)
- `<docname>-consensus.md` -- only if Round 3 runs (review mode)
- `<docname>-decisions.md` -- only if Round 4 runs (review mode)
- `<docname>-debate.md` -- always produced (debate mode)

**Temp files** (in the working directory, cleaned up at the end):
- `context-preamble.md` -- project context prepended to doc for reviewers
- `review-<model>.md` -- raw review from each model (review mode)
- `rebuttal.md` -- Claude's rebuttal (review mode)
- `rebuttal-<model>.md` -- each model's response to the rebuttal (review mode)
- `debate-<model>-q<N>.md` -- raw argument from each model per question (debate mode)
- `counter-<model>-q<N>.md` -- counterargument responses from Round 2 (debate mode)

**Cleanup:** When the workflow completes, ask the user whether to keep or delete the temp working directory. Default: delete.

### Setup Commands

```bash
mkdir -p "<doc_dir>/.review-board-<docname>"
```

## CLI Invocation Details

All reviews go through a single CLI: `gh copilot`.

**Important shell details:**
- Use `printf '%s\n\n%s'` instead of `echo` to handle large documents safely.
- Use `-p` for non-interactive prompt execution.
- Use `-s` (silent) to suppress stats and get clean output.
- Use `--model` to select the specific model for each reviewer.
- Use `--add-dir` to give the model access to the project codebase.
- Use `--allow-all-tools` to let the model browse files without prompting.
- Use `--no-custom-instructions` to prevent repo-local instructions from biasing the review.
- Set `timeout: 600000` on all Bash calls.
- Run all models as background Bash tasks (`run_in_background: true`) concurrently.
- Use `TaskOutput` with `block: true` and `timeout: 300000` to wait for each.
- Suppress stderr with `2>/dev/null`.

### Working Directory

Determine the project root: walk up from the document's directory looking for `.git`, `go.mod`, `package.json`, or similar project markers. If found, use that as `$PROJECT_DIR`. If not found, use the document's parent directory.

### Directory Access (Critical)

External models need three things to browse the codebase:

1. **CWD set to the project root** -- `cd "$PROJECT_DIR"` before invoking `gh copilot`. This makes the project the model's working directory so relative paths resolve correctly.
2. **`--add-dir` for explicit path whitelisting** -- still pass `--add-dir "$PROJECT_DIR"` as a safety net.
3. **Project path in the prompt** -- explicitly tell the model where the code lives: "The project source code is at `$PROJECT_DIR`." Models that can browse files need to know the path, not just have permission to access it.

### Invocation Pattern

For each model on the panel:
```bash
cd "$PROJECT_DIR" && gh copilot -- -p "${PROMPT}

$(cat "$PREAMBLE_FILE")

$(cat "$INPUT_FILE")" --model "$MODEL" --add-dir "$PROJECT_DIR" --allow-all-tools --no-custom-instructions -s > "$OUTPUT_FILE" 2>/dev/null
```

**Why `cd` matters:** Without it, `gh copilot` runs from Claude's CWD which may be unrelated to the project. The model's file browsing tools resolve paths relative to CWD. Setting CWD to the project root means `ls`, `cat internal/...`, etc. work without full absolute paths.

### Display Names

In all output files, use the model ID as the reviewer name (e.g., "gpt-5.2", "claude-sonnet-4.5"). This is clearer than inventing aliases when all reviews come from the same CLI.

---

## Round 1: Initial Review + Synthesis

This round always runs.

### Step 1: Ask for the File

Always ask the user which file to review using `AskUserQuestion`. Do not auto-detect or assume. If the user provides a file path as an argument, confirm it and proceed.

### Step 2: Validate and Setup

1. Read the file with the `Read` tool. If it does not exist or is empty, report the error and stop.
2. Verify Copilot CLI: `gh copilot -- --version 2>/dev/null`. If not available, stop.
3. Run model selection (Step 0 above) if not already done.
4. Create the temp working directory.
5. Tell the user: "Review panel: <list of models>". No confirmation needed -- just inform.

### Step 2.5: Build Context Preamble

External models receive only the document text -- they have no knowledge of the project, repo, codebase, or team constraints. Claude DOES have this context from the current session. Use it.

**Generate a context preamble** and write it to `<workdir>/context-preamble.md`.

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

### Step 3: Collect Reviews

Send the context preamble + doc to all selected models in parallel using this review prompt (replace `$PROJECT_DIR` with the actual absolute path):

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

Run all models concurrently as background tasks. Save each to: `<workdir>/review-<model>.md`.

If a model fails, log the error and proceed with the others.

### Step 4: Synthesize

Read all review files and the original doc. Classify every finding into one engineering-centric category. Note which models flagged each finding and how many agree.

With a single model, all findings are single-source. With 2+ models, note agreement counts -- findings flagged by multiple models have higher confidence.

Write `<docname>-review-consolidated.md` (next to source doc):

```markdown
# Consolidated Review: <docname>

Review Panel: <list of model IDs>
Synthesized by: Claude

## Summary
<2-3 sentences: what type of document, total findings, key themes>

## Critical Issues (Must Fix Before Implementation)
Design flaws, missing components, or unhandled failure modes that will cause production incidents.

| # | Issue | Severity | Flagged By | Affected Sections | Technical Risk |
|---|-------|----------|-----------|-------------------|----------------|

### Details
#### 1. <Issue title>
**<model-a> said:** <quote or paraphrase>
**<model-b> said:** <quote or paraphrase> (if multiple flagged)
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

| # | Topic | Model Positions | Recommendation |
|---|-------|----------------|----------------|

### Details
(For each contradiction, present technical arguments from each model)

## False Positives (Already Addressed)
| # | Flagged Issue | Model | Already Covered In |
|---|---------------|-------|--------------------|

## Action Items (Priority Order)
- [ ] <action> -- [Critical/Gap/Risk/Operational/Security/Design] -- Section: <x>
```

### Step 5: Present and Ask

Report the summary to the user in chat. Then ask:

```
Round 1 complete. You have three options:
1) Stop here -- work from the action items list
2) Round 2: Rebuttal -- I'll respond to each finding (accept/reject/partial), send rebuttals back to the models, and see if they hold their positions
3) Skip to updating the doc -- I'll apply the accepted changes directly
```

Use `AskUserQuestion` with these three options.

If the user stops here, proceed to **Cleanup**.

---

## Round 2: Rebuttal (Optional)

### Step 6: Claude Writes Rebuttal

Read the consolidated review and original doc. For EACH finding, write one of:

- **Accept** -- the finding is valid, state what will change
- **Reject** -- the finding is wrong, explain why with specific references
- **Partially Accept** -- core concern valid but suggested fix is wrong
- **Defer** -- valid but out of scope for this version

Write to `<workdir>/rebuttal.md`:

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

### Step 7: Send Rebuttal to Models

Send the rebuttal + original doc back to all models in parallel (same models as Round 1) with this prompt:

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

Save responses to `<workdir>/rebuttal-<model>.md` for each model.

### Step 8: Present and Ask

Summarize the second-round responses. Highlight:
- Findings where models withdrew (resolved)
- Findings where models pushed back (still contested)
- New concerns raised

Then ask:

```
Round 2 complete. Options:
1) Stop here -- work from accepted items + contested items for your judgment
2) Round 3: Consensus -- I'll classify everything and present deadlocked items for your decision
```

If the user stops here, proceed to **Cleanup**.

---

## Round 3: Consensus (Optional)

### Step 9: Build Consensus Document

#### 9a: Model Flexibility Scorecard

Compute each model's flexibility score from their rebuttal responses:

- **Withdrew** -- model conceded or withdrew a finding
- **Held** -- model maintained position
- **Escalated** -- model raised new concerns

Compute: `flexibility_rate = withdrew / (withdrew + held)`

Flag a model as a **potential holdout** if:
- `flexibility_rate == 0` AND 3+ findings challenged
- OR escalated more than withdrew

This provides context, not auto-dismissal.

#### 9b: Classify Findings

- **Consensus** -- all parties agree
- **Resolved** -- rebuttal accepted, finding withdrawn
- **Deadlocked** -- still disagreeing

For deadlocked items:
1. Note support count (how many models hold vs. disagree)
2. Run a **pre-mortem**
3. If holdout flagged, add context note

Write `<docname>-consensus.md` (next to source doc):

```markdown
# Consensus: <docname>

## Model Flexibility Scorecard
| Model | Findings Challenged | Withdrew | Held | Escalated | Flexibility Rate | Flag |
|-------|-------------------|----------|------|-----------|-----------------|------|

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
- **<model-a>:** <technical argument with specifics>
- **<model-b>:** <technical argument with specifics>
- **<model-c>:** <technical argument with specifics>

**Support:** X models support position A, Y models support position B

**Held by:** <which model(s)> <holdout flag if applicable>

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

Present each deadlocked item to the user with options. Use `AskUserQuestion`.

After decisions, update the consensus doc.

Then ask:

```
Round 3 complete. Options:
1) Stop here -- work from the final action items
2) Round 4: Decision Records
```

If the user stops here, proceed to **Cleanup**.

---

## Round 4: Decision Records (Optional)

### Step 11: Generate Decision Records

Write `<docname>-decisions.md` (next to source doc):

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
**Reviewed by:** <model list>, Claude, <user>
```

### Step 12: Final Report

Summarize the journey and list all output files. Proceed to **Cleanup**.

---

## Debate Mode

Focused design debate where external models argue specific questions against a reference document and Claude synthesizes the arguments. Use this instead of full review mode when you have targeted questions like "Is this component over-engineered?" or "Should we use approach A vs B?"

Debate mode reuses the same infrastructure as review mode: CLI invocation, model discovery, panel selection, context preamble, directory access, background tasks, and cleanup.

### Debate Round 1: Opening Arguments

#### Step D1: Parse Arguments

Extract the file path and 1-4 debate questions from the invocation arguments.

- Arguments follow the pattern: `debate <file> "question1" "question2" ...`
- If the file path is provided but no questions, ask via `AskUserQuestion` with a free-text option: "What design questions should the panel debate? (1-4 questions)"
- If neither file nor questions are provided, ask for both.
- Limit: 4 questions max per debate session. If more are provided, take the first 4 and inform the user.

#### Step D2: Validate and Setup

Same as review mode:

1. Read the file with the `Read` tool. If it does not exist or is empty, report the error and stop.
2. Verify Copilot CLI: `gh copilot -- --version 2>/dev/null`. If not available, stop.
3. Run model selection (Step 0) if not already done.
4. Create the temp working directory: `<doc_dir>/.review-board-<docname>/`
5. Build the context preamble (Step 2.5 from review mode).
6. Tell the user: "Debate panel: <list of models>. Questions: <numbered list>".

#### Step D3: Collect Arguments

Send each question to all models in parallel. Use the same CLI invocation pattern as review mode, but with a debate-specific prompt.

For each model, for each question, run as a background task:

```bash
cd "$PROJECT_DIR" && gh copilot -- -p "You are a principal engineer participating in a design debate about the following document.

$(cat "$PREAMBLE_FILE")

$(cat "$INPUT_FILE")

IMPORTANT: The project source code is in your current working directory ($PROJECT_DIR).
Browse the codebase to ground your arguments in the actual implementation.

Answer this specific design question:

\"<QUESTION>\"

Structure your response as:

## Position
State your position clearly: is this justified, over-engineered, under-engineered, or wrong approach?

## Arguments For (why this design choice is justified)
- Concrete technical arguments with references to the document and code
- What problems does it solve? What breaks without it?

## Arguments Against (why this might be unnecessary or wrong)
- What would be simpler? What's the cost of this complexity?
- Is there a real-world scenario where this matters, or is it theoretical?

## Verdict
Your recommendation: keep, simplify, remove, or replace with alternative.

Be direct. Take a clear position. Do not hedge." --model "$MODEL" --add-dir "$PROJECT_DIR" --allow-all-tools --no-custom-instructions -s > "$OUTPUT_FILE" 2>/dev/null
```

Save output to: `<workdir>/debate-<model>-q<N>.md` (one file per model per question).

All models and all questions run concurrently as background tasks. Use `TaskOutput` with `block: true` and `timeout: 300000` to collect results.

If a model fails on a question, log the error and proceed with the others.

#### Step D4: Synthesize

Read all debate argument files and the original document. For each question, classify the panel's position:

- **Consensus** -- all models agree on the same verdict (keep / remove / simplify / replace)
- **Split** -- models disagree -- present both sides with argument strength

Write `<docname>-debate.md` (next to the source doc):

```markdown
# Design Debate: <docname>

Debate Panel: <list of model IDs>
Synthesized by: Claude

---

## Q1: <question text>

### Panel Positions
| Model | Position | Confidence |
|-------|----------|------------|
| <model-a> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |
| <model-b> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |
| <model-c> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |

### Arguments For
<strongest arguments from models that support the design, with attribution>

### Arguments Against
<strongest arguments from models that oppose the design, with attribution>

### Claude's Assessment
<Claude's own technical judgment weighing both sides, referencing the code and document>

### Verdict: <Consensus: Keep / Split: 2 Keep, 1 Remove / etc.>

---

## Q2: <question text>

(repeat for each question)

---

## Summary
| # | Question | Verdict | Action |
|---|----------|---------|--------|
| 1 | <short question> | Consensus: Keep / Split: 2-1 | <recommended next step> |
| 2 | <short question> | ... | ... |
```

**Confidence scoring:** Infer confidence from how strongly a model argues its position:
- **Strong** -- clear position with multiple concrete arguments referencing code/doc
- **Moderate** -- clear position but arguments are more theoretical
- **Weak** -- hedged position, "it depends", or thin argument

#### Step D5: Present and Ask

Report the summary to the user in chat. Then ask:

```
Debate complete. Options:
1) Stop here -- use the verdicts
2) Round 2: Counterarguments -- I'll challenge the minority position (or challenge consensus if I disagree), send back to models, see if anyone changes their mind
```

Use `AskUserQuestion` with these two options.

If the user stops here, proceed to **Cleanup**.

---

### Debate Round 2: Counterarguments (Optional)

#### Step D6: Claude Writes Counterarguments

For each question, identify which positions to challenge:

- **If models disagree (split):** Write a counterargument challenging the weaker/minority position. The goal is to stress-test whether the minority has a point or if the majority is right.
- **If all models agree but Claude disagrees:** Claude argues the opposing side directly. State why Claude disagrees and present the counter-case.
- **If all models agree and Claude agrees:** Skip this question in Round 2 -- the consensus is solid.

#### Step D7: Send Counterarguments to Models

For each question being challenged, send the counterargument to all models using the same background task pattern:

```
You previously argued the following position on a design question:

Question: "<QUESTION>"
Your position: <model's original position summary>

Here is a counterargument challenging your position:

<counterargument text>

Do you hold your position or change your mind?
- If you change: explain what convinced you and state your new position.
- If you hold: strengthen your argument -- address the counterargument directly.

Be direct.
```

Save responses to: `<workdir>/counter-<model>-q<N>.md`

#### Step D8: Present Final Positions

Update the debate synthesis with Round 2 results. For each challenged question:

- Note who changed position and who held
- Update the verdict if the balance shifted
- Present the final summary

Append a `## Round 2: Counterarguments` section to `<docname>-debate.md`:

```markdown
## Round 2: Counterarguments

### Q<N>: <question text>

**Challenge:** <summary of the counterargument sent>

| Model | Original Position | Final Position | Changed? |
|-------|------------------|----------------|----------|
| <model-a> | Keep | Keep | No -- strengthened argument |
| <model-b> | Remove | Keep | Yes -- convinced by X |
| <model-c> | Keep | Keep | No |

**Final Verdict:** <updated verdict>

---

## Final Summary
| # | Question | Round 1 Verdict | Round 2 Verdict | Action |
|---|----------|-----------------|-----------------|--------|
```

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

1. Ask: "Delete the intermediate review files in `<workdir>/`?"
2. If yes (default): `rm -rf "<workdir>"`
3. If no: tell the user the path.

Use `AskUserQuestion` with "Delete temp files (Recommended)" and "Keep temp files".

---

## Tools Used

| Tool | Purpose |
|------|---------|
| `AskUserQuestion` | File selection, model selection, round/debate options, deadlocks, cleanup |
| `Read` | Validate source doc, read review/rebuttal/debate argument files |
| `Bash` | Check CLI, create/delete temp directory |
| `Bash` (background) | Run `gh copilot` with different models in parallel (review and debate) |
| `TaskOutput` | Wait for background task completion |
| `Write` | Save all output files (consolidated reviews, debate synthesis, etc.) |

## Error Handling

- If Copilot CLI is not installed, report error and stop
- If a model fails, proceed with the others (note in output)
- If all models fail, report errors and stop that round
- If a model is not available in the user's Copilot subscription, skip with warning
- Suppress stderr with `2>/dev/null`
