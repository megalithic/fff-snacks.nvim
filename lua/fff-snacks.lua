---@module 'snacks'

local M = {}

local find_files = require("fff-snacks.find_files")
local live_grep = require("fff-snacks.live_grep")

---@class FFFSnacksGitIcons
---@field modified? string
---@field added? string
---@field deleted? string
---@field renamed? string
---@field untracked? string
---@field ignored? string
---@field clean? string

---@class FFFSnacksFrecencyIndicators
---@field enabled? boolean
---@field hot? string
---@field warm? string
---@field medium? string
---@field cold? string
---@field thresholds? { hot?: number, warm?: number, medium?: number }

---@class FFFSnacksConfig: snacks.picker.Config
---@field git_icons? FFFSnacksGitIcons
---@field frecency_indicators? FFFSnacksFrecencyIndicators

---@alias FFFGrepMode "plain" | "regex" | "fuzzy"

---@class FFFSnacksGrepConfig: snacks.picker.Config
---@field grep_mode? FFFGrepMode[]

M.sources = {
  find_files = find_files.source,
  live_grep = live_grep.source,
}

---@param opts? FFFSnacksConfig
function M.setup(opts)
  opts = opts or {}

  -- Configure git icons
  if opts.git_icons then
    find_files.git_icons = vim.tbl_deep_extend("force", find_files.git_icons, opts.git_icons)
    opts.git_icons = nil
  end

  -- Configure frecency indicators
  if opts.frecency_indicators then
    find_files.frecency_indicators = vim.tbl_deep_extend("force", find_files.frecency_indicators, opts.frecency_indicators)
    opts.frecency_indicators = nil
  end

  -- Register sources with Snacks
  if Snacks and pcall(require, "snacks.picker") then
    local fff_source = vim.tbl_deep_extend("force", find_files.source, opts)
    local grep_source = vim.tbl_deep_extend("force", live_grep.source, opts)
    Snacks.picker.sources.fff = fff_source
    Snacks.picker.sources.fff_live_grep = grep_source
  end

  -- Commands
  vim.api.nvim_create_user_command("FFFSnacks", function()
    if Snacks and pcall(require, "snacks.picker") then
      local fff_source = vim.tbl_deep_extend("force", find_files.source, opts)
      Snacks.picker(fff_source)
    else
      vim.notify("fff-snacks: Snacks is not loaded", vim.log.levels.ERROR)
    end
  end, { desc = "Open FFF file picker" })

  vim.api.nvim_create_user_command("FFFSnacksGrep", function()
    if Snacks and pcall(require, "snacks.picker") then
      local grep_source = vim.tbl_deep_extend("force", live_grep.source, opts)
      Snacks.picker(grep_source)
    else
      vim.notify("fff-snacks: Snacks is not loaded", vim.log.levels.ERROR)
    end
  end, { desc = "Open FFF live grep" })
end

---@param opts? snacks.picker.Config
function M.find_files(opts)
  Snacks.picker.fff(opts)
end

---@param opts? FFFSnacksGrepConfig
function M.live_grep(opts)
  Snacks.picker.fff_live_grep(opts)
end

---@param opts? FFFSnacksGrepConfig
function M.grep_word(opts)
  opts = opts or {}
  opts.search = function(picker)
    return picker:word()
  end
  Snacks.picker.fff_live_grep(opts)
end

return M
