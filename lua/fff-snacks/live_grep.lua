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

    ---@type snacks.picker.finder.Item[]
    local items = {}
    for idx, fff_item in ipairs(grep_result.items) do
      assert(fff_item.line_number, "Expected line_number in grep result item")
      local pos = { fff_item.line_number, fff_item.match_ranges[1][1] }

      local positions = {}
      for _, range in ipairs(fff_item.match_ranges) do
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
        end_pos = { fff_item.line_number, fff_item.match_ranges[1][2] },
        positions = positions,

        score = fff_item.total_frecency_score,
        text = ("%s:%d:%d:%s"):format(fff_item.relative_path, pos[1], pos[2], fff_item.line_content),
      }

      items[#items + 1] = item
    end

    return items
  end,

  toggles = {
    --- for showing the current grep mode next to the title
    _is_grep_mode_plain = { icon = "plain", value = true },
    _is_grep_mode_regex = { icon = "regex", value = true },
    _is_grep_mode_fuzzy = { icon = "fuzzy", value = true },
  },

  ---@param picker FFFSnacksGrepPicker
  on_show = function(picker)
    local modes = picker.opts.grep_mode or { "plain", "regex", "fuzzy" }
    picker.opts._is_grep_mode_plain = modes[1] == "plain"
    picker.opts._is_grep_mode_regex = modes[1] == "regex"
    picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"
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
