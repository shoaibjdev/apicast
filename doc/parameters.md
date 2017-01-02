# APIcast parameters

APIcast v2 has a number of parameters configured as environment variables that can modify the behavior of the gateway. The following reference provides descriptions of these parameters.

Note that when deploying APIcast v2 with OpenShift, some of thee parameters can be configured via OpenShift template parameters. The latter can be consulted directly in the [template](https://raw.githubusercontent.com/3scale/apicast/v2/openshift/apicast-template.yml).
 
- `APICAST_CUSTOM_CONFIG`
 
 Defines the name of the Lua module that implements custom logic overriding the existing APIcast logic. Find more information about custom config in [the documentation](/doc/custom-config.md).

- `APICAST_LOG_FILE`  
 **Default:** _stderr_
 
 Defines the file that will store the OpenResty error log. It is used by `bin/apicast` in the `error_log` directive. Refer to [NGINX documentation](http://nginx.org/en/docs/ngx_core_module.html#error_log) for more information. The file path  can be either absolute, or relative to the prefix directory (`apicast` by default) 

- `APICAST_LOG_LEVEL`  
 **Values:** debug | info | notice | warn | error | crit | alert | emerg
 **Default:** warn
 
 Specifies the log level for the OpenResty logs.

- `APICAST_MISSING_CONFIGURATION`  
 **Values:** log | exit  
 **Default:** log
 
 Used to define what APIcast should do when the configuration is missing at the initialization time. By default (_"log"_), the gateway will start successfully, and print an error message notifying of missing configuration. If set to _"exit"_, the gateway will fail to start.

- `APICAST_MODULE`  
 **Default:** "apicast"
 
 Specifies the name of the main Lua module that implements the API gateway logic. Custom modules can override the functionality of the default `apicast.lua` module. See [an example](/examples/custom-module) of how to use modules.

- `APICAST_PATH_ROUTING_ENABLED`  
 **Values:**
 - `true` or `1` for _true_
 - `false`, `0` or empty for _false_
 
 When this parameter is set to _true_, the gateway will use path-based routing instead of the default host-based routing. Learn more about the path routing mode in [the documentation](/doc/path-routing.md).

- `APICAST_RELOAD_CONFIG`  
 **Values:**
 - `true` or `1` for _true_
 - `false`, `0` or empty for _false_
 
 When this parameter is set to _true_ the configuration will be reloaded on every request. This is useful for development and testing, however it is highly discouraged to use it in production environment.

- `APICAST_REQUEST_LOGS`
 **Values:**
 - `true` or `1` for _true_
 - `false`, `0` or empty for _false_
 
 **Default:** \<empty\> (_false_)
 
 When set to _true_, APIcast will log the details about the API request (method, path and headers) and response (body and headers) in 3scale. In some plans this information can later be consulted from the 3scale admin portal.  
 Find more information about the Request Logs feature on the [3scale support site](https://support.3scale.net/docs/analytics/response-codes-tracking).

- `APICAST_RESPONSE_CODES`  
 **Values:**
 - `true` or `1` for _true_
 - `false`, `0` or empty for _false_
 
 **Default:** \<empty\> (_false_)
 
  When set to _true_, APIcast will log the response code of the response returned by the API backend in 3scale. In some plans this information can later be consulted from the 3scale admin portal.  
 Find more information about the Response Codes feature on the [3scale support site](https://support.3scale.net/docs/analytics/response-codes-tracking).
 
- `APICAST_SERVICES`  
 **Value:** a comma-separated list of service IDs
 
  Used to filter the services configured in the 3scale API Manager, and only use the configuration for specific services in the gateway, discarding those services IDs of which are not specified in the list.  
  Service IDs can be found on the **Dashboard > APIs** page, tagged as _ID for API calls_.

- `AUTO_UPDATE_INTERVAL`  
 **Values:** _a number > 60_  
 **Default:** 0

 Specifies the interval (in seconds) that will be used by the gateway to update the configuration automatically. The value should be set more than 60. For example, if `AUTO_UPDATE_INTERVAL` is set to 120, the gateway will reload the configuration every 2 minutes (120 seconds).
 
- `CURL_TIMEOUT`  
 **Default:** 3
 
 Sets the timeout (in seconds) for the `curl` command that is used to download the gateway configuration from the 3scale API Manager.

- `REDIS_HOST`  
 **Default:** "127.0.0.1"

 APIcast requires a running Redis instance for OAuth 2.0 flow. `REDIS_HOST` parameter is used to set the hostname of the IP of the Redis instance.
 
- `REDIS_PORT`  
 **Default:** 6379
 
 APIcast requires a running Redis instance for OAuth 2.0 flow. `REDIS_PORT` parameter can be used to set the port of the Redis instance.
 
- `RESOLVER`
 
 Allows to specify a custom DNS resolver that will be used by OpenResty. If the `RESOLVER` parameter is empty, the DNS resolver will be autodiscovered. 
 
- `THREESCALE_DEPLOYMENT_ENV`
 
 The value of this environment variable will be used in the header `X-3scale-User-Agent` in the authorize/report requests made to 3scale Service Management API. It is used by 3scale just for statistics.

- `THREESCALE_PORTAL_ENDPOINT`
 
 URI that includes your password and portal endpoint in following format: `<schema>://<password>@<admin-portal-domain>`. The `<password>` can be either the [provider key](https://support.3scale.net/docs/terminology#apikey) or an [access token](https://support.3scale.net/docs/terminology#tokens) for the 3scale Account Management API. `<admin-portal-domain>` is the URL used to log into the admin portal.
 
 **Example**: `https://access-token@account-admin.3scale.net`.
 
 When `THREESCALE_PORTAL_ENDPOINT` environment variable is provided, the gateway will download the configuration from 3scale on initializing. The configuration includes all the settings provided on the Integration page of the API(s).
 
 It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.

- `THREESCALE_CONFIG_FILE`
 
 Path to the JSON file with the configuration for the gateway. The configuration can be downloaded from the 3scale admin portal using the URL: `<schema>://<admin-portal-domain>/admin/api/nginx/spec.json` (**Example**: https://account-admin.3scale.net/admin/api/nginx/spec.json).
 
 When the gateway is deployed using Docker, the file has to be injected to the docker image as a read only volume, and the path should indicate where the volume is mounted, i.e. path local to the docker container.
 
 You can find sample configuration files in [examples](https://github.com/3scale/apicast/tree/v2/examples/configuration) folder.
 
 It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.
