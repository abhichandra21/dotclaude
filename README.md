# My Claude Code Configuration

Personal configuration for Claude Code CLI with custom commands, settings, and MCP integrations.

## Structure

```
.
├── CLAUDE.md                      # Main instructions file (template - fill in your values)
├── settings.json                  # Claude Code settings
├── config/
│   └── mcp.json                  # MCP server configurations
├── skills/                       # Custom skills
│   ├── codex/
│   ├── review-board/
│   ├── review-board-copilot/
│   ├── promptheus/
│   └── writing-assistant/
├── claude-powerline.json         # Powerline theme config
├── claude-powerline-custom.json  # Custom powerline theme
└── statusline-command.sh         # Status line script
```

## Setup

1. **Clone this repo to your preferred location**

2. **Copy configuration files to Claude's directory:**
   ```bash
   # Copy main instructions
   cp CLAUDE.md ~/.claude/CLAUDE.md

   # Copy settings (or merge with existing)
   cp settings.json ~/.claude/settings.json

   # Copy MCP config (or merge with existing)
   cp config/mcp.json ~/.claude/config/mcp.json

   # Copy custom skills
   cp -r skills/* ~/.claude/skills/

   # Copy powerline configs (optional)
   cp claude-powerline*.json ~/.claude/
   cp statusline-command.sh ~/.claude/
   ```

3. **Update CLAUDE.md with your specific values:**
   - Replace AWS account numbers, profiles, clusters
   - Add your Grafana tokens and URLs
   - Update Azure/K8s cluster information
   - Fill in any other environment-specific details

4. **Update config/mcp.json:**
   - Replace `<YOUR_API_KEY>` with your actual Anthropic API key
   - Replace `<YOUR_AWS_PROFILE>` with your AWS profile name
   - Update Python venv path for promptheus if using it

5. **Review settings.json:**
   - Adjust permissions as needed for your workflow
   - Update statusLine command if using custom powerline

## What's Included

### Custom Skills (in this repo)
- **code-review-copilot** - GitHub Copilot-powered multi-model code review
- **promptheus** - AI-powered prompt refinement via MCP
- **review-board** - Multi-LLM document review using external CLIs
- **review-board-copilot** - GitHub Copilot multi-model review board
- **writing-assistant** - Context-aware text rephrasing and improvement

### Marketplace Skills (download separately, not in repo)
- **algorithmic-art** - Generative algorithmic art creation
- **brand-guidelines** - Brand guideline extraction and application
- **canvas-design** - Canvas-based design tools
- **frontend-design** - Production-grade frontend UI generation
- **internal-comms** - Internal communication drafting
- **mcp-builder** - MCP server scaffolding and building
- **rekhta-qafia** - Rekhta qafia/rhyming dictionary search
- **skill-creator** - Guide for creating new skills
- **slack-gif-creator** - Slack GIF creation
- **template-skill** - Starter template for new skills
- **theme-factory** - UI theme generation
- **ac-triage-dependabot** - Safely triage open Dependabot PRs
- **ac-\*** - Private work-specific cluster health, log tracing, and operational skills (not in repo)
- **web-artifacts-builder** - Web artifact generation
- **webapp-testing** - Playwright-based web app testing

### Installed Plugins (install via `claude plugin install`)
- **superpowers** (`superpowers@claude-plugins-official`) - Meta-skill framework: brainstorming, debugging, TDD, plan writing, code review workflows
- **codex** (`codex@openai-codex`) - OpenAI Codex CLI integration
- **claude-hud** (`claude-hud@claude-hud`) - Status line / HUD display
- **claude-md-management** (`claude-md-management@claude-plugins-official`) - CLAUDE.md creation and improvement tools
- **claude-code-setup** (`claude-code-setup@claude-plugins-official`) - Claude Code setup and automation recommendations
- **gopls-lsp** (`gopls-lsp@claude-plugins-official`) - Go language server (LSP) integration
- **firebase** (`firebase@claude-plugins-official`) - Firebase project integration

### MCP Servers (config/mcp.json)
- **aws-knowledge** - AWS documentation search
- **kubernetes** - K8s cluster management
- **memory** - Persistent memory across sessions
- **git** - Git operations
- **promptheus** - Prompt refinement
- **aws-api** - AWS CLI operations
- **cloudflare** - Cloudflare documentation

### Key Features in CLAUDE.md
- **Code quality standards** - No emojis, human-readable names, direct language
- **Change management workflow** - Understand → Plan → One Change → Test → Commit
- **Problem-solving methodology** - Challenge constraints, enumerate solutions
- **Kubernetes safety rules** - No kubectl patch, always backup
- **Critical thinking protocols** - Blast radius analysis, surgical operations

## Notes

- **Only custom skills are in this repo** - Marketplace skills and plugin-provided skills are downloaded separately; see the full lists above
- **Plugins install via** `claude plugin install <name>@<registry>` - versions will differ from those listed above
- **Sensitive information has been redacted** - Fill in your own values
- **This is a template** - Customize to your needs

## Customization

Feel free to:
- Create your own custom skills in `skills/`
- Modify CLAUDE.md instructions for your workflow
- Add/remove MCP servers in config/mcp.json
- Adjust settings.json permissions and hooks
- Install command collections (like CCPlugins) separately in `~/.claude/commands/`

## Security

- Never commit real API keys or tokens
- Keep sensitive environment information in your local ~/.claude/CLAUDE.md
- Use this repo as a template, not a direct copy
