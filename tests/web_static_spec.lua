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
assert_true(app:find('function enabledPanels', 1, true) ~= nil, 'app filters hidden panels by dwell seconds')
assert_true(app:find('> 0', 1, true) ~= nil, 'app treats zero seconds as disabled')
assert_true(app:find('panels.length <= 1', 1, true) ~= nil, 'app does not rotate a single enabled panel')
assert_true(app:find('function levelPrefix', 1, true) ~= nil, 'app reads hand level prefix from state labels')
assert_true(app:find('title.textContent = "BALALIVE"', 1, true) == nil, 'app does not hardcode initial standby text')
assert_true(app:find('"Lv."', 1, true) == nil, 'app does not hardcode hand level prefix')
assert_true(css:find('.balalive-item-move', 1, true) ~= nil, 'css includes move animation class')
assert_true(css:find('@keyframes balalive-item-move', 1, true) ~= nil, 'css includes move keyframes')
assert_true(css:find('text-transform: uppercase', 1, true) == nil, 'css does not force localized panel labels to uppercase')

print('web_static_spec: PASS')
