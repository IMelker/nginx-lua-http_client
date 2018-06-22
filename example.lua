
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
http_query["host"] = '188.94.228.58'
http_query["port"] = '80'
http_query["path"] = 'get'
http_query["query"] = ''
http_query["headers"] = ''
http_query["body"] = ''
local ok = R:lpush(http_input_key, EncodeDictonary(http_query))

local http_output_key = "http_output"
local encoded_http_output = R:blpop(http_output_key, 60)
if encoded_http_output ~= nil then
    local http_query = DecodeDictonary(encoded_http_output[2])
    print("--------------------")
    print(http_query["method"])
    print(http_query["host"]) 
    print(http_query["port"])
    print(http_query["path"])
    print(http_query["query"])
    print(http_query["headers"])
    print(http_query["body"])
    print("")
    print(http_query["res_status"])
    print(http_query["res_headers"])
    print(http_query["res_body"])
    print("--------------------")
end
--------------------------------------------------------------------------------
