
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
local redis = require "redis"

local R = redis.connect('unix:/var/run/redis/redis.sock')
if not R then
    print("Failed to connect to Redis. ")
    return
end


local http_input_key = "http_input"
local http_query = { }
http_query["method"] = 'GET'
http_query["url"] = 'http://httpbin.org/get?text=kill'
local headers = { }
headers["Content-Type"] = "text/html; charset=UTF-8"
headers["Server"] = "Apache/2.0.45 (Unix) mod_ssl/2.0.45 OpenSSL/0.9.6b"
headers["Connection"] = "close"
http_query["headers"] = ToHeadersString(headers)
http_query["body"] = 'Test body'

local start_time = os.clock()
print("START TIME: ", start_time)

local ok = R:lpush(http_input_key, EncodeDictonary(http_query))
local http_output_key = "http_output"
local encoded_http_output = R:blpop(http_output_key, 60)
if encoded_http_output ~= nil then
    local http_response = DecodeDictonary(encoded_http_output[2])
    print("BODY = [", http_response["res_body"] ,"]")
    print("HEADERS = [", http_response["res_headers"], "]")
    print("STATUS = [", http_response["res_status"], "]")
end

print("END TIME: ", os.clock() - start_time)
--------------------------------------------------------------------------------
