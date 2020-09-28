require "resty.core"

ffi = require('ffi')
posix = require('posix')
timersub, gettimeofday = posix.timersub, posix.gettimeofday
htmlEntities = require('htmlEntities')
dtoutils = require('dtoutils')
logutils = require('logutils')
config_dict = ngx.shared.config_dict
USERGRANT_DICT_TTL = 180
USERGRANT_NOT_PRESENT = "USERGRANT_NOT_PRESENT"
MIDDLEWARE_NON_VALUE_PARAM_TOKEN = "##M_N_V_P_T##"
MIDDLEWARE_REPEATED_PARAM_TOKEN  = "##M_R_P_T##"
MIDDLEWARE_REPEATED_HEADER_TOKEN = "##M_R_H_T##"


--if access_by_lua crashes, we send a metric, but only block the request if this var is true
REQUEST_BLOCKED_ON_LUA_ERRORS = false

--Only for tests to see check send metrics to datadog
DEBUG_ON_DD_AND_LOG_IN_LOCAL = false

MIDDLEWARE_LOGS_ENABLED_DEFAULT_VALUE = tonumber(os.getenv("MIDDLEWARE_LOGS_ENABLED_DEFAULT_VALUE") or 0)

APPLICATION_VERSION = os.getenv("VERSION")
APPLICATION_NAME = os.getenv("APPLICATION")
SCOPE_NAME = os.getenv("SCOPE")

ffi_load = ffi.load
ffi_cdef = ffi.cdef
ffi_cdef[[
  struct MiddlewareError{
      const char* body;
      struct Entry* headers[100];
      int status;
  };
  struct Entry{
      const char* name;
      const char* value;
  };

  struct Request{
      const char* host;
      const char* method;
      const char* uri;
      int logs_enabled;
      struct Entry* headers[100];
      struct Entry* parameters[100];
      struct MiddlewareError* error;
      const char* debug_info;
  };
  extern void free(void * ptr);
  extern void initWorker(struct MiddlewareError* p0);
  extern void healthCheck();
  extern void filter(struct Request* p0, struct Request* p1);
  extern void intercept(struct Request* p0, struct Request* p1);
]]
