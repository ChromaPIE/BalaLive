BalaLive = SMODS.current_mod

local mod = SMODS.current_mod

local function load_module(path)
    local chunk, err = SMODS.load_file(path)
    if not chunk then
        error('BalaLive failed to load ' .. path .. ': ' .. tostring(err))
    end
    return chunk()
end

local State = load_module('src/state.lua')
local Server = load_module('src/server.lua')
local ConfigUI = load_module('src/config_ui.lua')

local nfs = rawget(_G, 'NFS') or (SMODS and SMODS.NFS)
local update_seconds = 0.25
local update_elapsed = update_seconds

mod.config = State.normalize_config(mod.config or {})

local current_snapshot = State.build_snapshot({config = mod.config})
local current_json = State.encode_json(current_snapshot)
local current_signature = State.signature(current_snapshot)

local function read_asset(name)
    if not nfs then return nil end
    return nfs.read(mod.path .. 'web/' .. name)
end

local function rebuild_state()
    current_snapshot = State.build_snapshot({config = mod.config})
    current_json = State.encode_json(current_snapshot)
    current_signature = State.signature(current_snapshot)
    return current_json, current_signature
end

local server = Server.new({
    read_asset = read_asset,
    state_json = function()
        return current_json
    end,
    log = function(message)
        print(message)
    end
})

server:start(mod.config.port)

BalaLive.state = State
BalaLive.server = server
BalaLive.get_state_json = function()
    return current_json
end

ConfigUI.install(mod, State)

function BalaLive.update(dt)
    if server then
        server:update()
    end

    update_elapsed = update_elapsed + (dt or 0)
    if update_elapsed < update_seconds then return end
    update_elapsed = 0

    local previous_signature = current_signature
    local json, signature = rebuild_state()
    if signature ~= previous_signature and server then
        server:broadcast(json, signature)
    end
end

local GameRef = rawget(_G, 'Game')
if GameRef and GameRef.update then
    local balalive_original_game_update = GameRef.update
    function GameRef:update(dt)
        balalive_original_game_update(self, dt)
        BalaLive.update(dt)
    end
end
