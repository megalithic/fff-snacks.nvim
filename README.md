# fff-snacks.nvim

A [snacks.nvim](https://github.com/folke/snacks.nvim) source for [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim).

**This fork** merges features from [madmaxieee/fff-snacks.nvim](https://github.com/madmaxieee/fff-snacks.nvim) (live_grep) and [nikbrunner/fff-snacks.nvim](https://github.com/nikbrunner/fff-snacks.nvim) (frecency indicators, git icons).

## Features

- Fast file finding powered by fff.nvim
- Live grep with mode cycling (plain/regex/fuzzy)
- Configurable git status icons
- Frecency indicators (🔥⚡●○)
- Right-aligned score display
- Hidden/ignored file toggle (`<C-h>`)
- Seeker-style refinement: toggle between files ↔ grep (`<C-g>`)

## Installation

```lua
return {
  {
    "dmtrKovalenko/fff.nvim",
    build = function()
      require("fff.download").download_or_build_binary()
    end,
    lazy = false,
  },

  {
    "megalithic/fff-snacks.nvim",
    dependencies = { "dmtrKovalenko/fff.nvim", "folke/snacks.nvim" },
    opts = {
      -- Custom git icons (optional)
      git_icons = {
        modified = " ",
        added = " ",
        deleted = " ",
        renamed = " ",
        untracked = "󰎔 ",
        ignored = " ",
        clean = "  ",
      },
      -- Frecency indicators (optional)
      frecency_indicators = {
        enabled = true,
        hot = "🔥",
        warm = "⚡",
        medium = "●",
        cold = "○",
        thresholds = { hot = 50, warm = 25, medium = 10 },
      },
    },
    keys = {
      { "<leader>ff", "<cmd>FFFSnacks<cr>", desc = "Find files (fff)" },
      { "<leader>fg", "<cmd>FFFSnacksGrep<cr>", desc = "Live grep (fff)" },
      {
        "<leader>fw",
        function() require("fff-snacks").grep_word() end,
        mode = { "n", "v" },
        desc = "Grep word (fff)",
      },
    },
  },
}
```

## Configuration

### Git Icons

Override the default git status icons:

```lua
opts = {
  git_icons = {
    modified = "M",   -- Modified files
    added = "A",      -- Staged new files
    deleted = "D",    -- Deleted files
    renamed = "R",    -- Renamed files
    untracked = "?",  -- Untracked files
    ignored = "!",    -- Ignored files
    clean = " ",      -- Clean/unchanged files
  },
}
```

### Frecency Indicators

Visual indicators for file access frequency:

```lua
opts = {
  frecency_indicators = {
    enabled = true,           -- Enable/disable indicators
    hot = "🔥",               -- Score >= 50
    warm = "⚡",               -- Score >= 25
    medium = "●",             -- Score >= 10
    cold = "○",               -- Score < 10
    thresholds = {
      hot = 50,
      warm = 25,
      medium = 10,
    },
  },
}
```

### Grep Modes

Cycle through grep modes with `<C-y>` in the live grep picker:

- `plain` - Literal string matching
- `regex` - Regular expression matching
- `fuzzy` - Fuzzy matching

```lua
-- Start with fuzzy mode
require("fff-snacks").live_grep({
  grep_mode = { "fuzzy", "plain", "regex" },
})
```

## Keybindings

### File Picker

| Key | Action |
|-----|--------|
| `<C-h>` | Toggle hidden + ignored files |
| `<C-g>` | Switch to grep mode (with current files) |

### Grep Picker

| Key | Action |
|-----|--------|
| `<C-y>` | Cycle grep mode (plain → regex → fuzzy) |
| `<C-g>` | Switch to file mode (with matched files) |

### Refinement Workflow (seeker-style)

1. Start with file search: `<leader>ff`
2. Narrow down files, then `<C-g>` to grep within those files
3. Or: Start with grep, then `<C-g>` to see unique files from results

## Commands

| Command | Description |
|---------|-------------|
| `:FFFSnacks` | Open file picker |
| `:FFFSnacksGrep` | Open live grep |

## API

```lua
local fff = require("fff-snacks")

fff.find_files(opts)   -- Open file picker
fff.live_grep(opts)    -- Open live grep
fff.grep_word(opts)    -- Grep word under cursor / selection
```

## Credits

- [dmtrKovalenko/fff.nvim](https://github.com/dmtrKovalenko/fff.nvim) - Fast file finder
- [madmaxieee/fff-snacks.nvim](https://github.com/madmaxieee/fff-snacks.nvim) - Original snacks integration + live_grep
- [nikbrunner/fff-snacks.nvim](https://github.com/nikbrunner/fff-snacks.nvim) - Frecency indicators + git icons
