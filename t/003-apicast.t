use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $apicast = $ENV{TEST_NGINX_APICAST_PATH} || "$pwd/apicast";

$ENV{TEST_NGINX_LUA_PATH} = "$apicast/src/?.lua;;";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$apicast/http.d/upstream.conf";
$ENV{TEST_NGINX_BACKEND_CONFIG} = "$apicast/conf.d/backend.conf";
$ENV{TEST_NGINX_APICAST_CONFIG} = "$apicast/conf.d/apicast.conf";

log_level('debug');
repeat_each(1);
no_root_location();
run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_missing = 'credentials missing!',
            error_status_auth_missing = 401
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_BACKEND_CONFIG;
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /
--- response_body chomp
credentials missing!
--- error_code: 401


=== TEST 2: no mapping rules matched
The message is configurable and status also.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_no_match = 'no mapping rules!',
            error_status_no_match = 412
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?user_key=value
--- response_body chomp
no mapping rules!
--- error_code: 412
--- error_log
skipping after action, no cached key

=== TEST 3: authentication credentials invalid
The message is configurable and default status is 403.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_failed = 'credentials invalid!',
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            error_status_auth_failed = 402,
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
      deny all;
  }

  location /api-backend/ {
     echo 'yay';
  }
--- request
GET /?user_key=value
--- response_body chomp
credentials invalid!
--- error_code: 402

=== TEST 4: api backend gets the request
It asks backend and then forwards the request to the api.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;

  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';
  set $backend_authentication_type 'service_token';
  set $backend_authentication_value 'token-value';

  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage[hits]=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
    }
  }

  location /api-backend/ {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend: 127.0.0.1
--- error_code: 200
--- error_log
apicast cache miss key: 42:value:usage[hits]=2
--- no_error_log
[error]

=== TEST 5: call to backend is cached
First call is done synchronously and the second out of band.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';
  set $backend_authentication_type 'service_token';
  set $backend_authentication_value 'token-value';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location /api-backend/ {
     echo 'yay, api backend';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host localhost;
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=value;
    echo_subrequest GET /test/two -q user_key=value;
  }
--- request
GET /t
--- response_body
yay, api backend
yay, api backend
--- error_code: 200
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 42:value:usage[hits]=2
apicast cache write key: 42:value:usage[hits]=2
apicast cache hit key: 42:value:usage[hits]=2

=== TEST 6: multi service configuration
Two services can exist together and are split by their hostname.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/one/",
            hosts = { 'one' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-one',
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 1 }
            }
          }
        },
        {
          id = 21,
          backend_version = 2,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/two/",
            hosts = { 'two' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-two',
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location ~ /api-backend(/.+) {
     echo 'yay, api backend: $1';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host $arg_host;
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=one-key&host=one;
    echo_subrequest GET /test/two -q app_id=two-id&app_key=two-key&host=two;
  }
--- request
GET /t
--- response_body
yay, api backend: /one/
yay, api backend: /two/
--- error_code: 200
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 42:one-key:usage[hits]=1
apicast cache write key: 42:one-key:usage[hits]=1
apicast cache miss key: 21:two-id:two-key:usage[hits]=2
apicast cache write key: 21:two-id:two-key:usage[hits]=2

=== TEST 7: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            error_no_match = 'no mapping rules matched!',
            error_status_no_match = 412,
            proxy_rules = {
              { pattern = '/foo?bar=baz',  querystring_parameters = { bar = 'baz' },
                http_method = 'GET', metric_system_name = 'bar', delta = 1 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar=foo&user_key=somekey
--- response_body chomp
no mapping rules matched!
--- error_code: 412

=== TEST 8: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar=baz',  querystring_parameters = { bar = 'baz' },
                http_method = 'GET', metric_system_name = 'bar', delta = 1 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar=baz&user_key=somekey
--- response_body
api response
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
--- error_code: 200
--- no_error_log
[error]

=== TEST 9: mapping rule with variable value is required to be sent
When mapping rule has a parameter with variable value it has to exist.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar={baz}',  querystring_parameters = { bar = '{baz}' },
                http_method = 'GET', metric_system_name = 'bar', delta = 3 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar={foo}&user_key=somekey
--- response_body
api response
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar={baz}
X-3scale-usage: usage[bar]=3


=== TEST 10: https api backend works

--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration').save({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'https://127.0.0.1:1953/api/',
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;
  listen 1953 ssl;

  ssl_certificate ../html/server.crt;
  ssl_certificate_key ../html/server.key;

  set $backend_endpoint 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT';

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
--- request
GET /test?user_key=foo
--- no_error_log
[error]
--- response_body
api response
--- error_code: 200
