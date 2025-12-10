---@class thirdparty.diffview
local M = {}

---@module "diffview"

--[[ ---------------------------------------------------------------------- ]]
--
--[[ ------------------- START OF PUBLIC API FUNCTIONS. ------------------- ]]
--
--[[ ---------------------------------------------------------------------- ]]

---Cycle between diff3_mixed and diff4_mixed.
function M.cycle_merge_conflict_layouts()
	local api = vim.api
	local lib = require("diffview.lib")
	local lazy = require("diffview.lazy")
	local utils = lazy.require("diffview.utils")

	local Diff3Mixed = lazy.access("diffview.scene.layouts.diff_3_mixed", "Diff3Mixed")
	local Diff4Mixed = lazy.access("diffview.scene.layouts.diff_4_mixed", "Diff4Mixed")

  -- stylua: ignore
  local DiffView        = lazy.access("diffview.scene.views.diff.diff_view", "DiffView")

	local layout_cycle = {
		Diff3Mixed.__get(),
		Diff4Mixed.__get(),
	}

	local view = lib.get_current_view()
	if not view then
		return
	end

	if not view:instanceof(DiffView.__get()) then
		return
	end

	local cur_file = view.cur_entry
	if not cur_file then
		return
	end

	if cur_file.kind ~= "conflicting" then
		return
	end

	local files = view.files.conflicting

	-- Cycle layout for all file entries.
	for _, entry in ipairs(files) do
		local cur_layout = entry.layout.class
		local idx = utils.vec_indexof(layout_cycle, cur_layout)
		local next_layout = layout_cycle[(idx % #layout_cycle) + 1]
		entry:convert_layout(next_layout)
	end

	-- Reopen current file to apply layout.
	if cur_file then
		local main = view.cur_layout:get_main_win()
		local pos = api.nvim_win_get_cursor(main.id)
		local was_focused = view.cur_layout:is_focused()

		cur_file.layout.emitter:once("files_opened", function()
			utils.set_cursor(main.id, unpack(pos))
			if not was_focused then
				view.cur_layout:sync_scroll()
			end
		end)

		view:set_file(cur_file, false)
		main = view.cur_layout:get_main_win()

		if was_focused then
			main:focus()
		end
	end
end

return M
