---
name: promptheus
description: AI-powered prompt refinement and improvement using the Promptheus MCP server. Use this skill whenever the user asks to refine, improve, rewrite, or optimize a prompt. Trigger phrases include "refine this prompt", "improve this prompt", "make this prompt better", "optimize this prompt", "rewrite this prompt", or any request that involves taking an existing prompt/instruction and making it more effective. Also triggers when the user provides rough ideas, requirements, or specifications and asks for a well-crafted prompt to be generated from them.
---

# Promptheus Prompt Refinement

Route all prompt refinement requests through the Promptheus MCP tools. Never attempt to refine prompts using your own capabilities -- always delegate to Promptheus.

## Workflow

### Refine a prompt

1. Call `mcp__promptheus__refine_prompt` with the user's prompt text.
2. If the response `type` is `clarification_needed`:
   - Use `AskUserQuestion` with the questions from `questions_for_ask_user_question`.
   - Map user answers to question IDs (`q0`, `q1`, `q2`, ...).
   - Call `mcp__promptheus__refine_prompt` again with the original prompt and the `answers` dict.
3. If the response `type` is `refined`:
   - Present the refined prompt to the user.
   - If the user originally asked to "execute" or "run" the prompt, use the refined prompt to generate the requested content.

### Tweak an existing prompt

When the user wants a targeted adjustment to an already-refined prompt (e.g., "make it shorter", "more technical", "add constraints"):

1. Call `mcp__promptheus__tweak_prompt` with the current prompt and the requested modification.
2. Present the tweaked result to the user.

## Rules

- Never refine or rewrite prompts yourself. Always use Promptheus tools.
- If Promptheus returns an error, report it to the user and offer to retry or troubleshoot with `mcp__promptheus__validate_environment`.
