local _M = {
  VERSION = '0.0.1'
}

local ngx_now = ngx.now

local sub = string.sub
local find = string.find
local insert = table.insert

local open = io.open
local execute = os.execute
local tmpname = os.tmpname
local getenv = os.getenv
local unpack = unpack

function _M.timer(name, fun, ...)
  local start = ngx_now()
  ngx.log(ngx.INFO, 'benchmark start ' .. name .. ' at ' .. start)
  local ret = { fun(...) }
  local time = ngx_now() - start
  ngx.log(ngx.INFO, 'benchmark ' .. name .. ' took ' .. time)
  return unpack(ret)
end


function _M.env_enabled(name)
  local val = getenv(name)
  local mapping = {
    ['true'] = true,
    ['false'] = false,
    ['1'] = true,
    ['0'] = false,
    [''] = false
  }

  return mapping[val]
end

function _M.system(command)
  local tmp = tmpname()
  ngx.log(ngx.DEBUG, 'os execute ' .. command)
  local success, exit, code = execute(command .. ' > ' .. tmp .. ' 2>&1')

  local handle, err = open(tmp)
  local output

  if handle then
    output = handle:read("*a")
    handle:close()
  else
    return nil, err
  end

  -- os.execute returns exit code as first return value on OSX
  -- even though the documentation says otherwise (true/false)
  if success == 0 or success == true then
    return output
  else
    return nil, output, code or exit or success
  end
end

return _M
