local M = {}

local conf = require "fff.conf"

--- Resolve an fff item's relative_path to an absolute path.
--- Mirrors canonicalize_fff_path in fff.nvim's picker_ui.lua. Required since
--- fff.nvim PR #387 (commit cebacb3) removed the `path` field from items;
--- only `relative_path` and `name` remain, anchored to the picker's base_path
--- which may differ from the current cwd.
--- @param relative_path string|nil
--- @return string|nil
function M.canonicalize(relative_path)
  if not relative_path or relative_path == "" then
    return nil
  end
  local path = relative_path
  -- Strip Windows long-path prefix (\\?\) — Neovim cannot open these.
  if vim.startswith(path, "\\\\?\\") then
    path = path:sub(5)
  end
  -- Already absolute: don't re-anchor.
  if vim.fn.fnamemodify(path, ":p") == path then
    return path
  end
  local base = conf.get().base_path
  if not base or base == "" then
    return path
  end
  return vim.fs.normalize(base .. "/" .. path)
end

--- pulled from get_current_file_cache in lua/fff/picker_ui.lua
--- Helper function to determine current file cache for deprioritization
--- @param base_path string Base path for relative path calculation
--- @return string|nil Current file cache path
function M.get_current_file(base_path)
  local current_buf = vim.api.nvim_get_current_buf()
  if not current_buf or not vim.api.nvim_buf_is_valid(current_buf) then
    return nil
  end

  local current_file = vim.api.nvim_buf_get_name(current_buf)
  if current_file == "" then
    return nil
  end

  -- Use vim.uv.fs_stat to check if file exists and is readable
  local stat = vim.uv.fs_stat(current_file)
  if not stat or stat.type ~= "file" then
    return nil
  end

  local absolute_path = vim.fn.fnamemodify(current_file, ":p")
  local resolved_abs = vim.fn.resolve(absolute_path)
  local resolved_base = vim.fn.resolve(base_path)

  -- icloud direcrtoes on macos contain a lot of special characters that break
  -- the fnamemodify which have to escaped with %
  local escaped_base = resolved_base:gsub("([%%^$()%.%[%]*+%-?])", "%%%1")
  local relative_path = resolved_abs:gsub("^" .. escaped_base .. "/", "")
  if relative_path == "" or relative_path == resolved_abs then
    return nil
  end
  return relative_path
end

return M
