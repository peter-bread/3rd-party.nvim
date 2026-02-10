---@alias thirdparty.mti.PkgStatus
---| "SUCCESS"
---| "SKIPPED"
---| "FAILED"

---@class thirdparty.mti.PkgState
---@field name string
---@field status thirdparty.mti.PkgStatus
---@field reason? string

---@class thirdparty.mti.State
---@field all_done boolean
---@field total integer
---@field completed integer
---@field pkg_states thirdparty.mti.PkgState[]
---@field _by_name table<string, thirdparty.mti.PkgState>
---@field on_complete fun(state: thirdparty.mti.State)?
local State = {}

---@param total integer
---@return thirdparty.mti.State
function State.new(total)
  return setmetatable({
    all_done = false,
    total = total,
    completed = 0,
    pkg_states = {},
    _by_name = {},
    on_complete = nil,
  }, { __index = State })
end

---@param name string
---@param status thirdparty.mti.PkgStatus
---@param reason? string
function State:report(name, status, reason)
  local pkg_state = self._by_name[name]

  if not pkg_state then
    pkg_state = {
      name = name,
      status = status,
      reason = reason,
    }
    self._by_name[name] = pkg_state
    table.insert(self.pkg_states, pkg_state)
  else
    pkg_state.status = status
    pkg_state.reason = reason
  end

  self.completed = self.completed + 1
  if self.completed >= self.total then
    self.all_done = true
    if self.on_complete then
      self:on_complete()
    end
  end
end

---@class thirdparty.mti.StateSummary
---@field total integer
---@field completed integer
---@field success integer
---@field skipped integer
---@field failed integer
---@field all_done boolean

---@return thirdparty.mti.StateSummary
function State:summary()
  local summary = {
    total = self.total,
    completed = self.completed,
    success = 0,
    skipped = 0,
    failed = 0,
    all_done = self.all_done,
  }

  for _, pkg in ipairs(self.pkg_states) do
    if pkg.status == "SUCCESS" then
      summary.success = summary.success + 1
    elseif pkg.status == "SKIPPED" then
      summary.skipped = summary.skipped + 1
    elseif pkg.status == "FAILED" then
      summary.failed = summary.failed + 1
    end
  end

  return summary
end

---@return { name: string, reason: string }[]
function State:failures()
  local ret = {}

  for _, pkg in ipairs(self.pkg_states) do
    if pkg.status == "FAILED" then
      table.insert(ret, {
        name = pkg.name,
        reason = pkg.reason or "unknown",
      })
    end
  end

  return ret
end

return State
