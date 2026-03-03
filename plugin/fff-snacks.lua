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
  local sub = args.fargs[1]
  if sub == "find_files" or sub == nil then
    fff_snacks.find_files()
  elseif sub == "live_grep" then
    fff_snacks.live_grep({ grep_mode = { "plain", "regex", "fuzzy" } })
  elseif sub == "fuzzy" then
    fff_snacks.live_grep({ grep_mode = { "fuzzy", "regex", "plain" } })
  else
    vim.notify("fff-snacks: Invalid argument. Use 'find_files', 'live_grep', or 'fuzzy'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function()
    return {
      "find_files",
      "live_grep",
      "fuzzy",
    }
  end,
  desc = "Open FFF in snacks picker",
})
