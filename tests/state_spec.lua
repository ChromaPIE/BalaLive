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

local signature_before = State.signature(snapshot)
fake_g.GAME.hands.Pair.level = 3
local signature_after = State.signature(State.build_snapshot({
    G = fake_g,
    config = snapshot.config,
    localize = fake_localize
}))
assert_true(signature_before ~= signature_after, 'signature changes when hidden rotation panel data changes')

local empty = State.build_snapshot({G = {}, config = {}, localize = fake_localize})
assert_equal(#empty.jokers.items, 0, 'missing joker area is empty')
assert_equal(#empty.consumables.items, 0, 'missing consumable area is empty')
assert_equal(#empty.hands.items, 0, 'missing hand table is empty')

local json = State.encode_json(snapshot)
assert_true(json:find('"jokers"', 1, true) ~= nil, 'encodes snapshot as JSON')
assert_true(json:find('"rarity_color":"#009DFF"', 1, true) ~= nil, 'JSON includes rarity color')

print('state_spec: PASS')
