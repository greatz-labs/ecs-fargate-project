## How I Work
- For IaC: prefer modular, DRY code. Always flag security risks in configs.
- For articles: clear, direct writing. No filler phrases or excessive hedging.
- Keep explanations concise. I know DevOps well, so skip the basics.
- When suggesting CLI commands, explain what they do but keep it brief.
- Don’t assume. Don’t hide confusion. Surface tradeoffs.
- Minimum code that solves the problem. Nothing speculative.
- Touch only what you must. Clean up only your own mess.
- Define success criteria. Loop until verified.

## Preferences
- YAML over JSON where both are valid
- Add inline comments to explain non-obvious IaC logic
- Flag any hardcoded secrets or credentials immediately

## Compacting instr: Do /compact manually at around 50% context usage rather than waiting for automatic compaction. This way you control what gets preserved.
- When compacting, always preserve: the list of modified files, current test status, and any unresolved issues.