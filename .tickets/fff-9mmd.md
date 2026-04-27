---
id: fff-9mmd
status: open
deps: []
links: []
created: 2026-04-25T01:41:36Z
type: bug
priority: 2
assignee: Seth Messer
---
# Fix item.path removal breaking find_files picker (fff.nvim PR #387)

Upstream fff.nvim PR #387 (commit cebacb3, 'feat!: Revamp & optimize the way strings are stored in RAM') removed the 'path' field from Lua items returned by file_picker.search_files() and live_grep. Paths now live in a picker-owned arena; only 'relative_path' and 'name' remain.

Snacks picker fails with 'error: Item has no `file`' on <leader>ff because lua/fff-snacks/find_files.lua:141 sets file = fff_item.path (now nil).

live_grep.lua:100 has a latent bug in the same class: file = fff_item.relative_path only resolves correctly when cwd == picker base_path.

Upstream reference resolver: ~/.local/share/nvim/lazy/fff.nvim/lua/fff/picker_ui.lua:15-32 (canonicalize_fff_path). Upstream also added a new rust export rust.get_base_path() but conf.get().base_path is the simpler source.

Fix: add a local canonicalize helper and use it in both find_files.lua and live_grep.lua wherever an absolute 'file' path is needed.

    local conf = require('fff.conf')
    local function abs(rel)
      if not rel or rel == '' then return nil end
      if vim.fn.fnamemodify(rel, ':p') == rel then return rel end
      local base = conf.get().base_path
      return (base and base ~= '') and vim.fs.normalize(base .. '/' .. rel) or rel
    end

Files:
- lua/fff-snacks/find_files.lua (line ~141, 'file = fff_item.path')
- lua/fff-snacks/live_grep.lua  (line ~100, 'file = fff_item.relative_path')

Min fff.nvim version required: cebacb3 or newer (0.6.2+).

## Acceptance Criteria

1. <leader>ff opens snacks picker and lists files (no 'Item has no `file`' error)
2. Selecting a file from find_files opens the correct absolute path regardless of cwd vs picker base_path
3. live_grep picker opens results at the correct file/line when cwd != base_path
4. Works against fff.nvim at current HEAD (post PR #387)
5. No regressions with earlier fff.nvim versions that still expose fff_item.path (graceful fallback OK, or README note if dropping support)
6. README updated to note the new min fff.nvim version if pre-#387 support is dropped


## Notes

**2026-04-25T01:42:10Z**

Cross-ref: dotfiles ticket dot-7ezy watches progress of this work (~/.dotfiles/.tickets/dot-7ezy.md). Close dot-7ezy after this one closes and :Lazy sync lands the fix.

**2026-04-27T12:28:19Z**

Fixed by adding utils.canonicalize (mirrors fff.nvim's picker_ui.canonicalize_fff_path). find_files.lua and live_grep.lua now resolve relative_path -> absolute via conf.get().base_path. Graceful fallback to fff_item.path retains compat with pre-#387 fff.nvim, so README min-version bump skipped (criterion 6 condition not triggered).

**2026-04-27T regression: doubled path on grep open/preview**

Reopened. Live_grep results break with `error: file not found: /<base>//<base>/<rel>` (literal `//` in middle). Reproduced when nvim cwd == base_path too, so it's not cwd-specific.

Root cause: snacks.nvim `lua/snacks/picker/util/init.lua:15` `M.path()` joins unconditionally:
```lua
item.cwd and item.cwd .. "/" .. item.file or item.file
```
It never checks if `item.file` is already absolute. When the previous fix set `file = abs_path` in live_grep.lua but kept `cwd = base_path`, every subsequent `M.path(item)` produced `base_path .. "/" .. abs_path`. find_files.lua was unaffected because it never set item.cwd.

Fix: drop `cwd = base_path` from the live_grep item. `file = abs_path` is sufficient — `M.path()` returns it as-is.

Audit of `item.cwd` consumers in snacks (verified safe to drop for grep finder):
- `util.path()` / `util.dir()` — was the bug; dropping resolves both (dir was also producing doubled path)
- `preview.lua:210` cmd-proc previewer cwd — N/A (file previewer in use)
- `actions.lua` git_stage/restore/stash/checkout — N/A for grep results
- `matcher.lua:378` filter prefix grouping — falls back to `path()`, still correct
- `format.lua` truncpath display — keyed off `picker:cwd()`, not `item.cwd`

Follow-up (deferred, not part of this ticket's fix):
1. Consider promoting `cwd = base_path` to source/picker-level (`opts.cwd`) so `picker:cwd()` returns fff base. Cleans up truncpath display when nvim cwd != fff base_path. Currently picker:cwd() = vim.fn.getcwd(0) by default.
2. live_grep.lua reads `local base_path = opts.cwd or vim.uv.cwd()` for scoped_set comparison, but fff's grep `relative_path` is anchored to `conf.get().base_path`. If those differ, scoped filtering can mismatch. Should use conf.get().base_path consistently.
3. Upstream snacks bug: `M.path()` joiner should detect absolute `file` and skip cwd prefix. Worth a PR to folke/snacks.nvim.

Acceptance criteria 2 & 3 still apply. Criterion 4 (works against fff.nvim HEAD post-#387) and criterion 5 (graceful fallback for pre-#387) unchanged.
