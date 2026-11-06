-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- WSL: use the Windows clipboard. win32yank.exe (installed on Windows with
-- winget, on PATH via the WinGet Links dir) is fast and handles UTF-8 and line
-- endings. Without it, fall back to OSC 52 through the terminal (WezTerm) rather
-- than Neovim's auto-detection, which would pick xclip/wl-copy via WSLg.
if vim.fn.has("wsl") == 1 then
  if vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
      name = "win32yank-wsl",
      copy = {
        ["+"] = { "win32yank.exe", "-i", "--crlf" },
        ["*"] = { "win32yank.exe", "-i", "--crlf" },
      },
      paste = {
        ["+"] = { "win32yank.exe", "-o", "--lf" },
        ["*"] = { "win32yank.exe", "-o", "--lf" },
      },
      cache_enabled = 0,
    }
  else
    -- WezTerm doesn't answer OSC 52 paste queries (nvim would hang until the
    -- timeout), so "paste" from the unnamed register; paste from Windows with
    -- the terminal's own paste key instead.
    local osc52 = require("vim.ui.clipboard.osc52")
    local function paste()
      return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste, ["*"] = paste },
    }
  end
end
