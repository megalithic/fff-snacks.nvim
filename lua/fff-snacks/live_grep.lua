-- maps to require("fff").live_grep()

local M = {}

local conf = require "fff.conf"
local file_picker = require "fff.file_picker"

---@type FFFSnacksGrepConfig
M.source = {
  title = "FFF Live Grep",
  format = "file",
  live = true,

  ---@param opts FFFSnacksGrepConfig
  finder = function(opts, ctx)
    -- fff.picker_ui: initialize_picker
    if not file_picker.is_initialized() then
      if not file_picker.setup() then
        vim.notify("Failed to initialize file picker", vim.log.levels.ERROR)
        return {}
      end
    end

    local config = conf.get()
    local merged_config = vim.tbl_deep_extend("force", config or {}, opts or {})
    if not merged_config then
      return {}
    end

    local base_path = opts.cwd or vim.uv.cwd()
    if not base_path then
      return {}
    end

    if ctx.filter.search == "" then
      return {}
    end

    opts.grep_mode = opts.grep_mode or vim.tbl_get(merged_config, "grep", "modes") or { "plain", "regex", "fuzzy" }

    local grep = require "fff.grep"
    local grep_result = grep.search(
      ctx.filter.search,
      0,
      opts.limit or merged_config.max_results,
      merged_config.grep_config,
      opts.grep_mode[1] or "plain"
    )

    -- If scoped from file picker, filter to only those files
    local scoped_files = opts._scoped_files
    local scoped_set = nil
    if scoped_files then
      scoped_set = {}
      for _, f in ipairs(scoped_files) do
        scoped_set[f] = true
      end
    end

    ---@type snacks.picker.finder.Item[]
    local items = {}
    for idx, fff_item in ipairs(grep_result.items) do
      -- Skip files not in scoped set (if scoped)
      if scoped_set and not scoped_set[fff_item.relative_path] then
        goto continue
      end
      assert(fff_item.line_number, "Expected line_number in grep result item")
      local match_ranges = fff_item.match_ranges or {}
      local first_range = match_ranges[1] or { 0, 0 }
      local pos = { fff_item.line_number, first_range[1] }

      local positions = {}
      for _, range in ipairs(match_ranges) do
        for i = range[1] + 1, range[2] do
          positions[#positions + 1] = i
        end
      end

      ---@type snacks.picker.finder.Item
      local item = {
        idx = idx,
        cwd = base_path,
        file = fff_item.relative_path,
        line = fff_item.line_content,

        pos = pos,
        end_pos = { fff_item.line_number, first_range[2] },
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

  ---@param picker FFFSnacksGrepPicker
  on_show = function(picker)
    local modes = picker.opts.grep_mode or { "plain", "regex", "fuzzy" }
    picker.opts._is_grep_mode_plain = modes[1] == "plain"
    picker.opts._is_grep_mode_regex = modes[1] == "regex"
    picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"

    -- Update title to show current mode
    local mode_label = modes[1]:sub(1, 1):upper() .. modes[1]:sub(2)
    local base_title = picker.opts._from_files and "FFF Grep (scoped)" or "FFF Grep"
    picker.opts.title = base_title .. " [" .. mode_label .. "]"
  end,

  actions = {
    ---@param picker FFFSnacksGrepPicker
    cycle_grep_mode = function(picker)
      local modes = picker.opts.grep_mode or { "plain", "regex", "fuzzy" }
      -- move the first mode to the end of the list
      local first_mode = modes[1]
      table.remove(modes, 1)
      modes[#modes + 1] = first_mode
      picker.opts.grep_mode = modes
      picker.opts._is_grep_mode_plain = modes[1] == "plain"
      picker.opts._is_grep_mode_regex = modes[1] == "regex"
      picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"

      -- Update title to show current mode
      local mode_label = modes[1]:sub(1, 1):upper() .. modes[1]:sub(2)
      local base_title = picker.opts._from_files and "FFF Grep (scoped)" or "FFF Grep"
      picker.opts.title = base_title .. " [" .. mode_label .. "]"

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
        ["<c-y>"] = { "cycle_grep_mode", mode = { "n", "i" }, nowait = true },
      },
    },
  },
}

return M
