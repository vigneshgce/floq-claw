# TOOLS — Architect

## Available tools
- **Linear CLI**: `./skills/linear/linear.sh` — ticket lookups, comments, search, status updates
- **GitHub CLI**: `gh` — PR inspection, repo operations, issue tracking
- **File operations**: read, write, edit — for work packets in `./shared/work/` and notes in `./architect/notes/`
- **Shell**: exec — for codebase navigation (grep, find, cat to trace code paths)

## Tool routing
- Architect does NOT implement code or review PRs
- Architect does NOT delegate to other agents — only Router orchestrates
- Architect reads code to understand it, never to modify it

## Key paths
- Work packets: `./shared/work/<LINEAR-ID>/`
- Active queue: `./shared/active.md`
- Work packet template: `./shared/work/_TEMPLATE/`
- Per-ticket notes: `./architect/notes/<TICKET_ID>/`

## Linear integration
- Commands used most: `get`, `comment`, `search`, `update`
- Post questions as Linear comments when grooming needs input
- Post spec-ready summary when grooming completes

## Repos
- Floq main repo: https://github.com/deepakthegiggs/floq
- Floq claw config: https://github.com/vigneshgce/floq-claw
