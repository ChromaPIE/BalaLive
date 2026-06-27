local function assert_true(value, message)
    if not value then error(message or 'assert_true failed', 2) end
end

local function read(path)
    local file = assert(io.open(path, 'rb'))
    local data = file:read('*a')
    file:close()
    return data
end

local app = read('web/app.js')
local css = read('web/style.css')

assert_true(app:find('function animateMovedItems', 1, true) ~= nil, 'app includes reorder animation function')
assert_true(app:find('getBoundingClientRect', 1, true) ~= nil, 'app measures item positions for FLIP animation')
assert_true(css:find('.balalive-item-move', 1, true) ~= nil, 'css includes move animation class')
assert_true(css:find('@keyframes balalive-item-move', 1, true) ~= nil, 'css includes move keyframes')
assert_true(css:find('text-transform: uppercase', 1, true) == nil, 'css does not force localized panel labels to uppercase')

print('web_static_spec: PASS')
