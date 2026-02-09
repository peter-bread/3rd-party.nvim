---@alias thirdparty.mti.Logger fun(msg:string, level?:vim.log.levels)

local M = {}

---@type thirdparty.mti.Logger
local log = function(msg, level)
  local is_headless = vim.g.is_headless ~= nil and #vim.api.nvim_list_uis() == 0
    or vim.g.is_headless

  if not is_headless then
    vim.notify(
      msg,
      level or vim.log.levels.INFO,
      { title = "Mason Tool Installer" }
    )
  else
    vim.api.nvim_echo({ { msg }, { "\n" } }, false, {})
  end
end

---@type thirdparty.mti.Logger
M.info = vim.schedule_wrap(function(msg)
  log(msg)
end)

---@type thirdparty.mti.Logger
M.error = vim.schedule_wrap(function(msg)
  log(msg, vim.log.levels.ERROR)
end)

return M
