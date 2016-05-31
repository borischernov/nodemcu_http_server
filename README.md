# nodemcu_http_server : Minimalistic HTTP server for NodeMCU

## Features
* Serving static files from NodeMCU file system
* Support for gzipped static files
* Basic templates support (variable expansion)
* Common layout
* Redirects
* Custom error pages

## Basic usage example

~~~
dofile("server.lua")

print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
wifi.sta.config("MY_SSID","MY_PASS")
wifi.sta.connect()

-- Start HTTP server on port 80
server(80, function(method, path, params, client_ip)
  if path == "/" then
    local html = interpolate_string("<h1>Your ip is ${ip}</h1>", {ip = client_ip})
    return 200, html, "text/html"
  end
  return 404
end)

tmr.alarm(1, 1000, tmr.ALARM_AUTO, function() 
  if wifi.sta.getip() == nil then 
    print("Waiting for IP ...") 
  else 
    print("IP is " .. wifi.sta.getip())
    tmr.stop(1)
  end
end)
~~~

HTTP requests are handled by user-provided function that receives the following arguments:
* method - HTTP request verb (i.e. GET)
* path - request path (i.e. /abc )
* params - table containing parameters from request string (parsing of post request parameters is not yet supported)
* client_ip - client IP address

Handler function returns the following values:
* HTTP result code (i.e. 200)
* Response body OR redirect URL for 3xx codes (not needed for error responses)
* Content type (optional, defaults to "text/html")

## Serving static files

If "/static/" prefix is detected in request path, serving static file is attempted. Slashes in request path are converted to underscores to get appropriate file name. E.g. for request path "/static/foo/bar.css" file "_static_foo_bar.css" will be served.

Static files may be gzipped to reduce used filesystem space. For a static file gzipped version is searched for first, i.e. for request path "/static/foo/bar.css" the server will first look for "_static_foo_bar.css.gz" and only then for "_static_foo_bar.css".

Server tries to guess content types for the most common file extensions used; see function guess_content_type() for details.

## Layout and basic templating

If a file named "layout.html" is found, then it is used as a layout for all HTML responses returned by user callback function. Layout is only applied to responses with code 200 and content type "text/html".

Layout should contain "${content}" string which is replaced by actual response.

User callback function may use interpolate_string(string, table) and interpolate_file(filename, table) helper functions for variable expansion. The string or file contents (depending on the function used) is searched for strings like "${table_key}" which are replaced by respective values from the table.

## Redirects

If the callback function returns a 3xx status code then the content returned is treated as redirect url (and returned in Location header)

## Custom error pages

For custom error pages create respective html files - e.g. 404.html for 404 status code. If such a file exists - it will be served instead of standard error page. Layout (layout.html) is NOT applied to error pages.

