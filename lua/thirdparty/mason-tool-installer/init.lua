-- Modified from https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
-- by Peter Sheehan, 2026.

-- TODO: Allow vim.g.thirdparty_mti_config instead of setup().
-- TODO: Ensure consistent logging messages.

---@module "mason"

---@class thirdparty.mti
local M = {}

---Setup.
---@param opts thirdparty.mti.Config
M.setup = function(opts)
  require("thirdparty.mason-tool-installer.config").setup(opts)
end

---@param opts thirdparty.mti.check-install.Opts
M.check_install = function(opts)
  require("thirdparty.mason-tool-installer.installer").check_install(opts)
end

M.clean = function()
  require("thirdparty.mason-tool-installer.installer").clean()
end

M.get_ensure_installed_names = function()
  require("thirdparty.mason-tool-installer.installer").get_ensure_installed_names()
end

return M
