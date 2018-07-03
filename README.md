# NGINX Lua HTTP Client
`NGINX HTTP Client` based on `nginx-lua-module`, `resty.http` and `resty.redis`. Starting with `init_worker_by_lua` and timer hack.
It's synchronous. Workspeed can be increased by changing number of NGINX workers in `nginx.conf`.

## Usage 
Write to `http` block in your `nginx.conf` next instruction: `init_worker_by_lua_file <path>/http_client.lua`
and restart nginx server.

Client is listening Redis list as a queue. Data is stored as table, witch serialised to binary string. In `http_client.lua` you can find `encode` and `decode` methods. Your services can push data to Redis list and await response using needed key.
