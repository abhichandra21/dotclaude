# Hard Rules

- **Talk plain English, keep it short.** No technical deep dives, no edge-case lists. What happened, what you recommend, what you need from me — a few lines. If I have to scroll, it is too long.
- **Do not over-engineer.** Fix the real problem the simple way, then stop. Do not chase rare edge cases. When reviews keep finding narrower cases, ship and list what's left as known limits.
- Do exactly what is asked. Never create files unless explicitly requested or required for execution. Prefer editing existing files. Never create markdown/documentation/summary files as side effects.
- Be concise, no preamble, no meta-commentary. If it can be said in chat, say it in chat.
- Write like you're explaining to a colleague out loud. Plain words over precise-sounding ones. One idea per sentence. If a sentence has to be read twice, rewrite it.
- Never commit without asking. Never commit to main/master directly.
- No `kubectl patch`. Backup before any Kubernetes object change.
- No `patch` command. Use venv when running Python if one exists.
- No emoji in code or documentation.
- When given a plan or specification, follow it exactly. Do not reorganize, deduplicate, or improve unless asked. If something seems wrong, ASK before changing course.
- When asked for something specific (a name, path, version, status), answer directly. Do not explore the codebase first.
- When explaining a system, give the 3-sentence answer first. Go deeper only if asked.
- If you don't have the data to answer a question, say so and stop. Do not substitute inferior data sources and present the result as if it were equivalent. No answer is better than a wrong answer dressed up as analysis.
- Do not hard-wrap prose in markdown files to 80 columns. Use semantic line breaks (one sentence per line) for prose. Code blocks and tables are exempt.
- When adding rules to this file, fold them into the existing section on that topic instead of adding a new section.
- Always use Context7 MCP when library/API documentation, code generation, setup or configuration steps are needed without being explicitly asked.

# Workflow

- Investigate and report findings before making code changes. When asked to "diagnose", "check", "investigate", or "look at" something, stop after analysis and wait for approval before implementing fixes.

# Context & Conventions

- When the user mentions "session", "history", or "last session" in a Claude Code context, default to interpreting this as Claude conversation sessions (`~/.claude` directory) rather than git history or project sessions.

# Scope Discipline

Default to the lightest process path that fits the request.

- Freeze intent before designing: goal, explicit in-scope, explicit out-of-scope, decisions that must not change, and what counts as unauthorized scope expansion.
- Start from the requested delta. Find the smallest necessary change. Reuse existing ownership boundaries and extension points. Do not redesign surrounding systems.
- Do not refactor adjacent code or add abstractions as part of an unrelated change. Flag it as a question instead.
- Propose exactly one approach with reasoning. Enumerate alternatives only if asked, or if the choice genuinely forks the architecture.
- Do not write a spec or design document unless asked. A design presented in chat is the default deliverable.
- When planning surfaces new work, classify it out loud — required for correctness, required prerequisite, deferred hardening, unrelated improvement, or open question — and stop for approval rather than silently absorbing it.

# Change Management

## Workflow: Understand > Plan > One Change > Test > Commit > Repeat
1. **Understand first**: Check git history, existing code, docs before touching anything.
2. **One file at a time**: Modify one file, test it, confirm it works, then move on.
3. **On error, stop**: Analyze why it failed. Fix or revert that one change. Never pile on more changes hoping something works.

## When Changes Start Failing
Stop all work when you see any of these:
- Same error after multiple attempts
- Different errors with each change
- Changing the same file 3+ times
- User says "too complicated" or "too many changes"

## Git Operations
- `git diff HEAD -- <path>` before any revert
- Revert one file at a time, never directories
- Never `git checkout HEAD -- directory/` without reviewing each file

## Anti-Patterns
- Change A fails > change B fails > change C = chaos. Instead: change A fails > understand > fix or revert > next change.
- "Looks wrong everywhere, change it all" = wrong. "Looks unexpected, understand why first" = right.

## Git Workflow
- Always confirm which branch we're on before committing
- Commit to the branch we are already on. Do not create a new branch on your own initiative.
- When creating a new branch, switch to it immediately
- Never rename branches that have open PRs
- Prefer merge over rebase when conflicts are likely
- Never merge a PR unless explicitly told to merge that PR.
- Check branch protection before pushing to a shared branch. Never learn about a protection rule from push output.

# Critical Thinking Before Action

Before any destructive or impactful operation, STOP:

1. Do not jump to conclusions or start executing immediately.
2. Ask clarifying questions: "Which node?", "All or specific?", "What's the scope?"
3. Present options from least to most destructive, with tradeoffs and blast radius.
4. Get explicit confirmation before proceeding.
5. Prefer reversible over irreversible (scale down > delete, cordon > shutdown).
6. One small step at a time, not cluster-wide changes when single-node suffices.

If you are about to execute multiple destructive commands in sequence, stop. You are not thinking it through.

- A short "keep going" or "next" only continues the current track. It never approves a separate action that needs approval.
- Never treat an unanswered question as answered, and never pick a default for it.
- Never run `rsync --delete` or any deleting mirror on local folders without explicit OK on the exact files.

## Kubernetes
- Do NOT modify Custom Resources, cluster state, or deployment configs unless explicitly instructed.
- When debugging K8s issues, observe and report first. Never modify resources without asking.
- When a user specifies a namespace explicitly, use it as-is. Never substitute it.
- Every mutating kubectl command (`apply`, `delete`, `patch`, `create`, `edit`, `replace`, `scale`, `rollout`, `cordon`, `drain`, `taint`, `label --overwrite`, `annotate --overwrite`, `exec`, `cp`, `run`) MUST include `--context=<name>` explicitly on the command line. Never rely on `kubectl config current-context` or the `KUBECONFIG` env var.
- Before any mutating kubectl command against a remote cluster, print the exact command and target context, then STOP and wait for explicit user confirmation. Prior confirmation does not carry forward.
- Read-only intent is enforced by command shape, not discipline. When a cluster is declared read-only for the session, only `get`, `describe`, `logs`, `top`, `explain`, `api-resources`, `config view`, `auth can-i` are permitted.
- Do not run install/deploy/uninstall scripts that perform mutating kubectl operations without first verifying the script pins context. If it inherits ambient context, pin `KUBECONFIG` to a single-cluster file or don't run it.

# Deployment & Infrastructure

- Before making assumptions about deployment targets, namespaces, or managed services, inspect the actual live state (`kubectl get`, AWS CLI, etc.) rather than inferring from similar/reference environments.

# Problem Solving

## Challenge Constraints
When told "we can't change X": distinguish impossible vs difficult vs requires-approval. Ask who owns it. Present solutions requiring external changes and let the user decide feasibility.

## Enumerate Solutions Before Deep Work
This triggers when stuck, or before committing to an approach expected to take more than ~15 minutes.
List all possible solutions (including ideal-world ones). Show what each changes, rank by total system complexity, present options.

## When Stuck
- Check for anchoring (locked onto first solution), confirmation bias, sunk cost fallacy.
- After 15-20 min on one approach, ask: "Is there a simpler way? What if my core assumption is wrong?"
- Ask naive questions: "Why do we need X at all? What would eliminate this entire category of problem?"

## Heuristics
- Alignment > compensation (align paths/configs vs complex workarounds)
- One 5-min external approval > 3 hours of technical gymnastics
- Total system complexity matters (code + config + external + maintenance)

# Development Standards

## Tech Stack
Primary languages: Go, Python, YAML/Kubernetes manifests, Shell scripts. Markdown for docs. Primary platform: Kubernetes (operators, CRDs, Helm). Apply Go/K8s conventions by default unless told otherwise.

## Code Quality
- Human-readable names, follow language conventions (camelCase, PascalCase, snake_case)
- Include units in measurement variables
- Direct, technical language. "Failed to ensure broker" not "broker ensure failed."
- Comment why, not what. Match existing patterns. Choose the most straightforward solution.
- Keep docs current, remove automated generation markers

## Code Review Checklist
- [ ] Sounds like team-written code (tone, consistency)
- [ ] Intent immediately clear
- [ ] No redundant code/comments
- [ ] Most direct approach used
- [ ] Diff covers full branch vs base (`git diff main...HEAD`), not just last commit

## Testing and Verification
- A new test counts only after it fails with the fix removed.
- A passing health check or replica count does not prove a service works. Test one real request end to end.
- Before saying something does or does not work, trace it end to end and cite what you saw.

## Shell Scripts
- Must be bash/zsh compatible. Use POSIX syntax. Use `#!/bin/bash` explicitly.

## Error Handling
- Proper exception handling with meaningful messages
- Log errors with context

# AWS Guidance

- Prefer the AWS MCP Server for AWS interactions — it provides sandboxed execution, observability, and audit logging.
- Before starting AWS work, check for a relevant AWS skill and prefer it over general knowledge.
- When uncertain about specific AWS details (API parameters, permissions, limits, error codes), verify against documentation rather than guessing.
- When creating infrastructure, prefer infrastructure-as-code (CDK or CloudFormation) over direct CLI commands.
- Follow AWS Well-Architected Framework principles.
- Do not use em dashes in AWS resource names. Use hyphens instead.

# Skill File Locations

Skills have two copies: the **active** copy at `~/.claude/skills/<skill>/SKILL.md` and the **repo** copy at `skills/<skill>/SKILL.md` in this project.

- Always write changes to the active copy first, then sync to the repo copy.
- Both files must stay identical.
