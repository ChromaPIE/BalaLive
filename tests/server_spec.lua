package.path = package.path .. ';./?.lua;./?/init.lua'

local Server = require('src.server')

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or 'assert_equal failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function assert_true(value, message)
    if not value then error(message or 'assert_true failed', 2) end
end

local function make_client(fail_after)
    return {
        sent = {},
        closed = false,
        sends = 0,
        settimeout = function() end,
        send = function(self, payload)
            self.sends = self.sends + 1
            if fail_after and self.sends > fail_after then
                return nil, 'closed'
            end
            self.sent[#self.sent + 1] = payload
            return #payload
        end,
        close = function(self)
            self.closed = true
        end
    }
end

local response = Server.response(200, 'text/plain', 'ok', {'X-Test: yes'})
assert_true(response:find('HTTP/1.1 200 OK', 1, true), 'response has status line')
assert_true(response:find('Content-Type: text/plain', 1, true), 'response has content type')
assert_true(response:find('Content-Length: 2', 1, true), 'response has content length')
assert_true(response:find('X-Test: yes', 1, true), 'response includes extra headers')
assert_true(response:find('\r\n\r\nok', 1, true), 'response includes body')

local event = Server.sse_event(3, '{"ok":true}')
assert_equal(event, 'id: 3\nevent: state\ndata: {"ok":true}\n\n', 'formats SSE event')

local server = Server.new({
    read_asset = function(name) return 'asset:' .. name end,
    state_json = function() return '{"state":true}' end
})

local index = server:route('GET', '/', make_client())
assert_true(index:find('Content-Type: text/html; charset=utf-8', 1, true), 'serves index as html')
assert_true(index:find('asset:index.html', 1, true), 'serves index asset')

local css = server:route('GET', '/style.css', make_client())
assert_true(css:find('Content-Type: text/css; charset=utf-8', 1, true), 'serves css content type')
assert_true(css:find('asset:style.css', 1, true), 'serves css asset')

local state = server:route('GET', '/state.json', make_client())
assert_true(state:find('Content-Type: application/json; charset=utf-8', 1, true), 'serves json content type')
assert_true(state:find('{"state":true}', 1, true), 'serves state json')

local missing = server:route('GET', '/missing', make_client())
assert_true(missing:find('HTTP/1.1 404 Not Found', 1, true), 'unknown route is 404')

local sse_client = make_client()
local opened = server:route('GET', '/events', sse_client)
assert_equal(opened, nil, 'SSE route keeps connection open')
assert_equal(#server.clients, 1, 'SSE route stores client')
assert_true(sse_client.sent[1]:find('Content-Type: text/event-stream', 1, true), 'SSE headers are sent')
assert_true(sse_client.sent[2]:find('data: {"state":true}', 1, true), 'SSE sends initial state')

local good = make_client()
local stale = make_client(0)
server.clients = {good, stale}
local sent = server:broadcast('{"changed":true}', 'sig-1')
assert_equal(sent, 1, 'broadcast counts successful clients')
assert_equal(#server.clients, 1, 'broadcast removes stale clients')
assert_true(good.sent[1]:find('data: {"changed":true}', 1, true), 'broadcast sends event')

local repeat_sent = server:broadcast('{"changed":true}', 'sig-1')
assert_equal(repeat_sent, 0, 'same signature is not rebroadcast')

print('server_spec: PASS')
