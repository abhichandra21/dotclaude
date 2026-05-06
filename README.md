# dotclaude

My Claude Code configuration — behavior rules, custom skills, agent definitions, MCP servers, and a status line that shows what Claude is actually doing.

## What this changes

Out of the box, Claude Code is capable but generic. This configuration makes it opinionated:

- **It doesn't act without understanding.** Before touching code, it checks git history, reads the existing pattern, and understands the why. When asked to diagnose something, it stops after analysis and waits — it doesn't immediately start making changes.
- **It thinks about blast radius.** Destructive operations get a pause and a confirmation. For Kubernetes, every mutating command must name its context explicitly. No ambient context drift.
- **It doesn't pile on changes.** One file, one change, test it, move on. If something fails three times the same way, it stops instead of trying a fourth approach.
- **It argues back on constraints.** When told "we can't change X," it distinguishes between impossible and just-needs-approval, and presents options rather than accepting the constraint as final.

The full ruleset lives in [CLAUDE.md](CLAUDE.md).

## Status line

A custom status line that mirrors a Powerlevel10k prompt: current directory, AWS/EKS session, virtualenv, git branch with dirty/ahead/behind indicators, model name, and context window usage colored green → yellow → red as it fills.

```
~/Data/Codebase/my-project | λ dev | main* | claude-sonnet-4-6 | 34%
```

Reads from `~/.aws_sessions` for the EKS indicator — customize the `case` statement in [statusline-command.sh](statusline-command.sh) to match your own profile names.

## Skills

### In this repo

| Skill | What it does |
|---|---|
| `code-review-copilot` | Multi-model code review via GitHub Copilot CLI — sends diffs to GPT, Claude, and Gemini, synthesizes findings |
| `promptheus` | Refines prompts using the Promptheus MCP server |
| `review-board` | Document review board powered by multiple LLM CLIs |
| `review-board-copilot` | Same as above but scoped to Copilot |
| `writing-assistant` | Context-aware text rephrasing and improvement |

### Marketplace (download separately)

General-purpose skills available from the marketplace:

- `algorithmic-art` — generative algorithmic art
- `brand-guidelines` — extract and apply brand guidelines
- `canvas-design` — canvas-based design tools
- `frontend-design` — production-grade frontend UI generation
- `internal-comms` — draft internal communications
- `mcp-builder` — scaffold MCP servers
- `rekhta-qafia` — Rekhta qafia/rhyming dictionary search
- `skill-creator` — guide for creating new skills
- `slack-gif-creator` — Slack GIF creation
- `template-skill` — starter template for new skills
- `theme-factory` — UI theme generation
- `ac-triage-dependabot` — safely triage open Dependabot PRs
- `ac-*` — private work-specific cluster health, log tracing, and operational skills
- `web-artifacts-builder` — web artifact generation
- `webapp-testing` — Playwright-based web app testing

## Plugins

Install with `claude plugin install <name>@<registry>`:

| Plugin | Registry | What it does |
|---|---|---|
| `superpowers` | `claude-plugins-official` | Meta-skill framework: brainstorming, TDD, systematic debugging, plan writing, code review workflows |
| `codex` | `openai-codex` | OpenAI Codex CLI integration |
| `claude-hud` | `claude-hud` | Status line / HUD display |
| `claude-md-management` | `claude-plugins-official` | CLAUDE.md creation and improvement tools |
| `claude-code-setup` | `claude-plugins-official` | Setup and automation recommendations |
| `gopls-lsp` | `claude-plugins-official` | Go language server (LSP) integration |
| `firebase` | `claude-plugins-official` | Firebase project integration |

## MCP Servers

Configured in [config/mcp.json](config/mcp.json):

| Server | What it does |
|---|---|
| `aws-knowledge` | AWS documentation search |
| `kubernetes` | K8s cluster management |
| `memory` | Persistent memory across sessions |
| `git` | Git operations |
| `promptheus` | Prompt refinement |
| `aws-api` | AWS CLI operations |
| `cloudflare` | Cloudflare documentation |

## Agents

Custom agent definitions in [agents/](agents/) — specialized subagents for Go, Python, Kubernetes, debugging, cloud architecture, and more. Dropped into `~/.claude/agents/` so Claude can dispatch them automatically.

## Setup

```bash
# Clone wherever you keep dotfiles
git clone <repo> ~/dotfiles/claude

# Symlink or copy to ~/.claude
cp CLAUDE.md ~/.claude/CLAUDE.md
cp settings.json ~/.claude/settings.json
cp config/mcp.json ~/.claude/config/mcp.json
cp -r skills/* ~/.claude/skills/
cp -r agents/* ~/.claude/agents/
cp claude-powerline*.json ~/.claude/
cp statusline-command.sh ~/.claude/
```

Then fill in your values:

- `config/mcp.json` — replace `<YOUR_API_KEY>` and `<YOUR_AWS_PROFILE>`
- `CLAUDE.md` — replace any environment-specific references with your own clusters, namespaces, and tooling
- `statusline-command.sh` — update the `case` block with your AWS profile names
- `settings.json` — adjust permissions to match the tools you actually use

## Structure

```
.
├── CLAUDE.md                       # Behavior rules and conventions
├── settings.json                   # Permissions, hooks, plugins
├── config/
│   └── mcp.json                    # MCP server configurations
├── skills/                         # Custom skills (see above)
├── agents/                         # Custom agent definitions
├── claude-powerline.json           # Powerline theme config
├── claude-powerline-custom.json    # Custom powerline theme
└── statusline-command.sh           # Status line script
```

## Notes

- Only custom skills are in this repo. Marketplace skills and plugin-provided skills install separately.
- `commands/` is gitignored — command collections like CCPlugins install there and are project-specific.
- Never commit real API keys. The `mcp.json` here uses placeholders; keep your real values in `~/.claude/config/mcp.json`.
