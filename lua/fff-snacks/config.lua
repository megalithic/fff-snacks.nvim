local M = {}

---@class fff_snacks.Config
---@field find_files? snacks.picker.Config Default options for find_files
---@field live_grep? fff_snacks.GrepConfig Default options for live_grep
---@field grep_word? fff_snacks.GrepConfig Default options for grep_word (defaults to live_grep if not set)

---@type fff_snacks.Config
local config = {
  find_files = nil,
  live_grep = nil,
  grep_word = nil,
}

---@type table<string, snacks.picker.Config>
local sources = {
  find_files = require("fff-snacks.find_files").source,
  live_grep = require("fff-snacks.live_grep").source,
}

---@param opts? fff_snacks.Config
function M.setup(opts)
  if not opts then
    return
  end
  config.find_files = opts.find_files
  config.live_grep = opts.live_grep
  config.grep_word = opts.grep_word
end

---@return fff_snacks.Config
function M.get_config()
  return config
end

---@param func_type "find_files" | "live_grep" | "grep_word"
---@param runtime_opts? table
---@return snacks.picker.Config
function M.make_opts(func_type, runtime_opts)
  runtime_opts = runtime_opts or {}
  local defaults = config[func_type]
  local source = sources[func_type] or sources.live_grep

  -- grep_word falls back to live_grep if not explicitly set
  if func_type == "grep_word" and defaults == nil then
    defaults = config.live_grep
  end

  -- Merge: source + defaults + runtime_opts
  return vim.tbl_deep_extend("force", source, defaults or {}, runtime_opts)
end

return M
