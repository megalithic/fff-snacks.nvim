---@module 'snacks'

---@class snacks.picker.sources.Config
---@field fff snacks.picker.Config
---@field fff_live_grep FFFSnacksGrepConfig

---@class snacks.picker
---@field fff fun(opts?: snacks.picker.Config): snacks.Picker
---@field fff_live_grep fun(opts?: FFFSnacksGrepConfig): snacks.Picker

---@alias FFFGrepMode "plain" | "regex" | "fuzzy"

---@class FFFSnacksGrepConfig: snacks.picker.Config
---@field grep_mode? FFFGrepMode[]
---@field _is_grep_mode_plain? boolean
---@field _is_grep_mode_regex? boolean
---@field _is_grep_mode_fuzzy? boolean

---@class FFFSnacksGrepPicker: snacks.Picker
---@field opts FFFSnacksGrepConfig

return {
  sources = {
    find_files = require("fff-snacks.find_files").source,
    live_grep = require("fff-snacks.live_grep").source,
  },
  ---@param opts? snacks.picker.Config
  find_files = function(opts)
    Snacks.picker.fff(opts)
  end,
  ---@param opts? FFFSnacksGrepConfig
  live_grep = function(opts)
    Snacks.picker.fff_live_grep(opts)
  end,
  ---@param opts? FFFSnacksGrepConfig
  grep_word = function(opts)
    opts = opts or {}
    opts.search = function(picker)
      return picker:word()
    end
    Snacks.picker.fff_live_grep(opts)
  end,
}
