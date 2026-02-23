# fff-snacks.nvim - Merged Fork

Merged fork combining features from two upstream sources.

## Upstreams

| Remote | Repo | Features |
|--------|------|----------|
| `upstream` | madmaxieee/fff-snacks.nvim | Base, live_grep, modular structure |
| `nikbrunner` | nikbrunner/fff-snacks.nvim | Frecency indicators, git icons, config |

## Strategy

- **Base**: madmaxieee (upstream) - has live_grep and modular file structure
- **Enhancements**: Cherry-pick nikbrunner's features on top
- **Conflicts**: Prefer madmaxieee's structure, adapt nikbrunner's features

## Workflow

```bash
# Fetch latest from both upstreams
just fetch

# See what's new
just whats-new

# Review nikbrunner commits interactively
just review-nikbrunner

# Or cherry-pick all at once
just cherry-pick-nikbrunner

# After resolving any conflicts
just push
```

## Key Commands

| Command | Description |
|---------|-------------|
| `just fetch` | Fetch all remotes |
| `just divergence` | Show commit history of both upstreams |
| `just whats-new` | Show new commits since last sync |
| `just nikbrunner-commits` | Commits unique to nikbrunner |
| `just review-nikbrunner` | Interactive cherry-pick |
| `just diff-upstreams` | Full diff between upstreams |
| `just push` | Push main to origin |

## Conflict Resolution

When cherry-picking causes conflicts:

```bash
# See what's conflicted
just conflicts

# Open resolution (uses configured merge tool)
just resolve

# After resolving
just continue
```

## File Structure

madmaxieee uses modular structure:
```
lua/
├── fff-snacks.lua          # Entry point
└── fff-snacks/
    ├── find_files.lua      # File picker source
    ├── live_grep.lua       # Grep source
    └── utils.lua           # Shared utilities
```

nikbrunner uses single file:
```
lua/
└── fff-snacks.lua          # Everything in one file
```

When merging nikbrunner features, adapt them into the modular structure.
