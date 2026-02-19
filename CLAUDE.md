# Hard Rules

- Do exactly what is asked. Never create files unless explicitly requested or required for execution. Prefer editing existing files. Never create markdown/documentation/summary files as side effects.
- Be concise, no preamble, no meta-commentary. If it can be said in chat, say it in chat.
- Never commit without asking. Never commit to main/master directly.
- No `kubectl patch`. Backup before any Kubernetes object change.
- No `patch` command. Use venv when running Python if one exists.
- No emoji in code or documentation.

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

# Critical Thinking Before Action

Before any destructive or impactful operation, STOP:

1. Do not jump to conclusions or start executing immediately.
2. Ask clarifying questions: "Which node?", "All or specific?", "What's the scope?"
3. Present options from least to most destructive, with tradeoffs and blast radius.
4. Get explicit confirmation before proceeding.
5. Prefer reversible over irreversible (scale down > delete, cordon > shutdown).
6. One small step at a time, not cluster-wide changes when single-node suffices.

If you are about to execute multiple destructive commands in sequence, stop. You are not thinking it through.

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

## Error Handling
- Proper exception handling with meaningful messages
- Log errors with context
- Keep docs current, remove automated generation markers

# Skill File Locations

Skills have two copies: the **active** copy at `~/.claude/skills/<skill>/SKILL.md` and the **repo** copy at `skills/<skill>/SKILL.md` in this project.

- Always write changes to the active copy first, then sync to the repo copy.
- Both files must stay identical.
