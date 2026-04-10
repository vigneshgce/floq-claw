# floq-claw

OpenClaw agent profile for automating Floq product development. 5 agents working together through Linear and GitHub.

## Agents

| Agent | Role |
|-------|------|
| **Router** 🚦 | Front-door orchestrator — classifies tasks, routes to agents, keeps Linear updated |
| **Architect** 🧠 | CTO-level technical grooming — reads codebase, produces specs and task breakdowns |
| **Builder** 🛠️ | Implementation owner — writes code, creates branches and PRs |
| **Reviewer** 🔬 | Principal engineer review gate — correctness, security, performance |
| **Infra** 🚂 | Railway infrastructure — deployments, services, environments |

## How it works

```
Linear ticket → Router classifies → Architect designs (if needed) → Builder implements → Reviewer reviews → Linear updated
```

### Three pipelines

- **SMALL** (builder only): typos, config changes, simple fixes
- **MEDIUM** (architect → builder → reviewer): standard features — architect produces task breakdown
- **BIG** (architect → builder → reviewer): complex features — architect produces full spec, tasks, and tests

### Big task flow

1. Router classifies task as BIG, creates work folder, sends to Architect
2. Architect reads codebase, produces `spec.md`, `tasks.md`, `tests.md` (may ask questions first)
3. Builder implements per spec, creates PR
4. Reviewer reviews against spec and acceptance criteria
5. If issues found: builder fixes, reviewer re-reviews (max 3 rounds)
6. On pass: Linear updated to Done, PR approved

## Setup

```bash
# Clone
git clone https://github.com/vigneshgce/floq-claw.git
cd floq-claw

# Set up Linear API key
./scripts/setup.sh --api-key lin_api_XXXXX

# Or manually
echo "lin_api_XXXXX" > ./skills/linear/.linear-api-key
chmod 600 ./skills/linear/.linear-api-key
```

## Project structure

```
floq-claw/
├── openclaw.json              # Main OpenClaw config (5 agents)
├── agents/
│   ├── router/                # Router: SOUL.md, AGENTS.md, IDENTITY.md, TOOLS.md
│   ├── architect/             # Architect: CTO-level grooming and specs
│   ├── builder/               # Builder: implementation agent
│   ├── reviewer/              # Reviewer: principal engineer review
│   └── infra/                 # Infra: Railway infrastructure
├── architect/
│   └── notes/                 # Per-ticket analysis notes (ANALYSIS.md, QUESTIONS.md)
├── skills/
│   └── linear/                # Linear API skill (SKILL.md + linear.sh)
├── shared/
│   ├── templates/             # Spec, tasks, tests, status templates
│   └── work/                  # Per-ticket work packets
│       └── _TEMPLATE/         # Base templates for work packets
├── scripts/
│   ├── setup.sh               # Setup script
│   ├── create-work-packet.sh  # Create work packet from Linear ticket
│   └── sync-linear.sh         # Sync status between local and Linear
└── docs/
    └── architecture.md        # Full architecture documentation
```

## Linear integration

All agents use the Linear skill for ticket management:

```bash
./skills/linear/linear.sh get FLOQ-42           # Get ticket details
./skills/linear/linear.sh comment FLOQ-42 "msg"  # Add comment
./skills/linear/linear.sh search "auth bug"       # Search tickets
./skills/linear/linear.sh update FLOQ-42 state "In Progress"
./skills/linear/linear.sh create "New feature"    # Create ticket
./skills/linear/linear.sh list-states             # List workflow states
./skills/linear/linear.sh assign FLOQ-42 "Name"  # Assign ticket
```

## Work packets

Each Linear ticket gets a work folder at `./shared/work/<LINEAR-ID>/`:

| File | When | Purpose |
|------|------|---------|
| `status.md` | Always | State, owner, timeline, links |
| `tasks.md` | MEDIUM + BIG | Ordered task checklist (by Architect) |
| `spec.md` | BIG only | Technical specification (by Architect) |
| `tests.md` | BIG only | Test plan, curl commands, acceptance criteria (by Architect) |
| `review.md` | After review | Verdict, findings, spec compliance |

## Configuration

The `openclaw.json` is designed to be loaded as an OpenClaw profile:

```bash
# Copy to OpenClaw config directory
cp openclaw.json ~/.openclaw/profiles/floq.json

# Or load directly
openclaw config load ./openclaw.json --profile floq
```

## Inspired by

Architecture informed by:
- [Anthropic: Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
- [OpenClaw multi-agent patterns](https://docs.openclaw.ai/concepts/multi-agent)
- [Composio Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator)
- [McKinsey: Agentic Workflows for Software Development](https://medium.com/quantumblack/agentic-workflows-for-software-development)
- Existing floq default profile (yoda/builder/critic/architect/infra)

## License

MIT
