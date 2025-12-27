-- Modified from which-key.view.format by Peter Sheehan, 2025.

local M = {}

---Given a key in the form `<modifier(s)-key>`, return a list of modifiers and the final key to be pressed.
---
---For example:
---
--- ```lua
--- get_lhs_parts("<C-S-p>") -- { "C", "S", "p" }
--- ```
---
---Ported from Neovim C code to Lua and simplified.
---See [find_special_key](https://github.com/neovim/neovim/blob/7b5276b382ac1ea1a2771ecf3ff6c8ae944cc7f9/src/nvim/keycodes.c#L417)
---See [extract_modifiers](https://github.com/neovim/neovim/blob/7b5276b382ac1ea1a2771ecf3ff6c8ae944cc7f9/src/nvim/keycodes.c#L553)
---See [neovim/src/nvim/keycodes.c](https://github.com/neovim/neovim/blob/7b5276b382ac1ea1a2771ecf3ff6c8ae944cc7f9/src/nvim/keycodes.c)
---@param src any
---@return nil
local function get_lhs_parts(src)
	if src:sub(1, 1) ~= "<" or src:sub(-1) ~= ">" then
		return nil
	end

	local body = src:sub(2, -2)

	local last_dash
	for i = 1, #body do
		local c = body:sub(i, i)
		if c == "-" then
			last_dash = i
		elseif not c:match("[%w_]") then
			break
		end
	end

	local parts = {}
	local key

	if last_dash then
		for i = 1, last_dash - 1 do
			local c = body:sub(i, i)
			if c ~= "-" then
				parts[#parts + 1] = c:upper()
			end
		end
		key = body:sub(last_dash + 1)
		if key == "" then
			key = "-"
		end
	else
		key = body
	end

	parts[#parts + 1] = key

	return parts
end

---@param lhs string
function M.format(lhs)
	local Config = require("which-key.config")
	local Util = require("which-key.util")
	local keys = Util.keys(lhs)
	local ret = vim.tbl_map(function(key)
		local inner = key:match("^<(.*)>$")
		if not inner then
			return key
		end
		if inner == "NL" then
			inner = "C-J"
		end

		local parts = get_lhs_parts("<" .. inner .. ">")
		if not parts then
			return key
		end

		for i, part in ipairs(parts) do
			if i == 1 or i ~= #parts or not part:match("^%w$") then
				parts[i] = Config.icons.keys[part] or parts[i]
			end
		end
		return table.concat(parts, "")
	end, keys)
	return table.concat(ret, "")
end

return M
