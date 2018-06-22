--init_worker_by_lua_file <path>/http_client.lua

if ngx.worker.id() ~= nil then
    ngx .log(ngx.INFO, "START [", ngx.worker.id(),"] time [", ngx.time(), "]")
    local delay = 15
    local timer = ngx.timer.at
    local check
    
    check = function(premature)
        if not premature then
            --ngx.log(ngx.INFO, "ITERATION ", ngx.time())
            
            -- redis init
            -- start loop with blpop
                -- in loop get all params and send request
                -- wait for response
                -- write down response to redis
            -- loop again

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
