local ConfigUI = {}

local STYLE_OPTIONS = {'Text color', 'Background'}
local STYLE_VALUES = {'text', 'background'}

local function style_option_index(style)
    return style == 'background' and 2 or 1
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
                label('BalaLive', 0.5, G.C.BLUE),
                label('Overlay URL: http://localhost:' .. tostring(mod.config.port) .. '/', 0.3, G.C.UI.TEXT_LIGHT),
                label('Port changes apply after reload.', 0.25, G.C.UI.TEXT_INACTIVE),
                slider('Port', mod.config, 'port', 1024, 65535, 5),
                slider('Joker seconds', mod.config, 'joker_seconds', 1, 30, 4),
                slider('Consumable seconds', mod.config, 'consumable_seconds', 1, 30, 4),
                slider('Hand seconds', mod.config, 'hand_seconds', 1, 30, 4),
                {
                    n = G.UIT.R,
                    config = {align = 'cm', padding = 0.08},
                    nodes = {
                        {n = G.UIT.T, config = {text = 'Joker rarity style', scale = 0.35, colour = G.C.UI.TEXT_LIGHT}},
                        create_option_cycle({
                            options = STYLE_OPTIONS,
                            current_option = style_option_index(mod.config.joker_rarity_style),
                            opt_callback = 'balalive_style_cycle',
                            ref_table = mod.config,
                            ref_value = 'joker_rarity_style',
                            values = STYLE_VALUES,
                            w = 3.2,
                            h = 0.45,
                            text_scale = 0.32,
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
