--init_worker_by_lua_file <path>/http_client.lua

if ngx.worker.id() ~= nil then
    ngx .log(ngx.INFO, "START [", ngx.worker.id(),"] time [", ngx.time(), "]")
    local delay = 15
    local timer = ngx.timer.at
    local check
    
    check = function(premature)
        if not premature then
            local redis = require "resty.redis"
            local R = redis:new()
            
            local ok, error = R:connect("unix:/var/run/redis/redis.sock")
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to redis: ", error)
                goto continue
            end
            
            local test_redis_key = "test:" .. to_string(ngx.worker.id())
            
            local ok, error = R:set(test_redis_key, to_string(ngx.time()))
            if not ok then
                ngx.log(ngx.ERR, "failed to write down to redis: ", error)
                goto continue
            end
            
            local text, error = R:get(test_redis_key)
            if text and (type(text) == 'string') then
                ngx.log(ngx.INFO, "Readed form Redis: [", text, "]")
            end

            -- redis init
            -- start loop with blpop
                -- in loop get all params and send request
                -- wait for response
                -- write down response to redis
            -- loop again

            ::continue::
            local ok, err = timer(delay, check)
            if not ok then
                ngx.log(ngx.ERR, "failed to create timer: ", err)
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
