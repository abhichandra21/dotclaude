# Hard Rules

- Do exactly what is asked. Never create files unless explicitly requested or required for execution. Prefer editing existing files. Never create markdown/documentation/summary files as side effects.
- Be concise, no preamble, no meta-commentary. If it can be said in chat, say it in chat.
- Never commit without asking. Never commit to main/master directly.
- No `kubectl patch`. Backup before any Kubernetes object change.
- No `patch` command. Use venv when running Python if one exists.
- No emoji in code or documentation.
- When given a plan or specification, follow it exactly. Do not reorganize, deduplicate, or improve unless asked. If something seems wrong, ASK before changing course.
- When asked for something specific (a name, path, version, status), answer directly. Do not explore the codebase first.
- If you don't have the data to answer a question, say so and stop. Do not substitute inferior data sources and present the result as if it were equivalent. A 5-minute log sample is not a substitute for time-series metrics. No answer is better than a wrong answer dressed up as analysis.
- Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

# Workflow

- Investigate and report findings before making code changes. When asked to "diagnose", "check", "investigate", or "look at" something, stop after analysis and wait for approval before implementing fixes.

# Context & Conventions

- When the user mentions "session", "history", or "last session" in a Claude Code context, default to interpreting this as Claude conversation sessions (`~/.claude` directory) rather than git history or project sessions.

# Change Management

## Workflow: Understand > Plan > One Change > Test > Commit > Repeat
1. **Understand first**: Check git history, existing code, docs before touching anything.
2. **One file at a time**: Modify one file, test it, confirm it works, then move on.
3. **On error, stop**: Analyze why it failed. Fix or revert that one change. Never pile on more changes hoping something works.

## Red Flags (stop all work)
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
- Prefer merge over rebase when conflicts are likely
- Never rename branches that have open PRs
- When creating a new branch, switch to it immediately

# Critical Thinking Before Action

Before any destructive or impactful operation, STOP:

1. Do not jump to conclusions or start executing immediately.
2. Ask clarifying questions: "Which node?", "All or specific?", "What's the scope?"
3. Present options from least to most destructive, with tradeoffs and blast radius.
4. Get explicit confirmation before proceeding.
5. Prefer reversible over irreversible (scale down > delete, cordon > shutdown).
6. One small step at a time, not cluster-wide changes when single-node suffices.

If you are about to execute multiple destructive commands in sequence, stop. You are not thinking it through.

## Kubernetes
- Do NOT modify Custom Resources, cluster state, or deployment configs unless explicitly instructed.
- When debugging K8s issues, observe and report first. Never modify resources without asking.
- When a user specifies a namespace explicitly, use it as-is. Never substitute it with a value from environment.md or any lookup table.
- If the specified namespace does not match the known VNA namespace for that cluster, ask: "You said `<user-value>` but the known VNA namespace for this cluster is `<known-value>` — did you mean `<user-value>` or `<known-value>`?" before proceeding.
- Every mutating kubectl command (`apply`, `delete`, `patch`, `create`, `edit`, `replace`, `scale`, `rollout`, `cordon`, `drain`, `taint`, `label --overwrite`, `annotate --overwrite`, `exec`, `cp`, `run`) MUST include `--context=<name>` explicitly on the command line. Never rely on `kubectl config current-context` or the `KUBECONFIG` env var to pick the target. If a script does not accept `--context`, invoke it with `KUBECONFIG=<path>` set inline for that single invocation.
- Before any mutating kubectl command against a remote cluster (anything other than `docker-desktop`, `kind`, `minikube`, local `rke2`), print the exact command and the target context, then STOP and wait for explicit user confirmation. Prior confirmation does not carry forward — each mutating command against a remote cluster needs its own confirmation.
- Read-only intent is enforced by command shape, not discipline. When a cluster is declared read-only for the session (EA edge, production EKS, any prod-designated context), only `get`, `describe`, `logs`, `top`, `explain`, `api-resources`, `config view`, `auth can-i` are permitted. State the read-only contract at the top of any session that touches such a cluster so it survives context compaction.
- Do not run install/deploy/uninstall scripts that perform mutating kubectl operations without first verifying the script pins context (checks `current-context` against an allowlist, or requires `--context`/`--kubeconfig`). If the script inherits ambient context, do not run it against any non-local cluster — pin `KUBECONFIG` to a single-cluster file for the invocation, or don't run it.

# Deployment & Infrastructure

- Before making assumptions about deployment targets, namespaces, or managed services, inspect the actual live state (`kubectl get`, AWS CLI, etc.) rather than inferring from similar/reference environments.

# Problem Solving

## Challenge Constraints
When told "we can't change X": distinguish impossible vs difficult vs requires-approval. Ask who owns it. Present solutions requiring external changes and let the user decide feasibility.

## Enumerate Solutions Before Deep Work
Before spending >15 minutes on one approach, list all possible solutions (including ideal-world ones). Show what each changes, rank by total system complexity, present options.

## When Stuck
- Check for anchoring (locked onto first solution), confirmation bias, sunk cost fallacy.
- After 15-20 min on one approach, ask: "Is there a simpler way? What if my core assumption is wrong?"
- Ask naive questions: "Why do we need X at all? What would eliminate this entire category of problem?"
- Explore ideal solutions: "What if we could change external system X?"

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

## Code Review Checklist
- [ ] Sounds like team-written code (tone, consistency)
- [ ] Intent immediately clear
- [ ] No redundant code/comments
- [ ] Most direct approach used
- [ ] Diff covers full branch vs base (`git diff main...HEAD`), not just last commit

## Shell Scripts
- Must be bash/zsh compatible. Use POSIX syntax. Use `#!/bin/bash` explicitly.

## Error Handling
- Proper exception handling with meaningful messages
- Log errors with context
- Keep docs current, remove automated generation markers

# Skill File Locations

Skills have two copies: the **active** copy at `~/.claude/skills/<skill>/SKILL.md` and the **repo** copy at `skills/<skill>/SKILL.md` in this project.

- Always write changes to the active copy first, then sync to the repo copy.
- Both files must stay identical.
