local Server = {}
Server.__index = Server

local STATUS_TEXT = {
    [200] = 'OK',
    [204] = 'No Content',
    [400] = 'Bad Request',
    [404] = 'Not Found',
    [405] = 'Method Not Allowed',
    [413] = 'Payload Too Large',
    [500] = 'Internal Server Error'
}

local ASSET_ROUTES = {
    ['/'] = {'index.html', 'text/html; charset=utf-8'},
    ['/index.html'] = {'index.html', 'text/html; charset=utf-8'},
    ['/style.css'] = {'style.css', 'text/css; charset=utf-8'},
    ['/app.js'] = {'app.js', 'application/javascript; charset=utf-8'}
}

local function noop() end

local function default_now()
    return os.clock()
end

local function load_socket()
    local ok, socket = pcall(require, 'socket')
    if ok then return socket end
    return nil
end

local function close_client(client)
    if client and client.close then
        pcall(function() client:close() end)
    end
end

local function safe_send(client, payload)
    if not client or not client.send then return false end
    local ok, err = client:send(payload)
    if ok then return true end
    return err == 'timeout'
end

local function strip_query(path)
    path = path or '/'
    local clean = path:match('^[^?]*')
    if clean == '' then return '/' end
    return clean or '/'
end

function Server.response(status, content_type, body, extra_headers)
    body = body or ''
    local headers = {
        'HTTP/1.1 ' .. tostring(status) .. ' ' .. (STATUS_TEXT[status] or 'OK'),
        'Content-Type: ' .. content_type,
        'Content-Length: ' .. tostring(#body),
        'Cache-Control: no-store',
        'Access-Control-Allow-Origin: *',
        'Connection: close'
    }

    for _, header in ipairs(extra_headers or {}) do
        headers[#headers + 1] = header
    end

    return table.concat(headers, '\r\n') .. '\r\n\r\n' .. body
end

function Server.sse_event(id, json)
    json = tostring(json or '{}')
    json = json:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n', '\ndata: ')
    return 'id: ' .. tostring(id) .. '\nevent: state\ndata: ' .. json .. '\n\n'
end

local function sse_headers()
    return table.concat({
        'HTTP/1.1 200 OK',
        'Content-Type: text/event-stream',
        'Cache-Control: no-store',
        'Access-Control-Allow-Origin: *',
        'Connection: keep-alive',
        'X-Accel-Buffering: no'
    }, '\r\n') .. '\r\n\r\n'
end

function Server.new(args)
    args = args or {}
    return setmetatable({
        socket = args.socket,
        host = args.host or '127.0.0.1',
        read_asset = args.read_asset or function() return nil end,
        state_json = args.state_json or function() return '{}' end,
        log = args.log or noop,
        now = args.now or default_now,
        server = nil,
        clients = {},
        pending = {},
        event_id = 0,
        last_signature = nil,
        last_heartbeat = 0,
        max_accepts = args.max_accepts or 4,
        max_pending = args.max_pending or 8,
        max_request_bytes = args.max_request_bytes or 8192,
        heartbeat_seconds = args.heartbeat_seconds or 15
    }, Server)
end

function Server:start(port)
    self:stop()
    self.socket = self.socket or load_socket()
    if not self.socket then
        self.log('BalaLive: LuaSocket is unavailable')
        return nil, 'socket unavailable'
    end

    local server, err = self.socket.bind(self.host, tonumber(port) or 43140)
    if not server then
        self.log('BalaLive: failed to bind localhost server: ' .. tostring(err))
        return nil, err
    end

    server:settimeout(0)
    self.server = server
    self.port = tonumber(port) or 43140
    self.log('BalaLive: serving overlay at http://localhost:' .. tostring(self.port) .. '/')
    return true
end

function Server:stop()
    if self.server then
        close_client(self.server)
        self.server = nil
    end
    for _, client in ipairs(self.clients) do close_client(client) end
    for _, pending in ipairs(self.pending) do close_client(pending.client) end
    self.clients = {}
    self.pending = {}
end

function Server:open_sse(client)
    if client.settimeout then client:settimeout(0) end
    if not safe_send(client, sse_headers()) then
        close_client(client)
        return false
    end

    self.clients[#self.clients + 1] = client
    local json = self.state_json()
    if type(json) == 'string' and json ~= '' then
        self.event_id = self.event_id + 1
        if not safe_send(client, Server.sse_event(self.event_id, json)) then
            table.remove(self.clients, #self.clients)
            close_client(client)
            return false
        end
    end

    return true
end

function Server:route(method, path, client)
    method = method or 'GET'
    path = strip_query(path)

    if method ~= 'GET' and method ~= 'HEAD' then
        return Server.response(405, 'text/plain; charset=utf-8', 'Method Not Allowed')
    end

    if path == '/events' then
        self:open_sse(client)
        return nil
    end

    if path == '/state.json' then
        local body = self.state_json()
        if type(body) ~= 'string' then body = '{}' end
        if method == 'HEAD' then body = '' end
        return Server.response(200, 'application/json; charset=utf-8', body)
    end

    local asset = ASSET_ROUTES[path]
    if asset then
        local body = self.read_asset(asset[1])
        if type(body) ~= 'string' then
            return Server.response(500, 'text/plain; charset=utf-8', 'Asset unavailable')
        end
        if method == 'HEAD' then body = '' end
        return Server.response(200, asset[2], body)
    end

    return Server.response(404, 'text/plain; charset=utf-8', 'Not Found')
end

local function parse_request(buffer)
    local method, path = buffer:match('^(%u+)%s+([^%s]+)%s+HTTP/%d%.%d')
    return method, path
end

function Server:accept_clients()
    if not self.server then return end

    for _ = 1, self.max_accepts do
        local client, err = self.server:accept()
        if not client then
            if err ~= 'timeout' then self.log('BalaLive: accept failed: ' .. tostring(err)) end
            return
        end

        client:settimeout(0)
        self.pending[#self.pending + 1] = {
            client = client,
            buffer = '',
            created = self.now()
        }
    end
end

function Server:finish_pending(index, pending, response)
    if response then safe_send(pending.client, response) end
    close_client(pending.client)
    table.remove(self.pending, index)
end

function Server:pump_pending()
    local processed = 0
    local index = 1

    while index <= #self.pending and processed < self.max_pending do
        local pending = self.pending[index]
        local chunk, err, partial = pending.client:receive(1024)
        chunk = chunk or partial

        if chunk and chunk ~= '' then
            pending.buffer = pending.buffer .. chunk
        end

        if #pending.buffer > self.max_request_bytes then
            self:finish_pending(index, pending, Server.response(413, 'text/plain; charset=utf-8', 'Payload Too Large'))
        elseif pending.buffer:find('\r\n\r\n', 1, true) or pending.buffer:find('\n\n', 1, true) then
            local method, path = parse_request(pending.buffer)
            if method and path then
                local response = self:route(method, path, pending.client)
                if response then
                    self:finish_pending(index, pending, response)
                else
                    table.remove(self.pending, index)
                end
            else
                self:finish_pending(index, pending, Server.response(400, 'text/plain; charset=utf-8', 'Bad Request'))
            end
        elseif err == 'closed' then
            self:finish_pending(index, pending)
        else
            index = index + 1
        end

        processed = processed + 1
    end
end

function Server:broadcast(json, signature)
    if signature and signature == self.last_signature then return 0 end
    if signature then self.last_signature = signature end

    self.event_id = self.event_id + 1
    local payload = Server.sse_event(self.event_id, json)
    local kept = {}
    local sent = 0

    for _, client in ipairs(self.clients) do
        if safe_send(client, payload) then
            kept[#kept + 1] = client
            sent = sent + 1
        else
            close_client(client)
        end
    end

    self.clients = kept
    return sent
end

function Server:heartbeat()
    local now = self.now()
    if now - self.last_heartbeat < self.heartbeat_seconds then return end
    self.last_heartbeat = now

    local kept = {}
    for _, client in ipairs(self.clients) do
        if safe_send(client, ': heartbeat\n\n') then
            kept[#kept + 1] = client
        else
            close_client(client)
        end
    end
    self.clients = kept
end

function Server:update()
    self:accept_clients()
    self:pump_pending()
    self:heartbeat()
end

return Server
