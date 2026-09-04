-- maps to require("fff").live_grep()

local M = {}

local fff = require "fff"
local conf = require "fff.conf"
local file_picker = require "fff.file_picker"
local utils = require "fff-snacks.utils"

--- Resolve grep config from picker opts override and fff config.
---@param picker_opts table
---@return table
local function get_grep_config(picker_opts)
  local fff_config = conf.get()
  return vim.tbl_deep_extend("force", fff_config.grep or fff_config.grep_config or {}, picker_opts.grep or picker_opts.grep_config or {})
end

--- Resolve grep modes from picker opts override, fff config, or fallback defaults
---@param picker_opts table
---@return string[]
local function get_grep_modes(picker_opts)
  local grep_config = get_grep_config(picker_opts)
  return picker_opts.grep_mode
    or grep_config.modes
    or {
      "plain",
      "regex",
      "fuzzy",
    }
end

---@type fff_snacks.GrepConfig
M.source = {
  title = "Live Grep",
  format = "file",
  live = true,

  ---@param opts fff_snacks.GrepConfig
  finder = function(opts, ctx)
    if ctx.filter.search == "" then
      return {}
    end

    if opts.cwd ~= nil then
      vim.notify("The 'cwd' option is not supported in FFF", vim.log.levels.WARN)
    end

    local fff_config = conf.get()
    local base_path = fff_config.base_path or vim.fn.getcwd()
    local grep_config = get_grep_config(opts)
    local grep_mode = get_grep_modes(opts)
    local grep_result = fff.content_search(ctx.filter.search, {
      cwd = base_path,
      file_offset = 0,
      page_size = opts.limit or fff_config.max_results,
      mode = grep_mode[1],
      max_file_size = grep_config.max_file_size,
      max_matches_per_file = grep_config.max_matches_per_file,
      smart_case = grep_config.smart_case,
      time_budget_ms = grep_config.time_budget_ms,
      trim_whitespace = grep_config.trim_whitespace,
    })

    -- If scoped from file picker, filter to only those files
    local scoped_files = opts._scoped_files
    local scoped_set = nil
    local scoped_cwd = base_path:gsub("/$", "") .. "/"
    if scoped_files then
      scoped_set = {}
      for _, f in ipairs(scoped_files) do
        -- Store both absolute and relative versions for matching
        local rel = f
        if f:sub(1, #scoped_cwd) == scoped_cwd then
          rel = f:sub(#scoped_cwd + 1)
        end
        scoped_set[rel] = true
        scoped_set[f] = true -- Also store original
      end
    end

    ---@type snacks.picker.finder.Item[]
    local items = {}
    for idx, fff_item in ipairs(grep_result.items) do
      -- Resolve to absolute path so opening works when cwd != picker base_path.
      -- Falls back to fff_item.path on older fff.nvim versions (pre PR #387).
      -- NOTE: do NOT set `cwd` on the item. Snacks.picker.util.path() joins
      -- `item.cwd .. "/" .. item.file` unconditionally; pairing absolute `file`
      -- with `cwd` produces `/base//abs/path` and breaks open + preview.
      local abs_path = fff_item.path or utils.canonicalize(fff_item.relative_path)

      -- Skip files not in scoped set (if scoped)
      if scoped_set then
        local rel_path = fff_item.relative_path or abs_path
        if abs_path and abs_path:sub(1, #scoped_cwd) == scoped_cwd then
          rel_path = abs_path:sub(#scoped_cwd + 1)
        end
        if not scoped_set[abs_path] and not scoped_set[rel_path] then
          goto continue
        end
      end

      assert(fff_item.line_number, "Expected line_number in grep result item")
      local match_ranges = fff_item.match_ranges or {}

      local pos
      local end_pos
      if #match_ranges == 0 then
        pos = { fff_item.line_number, 0 }
        end_pos = nil
      else
        pos = { fff_item.line_number, match_ranges[1][1] }
        end_pos = { fff_item.line_number, match_ranges[1][2] }
      end

      local positions = {}
      for _, range in ipairs(match_ranges) do
        for i = range[1] + 1, range[2] do
          positions[#positions + 1] = i
        end
      end

      ---@type snacks.picker.finder.Item
      local item = {
        idx = idx,
        file = abs_path,
        line = fff_item.line_content,

        pos = pos,
        end_pos = end_pos,
        positions = positions,

        score = fff_item.total_frecency_score,
        text = ("%s:%d:%d:%s"):format(fff_item.relative_path, pos[1], pos[2], fff_item.line_content),
      }

      items[#items + 1] = item

      ::continue::
    end

    return items
  end,

  toggles = {
    hidden = { icon = "󰘓", value = false },
    ignored = { icon = "󰈉", value = false },
    --- for showing the current grep mode next to the title
    _is_grep_mode_plain = { icon = "plain", value = true },
    _is_grep_mode_regex = { icon = "regex", value = true },
    _is_grep_mode_fuzzy = { icon = "fuzzy", value = true },
    _from_files = { icon = "󰈔→", value = false }, -- scoped from file picker
  },

  ---@param picker fff_snacks.GrepPicker
  on_show = function(picker)
    -- fff.picker_ui: initialize_picker
    if not file_picker.is_initialized() then
      if not file_picker.setup() then
        vim.notify("Failed to initialize file picker", vim.log.levels.ERROR)
        return
      end
    end

    local modes = get_grep_modes(picker.opts)

    picker.opts.grep_mode = modes
    picker.opts._is_grep_mode_plain = modes[1] == "plain"
    picker.opts._is_grep_mode_regex = modes[1] == "regex"
    picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"

    -- Preserve base title for cycle_grep_mode to reuse
    if not picker.opts._base_title then
      picker.opts._base_title = picker.opts.title or "Live Grep"
    end

    local mode_label = modes[1]:sub(1, 1):upper() .. modes[1]:sub(2)
    picker.opts.title = picker.opts._base_title .. " [" .. mode_label .. "]"
  end,

  actions = {
    ---@param picker fff_snacks.GrepPicker
    cycle_grep_mode = function(picker)
      local modes = get_grep_modes(picker.opts)

      local new_modes = vim.deepcopy(modes)
      -- move the first mode to the end of the list
      local first_mode = new_modes[1]
      table.remove(new_modes, 1)
      new_modes[#new_modes + 1] = first_mode

      picker.opts.grep_mode = new_modes
      picker.opts._is_grep_mode_plain = new_modes[1] == "plain"
      picker.opts._is_grep_mode_regex = new_modes[1] == "regex"
      picker.opts._is_grep_mode_fuzzy = new_modes[1] == "fuzzy"

      -- Update title to show current mode
      local mode_label = new_modes[1]:sub(1, 1):upper() .. new_modes[1]:sub(2)
      picker.opts.title = (picker.opts._base_title or "Live Grep") .. " [" .. mode_label .. "]"

      -- Update title in the window
      if picker.input and picker.input.win and picker.input.win.win then
        vim.api.nvim_win_set_config(picker.input.win.win, { title = picker.opts.title })
      end

      picker:refresh()
    end,
  },

  win = {
    input = {
      keys = {
        ["<S-Tab>"] = { "cycle_grep_mode", mode = { "n", "i" }, nowait = true },
      },
    },
  },
}

return M
