package.path = package.path .. ';./?.lua;./?/init.lua'

local State = require('src.state')

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or 'assert_equal failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function assert_true(value, message)
    if not value then error(message or 'assert_true failed', 2) end
end

local function fake_localize(args, misc_cat)
    local labels = {
        b_jokers = 'loc:Jokers',
        b_stat_consumables = 'loc:Consumables',
        b_poker_hands = 'loc:Hands'
    }
    if type(args) == 'string' and labels[args] then
        return labels[args]
    end
    if type(args) == 'table' and args.type == 'name_text' then
        return 'loc:' .. tostring(args.key)
    end
    if misc_cat == 'poker_hands' then
        return 'hand:' .. tostring(args)
    end
    return tostring(args)
end

local fake_g = {
    C = {
        RARITY = {
            [1] = {0, 0.615, 1, 1},
            [2] = {0.294, 0.761, 0.573, 1},
            [3] = {0.996, 0.373, 0.333, 1},
            [4] = {0.698, 0.424, 0.733, 1},
            cry_exotic = {1, 0, 0.6, 1}
        }
    },
    jokers = {
        cards = {
            {config = {center = {key = 'j_joker', set = 'Joker', rarity = 1}}},
            {config = {center = {key = 'j_joker', set = 'Joker', rarity = 1}}},
            {config = {center = {key = 'j_rare', set = 'Joker', rarity = 3}}},
            {config = {center = {key = 'j_custom', set = 'Joker', rarity = 'cry_exotic'}}}
        }
    },
    consumeables = {
        cards = {
            {config = {center = {key = 'c_fool', set = 'Tarot'}}},
            {config = {center = {key = 'c_fool', set = 'Tarot'}}},
            {config = {center = {key = 'c_mars', set = 'Planet'}}}
        }
    },
    GAME = {
        hands = {
            ['High Card'] = {visible = true, level = 2, order = 1},
            Pair = {visible = true, level = 1, order = 2},
            ['Flush Five'] = {visible = false, level = 4, order = 12}
        }
    }
}

local snapshot = State.build_snapshot({
    G = fake_g,
    config = {
        port = 43140,
        joker_seconds = 7,
        consumable_seconds = 3,
        hand_seconds = 5,
        joker_rarity_style = 'background'
    },
    localize = fake_localize
})

assert_equal(snapshot.config.port, 43140, 'normalizes port')
assert_equal(snapshot.config.joker_rarity_style, 'background', 'keeps configured rarity style')
assert_equal(snapshot.in_run, true, 'detects active run from hands table')
assert_equal(snapshot.labels.jokers, 'loc:Jokers', 'localizes joker panel label')
assert_equal(snapshot.labels.consumables, 'loc:Consumables', 'localizes consumable panel label')
assert_equal(snapshot.labels.hands, 'loc:Hands', 'localizes hand panel label')
assert_equal(snapshot.labels.standby, 'BALALIVE', 'sets standby label')

assert_equal(#snapshot.jokers.items, 3, 'merges duplicate jokers')
assert_equal(snapshot.jokers.items[1].name, 'loc:j_joker', 'localizes joker name')
assert_equal(snapshot.jokers.items[1].count, 2, 'counts duplicate jokers')
assert_equal(snapshot.jokers.items[1].rarity_key, 'common', 'maps common rarity key')
assert_equal(snapshot.jokers.items[1].rarity_color, '#009DFF', 'serializes rarity color')
assert_equal(snapshot.jokers.items[3].rarity_key, 'cry_exotic', 'keeps custom rarity key')
assert_equal(snapshot.jokers.items[3].rarity_color, '#FF0099', 'serializes custom rarity color')

assert_equal(#snapshot.consumables.items, 2, 'merges duplicate consumables')
assert_equal(snapshot.consumables.items[1].name, 'loc:c_fool', 'localizes consumable name')
assert_equal(snapshot.consumables.items[1].count, 2, 'counts duplicate consumables')

assert_equal(#snapshot.hands.items, 2, 'includes visible hands only')
assert_equal(snapshot.hands.items[1].name, 'hand:High Card', 'localizes hand name')
assert_equal(snapshot.hands.items[1].level, 2, 'reads hand level')

local ordered_a = State.build_snapshot({
    G = {
        GAME = {hands = {}},
        jokers = {
            cards = {
                {config = {center = {key = 'j_a', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_b', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_a', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_c', set = 'Joker', rarity = 1}}}
            }
        }
    },
    config = {},
    localize = fake_localize
})
assert_equal(ordered_a.jokers.items[1].key, 'j_a', 'merged joker order uses first occurrence A')
assert_equal(ordered_a.jokers.items[1].count, 2, 'merged first joker keeps full count')
assert_equal(ordered_a.jokers.items[2].key, 'j_b', 'later unique joker keeps relative order')

local ordered_b = State.build_snapshot({
    G = {
        GAME = {hands = {}},
        jokers = {
            cards = {
                {config = {center = {key = 'j_b', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_a', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_a', set = 'Joker', rarity = 1}}},
                {config = {center = {key = 'j_c', set = 'Joker', rarity = 1}}}
            }
        }
    },
    config = {},
    localize = fake_localize
})
assert_equal(ordered_b.jokers.items[1].key, 'j_b', 'merged joker order uses first occurrence B')
assert_equal(ordered_b.jokers.items[2].key, 'j_a', 'duplicate joker stays at first duplicate position')

local signature_before = State.signature(snapshot)
fake_g.GAME.hands.Pair.level = 3
local signature_after = State.signature(State.build_snapshot({
    G = fake_g,
    config = snapshot.config,
    localize = fake_localize
}))
assert_true(signature_before ~= signature_after, 'signature changes when hidden rotation panel data changes')

local empty = State.build_snapshot({G = {}, config = {}, localize = fake_localize})
assert_equal(empty.in_run, false, 'missing hand table is not an active run')
assert_equal(empty.labels.standby, 'BALALIVE', 'standby label remains available outside a run')
assert_equal(#empty.jokers.items, 0, 'missing joker area is empty')
assert_equal(#empty.consumables.items, 0, 'missing consumable area is empty')
assert_equal(#empty.hands.items, 0, 'missing hand table is empty')
assert_true(State.signature(snapshot) ~= State.signature(empty), 'signature changes when run state changes')

local menu_state = State.build_snapshot({
    G = {
        STAGE = 'MAIN_MENU',
        STAGES = {RUN = 'RUN'},
        GAME = {hands = {Pair = {visible = true, level = 3, order = 1}}},
        jokers = {cards = {{config = {center = {key = 'j_joker', set = 'Joker', rarity = 1}}}}}
    },
    config = {},
    localize = fake_localize
})
assert_equal(menu_state.in_run, false, 'explicit non-run stage overrides stale game tables')
assert_equal(#menu_state.jokers.items, 0, 'non-run stage does not expose stale jokers')
assert_equal(#menu_state.hands.items, 0, 'non-run stage does not expose stale hands')

local json = State.encode_json(snapshot)
assert_true(json:find('"jokers"', 1, true) ~= nil, 'encodes snapshot as JSON')
assert_true(json:find('"rarity_color":"#009DFF"', 1, true) ~= nil, 'JSON includes rarity color')
assert_true(json:find('"labels"', 1, true) ~= nil, 'JSON includes localized labels')

print('state_spec: PASS')
