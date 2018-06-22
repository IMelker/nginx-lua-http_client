--init_worker_by_lua_file <path>/http_client.lua

--------------------------------------------------------------------------------
local struct = require "struct"
local function EncodeDictonary(msg)
  local str = ""
  for key, value in pairs(msg) do
    local frmt = "<Lc" .. string.len(key) .. "Lc" .. string.len(value)
    local pack_unit = struct.pack(frmt, string.len(key), key
                                 , string.len(value), value)
    str = str .. pack_unit
  end
  return str
end

local function DecodeDictonary(str)
  local message = {}
  while string.len(str) ~= 0 do
    local size_key = struct.unpack("<L", string.sub(str, 1, 8))
    str = string.sub(str, 9)
    local key = struct.unpack("<c" .. size_key, string.sub(str, 1, size_key))
    str = string.sub(str, size_key + 1)
    local size_value = struct.unpack("<L", string.sub(str, 1, 8))
    str = string.sub(str, 9)
    local value = struct.unpack("<c" .. size_value, string.sub(str, 1, size_value))
    str = string.sub(str, size_value + 1)
    message[key] = value
  end
  return message
end
--------------------------------------------------------------------------------
function string:ToHeadersTable()
  local outResults = { }
  
  return outResults
end

function table:ToHeadersString()
  local outResults = ""

  return outResults
end
--------------------------------------------------------------------------------

if ngx.worker.id() ~= nil then
    ngx .log(ngx.INFO, "START [", ngx.worker.id(),"] time [", ngx.time(), "]")
    local delay = 5
    local timer = ngx.timer.at
    local check
    
    check = function(premature)
        if not premature then
            local redis = require "resty.redis"
            local http = require "resty.http"
            local R = redis:new()
            local httpc = http.new()
            
            local ok, error = R:connect("unix:/var/run/redis/redis.sock")
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to redis: ", error)
                goto continue
            end

            while ok do 
                local http_input_key = "http_input"
                local encoded_http_input, error = R:blpop(http_input_key, 60)
                if encoded_http_input ~= nil and encoded_http_input[2] ~= nil then
                    local http_query = DecodeDictonary(encoded_http_input[2])
                    
                    ngx.log(ngx.INFO, http_query["method"])
                    ngx.log(ngx.INFO, http_query["uri"])
                    ngx.log(ngx.INFO, http_query["headers"])
                    ngx.log(ngx.INFO, http_query["body"])
                    
                    local httpc_res, httpc_error = httpc:request_uri(http_query["uri"], {
                        method = http_query["method"],
                        body = http_query["body"],
                        headers = http_query["headers"]:ToHeadersTable()
                    })

                    if not httpc_res then
                        ngx.say("failed to request: ", httpc_error)
                        return
                    end
                    
                    ngx.log(ngx.INFO, httpc_res.status)
                    ngx.log(ngx.INFO, httpc_res.headers:ToHeadersString())
                    ngx.log(ngx.INFO, httpc_res:read_body())
                    
                    local http_output_key = "http_output"
                    http_query["res_status"] = httpc_res.status
                    http_query["res_headers"] = httpc_res.headers:ToHeadersString()
                    http_query["res_body"] = httpc_res:read_body()
                    local res_redis_res, res_redis_err = R:lpush(http_output_key, EncodeDictonary(http_query))
                    if (not res_redis_res) then
                        ngx.log(ngx.ERR, "Failed to write down response data to redis: ", res_redis_err)
                    end
                end
                httpc:set_keepalive(60000, 1024)
                R:set_keepalive(10000, 1024)
            end 

            ::continue::
            local tm_ok, tm_error = timer(delay, check)
            if not tm_ok then
                ngx.log(ngx.ERR, "failed to create timer: ", tm_error)
                return
            end
        end
    end

    local hdl, err = timer(delay, check)
    if not hdl then
        log(ngx.ERR, "failed to create timer: ", err)
        return
    end
end
