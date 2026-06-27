local State = {}

local DEFAULT_CONFIG = {
    port = 43140,
    joker_seconds = 5,
    consumable_seconds = 5,
    hand_seconds = 5,
    joker_rarity_style = 'text'
}

local VANILLA_RARITY_KEYS = {
    [1] = 'common',
    [2] = 'uncommon',
    [3] = 'rare',
    [4] = 'legendary',
    Common = 'common',
    Uncommon = 'uncommon',
    Rare = 'rare',
    Legendary = 'legendary'
}

local VANILLA_RARITY_COLOUR_KEYS = {
    common = 1,
    uncommon = 2,
    rare = 3,
    legendary = 4
}

local PANEL_LABEL_KEYS = {
    jokers = {'b_jokers', 'b_stat_jokers', 'k_jokers'},
    consumables = {'b_stat_consumables', 'b_consumables', 'k_consumables'},
    hands = {'b_poker_hands', 'k_poker_hands'}
}

local function clamp_number(value, default, min, max)
    value = tonumber(value)
    if not value then return default end
    if min and value < min then value = min end
    if max and value > max then value = max end
    return value
end

function State.normalize_config(config)
    config = config or {}
    local style = config.joker_rarity_style == 'background' and 'background' or 'text'

    return {
        port = math.floor(clamp_number(config.port, DEFAULT_CONFIG.port, 1024, 65535)),
        joker_seconds = clamp_number(config.joker_seconds, DEFAULT_CONFIG.joker_seconds, 0, 60),
        consumable_seconds = clamp_number(config.consumable_seconds, DEFAULT_CONFIG.consumable_seconds, 0, 60),
        hand_seconds = clamp_number(config.hand_seconds, DEFAULT_CONFIG.hand_seconds, 0, 60),
        joker_rarity_style = style
    }
end

local function safe_localize(localize_fn, args, misc_cat, fallback)
    if type(localize_fn) ~= 'function' then return fallback end
    local ok, value = pcall(localize_fn, args, misc_cat)
    if ok and type(value) == 'string' and value ~= '' and value ~= 'ERROR' then
        return value
    end
    return fallback
end

local function first_localized_key(localize_fn, keys, fallback)
    for _, key in ipairs(keys or {}) do
        local value = safe_localize(localize_fn, key, nil, nil)
        if value and value ~= key then return value end
    end
    return fallback
end

local function panel_labels(localize_fn)
    return {
        jokers = first_localized_key(localize_fn, PANEL_LABEL_KEYS.jokers, 'JOKERS'),
        consumables = first_localized_key(localize_fn, PANEL_LABEL_KEYS.consumables, 'CONSUMABLES'),
        hands = first_localized_key(localize_fn, PANEL_LABEL_KEYS.hands, 'HANDS'),
        standby = first_localized_key(localize_fn, {'balalive_standby'}, 'BALALIVE'),
        level_prefix = first_localized_key(localize_fn, {'balalive_level_prefix'}, 'Lv.')
    }
end

local function is_in_run(g)
    if type(g) ~= 'table' then return false end
    if type(g.STAGES) == 'table' and g.STAGES.RUN ~= nil and g.STAGE ~= nil then
        return g.STAGE == g.STAGES.RUN
    end
    return type(g.GAME) == 'table' and type(g.GAME.hands) == 'table'
end

local function css_key(value)
    value = tostring(value or 'unknown'):lower()
    value = value:gsub('[^%w_-]', '-')
    return value
end

local function to_hex_colour(colour)
    if type(colour) ~= 'table' then return nil end
    local r, g, b = tonumber(colour[1]), tonumber(colour[2]), tonumber(colour[3])
    if not r or not g or not b then return nil end
    if r <= 1 and g <= 1 and b <= 1 then
        r, g, b = r * 255, g * 255, b * 255
    end
    local function byte(v)
        v = math.floor(v + 0.5)
        if v < 0 then return 0 end
        if v > 255 then return 255 end
        return v
    end
    return string.format('#%02X%02X%02X', byte(r), byte(g), byte(b))
end

local function rarity_info(center, g)
    local rarity = center and center.rarity
    local rarity_key = VANILLA_RARITY_KEYS[rarity] or css_key(rarity)
    local colour_ref = nil

    if g and g.C and g.C.RARITY then
        colour_ref = g.C.RARITY[rarity]
        if not colour_ref and VANILLA_RARITY_COLOUR_KEYS[rarity_key] then
            colour_ref = g.C.RARITY[VANILLA_RARITY_COLOUR_KEYS[rarity_key]]
        end
    end

    return {
        key = rarity_key,
        class = 'rarity-' .. css_key(rarity_key),
        color = to_hex_colour(colour_ref) or '#CDD9DC'
    }
end

local function card_name(center, localize_fn)
    return safe_localize(
        localize_fn,
        {type = 'name_text', set = center.set or 'Joker', key = center.key},
        nil,
        center.name or center.key
    )
end

local function collect_cards(cards, localize_fn, include_rarity, g)
    local items = {}
    local by_id = {}

    for _, card in ipairs(cards or {}) do
        local center = card and card.config and card.config.center
        if center and center.key then
            local set = center.set or 'Unknown'
            local name = card_name(center, localize_fn)
            local id = set .. ':' .. center.key
            local item = by_id[id]

            if not item then
                item = {
                    id = id,
                    key = center.key,
                    set = set,
                    name = name,
                    count = 0
                }
                if include_rarity then
                    local rarity = rarity_info(center, g)
                    item.rarity_key = rarity.key
                    item.rarity_class = rarity.class
                    item.rarity_color = rarity.color
                end
                by_id[id] = item
                items[#items + 1] = item
            end

            item.count = item.count + 1
        end
    end

    return items
end

local function hand_items(hands, localize_fn)
    local items = {}

    for key, hand in pairs(hands or {}) do
        if type(hand) == 'table' and hand.visible then
            items[#items + 1] = {
                id = 'hand:' .. key,
                key = key,
                name = safe_localize(localize_fn, key, 'poker_hands', key),
                level = tonumber(hand.level) or 1,
                order = tonumber(hand.order) or 999
            }
        end
    end

    table.sort(items, function(a, b)
        if a.order == b.order then return a.key < b.key end
        return a.order < b.order
    end)

    for _, item in ipairs(items) do
        item.order = nil
    end

    return items
end

function State.build_snapshot(args)
    args = args or {}
    local g = args.G or rawget(_G, 'G') or {}
    local config = State.normalize_config(args.config or (rawget(_G, 'SMODS') and SMODS.current_mod and SMODS.current_mod.config) or {})
    local localize_fn = args.localize or rawget(_G, 'localize')
    local in_run = is_in_run(g)
    local labels = panel_labels(localize_fn)

    local jokers = in_run and g.jokers and g.jokers.cards or {}
    local consumables = in_run and g.consumeables and g.consumeables.cards or {}
    local hands = in_run and g.GAME and g.GAME.hands or {}

    return {
        config = config,
        in_run = in_run,
        labels = labels,
        jokers = {
            id = 'jokers',
            items = collect_cards(jokers, localize_fn, true, g)
        },
        consumables = {
            id = 'consumables',
            items = collect_cards(consumables, localize_fn, false, g)
        },
        hands = {
            id = 'hands',
            items = hand_items(hands, localize_fn)
        }
    }
end

local function append_item_signature(parts, item)
    parts[#parts + 1] = item.id or ''
    parts[#parts + 1] = item.name or ''
    parts[#parts + 1] = tostring(item.count or item.level or '')
    parts[#parts + 1] = item.rarity_key or ''
    parts[#parts + 1] = item.rarity_color or ''
end

function State.signature(snapshot)
    snapshot = snapshot or {}
    local config = snapshot.config or {}
    local parts = {
        tostring(config.port or ''),
        tostring(config.joker_seconds or ''),
        tostring(config.consumable_seconds or ''),
        tostring(config.hand_seconds or ''),
        tostring(config.joker_rarity_style or ''),
        tostring(snapshot.in_run == true)
    }

    local labels = snapshot.labels or {}
    for _, label_key in ipairs({'jokers', 'consumables', 'hands', 'standby', 'level_prefix'}) do
        parts[#parts + 1] = label_key
        parts[#parts + 1] = labels[label_key] or ''
    end

    for _, panel_key in ipairs({'jokers', 'consumables', 'hands'}) do
        local panel = snapshot[panel_key] or {}
        parts[#parts + 1] = panel_key
        for _, item in ipairs(panel.items or {}) do
            append_item_signature(parts, item)
        end
    end

    return table.concat(parts, '|')
end

local function json_escape(value)
    return value:gsub('[%z\1-\31\\"]', function(ch)
        if ch == '\\' then return '\\\\' end
        if ch == '"' then return '\\"' end
        if ch == '\n' then return '\\n' end
        if ch == '\r' then return '\\r' end
        if ch == '\t' then return '\\t' end
        return string.format('\\u%04x', ch:byte())
    end)
end

local function is_array(value)
    local max = 0
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return false
        end
        if key > max then max = key end
        count = count + 1
    end
    return max == count
end

local encode_json

local function encode_array(value)
    local out = {}
    for i = 1, #value do
        out[#out + 1] = encode_json(value[i])
    end
    return '[' .. table.concat(out, ',') .. ']'
end

local function encode_object(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    local out = {}
    for _, key in ipairs(keys) do
        local encoded_value = encode_json(value[key])
        if encoded_value then
            out[#out + 1] = encode_json(tostring(key)) .. ':' .. encoded_value
        end
    end
    return '{' .. table.concat(out, ',') .. '}'
end

encode_json = function(value)
    local value_type = type(value)
    if value_type == 'nil' then return 'null' end
    if value_type == 'boolean' then return value and 'true' or 'false' end
    if value_type == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then return 'null' end
        return tostring(value)
    end
    if value_type == 'string' then return '"' .. json_escape(value) .. '"' end
    if value_type == 'table' then
        if is_array(value) then return encode_array(value) end
        return encode_object(value)
    end
    return nil
end

function State.encode_json(value)
    return encode_json(value)
end

return State
