vim.api.nvim_create_user_command("MasonToolsClean", function()
  require("thirdparty.mason-tool-installer").clean()
end, { force = true })

vim.api.nvim_create_user_command("MasonToolsEnsureInstalled", function()
  require("thirdparty.mason-tool-installer").check_install()
end, { force = true })

vim.api.nvim_create_user_command("MasonToolsEnsureUpdated", function()
  require("thirdparty.mason-tool-installer").check_install({ update = true })
end, { force = true })
