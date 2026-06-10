-- maps to require("fff").find_files()

local M = {}

local utils = require "fff-snacks.utils"

local conf = require "fff.conf"
local file_picker = require "fff.file_picker"

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
  -- clean = "",
  -- clear = "",
  unknown = "untracked",
}

---@type table<string, string[]>
local ignored_cache = {}

---@param text string
---@param query string
---@return boolean
local function fuzzy_match(text, query)
  if query == "" then
    return true
  end

  text = text:lower()
  query = query:lower()

  local pos = 1
  for i = 1, #query do
    local char = query:sub(i, i)
    local found = text:find(char, pos, true)
    if not found then
      return false
    end
    pos = found + 1
  end

  return true
end

---@param base_path string
---@return string[]
local function git_ignored_files(base_path)
  if ignored_cache[base_path] then
    return ignored_cache[base_path]
  end

  local output = vim.fn.system {
    "git",
    "-C",
    base_path,
    "ls-files",
    "--others",
    "--ignored",
    "--exclude-standard",
    "-z",
  }

  if vim.v.shell_error ~= 0 or output == "" then
    ignored_cache[base_path] = {}
    return ignored_cache[base_path]
  end

  ignored_cache[base_path] = vim.split(output, "\0", { plain = true, trimempty = true })
  return ignored_cache[base_path]
end

--- tweaked version of `Snacks.picker.format.file_git_status`
--- @type snacks.picker.format
local function format_file_git_status(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local status = item.status

  local hl = "SnacksPickerGitStatus"
  if status.unmerged then
    hl = "SnacksPickerGitStatusUnmerged"
  elseif status.staged then
    hl = "SnacksPickerGitStatusStaged"
  else
    hl = "SnacksPickerGitStatus" .. status.status:sub(1, 1):upper() .. status.status:sub(2)
  end

  local icon = picker.opts.icons.git[status.status]
  if status.staged then
    icon = picker.opts.icons.git.staged
  end

  local text_icon = status.status:sub(1, 1):upper()
  text_icon = status.status == "untracked" and "?" or status.status == "ignored" and "!" or text_icon

  ret[#ret + 1] = { icon, hl }
  ret[#ret + 1] = { " ", virtual = true }

  ret[#ret + 1] = {
    col = 0,
    virt_text = { { text_icon, hl }, { " " } },
    virt_text_pos = "right_align",
    hl_mode = "combine",
  }
  return ret
end

---@type snacks.picker.Config
M.source = {
  title = "Files",

  toggles = {
    hidden = { icon = "󰘓", value = false },
    ignored = { icon = "󰈉", value = false },
    _from_grep = { icon = "󰱼→", value = false }, -- scoped from grep results
  },

  finder = function(opts, ctx)
    if opts.cwd ~= nil then
      vim.notify("The 'cwd' option is not supported in FFF", vim.log.levels.WARN)
    end

    local fff_config = conf.get()
    local base_path = fff_config.base_path or vim.fn.getcwd()
    local current_file = utils.get_current_file(base_path)

    local fff_result = file_picker.search_files(
      ctx.filter.search,
      current_file,
      opts.limit or fff_config.max_results,
      fff_config.max_threads,
      nil
    )

    ---@type snacks.picker.finder.Item[]
    local items = {}

    -- If scoped from grep, filter to only those files
    local scoped_files = opts._scoped_files
    local scoped_set = nil
    if scoped_files then
      scoped_set = {}
      local cwd = (base_path:gsub("/$", "")) .. "/"
      for _, f in ipairs(scoped_files) do
        -- Normalize: store both relative and absolute versions for matching
        local rel = f
        if f:sub(1, #cwd) == cwd then
          rel = f:sub(#cwd + 1)
        end
        scoped_set[rel] = true
        scoped_set[f] = true -- Also store original in case paths are already relative
      end
    end

    local show_hidden = opts.hidden == true
    local show_ignored = opts.ignored == true
    local seen_files = {}

    for idx, fff_item in ipairs(fff_result) do
      -- Resolve to absolute path. fff.nvim PR #387 removed `fff_item.path`;
      -- fall back to it for older versions, otherwise canonicalize relative_path.
      local abs_path = fff_item.path or utils.canonicalize(fff_item.relative_path)

      -- Filter hidden/ignored based on toggle state
      if not show_hidden and fff_item.name:sub(1, 1) == "." then
        goto continue
      end
      if not show_ignored and fff_item.git_status == "ignored" then
        goto continue
      end

      -- Skip files not in scoped set (if scoped)
      if scoped_set then
        local rel_path = fff_item.relative_path or abs_path
        if abs_path then
          local cwd = (base_path:gsub("/$", "")) .. "/"
          if abs_path:sub(1, #cwd) == cwd then
            rel_path = abs_path:sub(#cwd + 1)
          end
        end
        if not scoped_set[abs_path] and not scoped_set[rel_path] then
          goto continue
        end
      end

      ---@type snacks.picker.finder.Item
      local item = {
        idx = idx,
        file = abs_path,

        score = fff_item.total_frecency_score,
        text = fff_item.name,
        -- HACK: in original snacks implementation status is a string of
        -- `git status --porcelain` output
        status = status_map[fff_item.git_status] and {
          status = status_map[fff_item.git_status],
          staged = staged_status[fff_item.git_status] or false,
          unmerged = fff_item.git_status == "unmerged",
        },
      }
      items[#items + 1] = item
      if abs_path then
        seen_files[abs_path] = true
      end

      ::continue::
    end

    if show_ignored then
      for _, rel_path in ipairs(git_ignored_files(base_path)) do
        if not fuzzy_match(rel_path, ctx.filter.search or "") then
          goto ignored_continue
        end

        local abs_path = vim.fs.normalize((base_path:gsub("/$", "")) .. "/" .. rel_path)
        if seen_files[abs_path] then
          goto ignored_continue
        end

        if scoped_set and not scoped_set[abs_path] and not scoped_set[rel_path] then
          goto ignored_continue
        end

        items[#items + 1] = {
          idx = #items + 1,
          file = abs_path,
          score = 0,
          text = vim.fn.fnamemodify(rel_path, ":t"),
          status = {
            status = "ignored",
            staged = false,
            unmerged = false,
          },
        }
        seen_files[abs_path] = true

        ::ignored_continue::
      end
    end

    return items
  end,
  format = function(item, picker)
    ---@type snacks.picker.Highlight[]
    local ret = {}

    if item.label then
      ret[#ret + 1] = { item.label, "SnacksPickerLabel" }
      ret[#ret + 1] = { " ", virtual = true }
    end

    if item.status then
      vim.list_extend(ret, format_file_git_status(item, picker))
    else
      ret[#ret + 1] = { "  ", virtual = true }
    end

    vim.list_extend(ret, require("snacks").picker.format.filename(item, picker))

    if item.line then
      require("snacks").picker.highlight.format(item, item.line, ret)
      table.insert(ret, { " " })
    end
    return ret
  end,

  on_show = function(_)
    -- fff.picker_ui: initialize_picker
    if not file_picker.is_initialized() then
      if not file_picker.setup() then
        vim.notify("Failed to initialize file picker", vim.log.levels.ERROR)
      end
    end
  end,

  formatters = {
    file = {
      filename_first = true,
    },
  },
  live = true,
}

return M
