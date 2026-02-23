local M = {}

local conf = require("fff.conf")
local file_picker = require("fff.file_picker")

M.source = {
  title = "FFF Grep {flags}",
  format = "file",
  live = true,

  finder = function(opts, ctx)
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

    local grep = require("fff.grep")
    local grep_result = grep.search(
      ctx.filter.search,
      0,
      opts.limit or merged_config.max_results,
      merged_config.grep_config,
      opts.grep_mode[1] or "plain"
    )

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
    _is_grep_mode_plain = { icon = "plain", value = true },
    _is_grep_mode_regex = { icon = "regex", value = true },
    _is_grep_mode_fuzzy = { icon = "fuzzy", value = true },
    _from_files = { icon = "󰈔→󰱼", value = false }, -- shows when scoped from file picker
  },

  on_show = function(picker)
    local modes = picker.opts.grep_mode or { "plain", "regex", "fuzzy" }
    picker.opts._is_grep_mode_plain = modes[1] == "plain"
    picker.opts._is_grep_mode_regex = modes[1] == "regex"
    picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"
  end,

  actions = {
    cycle_grep_mode = function(picker)
      local modes = picker.opts.grep_mode or { "plain", "regex", "fuzzy" }
      local first_mode = modes[1]
      table.remove(modes, 1)
      modes[#modes + 1] = first_mode
      picker.opts.grep_mode = modes
      picker.opts._is_grep_mode_plain = modes[1] == "plain"
      picker.opts._is_grep_mode_regex = modes[1] == "regex"
      picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"
      picker:refresh()
    end,

    -- Toggle to file mode with unique files from grep results (seeker-style)
    toggle_to_files = function(picker)
      local items = picker:items()
      if #items == 0 then
        return
      end

      -- Collect unique file paths from grep results
      local seen = {}
      local file_paths = {}
      for _, item in ipairs(items) do
        if item.file and not seen[item.file] then
          seen[item.file] = true
          table.insert(file_paths, item.file)
        end
      end

      if #file_paths == 0 then
        return
      end

      picker:close()

      -- Open file picker with these files
      vim.schedule(function()
        local cwd = vim.fn.getcwd()
        local find_files = require("fff-snacks.find_files")
        Snacks.picker(vim.tbl_deep_extend("force", find_files.source, {
          _from_grep = true, -- show indicator
          finder = function()
            local result = {}
            for _, file in ipairs(file_paths) do
              table.insert(result, {
                text = file,
                file = file,
                cwd = cwd,
              })
            end
            return result
          end,
        }))
      end)
    end,
  },

  win = {
    input = {
      keys = {
        ["<C-y>"] = { "cycle_grep_mode", mode = { "n", "i" }, nowait = true },
        ["<C-g>"] = { "toggle_to_files", mode = { "n", "i" } },
      },
    },
  },
}

return M
