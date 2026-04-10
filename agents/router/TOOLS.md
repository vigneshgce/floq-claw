# TOOLS — Router

## Available tools
- **Linear CLI**: `./skills/linear/linear.sh` — ticket CRUD, comments, search, status updates
- **GitHub CLI**: `gh` — PR management, repo operations, issue tracking
- **File operations**: read, write, edit — for work packets in `./shared/work/`
- **Shell**: exec — for running scripts and CLI tools

## Tool routing
- Design/spec/grooming requests → delegate to **architect** via `sessions_send`
- Implementation requests → delegate to **builder** via `sessions_send`
- Review requests → delegate to **reviewer** via `sessions_send`
- Infrastructure requests → delegate to **infra** via `sessions_send`

## Repos
- Floq main repo: https://github.com/deepakthegiggs/floq
- Floq claw config: https://github.com/vigneshgce/floq-claw
