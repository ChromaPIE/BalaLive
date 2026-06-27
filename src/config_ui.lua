local ConfigUI = {}

local STYLE_VALUES = {'text', 'background'}

local function style_option_index(style)
    return style == 'background' and 2 or 1
end

local function loc(key, fallback)
    if type(localize) == 'function' then
        local ok, value = pcall(localize, key)
        if ok and type(value) == 'string' and value ~= '' and value ~= 'ERROR' and value ~= key then
            return value
        end
    end
    return fallback or key
end

local function loc_var(key, vars, fallback)
    if type(localize) == 'function' then
        local ok, value = pcall(localize, {type = 'variable', key = key, vars = vars or {}})
        if ok and type(value) == 'string' and value ~= '' and value ~= 'ERROR' then
            return value
        end
    end
    local text = fallback or key
    for index, value in ipairs(vars or {}) do
        text = text:gsub('#' .. tostring(index) .. '#', tostring(value))
    end
    return text
end

local function style_options()
    return {
        loc('balalive_style_text', 'Text color'),
        loc('balalive_style_background', 'Background')
    }
end

local function save_config(mod)
    if SMODS and SMODS.save_mod_config then
        SMODS.save_mod_config(mod)
    end
end

local function slider(label, config, key, min, max, width)
    return create_slider({
        label = label,
        label_scale = 0.35,
        text_scale = 0.3,
        w = width or 4,
        h = 0.35,
        ref_table = config,
        ref_value = key,
        min = min,
        max = max,
        decimal_places = 0,
        colour = G.C.BLUE
    })
end

local function port_input(config)
    return {
        n = G.UIT.R,
        config = {align = 'cm', padding = 0.04},
        nodes = {
            {n = G.UIT.T, config = {text = loc('balalive_config_port', 'Port'), scale = 0.35, colour = G.C.UI.TEXT_LIGHT}},
            create_text_input({
                id = 'balalive_port',
                ref_table = config,
                ref_value = 'port',
                prompt_text = tostring(config.port or ''),
                max_length = 5,
                extended_corpus = true,
                w = 1.35,
                h = 0.42,
                text_scale = 0.32,
                colour = G.C.BLUE
            })
        }
    }
end

local function label(text, scale, colour)
    return {
        n = G.UIT.R,
        config = {align = 'cm', padding = 0.03},
        nodes = {
            {n = G.UIT.T, config = {text = text, scale = scale or 0.35, colour = colour or G.C.UI.TEXT_LIGHT}}
        }
    }
end

function ConfigUI.install(mod, State)
    local config = mod.config or {}
    local normalized = State.normalize_config(config)
    for key, value in pairs(normalized) do
        config[key] = value
    end
    mod.config = config

    G.FUNCS.balalive_style_cycle = function(args)
        local cycle = args and args.cycle_config
        if not cycle or not cycle.ref_table or not cycle.ref_value then return end
        cycle.ref_table[cycle.ref_value] = STYLE_VALUES[args.to_key] or 'text'
        save_config(mod)
    end

    mod.config_tab = function()
        local current = State.normalize_config(mod.config)
        for key, value in pairs(current) do
            mod.config[key] = value
        end

        return {
            n = G.UIT.ROOT,
            config = {align = 'cm', padding = 0.08, colour = G.C.CLEAR},
            nodes = {
                label(loc('balalive_title', 'BalaLive'), 0.5, G.C.BLUE),
                label(loc_var('balalive_overlay_url', {tostring(mod.config.port)}, 'Overlay URL: http://localhost:#1#/'), 0.3, G.C.UI.TEXT_LIGHT),
                label(loc('balalive_port_reload', 'Port changes apply after reload.'), 0.25, G.C.UI.TEXT_INACTIVE),
                port_input(mod.config),
                slider(loc('balalive_config_joker_seconds', 'Joker seconds'), mod.config, 'joker_seconds', 0, 30, 4),
                slider(loc('balalive_config_consumable_seconds', 'Consumable seconds'), mod.config, 'consumable_seconds', 0, 30, 4),
                slider(loc('balalive_config_hand_seconds', 'Hand seconds'), mod.config, 'hand_seconds', 0, 30, 4),
                {
                    n = G.UIT.R,
                    config = {align = 'cm', padding = 0.03},
                    nodes = {
                        {n = G.UIT.T, config = {text = loc('balalive_config_rarity_style', 'Joker rarity style'), scale = 0.35, colour = G.C.UI.TEXT_LIGHT}}
                    }
                },
                {
                    n = G.UIT.R,
                    config = {align = 'cm', padding = 0.03},
                    nodes = {
                        create_option_cycle({
                            options = style_options(),
                            current_option = style_option_index(mod.config.joker_rarity_style),
                            opt_callback = 'balalive_style_cycle',
                            ref_table = mod.config,
                            ref_value = 'joker_rarity_style',
                            values = STYLE_VALUES,
                            w = 2.55,
                            h = 0.45,
                            text_scale = 0.3,
                            colour = G.C.BLUE,
                            no_pips = true,
                            focus_args = {snap_to = true, nav = 'wide'}
                        })
                    }
                }
            }
        }
    end
end

return ConfigUI
