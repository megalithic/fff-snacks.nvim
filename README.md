# fff-snacks.nvim

A [snacks.nvim](https://github.com/folke/snacks.nvim) source for [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim).

## Installation

```lua
return {
  {
    "dmtrKovalenko/fff.nvim",
    build = function()
      require("fff.download").download_or_build_binary()
    end,
    lazy = false, -- make fff initialize on startup
  },

  {
    "madmaxieee/fff-snacks.nvim",
    lazy = false, -- lazy loaded by design
    ---@module "fff_snacks"
    ---@type fff_snacks.Config
    opts = {
      -- Optional: configure default options for each picker
      -- find_files = { ... },
      -- live_grep = { grep_mode = { "fuzzy", "regex", "plain" } },
      -- grep_word = { ... }, -- defaults to live_grep if not set
    },
    keys = {
      {
        "ff",
        function()
          require("fff-snacks").find_files()
        end,
        desc = "FFF find files",
      },
      {
        "fw",
        function()
          require("fff-snacks").live_grep()
        end,
        desc = "FFF live grep",
      },
      {
        mode = "v",
        "fw",
        function()
          require("fff-snacks").grep_word()
        end,
        desc = "FFF grep word",
      },
      {
        "fz",
        function()
          require("fff-snacks").live_grep({
            grep_mode = { "fuzzy", "plain", "regex" },
          })
        end,
        desc = "FFF live grep (fuzzy)",
      },
    },
  },
}
```

### Type Hints

The plugin provides LuaCATS annotations for type hints. Available types:

- `fff_snacks.Config` - Configuration object
- `fff_snacks.GrepConfig` - Configuration for grep functions (extends `snacks.picker.Config`)
- `fff_snacks.GrepMode` - Union type: `"plain" | "regex" | "fuzzy"`

## User Commands

The plugin provides a `:FFFSnacks` command with the following subcommands:

- `:FFFSnacks find_files` - Open file picker (default if no argument)
- `:FFFSnacks live_grep` - Open grep picker with plain/regex/fuzzy modes
- `:FFFSnacks fuzzy` - Open grep picker with fuzzy/regex/plain modes
- `:FFFSnacks grep_word` - Grep for word under cursor

Custom default options configured via `setup()` also apply to these commands.
