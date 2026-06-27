local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or 'assert_equal failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function assert_true(value, message)
    if not value then error(message or 'assert_true failed', 2) end
end

local en = dofile('localization/en-us.lua')
local zh = dofile('localization/zh_CN.lua')

local keys = {
    'balalive_title',
    'balalive_overlay_url',
    'balalive_port_reload',
    'balalive_config_port',
    'balalive_config_joker_seconds',
    'balalive_config_consumable_seconds',
    'balalive_config_hand_seconds',
    'balalive_config_rarity_style',
    'balalive_style_text',
    'balalive_style_background',
    'balalive_standby',
    'balalive_level_prefix'
}

for _, key in ipairs(keys) do
    assert_true(en.misc.dictionary[key], 'en-us has ' .. key)
    assert_true(zh.misc.dictionary[key], 'zh_CN has ' .. key)
end

assert_equal(en.descriptions.Mod.balalive.name, 'BalaLive', 'en-us mod name is localized')
assert_equal(zh.descriptions.Mod.balalive.name, 'BalaLive', 'zh_CN mod name is localized')
assert_true(en.misc.dictionary.balalive_overlay_url:find('#1#', 1, true) ~= nil, 'en-us overlay URL is variable localized')
assert_true(zh.misc.dictionary.balalive_overlay_url:find('#1#', 1, true) ~= nil, 'zh_CN overlay URL is variable localized')

print('localization_spec: PASS')
