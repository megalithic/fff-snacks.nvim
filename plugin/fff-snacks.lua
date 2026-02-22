local init = vim.schedule_wrap(function()
  if Snacks and pcall(require, "snacks.picker") then
    -- Users can call Snacks.picker.fff() after this
    Snacks.picker.sources.fff = require("fff-snacks").sources.find_files
    Snacks.picker.sources.fff_live_grep = require("fff-snacks").sources.live_grep
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
  if Snacks and pcall(require, "snacks.picker") then
    if args.fargs[1] == "find_files" or args.fargs[1] == nil then
      Snacks.picker.fff()
    elseif args.fargs[1] == "live_grep" then
      Snacks.picker.fff_live_grep { grep_mode = { "plain", "regex", "fuzzy" } }
    elseif args.fargs[1] == "fuzzy" then
      Snacks.picker.fff_live_grep { grep_mode = { "fuzzy", "regex", "plain" } }
    else
      vim.notify("fff-snacks: Invalid argument. Use 'find_files', 'live_grep', or 'fuzzy'", vim.log.levels.ERROR)
    end
  else
    vim.notify("fff-snacks: Snacks is not loaded", vim.log.levels.ERROR)
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
