--[[
      OBS Studio Lua script : animate movement of object with hotkey
      Modified by : James Kao

      Based on original Lua script : rotate an object with hotkeys
      Original Author: John Craig
      Original Version: 0.2 (added reset)
      Originally Released: 2018-09-23
--]]


local obs = obslua
local source, increment, interval, reset, debug, sceneName
local distance, delay
local sceneItem
local direction = 1
local times = 1
local hk = {}
local iter = 0
local horizontal = true


-- if you are extending the script, you can add more hotkeys here
-- then add actions in the 'onHotKey' function further below
local hotkeys = {
	ROTATE_cw = "Advance Object",
	ROTATE_ccw = "Retract Object",
	ROTATE_stop = "Stop movement",
	ROTATE_reset = "Reset position",
}


local function currentSceneName()
	local src = obs.obs_frontend_get_current_scene()
	local name = obs.obs_source_get_name(src)
	obs.script_log(obs.LOG_INFO, string.format("Current scene : %s", name))
	obs.obs_source_release(src)
	return name
end


local function findSceneItem(itemName)
	-- local src = obs.obs_get_source_by_name(currentSceneName())
	local src = obs.obs_get_source_by_name(sceneName)
	if src then
		local scene = obs.obs_scene_from_source(src)
		obs.obs_source_release(src)
		if scene then
			sceneItem = obs.obs_scene_find_source(scene, source)
			if sceneItem and debug then obs.script_log(obs.LOG_INFO, string.format("Found source : %s", source)) end
			return true
		end
		obs.script_log(obs.LOG_INFO, string.format("Could not find source : %s", source))
	else
		obs.script_log(obs.LOG_INFO, string.format("Could not find scene: %s", sceneName))
	end
	sceneItem = nil
end


local function moveStep()
	if sceneItem and iter < times then
		iter = iter + 1
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(sceneItem, pos)
		if (duration - iter * interval > interval) then
			-- We're not on the last step, so move
			if horizontal then
				pos.x = pos.x + increment * direction
			else
				pos.y = pos.y + increment * direction
			end
		else
			-- We are on the last step, move to the final location
			if horizontal then
				pos.x = reset + distance * direction
			else
				pos.y = reset + distance * direction
			end
			obs.script_log(obs.LOG_INFO, string.format("Last step move to: %f", pos.x))
		end
		obs.obs_sceneitem_set_pos(sceneItem, pos)
		-- local r = obs.obs_sceneitem_get_rot(sceneItem) + increment * direction
		-- obs.obs_sceneitem_set_rot(sceneItem, r)
	else
		obs.remove_current_callback()
	end
end


-- add any custom actions here
local function onHotKey(action)
	if (iter ~= 0 and iter < times) then
		return
	end
	obs.timer_remove(moveStep)
	findSceneItem()
	if debug then obs.script_log(obs.LOG_INFO, string.format("Hotkey : %s", action)) end
	if action == "ROTATE_cw" then
		direction = 1
		iter = 0
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(sceneItem, pos)
		if horizontal then
			reset = pos.x
		else
			reset = pos.y
		end
		obs.timer_add(moveStep, interval)
	elseif action == "ROTATE_ccw" then
		direction = -1
		iter = 0
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(sceneItem, pos)
		if horizontal then
			reset = pos.x
		else
			reset = pos.y
		end
		obs.timer_add(moveStep, interval)
	elseif action == "ROTATE_reset" and sceneItem then
		-- obs.obs_sceneitem_set_rot(sceneItem, reset)
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(sceneItem, pos)
		if horizontal then
			pos.x = reset
		else
			pos.y = reset
		end
		obs.obs_sceneitem_set_pos(sceneItem, pos)
	end
end


----------------------------------------------------------


-- called on startup
function script_load(settings)
	for k, v in pairs(hotkeys) do
		hk[k] = obs.obs_hotkey_register_frontend(k, v, function(pressed) if pressed then onHotKey(k) end end)
		local hotkeyArray = obs.obs_data_get_array(settings, k)
		obs.obs_hotkey_load(hk[k], hotkeyArray)
		obs.obs_data_array_release(hotkeyArray)
	end
	-- findSceneItem()
end


-- called on unload
function script_unload()
end


-- called when settings changed
function script_update(settings)
	sceneName = obs.obs_data_get_string(settings, "scene")
	source = obs.obs_data_get_string(settings, "source")
	distance = obs.obs_data_get_double(settings, "distance")
	duration = obs.obs_data_get_int(settings, "duration")
	horizontal = obs.obs_data_get_bool(settings, "horizontal")

	interval = 30.0
	times = duration / interval
	increment = distance / times

	obs.script_log(obs.LOG_INFO, string.format("Move increment: %f", increment))
	obs.script_log(obs.LOG_INFO, string.format("Times to move: %d", times))

	debug = obs.obs_data_get_bool(settings, "debug")
	findSceneItem()
	if sceneItem then
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(sceneItem, pos)
		if horizontal then
			reset = pos.x
		else
			reset = pos.y
		end
	end
end


-- return description shown to user
function script_description()
	return "Rotate an object with hotkeys"
end


-- define properties that user can change
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_text(props, "scene", "Scene containing object", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "source", "Object to move", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_float(props, "distance", "Distance (px)", 0, 3840, 0.05)
	obs.obs_properties_add_int(props, "duration", "Duration (ms)", 2, 60000, 1)
	obs.obs_properties_add_bool(props, "horizontal", "Horizontal Move")
	-- obs.obs_properties_add_float(props, "times", "Times", 1, 2000, 1)
	-- obs.obs_properties_add_int(props, "reset", "Reset position", 0, 359, 1)
	obs.obs_properties_add_bool(props, "debug", "Debug")
	return props
end


-- set default values
function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "scene", "")
	obs.obs_data_set_default_string(settings, "source", "")
	obs.obs_data_set_default_double(settings, "distance", 2)
	obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_bool(settings, "horizontal", true)
	obs.obs_data_set_default_bool(settings, "debug", false)
end


-- save additional data not set by user
function script_save(settings)
	for k, v in pairs(hotkeys) do
		local hotkeyArray = obs.obs_hotkey_save(hk[k])
		obs.obs_data_set_array(settings, k, hotkeyArray)
		obs.obs_data_array_release(hotkeyArray)
	end
end
