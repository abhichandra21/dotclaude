---
name: code-review-copilot
description: >
  Multi-model code review board powered by GitHub Copilot CLI. Reviews PRs,
  branches, commits, or uncommitted changes by sending review targets to
  multiple AI models (GPT, Claude, Gemini) via Copilot CLI. Models fetch
  diffs and browse the codebase independently, then Claude synthesizes
  findings through optional rebuttal and consensus rounds. Uses Copilot
  subscription tokens instead of separate API keys.
  Trigger phrases include "code review copilot", "copilot code review",
  "review this PR", "review my changes", "review this branch",
  "copilot debate code", or any request for Copilot-powered code review
  or code-focused design debate.
---

# Code Review Board (Copilot Multi-Model)

Multi-round code review process using GitHub Copilot CLI with different models as independent reviewers and Claude as the synthesizer and moderator. Each model acts as a separate reviewer on the panel. Each round after Round 1 is optional.

Unlike the document review skill, models here receive a **review target** (PR number, branch, commit, or "uncommitted") and use their own tools to fetch diffs, browse files, and investigate the codebase. No diff is piped into the prompt.

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

## Review Targets (4 Input Types)

This skill reviews code changes, not documents. Detect the review target from the invocation arguments:

### Detection Rules

1. **PR review** -- argument matches `#<number>` or contains `github.com/.*/pull/<number>`. Extract the PR number.
2. **Commit review** -- argument is a 7-40 character hex string (matches `^[0-9a-f]{7,40}$`). Verify with `git rev-parse --verify <arg>`.
3. **Uncommitted changes** -- argument is literally `uncommitted`.
4. **Branch review** -- anything else. Verify the branch exists with `git rev-parse --verify <arg>`.

**If ambiguous** (e.g., a branch name that looks like a hex string), ask the user via `AskUserQuestion`: "Is `abc1234` a commit SHA or a branch name?"

**If no argument provided**, ask the user what to review via `AskUserQuestion` with options: PR number, branch name, commit SHA, or uncommitted changes.

### Gathering Change Metadata

After detecting the target, gather metadata for the context preamble:

- **PR:** `gh pr view <number> --json title,body,additions,deletions,changedFiles,baseRefName,headRefName,files`
- **Branch:** `git log --oneline main..<branch>` for commit list, `git diff --stat main...<branch>` for file stats
- **Commit:** `git log -1 --format='%s%n%n%b' <sha>` for message, `git diff --stat <sha>^..<sha>` for file stats
- **Uncommitted:** `git diff --stat` for staged+unstaged, `git status --short` for untracked files

Store: change summary, file count, additions/deletions, affected areas.

### File Filtering

Before sending diffs to reviewers, exclude files that produce noise rather than signal. Add this instruction to the review prompt so models skip them too.

**Always skip these patterns** (generated code, vendored deps, lockfiles):
- `vendor/`, `node_modules/`, `third_party/`
- `*.pb.go`, `*_pb2.py`, `*.pb.h`, `*.pb.cc` (protobuf generated)
- `*_generated.*`, `*_gen.go`, `*.gen.ts`
- `*.lock`, `package-lock.json`, `yarn.lock`, `go.sum`, `Cargo.lock`
- `*.min.js`, `*.min.css` (minified assets)
- `*.snap` (test snapshots)
- `swagger_*.go`, `*_swagger.json`, `openapi_*.yaml` (API spec generated)
- `mocks/*`, `*_mock.go`, `mock_*.py` (generated mocks)

**Include in the review prompt as:**
```
Skip these files entirely -- do not review generated code, vendored dependencies, or lockfiles:
vendor/, node_modules/, third_party/, *.pb.go, *_pb2.py, *_generated.*, *_gen.go,
*.lock, package-lock.json, go.sum, *.min.js, *.min.css, *.snap, mocks/*
If a changed file matches these patterns, note "Skipped (generated/vendored)" and move on.
```

**When gathering change metadata**, also count how many files are skipped so the user knows the effective review scope.

## Mode Detection

This skill supports two modes. Detect the mode from the invocation arguments:

- **Review mode** (default): `/code-review-copilot <target>` or `/code-review-copilot <target> "focus area"` -- full 7-category code review with optional rebuttal/consensus rounds.
- **Debate mode**: `/code-review-copilot debate <target> "question1" "question2"` -- focused design debate on specific code questions.

**Detection rule:** If the first argument is literally `debate`, enter debate mode and parse remaining arguments as `<target> "question1" "question2" ...`. Otherwise, enter review mode.

**If invoked as just `/code-review-copilot debate` with no further arguments**, ask for the review target and debate questions via `AskUserQuestion`.

Everything below the mode split -- CLI invocation, model discovery, directory access, background tasks, context preamble, cleanup -- is shared between both modes.

## Review Focus (Optional)

The user can optionally specify a focus area after the target:
- `/code-review-copilot #42 "focus on the authentication changes"`
- `/code-review-copilot uncommitted "focus on error handling"`

If present, this gets added to the review prompt as a focus directive. Without it, models do a full-spectrum review across all 7 categories.

## File Organization

All intermediate files go in a temp working directory at the project root. Final deliverables go in a `.code-reviews/` directory at the project root.

**Temp directory:** `$PROJECT_DIR/.code-review-copilot-<target>/`
  - `<target>` = `pr-42`, `branch-feature-x`, `commit-abc1234`, or `uncommitted`

Create this directory at the start of the workflow.

**Final deliverables** (in `$PROJECT_DIR/.code-reviews/`):
- `<target>-review-consolidated.md` -- always produced (review mode, Round 1)
- `<target>-consensus.md` -- only if Round 3 runs (review mode)
- `<target>-decisions.md` -- only if Round 4 runs (review mode)
- `<target>-debate.md` -- always produced (debate mode)

**Temp files** (in the working directory, cleaned up at the end):
- `context-preamble.md` -- project context and change metadata for reviewers
- `review-<model>.md` -- raw review from each model (review mode)
- `rebuttal.md` -- Claude's rebuttal (review mode)
- `rebuttal-<model>.md` -- each model's response to the rebuttal (review mode)
- `debate-<model>-q<N>.md` -- raw argument from each model per question (debate mode)
- `counter-<model>-q<N>.md` -- counterargument responses from Round 2 (debate mode)

**Cleanup:** When the workflow completes, ask the user whether to keep or delete the temp working directory. Default: delete.

### Setup Commands

```bash
mkdir -p "$PROJECT_DIR/.code-review-copilot-<target>"
mkdir -p "$PROJECT_DIR/.code-reviews"
```

## CLI Invocation Details

All reviews go through a single CLI: `gh copilot`.

**Important shell details:**
- Use `-p` for non-interactive prompt execution.
- Use `-s` (silent) to suppress stats and get clean output.
- Use `--model` to select the specific model for each reviewer.
- Use `--add-dir` to give the model access to the project codebase.
- Use `--allow-all-tools` to let the model browse files, run git commands, etc. without prompting.
- Use `--no-custom-instructions` to prevent repo-local instructions from biasing the review.
- Set `timeout: 600000` on all Bash calls.
- Run all models as background Bash tasks (`run_in_background: true`) concurrently.
- Use `TaskOutput` with `block: true` and `timeout: 300000` to wait for each.
- Capture output with `2>&1 | tee "$OUTPUT_FILE"` -- do NOT use `> file 2>/dev/null` as some models (notably gemini) produce empty files with shell redirect.

### Working Directory

Use the git repository root as `$PROJECT_DIR`. Determine it with:
```bash
git rev-parse --show-toplevel
```

If not in a git repo, report error and stop (code review requires git).

### Directory Access (Critical)

External models need three things to browse the codebase:

1. **CWD set to the project root** -- `cd "$PROJECT_DIR"` before invoking `gh copilot`. This makes the project the model's working directory so relative paths resolve correctly.
2. **`--add-dir` for explicit path whitelisting** -- still pass `--add-dir "$PROJECT_DIR"` as a safety net.
3. **Project path in the prompt** -- explicitly tell the model where the code lives: "The project source code is at `$PROJECT_DIR`." Models that can browse files need to know the path.

### Code State Constraint (Critical)

When the review target is a branch or commit, models MUST examine code at that specific
git ref -- not HEAD, not main, not dev. Without explicit constraint, models will browse
whatever is currently checked out and may reference code that doesn't exist at the review
target.

**Build a git constraint instruction based on review type:**

- **PR:** No constraint needed -- `gh pr diff` returns the correct diff regardless of checkout state.
- **Branch:** `IMPORTANT: Before browsing any source files, run 'git checkout <branch>' to ensure you are examining the code at the correct state. Do NOT look at HEAD, main, dev, or any other branch. All file reads and git commands must reflect the state of '<branch>'.`
- **Commit:** `IMPORTANT: Before browsing any source files, run 'git checkout <sha>' to ensure you are examining the code at the correct state. Do NOT look at HEAD, main, dev, or any other branch. All file reads and git commands must reflect the state of commit '<sha>'.`
- **Uncommitted:** No constraint needed -- uncommitted changes are against the current working tree.

Include this instruction in ALL prompts sent to external models (review, rebuttal, debate, counterargument).

### Invocation Pattern (Code Review)

Unlike document review, no file content is piped into the prompt. Models fetch their own diffs.

For each model on the panel:
```bash
cd "$PROJECT_DIR" && gh copilot -- -p "${PROMPT}" --model "$MODEL" --add-dir "$PROJECT_DIR" --allow-all-tools --no-custom-instructions -s 2>&1 | tee "$OUTPUT_FILE"
```

The `$PROMPT` includes the context preamble and review instructions. Models use git commands and file browsing to investigate the changes.

### Display Names

In all output files, use the model ID as the reviewer name (e.g., "gpt-5.2", "claude-sonnet-4.5"). This is clearer than inventing aliases when all reviews come from the same CLI.

---

## Round 1: Initial Review + Synthesis

This round always runs.

### Step 1: Parse the Review Target

Parse the invocation arguments to detect the review target type (PR, branch, commit, or uncommitted) using the detection rules above. If no argument or ambiguous, ask via `AskUserQuestion`.

Also extract the optional focus area if provided (quoted string after the target).

### Step 2: Validate and Setup

1. Verify this is a git repository: `git rev-parse --show-toplevel`. If not, stop.
2. Verify the review target exists:
   - PR: `gh pr view <number> --json number` must succeed
   - Branch: `git rev-parse --verify <branch>` must succeed
   - Commit: `git rev-parse --verify <sha>` must succeed
   - Uncommitted: `git status --short` must show changes (if clean working tree, report "nothing to review" and stop)
3. Verify Copilot CLI: `gh copilot -- --version 2>/dev/null`. If not available, stop.
4. Run model selection (Step 0 above) if not already done.
5. Gather change metadata (see "Gathering Change Metadata" section above).
6. Create the temp working directory and `.code-reviews/` directory.
7. Tell the user: "Review panel: <list of models>. Target: <description>". No confirmation needed.

### Step 2.5: Build Context Preamble

External models receive only the review prompt -- they have no knowledge of the project, repo, or constraints. Claude DOES have this context from the current session. Use it.

**Generate a context preamble** and write it to `<workdir>/context-preamble.md`.

Build the preamble by gathering what you know from the conversation and the filesystem. Run `ls` on the project root to discover structure. Check for README, go.mod, package.json, Makefile, Dockerfile, etc. to identify tech stack.

Use this template:

```markdown
## Context for Reviewers

> This context describes the project and the changes under review.
> Use it to calibrate your review.

**Project:** <what this project is>
**Tech Stack:** <languages, frameworks, key dependencies>
**Environment:** <where it runs>

**Change Summary:** <what this PR/branch/commit does, from PR description or commit message>
**Changed Files:** <count> files, <additions>+/<deletions>-
**Key Areas Affected:** <which packages/modules/components are touched>

**Known Constraints:**
- <constraints that affect the review>

**Review Focus:** <if user specified a focus area, state it here; otherwise "Full-spectrum review">

---
```

**Rules:**
- Keep it under 25 lines.
- Only include facts you're confident about.
- Omit sections you have no information for -- a shorter, accurate preamble beats a padded one.
- The constraints section is the most important -- it guides what reviewers focus on.

### Step 3: Collect Reviews

Send the review prompt to all selected models in parallel. The prompt tells each model what to review and how to fetch the changes. Replace `$PROJECT_DIR`, `$TARGET_INSTRUCTION`, and `$PREAMBLE_FILE` with actual values.

**Build the target instruction based on review type:**

- **PR:** `Review Pull Request #<number>. Run 'gh pr diff <number>' to see the full diff. Run 'gh pr view <number>' for the PR description.`
- **Branch:** `Review the changes on branch '<branch>' compared to main. Run 'git diff main...<branch>' to see the full diff. Run 'git log --oneline main..<branch>' for the commit history.`
- **Commit:** `Review commit <sha>. Run 'git show <sha>' to see the full diff and commit message.`
- **Uncommitted:** `Review all uncommitted changes in the working tree. Run 'git diff' for unstaged changes, 'git diff --cached' for staged changes, and 'git status' to see untracked files. Review ALL of these.`

**The review prompt:**

```
You are a principal engineer performing a code review.

$(cat "$PREAMBLE_FILE")

$TARGET_INSTRUCTION

IMPORTANT: The project source code is in your current working directory ($PROJECT_DIR).
You MUST use git commands and file browsing to investigate the changes. Follow these steps:
1. Fetch the diff using the command above.
2. Read the diff output carefully.
3. For each changed file, browse the full file to understand surrounding code and context.
4. Only then begin your review -- do not review based solely on the diff.
Check that changes are consistent with the existing codebase patterns.

$GIT_CONSTRAINT_INSTRUCTION

$FOCUS_DIRECTIVE

Review the code changes across these categories:

1) **Correctness & Logic**
   - Bugs, wrong assumptions, incorrect behavior
   - Off-by-one errors, race conditions, logic flaws
   - Does the code do what the commit message / PR description says it does?

2) **Error Handling & Edge Cases**
   - Missing error paths, unhandled exceptions
   - Boundary conditions, nil/null derefs, empty collections
   - What happens when inputs are unexpected?

3) **Security**
   - Injection vulnerabilities (SQL, command, XSS)
   - Auth bypass, privilege escalation
   - Secrets or credentials in code, insufficient input validation
   - Data exposure risks

4) **Testing**
   - Are there tests for the changes? Are they sufficient?
   - Untested code paths, missing edge case tests
   - Test quality -- do tests actually verify behavior or just exercise code?

5) **Performance & Resources**
   - Unnecessary allocations, N+1 queries, unbounded growth
   - Missing timeouts, connection leaks, resource cleanup
   - Algorithmic complexity concerns

6) **API & Interface Design**
   - Breaking changes to public APIs
   - Backward compatibility, versioning
   - Naming consistency, parameter design

7) **Maintainability**
   - Readability, unnecessary complexity
   - Dead code, commented-out code
   - Unclear intent, missing context for future readers
   - Inconsistency with existing patterns in the codebase

If a category has no findings, write "No issues found" for that category rather than
omitting it. This helps distinguish "reviewed and clean" from "skipped".

For EVERY finding, you MUST reference the specific file and line number(s).
Use the format: `path/to/file.go:42` or `path/to/file.go:42-55` for ranges.
If you cannot determine the exact line, browse the file with line numbers to find it.
Do not cite line numbers you did not verify by reading the actual file.

Be direct about flaws. Suggest concrete fixes. If the code is clean, say so --
do not invent problems. A short review of solid code is better than a padded
review that nitpicks style.
Aim for signal over volume. A review with 8 well-grounded findings is better than
25 findings where half are style nitpicks.

Do NOT flag the following -- these are noise, not findings:
- Missing docstrings, comments, or type annotations on unchanged code
- Import ordering or grouping style
- Variable naming style preferences (camelCase vs snake_case) unless inconsistent within the change itself
- Suggesting more specific exception types when the current handling is correct
- const vs let/var style preferences
- Adding logging to code that intentionally omits it
- Whitespace, formatting, or line length unless it causes a real readability problem

For each finding, assign a severity score from 1 to 10:
- 9-10: Will cause data loss, security breach, or production outage
- 7-8: Bug that will manifest under normal usage
- 5-6: Edge case bug, missing validation, or incorrect error handling
- 3-4: Performance concern, test gap, or API design issue
- 1-2: Maintainability suggestion, minor readability improvement

Include the score in your output as `[severity: N]` after each finding title.

If the change involves strategic concerns (cost, team structure, training),
note them briefly but do not deep-dive unless they affect correctness.
```

**Focus directive** (inserted only if user specified a focus area):
```
FOCUS: The reviewer has asked you to pay special attention to: "<focus area>".
Prioritize this area but still note critical issues in other categories.
```

Run all models concurrently as background tasks. Save each to: `<workdir>/review-<model>.md`.

**Capture timing:** Record `date +%s` before launching each model's background task. When `TaskOutput` returns, record the end time. Compute wall-clock seconds per model. Store in a variable for the Reviewer Stats table during synthesis.

If a model fails, log the error and proceed with the others.

### Step 4: Synthesize

Read all review files. Classify every finding into one of the 7 code-focused categories. Note which models flagged each finding and how many agree. Deduplicate findings that reference the same code location with the same concern.

With a single model, all findings are single-source. With 2+ models, note agreement counts -- findings flagged by multiple models have higher confidence.

Write `<target>-review-consolidated.md` (in `$PROJECT_DIR/.code-reviews/`):

```markdown
# Code Review: <target description>

Review Panel: <list of model IDs>
Synthesized by: Claude
Target: <PR #42 / branch feature-x / commit abc1234 / uncommitted changes>

## Summary
<2-3 sentences: scope of changes, total findings, key themes>

## Reviewer Stats

| Model | Wall Clock | Findings | Avg Severity | Skipped (noise) | Signal Rate |
|-------|-----------|----------|-------------|-----------------|-------------|
| <model-a> | 45s | 12 | 5.8 | 3 | 75% |
| <model-b> | 62s | 8 | 6.2 | 1 | 88% |
| <model-c> | 38s | 15 | 4.1 | 7 | 53% |

> Wall Clock = time from task start to completion.
> Skipped (noise) = findings scored 1-2 or matching the "do NOT flag" list, excluded from the review.
> Signal Rate = (findings - skipped) / findings.

## Critical Issues (Must Fix)
Bugs, logic errors, security vulnerabilities, or correctness problems that will cause failures.

| # | Issue | Severity | Flagged By | Location | Risk |
|---|-------|----------|-----------|----------|------|

### Details
#### 1. <Issue title> `[severity: 9]`
**Location:** `path/to/file.go:42-55`
**<model-a> said:** <quote or paraphrase>
**<model-b> said:** <quote or paraphrase> (if multiple flagged)
**Risk:** <what breaks>
**Recommended fix:** <specific code-level suggestion>

## Error Handling & Edge Cases
Missing error paths, unhandled conditions, boundary issues.

| # | Issue | Flagged By | Location | What Breaks |
|---|-------|-----------|----------|-------------|

### Details
(same format -- location, model quotes, what breaks, fix)

## Security Issues
Injection, auth, secrets, input validation, data exposure.

| # | Issue | Flagged By | Location | Security Impact |
|---|-------|-----------|----------|-----------------|

## Testing Gaps
Missing or insufficient tests for the changes.

| # | Gap | Flagged By | Location | What Needs Testing |
|---|-----|-----------|----------|--------------------|

## Performance Concerns
Resource issues, algorithmic concerns, missing cleanup.

| # | Concern | Flagged By | Location | Impact |
|---|---------|-----------|----------|--------|

## API & Interface Issues
Breaking changes, compatibility, naming.

| # | Issue | Flagged By | Location | Impact |
|---|-------|-----------|----------|--------|

## Maintainability Suggestions
Readability, complexity, dead code, pattern inconsistency.

| # | Suggestion | Flagged By | Location | Benefit |
|---|-----------|-----------|----------|---------|

## Contradictions (Models Disagree)
Technical disagreements requiring engineering judgment.

| # | Topic | Model Positions | Location | Recommendation |
|---|-------|----------------|----------|----------------|

### Details
(For each contradiction, present technical arguments from each model)

## False Positives (Already Addressed)
| # | Flagged Issue | Model | Why It's Fine |
|---|---------------|-------|---------------|

## Action Items (Priority Order, by Severity)
- [ ] `[9]` `path/to/file.go:42` -- <action> -- [Critical/Error-Handling/Security/Testing/Performance/API/Maintainability]
- [ ] `[7]` `path/to/file.go:88` -- <action> -- [category]
```

**Synthesis rules for severity scores:**
- Use the model-assigned severity score. If multiple models flag the same finding, use the highest score.
- Drop findings scored 1-2 from the consolidated report -- count them in "Skipped (noise)" in Reviewer Stats.
- Sort all tables and action items by severity descending.

### Step 5: Present and Ask

Report the summary to the user in chat. Then ask:

```
Round 1 complete. You have three options:
1) Stop here -- work from the action items list
2) Round 2: Rebuttal -- I'll respond to each finding (accept/reject/partial), send rebuttals back to the models, and see if they hold their positions
3) Skip to fixing -- I'll apply the accepted fixes directly to the code
```

Use `AskUserQuestion` with these three options.

If the user stops here, proceed to **Cleanup**.

---

## Round 2: Rebuttal (Optional)

### Step 6: Claude Writes Rebuttal

Read the consolidated review and the actual code (using `Read` tool on affected files). For EACH finding, write one of:

- **Accept** -- the finding is valid, state what will change
- **Reject** -- the finding is wrong, explain why with specific code references
- **Partially Accept** -- core concern valid but suggested fix is wrong or scope is different
- **Defer** -- valid but out of scope for this change

Write to `<workdir>/rebuttal.md`:

```markdown
# Rebuttal: <target>

## Accepted (will fix)
| # | Original Finding | Location | Response | Planned Fix |
|---|-----------------|----------|----------|-------------|

## Rejected (disagree)
| # | Original Finding | Location | Rejection Rationale |
|---|-----------------|----------|---------------------|

### Details
#### <Finding title>
**Location:** `path/to/file.go:42`
**Original claim:** <what was said>
**Why it's wrong:** <specific code reference, logic explanation>

## Partially Accepted
| # | Original Finding | Location | What We Accept | What We Reject |
|---|-----------------|----------|----------------|----------------|

## Deferred (valid, not this PR)
| # | Original Finding | Location | Why Deferred | Tracking |
|---|-----------------|----------|--------------|----------|
```

### Step 7: Send Rebuttal to Models

Send the rebuttal back to all models in parallel (same models as Round 1) with this prompt:

```
You previously reviewed code changes and provided feedback.
The author has responded to your findings with a rebuttal.

$(cat "$REBUTTAL_FILE")

For each item in the rebuttal:
- If ACCEPTED: acknowledge, no further action needed
- If REJECTED: do you still hold your position? If yes, explain why the rebuttal is insufficient with specific code references. If the rebuttal convinced you, withdraw your finding.
- If PARTIALLY ACCEPTED: is the partial acceptance sufficient? What's still missing?
- If DEFERRED: is deferral reasonable or is this a risk that must be addressed in this change?

The project source code is in your current working directory ($PROJECT_DIR).
Browse the code to verify claims in the rebuttal.

$GIT_CONSTRAINT_INSTRUCTION

Be direct. If you were wrong, say so. If you still disagree, strengthen your argument with code references.
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
2. Run a **pre-mortem** (what breaks in production if we get this wrong?)
3. If holdout flagged, add context note

Write `<target>-consensus.md` (in `$PROJECT_DIR/.code-reviews/`):

```markdown
# Consensus: <target>

## Model Flexibility Scorecard
| Model | Findings Challenged | Withdrew | Held | Escalated | Flexibility Rate | Flag |
|-------|-------------------|----------|------|-----------|-----------------|------|

## Consensus Items (agreed by all)
| # | Item | Location | Resolution | Owner |
|---|------|----------|-----------|-------|

## Resolved Items (rebuttal accepted)
| # | Item | Location | Original Concern | Why Resolved |
|---|------|----------|-----------------|--------------|

## Deadlocked Items (needs human decision)

### DL-X: <Issue Title>

**The problem:** <what's at stake in the code>

**Location:** `path/to/file.go:42-55`

**Model positions:**
- **<model-a>:** <technical argument with code references>
- **<model-b>:** <technical argument with code references>
- **<model-c>:** <technical argument with code references>

**Support:** X models support position A, Y models support position B

**Held by:** <which model(s)> <holdout flag if applicable>

**Blast radius if wrong:** <concrete failure scenario in production>

**Options:**
  A) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>
  B) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>
  C) <approach> -- Complexity: [Low/Med/High], Risk: [Low/Med/High], Tradeoff: <what you give up>

**Recommendation:** <which option and why>

## Final Action Items
- [ ] `path/to/file.go:42` -- <item> -- [Consensus/Resolved/Deadlocked-decided]
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

Write `<target>-decisions.md` (in `$PROJECT_DIR/.code-reviews/`):

```markdown
# Decision Records: <target>

## DR-001: <Decision Title>
**Status:** Accepted
**Location:** `path/to/file.go:42`
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

Focused design debate where external models argue specific code design questions and Claude synthesizes the arguments. Use this instead of full review mode for targeted questions like "Is this abstraction premature?" or "Should we use approach A or B for error handling?" or "Is the caching layer necessary?"

Debate mode reuses the same infrastructure as review mode: CLI invocation, model discovery, panel selection, context preamble, directory access, background tasks, and cleanup.

### Debate Round 1: Opening Arguments

#### Step D1: Parse Arguments

Extract the review target and 1-4 debate questions from the invocation arguments.

- Arguments follow the pattern: `debate <target> "question1" "question2" ...`
- If the target is provided but no questions, ask via `AskUserQuestion` with a free-text option: "What code design questions should the panel debate? (1-4 questions)"
- If neither target nor questions are provided, ask for both.
- Limit: 4 questions max per debate session. If more are provided, take the first 4 and inform the user.

#### Step D2: Validate and Setup

Same as review mode:

1. Verify git repository and review target (Step 2 from review mode).
2. Verify Copilot CLI.
3. Run model selection (Step 0) if not already done.
4. Gather change metadata.
5. Create the temp working directory and `.code-reviews/` directory.
6. Build the context preamble (Step 2.5 from review mode).
7. Tell the user: "Debate panel: <list of models>. Target: <description>. Questions: <numbered list>".

#### Step D3: Collect Arguments

Send each question to all models in parallel. Build the target instruction the same way as review mode.

For each model, for each question, run as a background task:

```bash
cd "$PROJECT_DIR" && gh copilot -- -p "You are a principal engineer participating in a code design debate.

$(cat "$PREAMBLE_FILE")

$TARGET_INSTRUCTION

IMPORTANT: The project source code is in your current working directory ($PROJECT_DIR).
Use git commands to fetch the diff and browse the codebase to ground your arguments in the actual implementation.

$GIT_CONSTRAINT_INSTRUCTION

Answer this specific design question about the code:

\"<QUESTION>\"

Structure your response as:

## Position
State your position clearly: is this justified, over-engineered, under-engineered, or wrong approach?

## Arguments For (why this design choice is justified)
- Concrete technical arguments with references to specific files and line numbers
- What problems does it solve? What breaks without it?

## Arguments Against (why this might be unnecessary or wrong)
- What would be simpler? What's the cost of this complexity?
- Is there a real-world scenario where this matters, or is it theoretical?

## Verdict
Your recommendation: keep, simplify, remove, or replace with alternative.

Be direct. Take a clear position. Do not hedge." --model "$MODEL" --add-dir "$PROJECT_DIR" --allow-all-tools --no-custom-instructions -s 2>&1 | tee "$OUTPUT_FILE"
```

Save output to: `<workdir>/debate-<model>-q<N>.md` (one file per model per question).

All models and all questions run concurrently as background tasks. Use `TaskOutput` with `block: true` and `timeout: 300000` to collect results.

If a model fails on a question, log the error and proceed with the others.

#### Step D4: Synthesize

Read all debate argument files. For each question, classify the panel's position:

- **Consensus** -- all models agree on the same verdict (keep / remove / simplify / replace)
- **Split** -- models disagree -- present both sides with argument strength

Write `<target>-debate.md` (in `$PROJECT_DIR/.code-reviews/`):

```markdown
# Code Design Debate: <target>

Debate Panel: <list of model IDs>
Synthesized by: Claude
Target: <PR #42 / branch feature-x / commit abc1234 / uncommitted changes>

---

## Q1: <question text>

### Panel Positions
| Model | Position | Confidence |
|-------|----------|------------|
| <model-a> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |
| <model-b> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |
| <model-c> | Keep / Simplify / Remove / Replace | Strong / Moderate / Weak |

### Arguments For
<strongest arguments from models that support the design, with attribution and code references>

### Arguments Against
<strongest arguments from models that oppose the design, with attribution and code references>

### Claude's Assessment
<Claude's own technical judgment weighing both sides, referencing the code>

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
- **Strong** -- clear position with multiple concrete arguments referencing specific code
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
You previously argued the following position on a code design question:

Question: "<QUESTION>"
Your position: <model's original position summary>

Here is a counterargument challenging your position:

<counterargument text>

The project source code is in your current working directory ($PROJECT_DIR).
Browse the code to verify or refute claims in the counterargument.

$GIT_CONSTRAINT_INSTRUCTION

Do you hold your position or change your mind?
- If you change: explain what convinced you and state your new position.
- If you hold: strengthen your argument -- address the counterargument directly with code references.

Be direct.
```

Save responses to: `<workdir>/counter-<model>-q<N>.md`

#### Step D8: Present Final Positions

Update the debate synthesis with Round 2 results. For each challenged question:

- Note who changed position and who held
- Update the verdict if the balance shifted
- Present the final summary

Append a `## Round 2: Counterarguments` section to `<target>-debate.md`:

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

The review board focuses on engineering quality. Strategic concerns belong in separate analysis.

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
| `AskUserQuestion` | Target selection, model selection, round/debate options, deadlocks, cleanup |
| `Read` | Read source files for rebuttal verification |
| `Bash` | Check CLI, git commands for metadata, create/delete directories |
| `Bash` (background) | Run `gh copilot` with different models in parallel (review and debate) |
| `TaskOutput` | Wait for background task completion |
| `Write` | Save all output files (consolidated reviews, debate synthesis, etc.) |

## Error Handling

- If not in a git repository, report error and stop
- If Copilot CLI is not installed, report error and stop
- If review target does not exist (bad PR number, nonexistent branch, invalid SHA), report error and stop
- If working tree is clean for "uncommitted" mode, report "nothing to review" and stop
- If a model fails, proceed with the others (note in output)
- If all models fail, report errors and stop that round
- If a model is not available in the user's Copilot subscription, skip with warning
- Capture output with `2>&1 | tee` (not `> file 2>/dev/null`)
