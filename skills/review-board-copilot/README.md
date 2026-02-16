# Review Board (Multi-Model Document Review)

Get your technical designs reviewed by multiple AI models in minutes instead of waiting days for human feedback. Think of it as having 3+ senior engineers review your document in parallel, with Claude synthesizing their feedback and highlighting where they agree, disagree, and what needs your decision.

## What This Does

Sends any technical document (architecture decisions, design docs, brain dumps, postmortems) to multiple AI models via GitHub Copilot CLI for independent review, then:

1. **Round 1:** Collects reviews from all models, synthesizes into actionable categories
2. **Round 2 (optional):** You write rebuttals, models respond, resolves false positives
3. **Round 3 (optional):** Builds consensus, surfaces deadlocked items for your decision
4. **Round 4 (optional):** Generates decision records for resolved disagreements

**All using a single GitHub Copilot subscription** - no separate API keys needed.

## Why Use This?

### Before You Code
**Problem:** You've designed a new Kubernetes operator / CLI tool / API but want to catch design flaws before writing 1000 lines of code.

**Solution:** 30-minute review catches:
- Missing components (monitoring, RBAC, error handling)
- Failure modes you didn't consider
- Security gaps
- Implementation gaps
- Edge cases

**Example from testing:** Vector logging ADR review found 25 engineering issues including missing buffer configuration, incorrect log collection mechanism, and unmitigated single point of failure - all before implementation started.

### When You're Stuck
**Problem:** You have a messy brain dump exploring multiple solutions but can't decide which approach is best.

**Solution:** Review structures your thinking:
- Builds evaluation matrix
- Fills gaps you didn't notice
- Challenges assumptions
- Suggests missing alternatives

**Example from testing:** Multi-cluster Helm deployment brain dump got structured into 5 options with evaluation criteria, eliminated one broken approach, added missing hybrid option, and surfaced 1 real engineering tradeoff requiring human judgment.

### After Incidents
**Problem:** Production incident, you've written a postmortem with proposed fixes but want validation.

**Solution:** Review validates:
- Root cause accuracy
- Whether fixes actually prevent recurrence
- What monitoring was missing
- Broader implications

## Prerequisites

**Required:**
- [GitHub Copilot CLI](https://github.com/github/gh-copilot) installed and authenticated
- GitHub Copilot subscription (Individual, Business, or Enterprise)

**Verify installation:**
```bash
gh copilot -- --version
```

If not installed:
```bash
gh extension install github/gh-copilot
```

## Quick Start

1. **Ask Claude to review your document:**
```
Review this design doc using the review board
```

2. **Claude asks which file** - provide the path

3. **Choose your review panel:**
   - Default (recommended): GPT-5.2, Claude Sonnet 4.5, Gemini 3 Pro
   - Pick specific models from 16+ available
   - Quick review (2 fast models)
   - Deep review (3 max-depth models)

4. **Get consolidated review** with:
   - Critical issues (must fix)
   - Implementation gaps
   - Risk factors
   - Operational concerns
   - Security issues
   - Contradictions

5. **Choose next step:**
   - Stop and work from action items
   - Round 2: Rebuttal (challenge findings, resolve false positives)
   - Round 3: Consensus (surface deadlocks for your decision)

## Available Models

Via `gh copilot -- --model`:

| Model | Provider | Best For |
|-------|----------|----------|
| `gpt-5.2-codex` | OpenAI | Deep technical review, code analysis |
| `gpt-5.2` | OpenAI | General architecture review |
| `gpt-5.1-codex-max` | OpenAI | Maximum depth review |
| `claude-opus-4.6` | Anthropic | Deep reasoning, thorough analysis |
| `claude-sonnet-4.5` | Anthropic | Balanced speed/depth (default) |
| `gemini-3-pro-preview` | Google | Alternative perspective |

Plus 10 more models. See [full list](SKILL.md#available-models).

**Default panel** (one from each provider for maximum diversity):
- `gpt-5.2` - OpenAI's perspective
- `claude-sonnet-4.5` - Anthropic's perspective
- `gemini-3-pro-preview` - Google's perspective

## What You Get

### Consolidated Review (Round 1)

```markdown
# Consolidated Review: your-document

## Summary
3 models reviewed. Found 22 issues: 4 critical, 5 implementation gaps,
4 risk factors, 3 operational concerns, 3 security issues, 3 design improvements.

## Critical Issues (Must Fix Before Implementation)
| # | Issue | Flagged By | Technical Risk |
|---|-------|-----------|----------------|
| 1 | No buffer/backpressure config | all 3 | Logs will be dropped during backpressure |
| 2 | Aggregator SPOF not mitigated | gpt-5.2, claude-opus-4.6 | Total log loss during failures |
...

## Implementation Gaps
| # | Gap | What's Needed |
|---|-----|---------------|
| 5 | No VRL transform code | Java multiline handling, PII scrubbing examples |
...

## Risk Factors (Edge Cases & Failure Scenarios)
| # | Risk | Failure Scenario | Mitigation |
|---|------|------------------|-----------|
| 10 | VRL syntax errors drop logs silently | Typo in config → logs vanish | Mandatory CI testing |
...

## Action Items (Priority Order)
- [ ] Add buffer and backpressure section -- [Critical] -- Section: Architecture
- [ ] Add security section (TLS, RBAC, PII scrubbing) -- [Critical] -- Section: New
...
```

### Consensus Document (Round 3, if used)

```markdown
# Consensus: your-document

## Model Flexibility Scorecard
| Model | Withdrew | Held | Flexibility Rate |
|-------|----------|------|-----------------|
| gpt-5.2-codex | 5 | 1 | 83% |
| claude-opus-4.6 | 5 | 1 | 83% |
| gemini-3-pro-preview | 7 | 0 | 100% |

## Consensus Items (agreed by all)
...implementation details everyone agrees on...

## Resolved Items (rebuttal accepted)
...false positives eliminated through Round 2...

## Deadlocked Items (needs human decision)

### DL-1: Buffer Sizing Feasibility Check

**The technical problem:** ADR commits to 2-hour buffer but doesn't verify
it's feasible on current node storage.

**Model positions:**
- gpt-5.2-codex: "Add storage budget per node to ADR"
- claude-opus-4.6: "5 minutes of math prevents Week 2 surprise"
- gemini: "Constraint is sufficient, defer sizing"

**Blast radius:** Week 2 discovery that buffer requires 8GB, exceeding
available disk. Forces PVCs (adds complexity) or reduces buffer target
(weakens resilience).

**Options:**
  A) Add back-of-envelope calculation (2 sentences) - Low complexity, Low risk
  B) Defer sizing to implementation - Low complexity, Medium risk

**Recommendation:** Option A. 5 minutes prevents architectural surprise.
```

## The Review Process

### Round 1: Initial Review + Synthesis

**Always runs.** Claude:
1. Builds context preamble from your project (tech stack, constraints, integrations)
2. Sends context + document to all selected models in parallel
3. Synthesizes findings into engineering-focused categories
4. Presents summary and action items

**You get:** Consolidated review with ~15-25 actionable issues

### Round 2: Rebuttal (Optional)

**When to use:** Initial review has false positives or you disagree with findings.

Claude:
1. Writes rebuttals for each finding (accept/reject/partial/defer)
2. Sends rebuttals back to all models
3. Models respond: withdraw, hold position, or strengthen argument

**You get:** Filtered findings - resolved items removed, contested items clarified

**Example:** "Migration requires downtime" → Rebuttal: "No downtime, just validation window with dual-write" → All 3 models withdrew

### Round 3: Consensus (Optional)

**When to use:** Complex changes or conflicting model opinions need structured resolution.

Claude:
1. Classifies everything: consensus, resolved, or deadlocked
2. For deadlocks: runs pre-mortem, analyzes options, makes recommendation
3. Presents each deadlock for your decision

**You get:** Clear engineering judgment calls with technical tradeoffs

**Example deadlock:** "Should deployment tool halt on cross-cluster failure?"
- 2 models: Yes, add to evaluation criteria
- 1 model: No, rely on backward-compatible APIs
- Recommendation with blast radius analysis

### Round 4: Decision Records (Optional)

**When to use:** You want formal documentation of decisions made.

Generates ADR-style decision records for resolved deadlocks.

## Engineering Focus (Not Strategy)

This skill focuses on **technical quality**, not business strategy:

### ✅ What It Reviews
- Technical correctness (will this work?)
- Failure modes and recovery
- Implementation gaps
- Security and safety
- Observability and debugging
- Production readiness
- Design quality

### ❌ What It Ignores
- Cost modeling (unless blocks technical feasibility)
- Team training timelines
- Long-term capacity planning
- Strategic alignment
- Market fit

**Example:** In testing, models flagged potential cross-AZ transfer costs but this was correctly filtered from the synthesis as a strategic concern, not a technical blocker.

## Real Test Results

### Vector Logging ADR (Structured Document)

**Input:** Architecture decision to replace Fluent Bit with Vector for log collection

**Round 1 findings:** 25 engineering issues including:
- Critical: Missing buffer configuration, incorrect log collection mechanism, SPOF not mitigated
- Security: No TLS, RBAC, or PII scrubbing strategy
- Operational: No monitoring, vague success criteria, no rollback procedure

**Round 3 deadlock:** "Should we do 5 minutes of buffer sizing math now or defer to implementation?" - Legitimate engineering judgment call

**Time:** 45 minutes for 3-round review
**Value:** Caught implementation-blocking issues before any code written

### Multi-Cluster Helm Brain Dump (Messy Exploration)

**Input:** Unstructured ideas about solving 12-cluster deployment problem

**Round 1 findings:** 19 issues including:
- Structured thinking: No evaluation matrix, key requirement buried in "Random Thoughts"
- Technical errors: Wrong Helmfile syntax, broken Kustomize approach
- Missing: Emergency hotfix workflow, RBAC/approval gates, migration path

**Round 3 deadlock:** "Should deployment tool halt on cross-cluster failure or rely on backward-compatible APIs?" - Real engineering tradeoff

**Time:** 40 minutes for 3-round review
**Value:** Transformed brain dump into structured decision document with evaluation criteria

## When to Use This

### ✅ Good Use Cases

**Pre-implementation review:**
- Kubernetes operators (VNA, config sync, custom controllers)
- CLI tools (diagnostic utilities, automation scripts)
- APIs and services
- Data pipelines

**Brain dump refinement:**
- Exploring multiple solution approaches
- Need structure for decision-making
- Want to avoid obvious mistakes

**Postmortem validation:**
- Verify root cause accuracy
- Check if fixes prevent recurrence
- Identify monitoring gaps

**Challenging your bias:**
- You're convinced of a solution but want to make sure
- Force yourself to articulate trade-offs
- Discover missed alternatives

### ❌ Not Recommended For

**Simple decisions:**
- "Should I add a health check?" (too simple, overhead too high)
- Single-line config changes

**Novel/critical systems:**
- Self-driving cars, medical devices, financial trading
- Need human domain experts, not AI review

**Strategic decisions:**
- Which vendor to choose (business decision)
- Team structure or headcount (organizational)
- Budget allocation (financial)

**When you lack context:**
- Models don't know your production quirks
- Models don't know your past incidents
- Models might hallucinate "facts"

## Tips for Best Results

### Write Context-Rich Documents

**Good:**
```markdown
## Context
We run Vector in 12 EKS clusters. Current log loss is 2-3% during peak
traffic (Java apps, 2-3 TB/day total). Must integrate with existing
Elasticsearch cluster (contract until Q4 2025). Can't change log volume
(business requirement).
```

**Poor:**
```markdown
## Context
We use Vector for logging.
```

Models use context to calibrate their review - specific constraints = better feedback.

### Use Multi-Round for Complex Decisions

**Round 1 only:** Feature implementation, straightforward changes
**Round 1-2:** Most design docs (eliminate false positives)
**Round 1-3:** Complex systems, critical infrastructure, big migrations

### Challenge Model Consensus

If all 3 models agree on something that seems wrong to you, **trust your judgment**. Models can have correlated biases.

Example: "SQLite doesn't scale!" (true in general, wrong for 100 req/day service)

### Review the Reviews

Models sometimes hallucinate "facts":
- "Vector requires TLS 1.3 minimum" (might be wrong)
- "This violates DICOM standard" (verify yourself)

Treat findings as **things to investigate**, not gospel.

## File Organization

```
your-project/
├── your-doc.md
├── your-doc-review-consolidated.md      (Round 1 output)
├── your-doc-consensus.md                 (Round 3 output, if run)
├── your-doc-decisions.md                 (Round 4 output, if run)
└── .review-board-your-doc/               (temp files, optional to keep)
    ├── context-preamble.md
    ├── review-gpt-5.2.md
    ├── review-claude-sonnet-4.5.md
    ├── review-gemini-3-pro-preview.md
    ├── rebuttal.md
    └── rebuttal-*.md
```

**Cleanup:** At the end, Claude asks if you want to keep or delete the temp directory. Default: delete.

## Limitations & Caveats

### Models Can Be Wrong Together
If all 3 models hallucinate the same "fact," you'll get strong consensus on something false. Use diverse models (GPT, Claude, Gemini) to reduce this risk.

### Groupthink on Conventional Wisdom
If you're doing something unconventional *on purpose*, all models might flag it as "wrong." The rebuttal round helps, but you need confidence to override unanimous opinion when you're right.

### No Domain Expertise
Models don't know:
- Your team's skill level
- Your organization's constraints
- Your specific production environment quirks
- Past incidents that inform decisions

### Not a Replacement for Human Review
This is a **force multiplier for your judgment**, not a replacement. Use it to catch 90% of obvious mistakes fast, then apply human judgment to the 10% that matters.

## Advanced Usage

### Custom Model Selection

```
Pick specific models for specialized reviews:

Security-focused review:
- gpt-5.2-codex (code analysis)
- claude-opus-4.6 (deep reasoning)
- claude-opus-4.6-fast (double-check)

Fast sanity check:
- gpt-5-mini
- claude-haiku-4.5
```

### Integration with Existing Workflows

**Pre-commit review:**
```bash
# In pre-commit hook
if [[ -f design-doc.md ]]; then
  gh copilot -- -p "Quick review: any critical issues?" -f design-doc.md
fi
```

**CI/CD validation:**
```yaml
# In GitHub Actions
- name: Review architecture changes
  if: contains(github.event.head_commit.modified, 'docs/architecture/')
  run: |
    # Trigger review for modified architecture docs
```

### Cross-Document Awareness

Claude can reference related documents in your project:

**Example:** When reviewing multi-cluster deployment strategy, Claude suggested using the Vector ADR as a prototype test case - smart cross-reference.

## Troubleshooting

### "GitHub Copilot CLI not found"
```bash
# Install Copilot CLI
gh extension install github/gh-copilot

# Verify
gh copilot -- --version
```

### "Model not available in your subscription"
Some models require specific Copilot tier (Business or Enterprise). Claude will skip unavailable models with a warning.

### "Review taking too long"
- Reduce number of models (use 2 instead of 3)
- Use faster models (haiku, mini variants)
- Skip Round 2-3 for simpler docs

### "Getting too many false positives"
- Use Round 2 (rebuttal) to filter
- Improve context preamble with more constraints
- Be specific about what's in/out of scope

## Contributing

Found a bug? Have a suggestion? This skill is designed to be shared and improved.

**Common improvements:**
- Better review prompts for specific domains (web APIs, ML pipelines, etc.)
- More sophisticated synthesis categories
- Enhanced context detection

## License

This skill uses GitHub Copilot CLI which requires a GitHub Copilot subscription. The skill document itself is provided as-is for community use.

---

## Example: Complete Workflow

```
You: Review this ADR for switching from Fluent Bit to Vector

Claude: I'll review your ADR using the multi-model review board.
        Which file should I review?

You: docs/adr-001-vector-logging.md

Claude: Review panel options:
        1) Default panel (GPT-5.2, Claude Sonnet 4.5, Gemini 3 Pro)
        2) Pick models from full list
        3) All providers, max depth
        4) Quick review (2 fast models)

You: 1

Claude: Review panel: gpt-5.2, claude-sonnet-4.5, gemini-3-pro-preview
        [Runs reviews in parallel...]

        Round 1 complete. Found 25 engineering issues:
        - 4 critical (buffer config, SPOF, sampling, log collection error)
        - 5 implementation gaps (VRL code, monitoring, RBAC, SLOs, configs)
        - 4 risk factors (VRL errors, ES downtime, queueing, concurrent updates)
        - 3 operational gaps (runbook, rollback, validation tests)
        - 3 security issues (encryption, PII scrubbing, RBAC scope)
        - 3 design improvements

        Options:
        1) Stop here - work from action items
        2) Round 2: Rebuttal
        3) Skip to updating the doc

You: 2

Claude: [Writes rebuttals for each finding...]
        [Sends back to models...]

        Round 2 complete. Results:
        - 6 items resolved (models withdrew after rebuttal)
        - 19 items still valid
        - Some models strengthened their arguments

        Options:
        1) Stop here
        2) Round 3: Consensus building

You: 2

Claude: [Analyzes all positions...]

        Round 3 complete.

        Consensus: 13 items all models agree on
        Resolved: 6 items withdrawn in Round 2
        Deadlocked: 1 item needs your decision

        DL-1: Buffer Sizing Math
        - 2 models say: Do 5 min calculation now
        - 1 model says: Defer to implementation

        Recommendation: Do the math (low cost, prevents surprise)

        Your decision?

You: Agree with recommendation - do the math

Claude: [Updates consensus doc with decision...]

        Final outputs:
        - adr-001-vector-logging-review-consolidated.md (25 action items)
        - adr-001-vector-logging-consensus.md (decision rationale)

        Delete temp files? [Yes/No]

You: Yes

Claude: Done. Review complete in 45 minutes.
        Next: Address the 25 action items before implementation.
```

---

**Ready to catch those design flaws before they become production incidents?**

Just ask Claude: *"Review this design doc using the review board"*
