local fff_snacks = require("fff-snacks")

local init = vim.schedule_wrap(function()
  if Snacks and pcall(require, "snacks.picker") then
    Snacks.picker.sources.fff = fff_snacks.sources.find_files
    Snacks.picker.sources.fff_live_grep = fff_snacks.sources.live_grep
  end
end)

if vim.v.vim_did_enter == 1 then
  init()
else
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("fff-snacks.init", {}),
    once = true,
    nested = true,
    callback = init,
  })
end

vim.api.nvim_create_user_command("FFFSnacks", function(args)
  if not (Snacks and pcall(require, "snacks.picker")) then
    vim.notify("fff-snacks: Snacks is not loaded", vim.log.levels.ERROR)
    return
  end

  local sub = args.fargs[1] or "find_files"
  if sub == "find_files" then
    fff_snacks.find_files()
  elseif sub == "live_grep" then
    fff_snacks.live_grep({ grep_mode = { "plain", "regex", "fuzzy" } })
  elseif sub == "fuzzy" then
    fff_snacks.live_grep({ grep_mode = { "fuzzy", "regex", "plain" } })
  elseif sub == "grep_word" then
    fff_snacks.grep_word()
  else
    vim.notify("fff-snacks: Invalid argument. Use 'find_files', 'live_grep', 'fuzzy', or 'grep_word'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function()
    return {
      "find_files",
      "live_grep",
      "fuzzy",
      "grep_word",
    }
  end,
  desc = "Open FFF in snacks picker",
})
