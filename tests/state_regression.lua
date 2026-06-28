local State = dofile('src/state.lua')

local failures = {}

local function expect_equal(actual, expected, label)
    if actual ~= expected then
        failures[#failures + 1] = string.format(
            '%s: expected %s, got %s',
            label,
            tostring(expected),
            tostring(actual)
        )
    end
end

local function localize(args, misc_cat)
    if type(args) == 'table' and args.type == 'name_text' then
        if args.set == 'Joker' and args.key == 'j_worm_tbp_spaceship' then
            return '#2#'
        end
        return args.key
    end
    if misc_cat == 'poker_hands' then return args end
    if type(args) == 'string' then return args end
    return 'ERROR'
end

local old_number_format = rawget(_G, 'number_format')
local old_format_ui_value = rawget(_G, 'format_ui_value')
_G.number_format = function(value)
    if type(value) == 'table' then return '12' end
    return tostring(value)
end
_G.format_ui_value = function(value)
    return tostring(value)
end

local level_object = {}

local level_snapshot = State.build_snapshot({
    localize = localize,
    G = {
        GAME = {
            hands = {
                Flush = {
                    visible = true,
                    level = level_object,
                    order = 1
                }
            }
        },
        jokers = {cards = {}},
        consumeables = {cards = {}}
    }
})

expect_equal(level_snapshot.hands.items[1].level, '12', 'formats non-number hand levels')

_G.number_format = old_number_format
_G.format_ui_value = old_format_ui_value

local spaceship_center = {
    key = 'j_worm_tbp_spaceship',
    set = 'Joker',
    name = 'Spaceship',
    loc_vars = function()
        return {
            vars = {
                colours = {},
                'Module Pack',
                'Modular Spaceship'
            }
        }
    end
}

local spaceship_snapshot = State.build_snapshot({
    localize = localize,
    G = {
        GAME = {hands = {}},
        jokers = {
            cards = {
                {
                    config = {center = spaceship_center},
                    ability = {
                        extra = {
                            ship_name = 'Spaceship'
                        }
                    }
                }
            }
        },
        consumeables = {cards = {}}
    }
})

expect_equal(spaceship_snapshot.jokers.items[1].name, 'Modular Spaceship', 'expands card name placeholders from loc_vars')

if #failures > 0 then
    error(table.concat(failures, '\n'), 0)
end

print('state regressions passed')
