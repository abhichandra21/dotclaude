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

### Custom Skills
- **codex** - Codex CLI integration for OpenAI GPT models
- **review-board** - Multi-LLM document review using external CLIs
- **review-board-copilot** - GitHub Copilot-powered multi-model review
- **promptheus** - AI-powered prompt refinement via MCP
- **writing-assistant** - Context-aware text rephrasing and improvement

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

- **Marketplace skills/plugins NOT included** - Only custom skills are in this repo. Download marketplace skills separately (algorithmic-art, canvas-design, frontend-design, mcp-builder, etc.)
- **Commands NOT included** - Install command collections like CCPlugins separately if needed
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
