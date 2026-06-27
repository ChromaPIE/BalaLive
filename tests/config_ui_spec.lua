package.path = package.path .. ';./?.lua;./?/init.lua'

local ConfigUI = require('src.config_ui')
local State = require('src.state')

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or 'assert_equal failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function assert_true(value, message)
    if not value then error(message or 'assert_true failed', 2) end
end

G = {
    C = {
        CLEAR = {0, 0, 0, 0},
        BLUE = {0, 0.5, 1, 1},
        UI = {
            TEXT_LIGHT = {1, 1, 1, 1},
            TEXT_INACTIVE = {0.5, 0.5, 0.5, 1}
        }
    },
    FUNCS = {},
    UIT = {ROOT = 'ROOT', R = 'R', C = 'C', T = 'T'}
}

SMODS = {
    save_mod_config = function() end
}

local sliders = {}
local inputs = {}
local cycles = {}

function create_slider(args)
    sliders[#sliders + 1] = args
    return {n = G.UIT.R, marker = 'slider', args = args}
end

function create_text_input(args)
    inputs[#inputs + 1] = args
    return {n = G.UIT.R, marker = 'text_input', args = args}
end

function create_option_cycle(args)
    cycles[#cycles + 1] = args
    return {n = G.UIT.R, marker = 'option_cycle', args = args}
end

local function contains_marker(node, marker)
    if type(node) ~= 'table' then return false end
    if node.marker == marker then return true end
    for _, child in ipairs(node.nodes or {}) do
        if contains_marker(child, marker) then return true end
    end
    return false
end

local function row_has_text(node, text)
    if type(node) ~= 'table' then return false end
    if node.n == G.UIT.T and node.config and node.config.text == text then return true end
    for _, child in ipairs(node.nodes or {}) do
        if row_has_text(child, text) then return true end
    end
    return false
end

local function find_row_with_text(node, text)
    if type(node) ~= 'table' then return nil end
    if node.n == G.UIT.R and row_has_text(node, text) then return node end
    for _, child in ipairs(node.nodes or {}) do
        local found = find_row_with_text(child, text)
        if found then return found end
    end
    return nil
end

local mod = {
    config = {
        port = 43140,
        joker_seconds = 5,
        consumable_seconds = 5,
        hand_seconds = 5,
        joker_rarity_style = 'text'
    }
}

ConfigUI.install(mod, State)
local tree = mod.config_tab()

local port_input
for _, input in ipairs(inputs) do
    if input.ref_value == 'port' then port_input = input end
end

assert_true(port_input ~= nil, 'port uses text input')
assert_equal(port_input.ref_table, mod.config, 'port input writes to mod config')
assert_equal(port_input.max_length, 5, 'port input accepts five digits')
assert_equal(port_input.extended_corpus, true, 'port input accepts numeric text directly')

for _, slider in ipairs(sliders) do
    assert_true(slider.ref_value ~= 'port', 'port does not use a slider')
end

local style_label_row = find_row_with_text(tree, 'Joker rarity style')
assert_true(style_label_row ~= nil, 'style label row exists')
assert_true(not contains_marker(style_label_row, 'option_cycle'), 'style cycle is not packed into the label row')
assert_true(cycles[1] and cycles[1].ref_value == 'joker_rarity_style', 'style cycle remains bound to config')
assert_true((cycles[1].w or 0) <= 2.8, 'style cycle is narrow enough for the config panel')

print('config_ui_spec: PASS')
