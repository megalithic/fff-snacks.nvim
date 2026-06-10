---@module 'snacks'

---@module 'fff_snacks'

---@alias fff_snacks.GrepMode "plain" | "regex" | "fuzzy"

---@class fff_snacks.GrepConfig: snacks.picker.Config
---@field grep_mode? fff_snacks.GrepMode[]
---@field _is_grep_mode_plain? boolean
---@field _is_grep_mode_regex? boolean
---@field _is_grep_mode_fuzzy? boolean

---@class fff_snacks.GrepPicker: snacks.Picker
---@field opts fff_snacks.GrepConfig

---@class FFFSnacksKeysConfig
---@field cycle_grep_mode? string Keybinding to cycle grep modes (default: "<c-y>")
---@field cycle_picker? string Keybinding to toggle between files/grep (default: "<c-g>")

---@class FFFSnacksJumpConfig
---@field reuse_win? boolean Reuse existing window if buffer is already open (default: true)

---@class FFFSnacksTitlesConfig
---@field files_from_grep? string Title when toggling to files from grep
---@field grep_from_files? string Title when toggling to grep from files

---@class FFFSnacksScopingConfig
---@field warn_threshold? number Warn if scoped file count exceeds this (default: 500)
---@field disable_threshold? number Disable scoping if file count exceeds this (default: nil/disabled)

---@class FFFSnacksSetupOpts
---@field find_files? snacks.picker.Config Config for find_files picker
---@field live_grep? FFFSnacksGrepConfig Config for live_grep picker
---@field keys? FFFSnacksKeysConfig Keybindings
---@field titles? FFFSnacksTitlesConfig Titles for toggled pickers
---@field scoping? FFFSnacksScopingConfig Scoping behavior config
---@field jump? FFFSnacksJumpConfig Jump/confirm behavior config

local M = {}

---@type FFFSnacksSetupOpts
M.config = {
  find_files = {},
  live_grep = {},
  keys = {
    cycle_grep_mode = "<c-y>",
    cycle_picker = "<c-g>",
  },
  titles = {
    files = "Files",
    files_from_grep = "Files (from grep)",
    live_grep = "Live Grep",
    grep_from_files = "Live Grep (from files)",
  },
  scoping = {
    warn_threshold = nil,      -- warn if scoping > N files (nil = disabled)
    disable_threshold = nil,   -- disable scoping if > N files (nil = never disable)
  },
  jump = {
    reuse_win = true,          -- focus existing window if buffer is already open
  },

}


---@param opts? FFFSnacksSetupOpts
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Rebuild sources with config applied
  M._build_sources()
end

--- Format title with search trail breadcrumbs
--- Example: "gitigno, nix → FFF Grep"
---@param base_title string The base picker title
---@param trail table[] Array of {text: string, type: "grep"|"files"}
---@return string
function M._format_title_with_trail(base_title, trail)
  if not trail or #trail == 0 then
    return base_title
  end

  local parts = {}
  for _, entry in ipairs(trail) do
    -- Optionally add icon based on type
    local icon = entry.type == "grep" and "󰱼" or "󰈔"
    parts[#parts + 1] = icon .. " " .. entry.text
  end

  return table.concat(parts, ", ") .. " → " .. base_title
end

--- Custom confirm action that properly opens multiple selected files in splits
---@param picker snacks.Picker
---@param _ any
---@param action table
local function multi_confirm(picker, _, action)
  -- Stop insert mode first
  if vim.fn.mode():sub(1, 1) == "i" then
    vim.cmd.stopinsert()
    vim.schedule(function()
      multi_confirm(picker, _, action)
    end)
    return
  end

  local items = picker:selected({ fallback = true })

  if picker.opts.jump and picker.opts.jump.close ~= false then
    picker:close()
  else
    vim.api.nvim_set_current_win(picker.main)
  end

  if #items == 0 then
    return
  end

  local cmd = action.cmd or "edit"
  local is_split = cmd == "vsplit" or cmd == "split"

  -- For single item or non-split commands, use default behavior
  if #items == 1 or not is_split then
    local item = items[1]
    local buf = item.buf
    if not buf then
      local path = Snacks.picker.util.path(item)
      if path then
        buf = vim.fn.bufadd(path)
      end
    end
    if buf then
      vim.bo[buf].buflisted = true
      local edit_cmd = ({
        edit = "buffer",
        split = "sbuffer",
        vsplit = "vert sbuffer",
        tab = "tab sbuffer",
      })[cmd] or "buffer"
      vim.cmd(("%s %d"):format(edit_cmd, buf))

      -- Set cursor position
      local pos = item.pos
      if pos and pos[1] > 0 then
        vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] })
        vim.cmd("norm! zzzv")
      end
    end
    return
  end

  -- Multiple items with split command - open all in splits
  local split_cmd = cmd == "vsplit" and "vsplit" or "split"

  for i, item in ipairs(items) do
    local buf = item.buf
    if not buf then
      local path = Snacks.picker.util.path(item)
      if path then
        buf = vim.fn.bufadd(path)
      end
    end

    if buf then
      vim.bo[buf].buflisted = true

      if i == 1 then
        -- First item: just open in current window
        vim.cmd(("buffer %d"):format(buf))
      else
        -- Subsequent items: open in new split
        vim.cmd(("%s | buffer %d"):format(split_cmd, buf))
      end

      -- Set cursor position for current window
      local pos = item.pos
      if pos and pos[1] > 0 then
        pcall(vim.api.nvim_win_set_cursor, 0, { pos[1], pos[2] })
      end
    end
  end

  -- Return to first split
  if #items > 1 then
    vim.cmd("wincmd t") -- go to top-left window
  end
end

function M._build_sources()
  local find_files_mod = require("fff-snacks.find_files")
  local live_grep_mod = require("fff-snacks.live_grep")

  -- Build jump config
  local jump_config = { jump = M.config.jump }

  -- Build find_files source with toggle action
  local find_files_source = vim.tbl_deep_extend("force", find_files_mod.source, jump_config, M.config.find_files or {})

  -- Inject custom actions
  find_files_source.actions = find_files_source.actions or {}

  -- Multi-select confirm action
  find_files_source.actions.multi_confirm = multi_confirm
  find_files_source.actions.multi_vsplit = { action = "multi_confirm", cmd = "vsplit" }
  find_files_source.actions.multi_split = { action = "multi_confirm", cmd = "split" }
  find_files_source.actions.toggle_all_files = function(picker)
    local enabled = not (picker.opts.hidden and picker.opts.ignored)
    picker.opts.hidden = enabled
    picker.opts.ignored = enabled
    picker.list:set_target()
    picker:find()
  end

  find_files_source.actions.toggle_to_grep = function(picker)
    local items = picker:items()

    -- Capture current filter text and build search trail
    local current_text = vim.trim(picker.input.filter.search or picker.input.filter.pattern or "")
    local trail = vim.deepcopy(picker.opts._search_trail or {})
    if current_text ~= "" then
      trail[#trail + 1] = { text = current_text, type = "files" }
    end

    -- Collect file paths for scoping (if any)
    local file_paths = {}
    for _, item in ipairs(items) do
      if item.file then
        file_paths[#file_paths + 1] = item.file
      end
    end

    -- Determine if we should scope
    local use_scoping = #file_paths > 0
    local scoping = M.config.scoping

    if use_scoping then
      local file_count = #file_paths
      if scoping.disable_threshold and file_count > scoping.disable_threshold then
        vim.notify(
          string.format("Scoping disabled: %d files exceeds threshold (%d)", file_count, scoping.disable_threshold),
          vim.log.levels.WARN
        )
        use_scoping = false
      elseif scoping.warn_threshold and file_count > scoping.warn_threshold then
        vim.notify(
          string.format("Large scoped search: %d files (may be slow)", file_count),
          vim.log.levels.WARN
        )
      end
    end

    picker:close()

    vim.schedule(function()
      -- Build title with search trail
      local base_title = use_scoping and M.config.titles.grep_from_files or M.config.titles.live_grep
      local title = M._format_title_with_trail(base_title, trail)

      local grep_source = vim.tbl_deep_extend("force", M.sources.live_grep, {
        title = title,
        _from_files = use_scoping,
        _scoped_files = use_scoping and file_paths or nil,
        _search_trail = trail,
        _base_title = title, -- Use title with trail so mode cycling preserves it
      })
      Snacks.picker(grep_source)
    end)
  end

  -- Set keybindings for find_files
  find_files_source.win = find_files_source.win or {}
  find_files_source.win.input = find_files_source.win.input or {}
  find_files_source.win.input.keys = find_files_source.win.input.keys or {}

  -- Toggle to grep
  find_files_source.win.input.keys[M.config.keys.cycle_picker] = {
    "toggle_to_grep", mode = { "n", "i" }, desc = "Toggle to grep"
  }
  find_files_source.win.input.keys["<a-h>"] = { "toggle_all_files", mode = { "n", "i" }, desc = "Toggle all files" }

  -- Multi-select aware confirm/split actions
  find_files_source.win.input.keys["<CR>"] = { "multi_vsplit", mode = { "n", "i" } }
  find_files_source.win.input.keys["<c-v>"] = { "multi_vsplit", mode = { "n", "i" } }
  find_files_source.win.input.keys["<c-s>"] = { "multi_split", mode = { "n", "i" } }
  find_files_source.win.input.keys["<c-o>"] = { "multi_confirm", mode = { "n", "i" } }

  -- List window keys too
  find_files_source.win.list = find_files_source.win.list or {}
  find_files_source.win.list.keys = find_files_source.win.list.keys or {}
  find_files_source.win.list.keys["<a-h>"] = { "toggle_all_files", mode = { "n" }, desc = "Toggle all files" }
  find_files_source.win.list.keys["<CR>"] = { "multi_vsplit", mode = { "n" } }
  find_files_source.win.list.keys["<c-v>"] = { "multi_vsplit", mode = { "n" } }
  find_files_source.win.list.keys["<c-s>"] = { "multi_split", mode = { "n" } }
  find_files_source.win.list.keys["<c-o>"] = { "multi_confirm", mode = { "n" } }

  -- Build live_grep source with toggle action
  local live_grep_source = vim.tbl_deep_extend("force", live_grep_mod.source, jump_config, M.config.live_grep or {})

  -- Inject custom actions
  live_grep_source.actions = live_grep_source.actions or {}

  -- Multi-select confirm action
  live_grep_source.actions.multi_confirm = multi_confirm
  live_grep_source.actions.multi_vsplit = { action = "multi_confirm", cmd = "vsplit" }
  live_grep_source.actions.multi_split = { action = "multi_confirm", cmd = "split" }

  live_grep_source.actions.toggle_to_files = function(picker)
    local items = picker:items()

    -- Capture current search text and build search trail
    local current_text = vim.trim(picker.input.filter.search or "")
    local trail = vim.deepcopy(picker.opts._search_trail or {})
    if current_text ~= "" then
      trail[#trail + 1] = { text = current_text, type = "grep" }
    end

    -- Collect unique file paths for scoping (if any)
    local seen = {}
    local file_paths = {}
    for _, item in ipairs(items) do
      if item.file and not seen[item.file] then
        seen[item.file] = true
        file_paths[#file_paths + 1] = item.file
      end
    end

    -- Determine if we should scope
    local use_scoping = #file_paths > 0
    local scoping = M.config.scoping

    if use_scoping then
      local file_count = #file_paths
      if scoping.disable_threshold and file_count > scoping.disable_threshold then
        vim.notify(
          string.format("Scoping disabled: %d files exceeds threshold (%d)", file_count, scoping.disable_threshold),
          vim.log.levels.WARN
        )
        use_scoping = false
      elseif scoping.warn_threshold and file_count > scoping.warn_threshold then
        vim.notify(
          string.format("Large scoped search: %d files (may be slow)", file_count),
          vim.log.levels.WARN
        )
      end
    end

    picker:close()

    vim.schedule(function()
      -- Build title with search trail
      local base_title = use_scoping and M.config.titles.files_from_grep or M.config.titles.files
      local title = M._format_title_with_trail(base_title, trail)

      local files_source = vim.tbl_deep_extend("force", M.sources.find_files, {
        title = title,
        _from_grep = use_scoping,
        _scoped_files = use_scoping and file_paths or nil,
        _search_trail = trail,
      })
      Snacks.picker(files_source)
    end)
  end

  -- Set keybindings for live_grep
  live_grep_source.win = live_grep_source.win or {}
  live_grep_source.win.input = live_grep_source.win.input or {}
  live_grep_source.win.input.keys = live_grep_source.win.input.keys or {}

  -- Toggle to files
  live_grep_source.win.input.keys[M.config.keys.cycle_picker] = {
    "toggle_to_files", mode = { "n", "i" }, desc = "Toggle to files"
  }

  -- Cycle grep mode (override default if configured differently)
  if M.config.keys.cycle_grep_mode ~= "<c-y>" then
    live_grep_source.win.input.keys["<c-y>"] = nil
  end
  live_grep_source.win.input.keys[M.config.keys.cycle_grep_mode] = {
    "cycle_grep_mode", mode = { "n", "i" }, nowait = true, desc = "Cycle grep mode"
  }

  -- Multi-select aware confirm/split actions
  live_grep_source.win.input.keys["<CR>"] = { "multi_vsplit", mode = { "n", "i" } }
  live_grep_source.win.input.keys["<c-v>"] = { "multi_vsplit", mode = { "n", "i" } }
  live_grep_source.win.input.keys["<c-s>"] = { "multi_split", mode = { "n", "i" } }
  live_grep_source.win.input.keys["<c-o>"] = { "multi_confirm", mode = { "n", "i" } }

  -- List window keys too
  live_grep_source.win.list = live_grep_source.win.list or {}
  live_grep_source.win.list.keys = live_grep_source.win.list.keys or {}
  live_grep_source.win.list.keys["<CR>"] = { "multi_vsplit", mode = { "n" } }
  live_grep_source.win.list.keys["<c-v>"] = { "multi_vsplit", mode = { "n" } }
  live_grep_source.win.list.keys["<c-s>"] = { "multi_split", mode = { "n" } }
  live_grep_source.win.list.keys["<c-o>"] = { "multi_confirm", mode = { "n" } }

  M.sources = {
    find_files = find_files_source,
    live_grep = live_grep_source,
  }
end

-- Initialize with defaults
M._build_sources()

---@param opts? snacks.picker.Config
function M.find_files(opts)
  local source = vim.tbl_deep_extend("force", M.sources.find_files, opts or {})
  Snacks.picker(source)
end

---@param opts? FFFSnacksGrepConfig
function M.live_grep(opts)
  local source = vim.tbl_deep_extend("force", M.sources.live_grep, opts or {})
  Snacks.picker(source)
end

---@param opts? FFFSnacksGrepConfig
function M.grep_word(opts)
  opts = opts or {}
  -- Get word before picker creation so we can show it in title
  local word = vim.fn.expand("<cword>")
  -- Check for visual selection
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    vim.cmd('noau normal! "vy')
    word = vim.fn.getreg("v")
  end
  opts.search = word
  opts.title = string.format('Grep "%s"', word)
  M.live_grep(opts)
end

return M
