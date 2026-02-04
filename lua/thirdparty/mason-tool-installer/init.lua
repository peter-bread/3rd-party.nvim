-- Modified from https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
-- by Peter Sheehan, 2026.

-- TODO: Allow vim.g.thirdparty_mti_config instead of setup().
-- TODO: Create a state class to use with on_done().
-- TODO: Ensure consistent logging messages.

---@module "mason"

---@class thirdparty.mti
local M = {}

local H = {}

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

---@alias thirdparty.mti.Logger fun(msg:string, level?:vim.log.levels)

--[[ ---------------------------------------------------------------------- ]]
--
--[[ ------------------- START OF PUBLIC API FUNCTIONS. ------------------- ]]
--
--[[ ---------------------------------------------------------------------- ]]

local mr = require("mason-registry")

---@type table
local mappings_cache

---@class thirdparty.mti.Config
local Config = {
  ---@type thirdparty.mti.PkgEntry[]
  ensure_installed = {},
}

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

  local completed = 0
  local all_done = false

  local function on_done()
    completed = completed + 1
    if completed >= total then
      all_done = true
    end
  end

  ---Attempt to install a single package.
  ---@param item thirdparty.mti.PkgEntry
  local function run_single(item)
    local name, condition, install_opts = normalise_spec(item)

    if condition and not condition() then
      -- TODO: Maybe pass arg to on_done to report state.
      on_done()
      return
    end

    local found, pkg = pcall(mr.get_package, name)
    if not found then
      -- TODO: Maybe pass arg to on_done to report state.
      H.log_error(string.format("Could not find package: %s", name))
      on_done()
      return
    end

    if needs_install(pkg, install_opts.version, opts.update) then
      H.install_package(pkg, install_opts, on_done)
    else
      on_done()
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
      return all_done
    end)
  end
end

---Setup.
---@param opts thirdparty.mti.Config
function M.setup(opts)
  Config = vim.tbl_deep_extend("force", Config, opts or {})

  vim.validate({
    ensure_installed = { Config.ensure_installed, "table", true },
  })
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
      H.log_info(string.format("%s: uninstalling", name))
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

--[[ ---------------------------------------------------------------------- ]]
--
--[[ ---------- END OF API FUNCTIONS. START OF HELPER FUNCTIONS. ---------- ]]
--
--[[ ---------------------------------------------------------------------- ]]

---@type thirdparty.mti.Logger
H.log = function(msg, level)
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
H.log_info = vim.schedule_wrap(function(msg)
  H.log(msg)
end)

---@type thirdparty.mti.Logger
H.log_error = vim.schedule_wrap(function(msg)
  H.log(msg, vim.log.levels.ERROR)
end)

function H.map_name(name)
  if not mappings_cache then
    mappings_cache = require("thirdparty.mason-lspconfig").get_mappings()
  end
  return mappings_cache.lspconfig_to_package[name] or name
end

---Install a mason package.
---@param pkg Package
---@param opts any
---@param on_done function
function H.install_package(pkg, opts, on_done)
  local version = opts.version
  if version then
    H.log_info(string.format("%s: installing %s", pkg.name, version))
  else
    H.log_info(string.format("%s: installing", pkg.name))
  end

  pkg:once("install:success", function()
    H.log_info(string.format("%s: installed", pkg.name))
    on_done()
  end)

  pkg:once("install:failed", function()
    H.log_error(string.format("%s: failed to install", pkg.name))
    on_done()
  end)

  if not pkg:is_installable() then
    -- TODO: Log.
    return
  end

  if pkg:is_installing() then
    -- TODO: Log.
    return
  end

  pkg:install(opts)
end

return M
