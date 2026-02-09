---@class thirdparty.mti.Config
local Config = {
  ---@type thirdparty.mti.PkgEntry[]
  ensure_installed = {},
}

local M = {}

function M.get()
  return Config
end

---Setup.
---@param opts thirdparty.mti.Config
function M.setup(opts)
  Config = vim.tbl_deep_extend("force", Config, opts or {})

  vim.validate({
    ensure_installed = { Config.ensure_installed, "table", true },
  })
end

return M
