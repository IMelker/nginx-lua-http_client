--init_worker_by_lua_file <path>/http_client.lua

--------------------------------------------------------------------------------
local struct = require "struct"
local function EncodeDictonary(msg)
  local str = ""
  for key, value in pairs(msg) do
    local frmt = "<Lc" .. string.len(key) .. "Lc" .. string.len(value)
    local pack_unit = struct.pack(frmt, 
                                  string.len(key), 
                                  key,
                                  string.len(value),
                                  value)
    str = str .. pack_unit
  end
  return str
end

local function DecodeDictonary(str)
  local message = {}
  while string.len(str) ~= 0 do
    local key_s = struct.unpack("<L", string.sub(str, 1, 8))
    str = string.sub(str, 9)
    local key = struct.unpack("<c" .. key_s, string.sub(str, 1, key_s))
    str = string.sub(str, key_s + 1)
    local value_s = struct.unpack("<L", string.sub(str, 1, 8))
    str = string.sub(str, 9)
    local value = struct.unpack("<c" .. value_s, string.sub(str, 1, value_s))
    str = string.sub(str, value_s + 1)
    message[key] = value
  end
  return message
end
--------------------------------------------------------------------------------
function ToHeadersTable(str)
  local result = { }
  local pairPtrn = "=\""
  local pairEndPtrn = "\""
  local theStart = 1
  local pairStart, pairEnd = str.find(str, pairPtrn, theStart)
  while pairStart do
    local pairEndStart, pairEndEnd = str.find(str, pairEndPtrn, pairEnd + 1)
    local key = str.sub(str, theStart, pairStart - 1)
    local value = str.sub(str, pairEnd + 1, pairEndStart - 1)
    result[key] = value
    theStart = pairEndEnd + 2 -- 2 because of , after "
    pairStart, pairEnd = str.find(str, pairPtrn, theStart)
  end
  return result
end

function ToHeadersString(headers_table)
  local result = ""
  for k, v in pairs(headers_table) do
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
            if ok then
                R:set_timeout(120000)
            else 
                ngx.log(ngx.ERR, "Redis connect error: ", error)
                working = false
	    end
	
	    local http_input_key = "http_input"
            while working do 
                local encoded_http_input, error = R:blpop(http_input_key, 50)
                if encoded_http_input then 
		    if (type(encoded_http_input) == 'table') and 
		       (type(encoded_http_input[2]) == 'string') then
                        local http_query = DecodeDictonary(encoded_http_input[2])
			ngx.log(ngx.ERR, http_query["headers"])
                        local httpc_res, httpc_error = httpc:request_uri(http_query["url"], {
                            method = http_query["method"],
                            body = http_query["body"],
                            headers = ToHeadersTable(http_query["headers"])
                        })

			local t_headers = ToHeadersTable(http_query["headers"])
			for k, v in pairs(t_headers) do 
			    ngx.log(ngx.ERR, "HEADERS VALUE [", k, ']=', v)
			end

                        if httpc_res ~= nil then
                            httpc_res:read_body();                   
                            local http_output_key = "http_output"
                            http_query["res_status"] = httpc_res.status
                            http_query["res_headers"] = ToHeadersString(httpc_res.headers)
                            ngx.log(ngx.ERR, "RESPONSE HEADERS = ", http_query["res_headers"])
			    http_query["res_body"] = httpc_res.body
                            local lpush_resp, lpush_err = R:lpush(http_output_key, EncodeDictonary(http_query))
                            if not lpush_resp then
                                ngx.log(ngx.ERR, "Redis lpush error: ", lpush_err)
                                working = false
		            end
		        else  
			    ngx.log(ngx.INFO, "HTTP request error: ", httpc_error)
                        end
	            end
	        else
	            ngx.log(ngx.INFO, "Redis blpop error: ", error)
	        end
            end 

            local tm_ok, tm_error = timer(delay, check)
            if not tm_ok then
                ngx.log(ngx.ERR, "Timer create error: ", tm_error)
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
