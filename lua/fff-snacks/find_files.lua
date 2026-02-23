local M = {}

local utils = require("fff-snacks.utils")
local conf = require("fff.conf")
local file_picker = require("fff.file_picker")

-- Configurable git icons (override via setup)
M.git_icons = {
  modified = "M",
  added = "A",
  deleted = "D",
  renamed = "R",
  untracked = "?",
  ignored = "!",
  clean = " ",
}

-- Frecency indicators (override via setup)
M.frecency_indicators = {
  enabled = true,
  hot = "🔥",
  warm = "⚡",
  medium = "●",
  cold = "○",
  thresholds = { hot = 50, warm = 25, medium = 10 },
}

local staged_status = {
  staged_new = true,
  staged_modified = true,
  staged_deleted = true,
  renamed = true,
}

local status_map = {
  untracked = "untracked",
  modified = "modified",
  deleted = "deleted",
  renamed = "renamed",
  staged_new = "added",
  staged_modified = "modified",
  staged_deleted = "deleted",
  ignored = "ignored",
  unknown = "untracked",
}

local function is_hidden(path)
  return path:match("/%.") or path:match("^%.")
end

local function format_file_git_status(item)
  local ret = {}
  local status = item.status

  local hl = "SnacksPickerGitStatus"
  if status.unmerged then
    hl = "SnacksPickerGitStatusUnmerged"
  elseif status.staged then
    hl = "SnacksPickerGitStatusStaged"
  else
    hl = "SnacksPickerGitStatus" .. status.status:sub(1, 1):upper() .. status.status:sub(2)
  end

  local icon = M.git_icons[status.status] or M.git_icons.clean
  ret[#ret + 1] = { icon, hl }
  ret[#ret + 1] = { " ", virtual = true }

  return ret
end

local function format_frecency(score)
  if not M.frecency_indicators.enabled then
    return tostring(score)
  end

  local t = M.frecency_indicators.thresholds
  local indicator
  if score >= t.hot then
    indicator = M.frecency_indicators.hot
  elseif score >= t.warm then
    indicator = M.frecency_indicators.warm
  elseif score >= t.medium then
    indicator = M.frecency_indicators.medium
  else
    indicator = M.frecency_indicators.cold
  end

  return tostring(score) .. " " .. indicator
end

M.source = {
  title = "FFFiles {flags}",

  -- Toggle state for hidden/ignored and mode indicator
  toggles = {
    hidden = { icon = "󰘓", value = false },
    ignored = { icon = "󰈉", value = false },
    _from_grep = { icon = "󰱼→󰈔", value = false }, -- shows when narrowed from grep
  },

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

    local current_file = utils.get_current_file(base_path)

    local fff_result = file_picker.search_files(
      ctx.filter.search,
      current_file,
      opts.limit or merged_config.max_results,
      merged_config.max_threads,
      nil
    )

    -- Get toggle state from picker opts
    local show_hidden = opts.hidden or false
    local show_ignored = opts.ignored or false

    local items = {}
    for idx, fff_item in ipairs(fff_result) do
      -- Filter hidden files
      if not show_hidden and is_hidden(fff_item.path) then
        goto continue
      end

      -- Filter ignored files
      if not show_ignored and fff_item.git_status == "ignored" then
        goto continue
      end

      local score_data = file_picker.get_file_score and file_picker.get_file_score(idx) or nil

      local item = {
        text = fff_item.name,
        file = fff_item.path,
        score = fff_item.total_frecency_score,
        status = status_map[fff_item.git_status] and {
          status = status_map[fff_item.git_status],
          staged = staged_status[fff_item.git_status] or false,
          unmerged = fff_item.git_status == "unmerged",
        },
        fff_item = fff_item,
        fff_score = score_data,
      }
      items[#items + 1] = item

      ::continue::
    end

    return items
  end,

  format = function(item, picker)
    local ret = {}

    if item.label then
      ret[#ret + 1] = { item.label, "SnacksPickerLabel" }
      ret[#ret + 1] = { " ", virtual = true }
    end

    if item.status then
      vim.list_extend(ret, format_file_git_status(item))
    else
      ret[#ret + 1] = { M.git_icons.clean, "Comment" }
      ret[#ret + 1] = { " ", virtual = true }
    end

    vim.list_extend(ret, require("snacks").picker.format.filename(item, picker))

    if item.line then
      require("snacks").picker.highlight.format(item, item.line, ret)
      table.insert(ret, { " " })
    end

    -- Right-aligned frecency score
    if item.fff_item then
      ret[#ret + 1] = {
        col = 0,
        virt_text = { { format_frecency(item.fff_item.total_frecency_score), "Comment" } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      }
    end

    return ret
  end,

  actions = {
    -- Toggle to grep mode with current results (seeker-style)
    toggle_to_grep = function(picker)
      local items = picker:items()
      if #items == 0 then
        return
      end

      -- Collect file paths from current results
      local file_paths = {}
      for _, item in ipairs(items) do
        if item.file then
          table.insert(file_paths, item.file)
        end
      end

      if #file_paths == 0 then
        return
      end

      picker:close()

      -- Open grep picker scoped to these files
      vim.schedule(function()
        local live_grep = require("fff-snacks.live_grep")
        Snacks.picker(vim.tbl_deep_extend("force", live_grep.source, {
          dirs = file_paths,
          _from_files = true, -- show indicator
        }))
      end)
    end,
  },

  win = {
    input = {
      keys = {
        -- Toggle hidden + ignored (like snacks <C-h>)
        ["<C-h>"] = { { "toggle_hidden", "toggle_ignored" }, mode = { "i", "n" } },
        -- Toggle to grep mode (seeker-style)
        ["<C-g>"] = { "toggle_to_grep", mode = { "i", "n" } },
      },
    },
  },

  on_close = function() end,

  formatters = {
    file = { filename_first = true },
  },
  live = true,
}

return M
