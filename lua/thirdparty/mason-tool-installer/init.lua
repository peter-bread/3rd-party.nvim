-- Modified from https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
-- by Peter Sheehan, 2026.

local mr = require("mason-registry")

---@alias thirdparty.MasonToolInstaller.PackageSpec string | { [1]: string, version: string, condition: fun():boolean }
---@alias thirdparty.MasonToolInstaller.Logger fun(msg:string, level?:vim.log.levels)

---@type table
local mappings_cache

---@class thirdparty.MasonToolInstaller.Config
local Config = {
	---@type thirdparty.MasonToolInstaller.PackageSpec[]
	ensure_installed = {},
}

---@type thirdparty.MasonToolInstaller.Logger
local _log = function(msg, level)
	if not vim.g.is_headless then
		vim.notify(msg, level or vim.log.levels.INFO, { title = "Mason Tool Installer" })
	else
		vim.api.nvim_echo({ { msg }, { "\n" } }, false, {})
	end
end

---@type thirdparty.MasonToolInstaller.Logger
local log_info = vim.schedule_wrap(function(msg)
	_log(msg)
end)

---@type thirdparty.MasonToolInstaller.Logger
local log_error = vim.schedule_wrap(function(msg)
	_log(msg, vim.log.levels.ERROR)
end)

local function map_name(name)
	if not mappings_cache then
		mappings_cache = require("thirdparty.mason-lspconfig").get_mappings()
	end
	return mappings_cache.lspconfig_to_package[name] or name
end

local function install_package(pkg, version, on_done)
	if version then
		log_info(string.format("%s: installing %s", pkg.name, version))
	else
		log_info(string.format("%s: installing", pkg.name))
	end

	pkg:once("install:success", function()
		log_info(string.format("%s: installed", pkg.name))
		on_done()
	end)

	pkg:once("install:failed", function()
		log_error(string.format("%s: failed to install", pkg.name))
		on_done()
	end)

	pkg:install({ version = version })
end

local function check_install(sync, upgrade)
	sync = sync or false
	upgrade = upgrade or false

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
			-- vim.api.nvim_exec_autocmds("User", {
			--   pattern = "MasonForgeUpdateCompleted",
			--   data = vim.tbl_map(function(item)
			--     return type(item) == "table" and item[1] or item
			--   end, Config.ensure_installed),
			-- })
		end
	end

	local function run()
		for _, item in ipairs(Config.ensure_installed) do
			local name
			local version
			local condition

			if type(item) == "table" then
				name = item[1]
				version = item.version
				condition = item.condition
			else
				name = item
			end

			if condition and not condition() then
				on_done()
			else
				name = map_name(name)
				local pkg = mr.get_package(name)

				local installed = pkg:is_installed()
				local installed_version = pkg:get_installed_version()
				local latest_version = pkg:get_latest_version()

				if not installed then
					install_package(pkg, version, on_done)
				elseif version and installed_version ~= version then
					install_package(pkg, version, on_done)
				elseif upgrade and installed_version ~= latest_version and not version then
					install_package(pkg, latest_version, on_done) -- could pass in version = nil?
				else
					on_done()
				end
			end
		end
	end

	if mr.refresh then
		mr.refresh(run)
	else
		run()
	end

	if sync then
		vim.wait(60 * 1000, function()
			return all_done
		end)
	end
end

---Setup.
---@param opts thirdparty.MasonToolInstaller.Config
local function setup(opts)
	Config = vim.tbl_deep_extend("force", Config, opts or {})

	vim.validate({
		ensure_installed = { Config.ensure_installed, "table", true },
	})
end

local function clean()
	local expected = {}

	for _, item in ipairs(Config.ensure_installed or {}) do
		local name = type(item) == "table" and item[1] or item
		name = map_name(name)
		expected[name] = true
	end

	for _, name in ipairs(mr.get_all_package_names()) do
		if mr.is_installed(name) and not expected[name] then
			log_info(string.format("%s: uninstalling", name))
			mr.get_package(name):uninstall()
		end
	end
end

---Return the mason names of all packages in `ensure_installed`.
---@return string[]
local function get_ensure_installed_names()
	local ret = vim.iter(Config.ensure_installed or {})
		:map(function(p)
			local name = type(p) == "string" and p or p[1]
			return map_name(name)
		end)
		:totable()

	table.sort(ret)

	return ret
end

-- stylua: ignore
return {
  setup                      = setup,
  check_install              = check_install,
  clean                      = clean,
  get_ensure_installed_names = get_ensure_installed_names,
}
