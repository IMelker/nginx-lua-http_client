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
  local result = { }
  local pairPtrn = "=\""
  local pairEndPtrn = "\""
  local theStart = 1
  local pairStart, pairEnd = string.find(self, pairPtrn, theStart)
  while pairStart do
    local pairEndStart, pairEndEnd = string.find(self, pairEndPtrn, pairEnd + 1)
    local key = string.sub(self, theStart, pairStart - 1)
    local value = string.sub(self, pairEnd + 1, pairEndStart - 1)
    result[key] = value
    theStart = pairEndEnd + 2 -- 2 because of , after "
    pairStart, pairEnd = string.find(self, pairPtrn, theStart)
  end
  return result
end

function table:ToHeadersString()
  local result = ""
  for k, v in pairs(table) do
    if type(k) == "string" then
      result = result .. k .. "="
    end
    if type(v) == "string" then
      result = result .. "\"" .. v .. "\""
    end
    result = result..","
  end
  -- Remove leading commas from the result
  if result ~= "" then
    result = result:sub(1, result:len()-1)
  end
  return result
end
--------------------------------------------------------------------------------

if ngx.worker.id() ~= nil then
    ngx .log(ngx.INFO, "START [", ngx.worker.id(),"] time [", ngx.time(), "]")
    local delay = 0
    local timer = ngx.timer.at
    local check
    
    check = function(premature)
        if not premature then
            local redis = require "resty.redis"
            local http = require "resty.http"
            local R = redis:new()
            local httpc = http.new()
	    local working = true;
            
	    local ok, error = R:connect("unix:/var/run/redis/redis.sock")
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to redis: ", error)
                working = false
	    end
	
	    local http_input_key = "http_input"
		
            while working do 
                local encoded_http_input, error = R:blpop(http_input_key, 50)
                if encoded_http_input and (type(encoded_http_input) == 'table') and 
		                          (type(encoded_http_input[2]) == 'string') then
                    local http_query = DecodeDictonary(encoded_http_input[2])
                    
                    --ngx.log(ngx.INFO, "[METHOD] = ", http_query["method"])
                    --ngx.log(ngx.INFO, "[URL] = ", http_query["url"])
                    --ngx.log(ngx.INFO, "[HEADERS] = ", http_query["headers"])
                    --ngx.log(ngx.INFO, "[BODY] = ",  http_query["body"])
                    
                    local httpc_res, httpc_error = httpc:request_uri(http_query["url"], {
                        method = http_query["method"],
                        body = http_query["body"],
                        headers = http_query["headers"]:ToHeadersTable()
                    })

                    if httpc_res ~= nil then
                        --ngx.log(ngx.INFO, httpc_res.status)
                        --ngx.log(ngx.INFO, httpc_res.headers:ToHeadersString())
                        httpc_res:read_body();
		        --ngx.log(ngx.INFO, httpc_res.body)
                    
                        local http_output_key = "http_output"
                        http_query["res_status"] = httpc_res.status
                        http_query["res_headers"] = "" --httpc_res.headers:ToHeadersString()
                        http_query["res_body"] = httpc_res.body
                        local res_redis_res, res_redis_err = R:lpush(http_output_key, EncodeDictonary(http_query))
                        if (not res_redis_res) then
                            ngx.log(ngx.ERR, "Failed to write down response data to redis: ", res_redis_err)
                            working = false
		        end	    
                    else 
			ngx.log(ngx.INFO, "Failed to request: ", httpc_error)
                    end
	        else
		    ngx.log(ngx.INFO, "Redis blpop error: ", error)
	            local ok, error = R:connect("unix:/var/run/redis/redis.sock")
                    if not ok then
                        ngx.log(ngx.ERR, "failed to connect to redis: ", error)
                        working = false
	            end
	        end
            end 

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
