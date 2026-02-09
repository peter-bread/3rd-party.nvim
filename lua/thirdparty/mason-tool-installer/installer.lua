local State = require("thirdparty.mason-tool-installer.state")
local Log = require("thirdparty.mason-tool-installer.log")
local Config = require("thirdparty.mason-tool-installer.config").get()

local mr = require("mason-registry")

---@alias thirdparty.mti.PackageInstallOptsExtensions
---| { condition: fun():boolean }

---@alias thirdparty.mti.PkgOpts
---| PackageInstallOpts Mason package install options.
---| thirdparty.mti.PackageInstallOptsExtensions

---@alias thirdparty.mti.PkgEntryComplex
---| { [1]: string }
---| thirdparty.mti.PkgOpts

---@alias thirdparty.mti.PkgEntrySimple string

---@alias thirdparty.mti.PkgEntry
---| thirdparty.mti.PkgEntrySimple No options.
---| thirdparty.mti.PkgEntryComplex With Options.

---@class thirdparty.mti.check-install.Opts
---@field sync? boolean Whether installation should be done synchronously.
---@field update? boolean Whether plugins wihout unpinned versions should be updated to latest version.

---@type table
local mappings_cache

local M = {}

local H = {}

local is_headless = #vim.api.nvim_list_uis() == 0

local VALID_INSTALL_OPTS = {
  debug = true,
  force = true,
  location = true,
  strict = true,
  target = true,
  version = true,
}

---@param item thirdparty.mti.PkgEntry
---@return PackageInstallOpts
local function extract_install_opts(item)
  local opts = {}
  if type(item) ~= "table" then
    return opts
  end

  for k, v in pairs(item) do
    if VALID_INSTALL_OPTS[k] then
      opts[k] = v
    end
  end

  return opts
end

---@param item thirdparty.mti.PkgEntry
---@return string name The name of the package.
---@return (fun():boolean)? condition Condition function.
---@return PackageInstallOpts install_opts Mason package install options.
local function normalise_spec(item)
  if type(item) == "table" then
    return H.map_name(item[1]), item.condition, extract_install_opts(item)
  end

  return H.map_name(item), nil, {}
end

---@param pkg Package
---@param version? string
---@param update boolean
---@return boolean should_install
local function needs_install(pkg, version, update)
  if not pkg:is_installed() then
    return true
  end

  local installed_version = pkg:get_installed_version()

  if version then
    return installed_version ~= version
  end

  if update then
    return installed_version ~= pkg:get_latest_version()
  end

  return false
end

---Install/update requested packages if necessary.
---@param opts thirdparty.mti.check-install.Opts
function M.check_install(opts)
  opts = vim.tbl_deep_extend(
    "force",
    {},
    { sync = false, update = false },
    opts or {}
  )

  local total = #Config.ensure_installed
  if total == 0 then
    return
  end

  local state = State.new(total)
  state.on_complete = function(self)
    local summary = self:summary()

    if summary.failed > 0 then
      for _, f in ipairs(self:failures()) do
        Log.error(string.format("%s: %s", f.name, f.reason))
      end
    end

    -- TODO: Summary should be shown regardless of state if invoked via user
    -- command.
    --
    -- Only show summary if not headless or at least one package was not skipped,
    -- i.e. there is at least one success or one fail.
    if not (is_headless or summary.skipped < summary.completed) then
      return
    end

    Log.info(
      string.format(
        "Done (%d/%d): %d success, %d skipped, %d failed",
        summary.completed,
        summary.total,
        summary.success,
        summary.skipped,
        summary.failed
      )
    )
  end

  ---Attempt to install a single package.
  ---@param item thirdparty.mti.PkgEntry
  local function run_single(item)
    local name, condition, install_opts = normalise_spec(item)

    if condition and not condition() then
      state:report(name, "SKIPPED", "condtion function returned false")
      return
    end

    local found, pkg = pcall(mr.get_package, name)
    if not found then
      -- TODO: Maybe pass arg to on_done to report state.
      -- Log.error(string.format("Could not find package: %s", name))
      state:report(name, "FAILED", "package not in registry")
      return
    end

    if needs_install(pkg, install_opts.version, opts.update) then
      H.install_package(pkg, install_opts, function(status, reason)
        state:report(name, status, reason)
      end)
    else
      state:report(name, "SKIPPED", "already installed")
    end
  end

  local function run()
    for _, item in ipairs(Config.ensure_installed) do
      run_single(item)
    end
  end

  if mr.refresh then
    mr.refresh(run)
  else
    run()
  end

  if opts.sync then
    vim.wait(60 * 1000, function()
      return state.all_done
    end)
  end
end

function M.clean()
  local expected = {}

  for _, item in ipairs(Config.ensure_installed or {}) do
    local name = type(item) == "table" and item[1] or item
    name = H.map_name(name)
    expected[name] = true
  end

  for _, name in ipairs(mr.get_all_package_names()) do
    if mr.is_installed(name) and not expected[name] then
      Log.info(string.format("%s: uninstalling", name))
      mr.get_package(name):uninstall()
    end
  end
end

---Return the mason names of all packages in `ensure_installed`.
---@return string[]
function M.get_ensure_installed_names()
  -- TODO: Make sure requested packages actually exist in the mason registry.
  local ret = vim
    .iter(Config.ensure_installed or {})
    :map(function(p)
      local name = type(p) == "string" and p or p[1]
      return H.map_name(name)
    end)
    :totable()

  table.sort(ret)

  return ret
end

function H.map_name(name)
  if not mappings_cache then
    mappings_cache = require("thirdparty.mason-lspconfig").get_mappings()
  end
  return mappings_cache.lspconfig_to_package[name] or name
end

---Install a mason package.
---@param pkg Package
---@param opts PackageInstallOpts
---@param report fun(status: thirdparty.mti.PkgStatus, reason?:string)
function H.install_package(pkg, opts, report)
  local version = opts.version
  if version then
    Log.info(string.format("%s: installing %s", pkg.name, version))
  else
    Log.info(string.format("%s: installing", pkg.name))
  end

  pkg:once("install:success", function()
    Log.info(string.format("%s: installed", pkg.name))
    report("SUCCESS")
  end)

  pkg:once("install:failed", function()
    Log.error(string.format("%s: failed to install", pkg.name))
    report("FAILED")
  end)

  if not pkg:is_installable() then
    report("FAILED", "not installable")
    return
  end

  if pkg:is_installing() then
    report("FAILED", "already installing")
    return
  end

  pkg:install(opts)
end

return M
