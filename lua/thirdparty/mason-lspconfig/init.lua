-- Modified from mason-lspconfig.init and mason-lspconfig.mappings
-- by Peter Sheehan, 2026.

local M = {}

function M.get_mappings()
	local _ = require("mason-core.functional")
	local registry = require("mason-registry")

	local package_to_lspconfig = {}

	for _, pkg_spec in ipairs(registry.get_all_package_specs()) do
		local lspconfig = vim.tbl_get(pkg_spec, "neovim", "lspconfig")
		if lspconfig then
			package_to_lspconfig[pkg_spec.name] = lspconfig
		end
	end

	return {
		package_to_lspconfig = package_to_lspconfig,
		lspconfig_to_package = _.invert(package_to_lspconfig),
	}
end

-- Ensure aliases can only be registered once.
local has_run = false

function M.register_lspconfig_aliases()
	if has_run then
		return
	end
	has_run = true

	local _ = require("mason-core.functional")
	local registry = require("mason-registry")

	local mapping = M.get_mappings()

	---@diagnostic disable-next-line: unused-local
	registry.refresh(vim.schedule_wrap(function(success, updated_registries)
		registry.register_package_aliases(_.map(function(server_name)
			return { server_name }
		end, mapping.package_to_lspconfig))
	end))
end

return M
