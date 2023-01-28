---@class PI : module
local M = {}


--#region Global data
local mod_data

---@class opened_Players_info_UI_refs
---@type table<integer, LuaGuiElement>
local opened_Players_info_UI_refs
--#endregion


--#region Constants
local tostring = tostring
local floor = math.floor
local DRAG_HANDLER = {type = "empty-widget", style = "flib_dialog_footer_drag_handle", name = "drag_handler"}
local TITLEBAR_FLOW = {type = "flow", style = "flib_titlebar_flow", name = "titlebar"}
local EMPTY_WIDGET = {type = "empty-widget"}
local LABEL = {type = "label"}
local FLOW = {type = "flow"}
local VERTICAL_FLOW = {type = "flow", direction = "vertical"}
local HIDE_BUTTON = {
	hovered_sprite = "utility/close_black",
	clicked_sprite = "utility/close_black",
	sprite = "utility/close_white",
	style = "frame_action_button",
	type = "sprite-button",
	name = "PI_hide"
}
local SCROLL_PANE = {
	type = "scroll-pane",
	name = "scroll-pane",
	horizontal_scroll_policy = "never"
}
local GREEN_COLOR = {0, 255, 0}
local GREY_COLOR = {190, 190, 190}
local RED_COLOR = {255, 0, 0}
local MIN_AFK_TIME = 60 * 10
--#endregion


--#region utils


---Format: hh:mm
---@param ticks integer
---@return string
local function get_player_time(ticks)
	local ticks_in_1_minute = 60 * 60 * game.speed
	local ticks_in_1_hour = 60 * ticks_in_1_minute
	local hours = floor(ticks / ticks_in_1_hour)
	local minutes = floor((ticks - (hours * ticks_in_1_hour)) / ticks_in_1_minute)

	if minutes < 10 then
		if minutes == 0 then
			minutes = "00"
		else
			minutes = "0" .. minutes
		end
	end

	return hours .. ":" .. minutes
end

local find_button = {type = "sprite-button", name = "PI_find_player", sprite = "entity/character", style = "slot_button_in_shallow_frame"}
local nick_label = {type = "label"}
---@param player LuaPlayer
---@param main_table LuaGuiElement?
local function update_players_info_UI(player, main_table)
	local player_force = player.force
	main_table = main_table or player.gui.screen.PI_frame.shallow_frame["scroll-pane"].main_table

	main_table.clear()

	-- Add headers
	local dummy
	dummy = main_table.add(EMPTY_WIDGET)
	dummy.style.horizontally_stretchable = true
	dummy = main_table.add(EMPTY_WIDGET)
	dummy.style.horizontally_stretchable = true
	dummy.style.minimal_width = 60
	dummy = main_table.add(EMPTY_WIDGET)
	dummy.style.horizontally_stretchable = true
	dummy.style.minimal_width = 60
	dummy = main_table.add(EMPTY_WIDGET)
	dummy.style.horizontally_stretchable = true
	dummy.style.minimal_width = 60

	main_table.add(EMPTY_WIDGET)
	main_table.add(LABEL).caption = {"Players_info.nickname-header"}
	local time_header = main_table.add(VERTICAL_FLOW)
	time_header.style.horizontal_align = "center"
	time_header.add(LABEL).caption = {"Players_info.play-time-header"}
	time_header.add(LABEL).caption = {"Players_info.time-format-header"}
	main_table.add(LABEL).caption = {"Players_info.force-header"}

	-- Update content
	for _, target in pairs(game.connected_players) do
		if target.valid and target ~= player then
			local target_force = target.force
			local flow = main_table.add(FLOW)
			flow.name = tostring(player.index)
			flow.add(find_button)
			nick_label.caption = target.name
			main_table.add(nick_label)
			local time_label = main_table.add(LABEL)
			time_label.caption = get_player_time(target.online_time)
			if target.afk_time >= MIN_AFK_TIME then
				time_label.style.font_color = GREY_COLOR
			end
			local force_label = main_table.add(LABEL)
			force_label.caption = target_force.name
			if target_force ~= player_force then
				if not target_force.get_cease_fire(player_force) then
					force_label.style.font_color = RED_COLOR
				elseif target_force.get_friend(player_force) then
					force_label.style.font_color = GREEN_COLOR
				end
			end
		end
	end
end

local function switch_players_info_GUI(player)
	local PI_frame = player.gui.screen.PI_frame
	if PI_frame.visible then
		opened_Players_info_UI_refs[player.index] = nil
	else
		update_players_info_UI(player)
	end

	PI_frame.visible = not PI_frame.visible
end

local function create_players_info_gui(player)
	local screen = player.gui.screen
	if screen.PI_frame then
		screen.PI_frame.destroy()
	end

	local main_frame = screen.add{type = "frame", name = "PI_frame", direction = "vertical", visible = false}
	local flow = main_frame.add(TITLEBAR_FLOW)
	flow.add{
		type = "label",
		style = "frame_title",
		caption = {"Players_info.title"},
		ignored_by_interaction = true
	}
	flow.add(DRAG_HANDLER).drag_target = main_frame
	flow.add(HIDE_BUTTON)

	local shallow_frame = main_frame.add{type = "frame", name = "shallow_frame", style = "inside_shallow_frame"}
	local scroll_pane = shallow_frame.add(SCROLL_PANE)
	scroll_pane.style.padding = 12
	scroll_pane.style.maximal_height = 290
	local main_table = scroll_pane.add{type = "table", name = "main_table", column_count = 4}
	main_table.style.horizontally_stretchable = true
	main_table.style.vertically_stretchable = true
	main_table.draw_horizontal_lines = true
	main_table.draw_vertical_lines = true
	main_table.style.horizontal_spacing = 16
	main_table.style.vertical_spacing = 8
	main_table.style.top_margin = -16

	main_frame.force_auto_center()
end

--#endregion


--#region Functions of events

local function on_player_removed(event)
	opened_Players_info_UI_refs[event.player_index] = nil
end

local function update_all_gui()
	for player_index, main_table in pairs(opened_Players_info_UI_refs) do
		local player = game.get_player(player_index)
		if player and player.valid then
			update_players_info_UI(player, main_table)
		end
	end
end

local function on_player_left_game(event)
	local player_index = event.player_index
	opened_Players_info_UI_refs[player_index] = nil

	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	player.gui.screen.PI_frame.visible = false
	update_all_gui()
end

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	create_players_info_gui(player)
end


local GUIS = {
	PI_hide = function(_, player)
		local PI_frame = player.gui.screen.PI_frame
		PI_frame.visible = false
		opened_Players_info_UI_refs[player.index] = nil
	end,
	PI_find_player = function(element, player)
		local target_index = tonumber(element.parent.name)
		local target = game.get_player(target_index)
		if not (target and target.valid) then
			player.print({"player-doesnt-exist", "?"}, RED_COLOR)
			return
		end

		local surface = player.surface
		if surface ~= target.surface then
			player.print({"Players_info.cant-find-target"}, {255, 255, 0})
			return
		end

		local position = target.position
		if not target.is_chunk_visible(surface, position) then
			player.print({"Players_info.cant-find-target"}, {255, 255, 0})
			return
		end

		local character = target.character
		if character and character.valid then
			player.zoom_to_world(position, 0.5, character)
		else
			player.zoom_to_world(position, 0.5)
		end
	end
}
local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end

	local f = GUIS[element.name]
	if f then
		f(element, game.get_player(event.player_index), event)
	end
end

local function on_players_info_GUI(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	switch_players_info_GUI(player)
end

-- local mod_settings = {
-- 	[""] = function(value)
-- 	end,
-- }
-- local function on_runtime_mod_setting_changed(event)
-- 	local setting_name = event.setting
-- 	local f = mod_settings[setting_name]
-- 	if f == nil then return end
-- 	f(settings.global[setting_name].value)
-- end

--#endregion


--#region Pre-game stage

local function link_data()
	mod_data = global.PI
	if mod_data == nil then return end
	opened_Players_info_UI_refs = mod_data.opened_Players_info_UI_refs
end

local function update_global_data()
	global.PI = global.PI or {}
	mod_data = global.PI
	mod_data.opened_Players_info_UI_refs = {}

	link_data()

	-- Remove main frame
	for _, player in pairs(game.players) do
		if player.valid and not player.connected then
			local PI_frame = player.gui.relative.PI_frame
			if PI_frame and PI_frame.valid then
				PI_frame.destroy()
			end
		end
	end
end

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("Players_info") -- For safety
	remote.add_interface("Players_info", {})
end

M.on_init = update_global_data

-- M.on_configuration_changed = function(event)
-- 	update_global_data()

-- 	local mod_changes = event.mod_changes["Players_info"]
-- 	if not (mod_changes and mod_changes.old_version) then return end

	-- local old_version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())
-- end

M.on_load = link_data
M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_changed_force] = update_all_gui,
	[defines.events.on_player_removed] = on_player_removed,
	[defines.events.on_player_left_game] = on_player_left_game,
	[defines.events.on_player_joined_game] = function()
		if #game.connected_players ~= 1 then
			update_all_gui()
			return
		end
		mod_data.opened_Players_info_UI_refs = {}
		opened_Players_info_UI_refs = mod_data.opened_Players_info_UI_refs
	end,
	[defines.events.on_gui_click] = on_gui_click,
	["PI_open_Players_info_GUI"] = on_players_info_GUI
	-- [defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}


return M
