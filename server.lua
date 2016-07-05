function hex_to_char(x)
  return string.char(tonumber(x, 16))
end

function unescape(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end

function get_file(name)
  if not file.exists(name) then
    return ""
  end
  file.open(name)
  local buf = ""
  repeat 
    local part = file.read()
    buf = buf .. part
  until part ~= ""
  file.close()
  return buf
end

function guess_content_type(path)
  local content_types = {[".css"] = "text/css", 
                         [".js"] = "application/javascript", 
                         [".html"] = "text/html",
                         [".png"] = "image/png",
                         [".jpg"] = "image/jpeg"}
  for ext, type in pairs(content_types) do
    if string.sub(path, -string.len(ext)) == ext then
      return type
    end
  end
  return "text/plain"
end

function interpolate_string(str, table)
  str = string.gsub(str, '$(%b{})', function(w) return table[w:sub(2, -2)] or w end)
  str = string.gsub(str, '$(%b[])(%b{})', function(w,v) return table[w:sub(2, -2)] and v:sub(2, -2) or '' end)
  return str
end

function interpolate_file(filename, table)
    return interpolate_string(get_file(filename), table)
end

function redirect_page(code, location)
  local redirects = {[301] =  "Moved Permanently", [302] = "Found", [303] = "See Other", [307] = "Temporary Redirect", [308] = "Permanent Redirect"}
  msg = redirects[code] or "Redirect"
  return interpolate_string("HTTP/1.1 ${code} ${msg}\nLocation: ${location}\nContent-type: text/plain\n\n${msg}", {code = code, msg = msg, location = location})
end

function error_page(code)
  local errors = {[401] = "Unauthorized", [403] = "Forbidden", [404] = "Not Found", [500] = "Internal server error"}
  local page = get_file(code .. ".html")
  if page == "" then
    page = errors[code] or ""
  end
  return interpolate_string("HTTP/1.1 ${code} ${msg}\nContent-type: text/html\n\n", {code = code, msg = errors[code]}) .. page
end

function server(port, callback)
    srv=net.createServer(net.TCP)
    srv:listen(port,function(conn)
        conn:on("receive", function(client,request)
            local cip, _ = client:getpeer()
            local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
            if method == nil then
                _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
            end
            local _GET = {}
            if (vars ~= nil)then
                vars = unescape(vars)
                for k, v in string.gmatch(vars, "([^&]+)=([^&]*)&*") do
                    _GET[k] = v
                end
            end
            local code, buf, content_type
            if string.sub(path,1,8)=="/static/" then
                code = serve_static(client, path)
                buf = ""
            else
                code, buf, content_type = callback(method, path, _GET, cip)
                content_type = content_type or "text/html"
                if code == 200 and content_type == "text/html" then
                    local layout = get_file("layout.html")
                    if layout ~= "" then
                      buf = string.gsub(layout, "${content}", buf)
                    end
                end
            end
            if code == 200 then
                if buf ~= "" then
                    buf = "HTTP/1.1 200 OK\nContent-Type: " .. content_type .. "\nContent-Length:" .. string.len(buf) .. "\n\n" .. buf
                end
            elseif code >= 300 and code < 400 then
                buf = redirect_page(code, buf)
            else
                buf = error_page(code)
            end
            if buf ~= "" then
                local function do_send(sock)
                    if (buf == "") then 
                      sock:close()
                    else
                      sock:send(string.sub(buf, 1, 512))
                      buf = string.sub(buf, 513)
                    end
                end
                client:on("sent", do_send)
                do_send(client)
            end
            print(cip .. " " .. method .. " " .. path .. " " .. code)
            collectgarbage()
        end)
    end)
end

function serve_static(client,path)
    path = string.gsub(path,"/","_")
    local ctype = guess_content_type(path)
    local content_encoding
    if file.exists(path .. ".gz") then
        content_encoding = "gzip"
        path = path .. ".gz"
    elseif file.exists(path) then
        content_encoding = ""
    else
        return 404
    end
    file.open(path, "r")
    client:on("sent", function(sock)
        local buf = file.read(512)
        if buf == nil then
            file.close()
            client:close()
        else
            client:send(buf)
        end
    end)
    local response = "HTTP/1.1 200 OK\nContent-Type: " .. ctype .. "\n"
    if content_encoding ~= "" then 
      response = response .. "Content-Encoding: " .. content_encoding .. "\n"
    end
    response = response .. "\n"
    client:send(response)
    collectgarbage()
    return 200   
end
