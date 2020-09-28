# tengine-dynamic-upstream-test
Testing tengine's dynamic upstream module

When using [upstream dynamic's tengine module](https://tengine.taobao.org/document/http_upstream_dynamic.html), `upstream_response_time` and `upstream_addr` nginx variables behaves extrangely.

Despite the fallback configuration I use, the `upstream_response_time` and `upstream_addr` register two values, even if was only one request and the connection was kept alive.  
Note that I have set `proxy_next_upstream off;` to avoid retries on failed upstream connections. 

### Example Configuration

 ```
upstream google_upstream {
    server google.com;
    keepalive 200;
}
```

```
upstream google_dynamic_upstream {
    dynamic_resolve fallback=shutdown fail_timeout=5s;
    server google.com max_fails=0;
    keepalive 200;
}
```

```
location /test-simple {
      proxy_pass http://google_upstream$request_uri;
      proxy_set_header    Host        $host;
      proxy_http_version  1.1;
      proxy_set_header    Connection  "";
}

location /test-dynamic {
      proxy_pass http://google_dynamic_upstream$request_uri;
      proxy_set_header    Host        $host;
      proxy_http_version  1.1;
      proxy_set_header    Connection  "";
}
```

### How to reproduce

Run
- `docker-compose up -d`
- `curl localhost:8080/test-simple && curl localhost:8080/test-dynamic`
- `docker-compose logs`

You'll see:

```
Attaching to tengine-dynamic-upstream-test_tengine_server_1
tengine_server_1  | GET /test-simple   [upstream_response_time:0.028] [upstream_addr:216.58.202.46:80] [status:404] [request_time:0.028]
tengine_server_1  | GET /test-dynamic  [upstream_response_time:0.002, 0.027] [upstream_addr:, 216.58.202.46:80] [status:404] [request_time:0.000]
```

### More info

1. Tcpdump GET /test-simple

![image](https://user-images.githubusercontent.com/13221002/94384851-fae42d00-0119-11eb-9592-2ed38e43c007.png)

2. Tcpdump GET /test-dynamic

![image](https://user-images.githubusercontent.com/13221002/94384860-020b3b00-011a-11eb-8a39-c3c91bb1e82f.png)

3. These tests were run with tengine 2.3.2.

tengine 2.2.1 logs differently (- instead of a value)
```
tengine_server_1  | GET /test-simple   [upstream_response_time:0.005] [upstream_addr:104.18.18.22:80] [status:200] [request_time:0.008]
tengine_server_1  | GET /test-dynamic  [upstream_response_time:-, 0.024] [upstream_addr:, 172.21.0.5:80] [status:200] [request_time:0.024]
```

tengine 2.3.2
```
tengine_server_1  | GET /test-simple   [upstream_response_time:0.028] [upstream_addr:216.58.202.46:80] [status:404] [request_time:0.028]
tengine_server_1  | GET /test-dynamic  [upstream_response_time:0.002, 0.027] [upstream_addr:, 216.58.202.46:80] [status:404] [request_time:0.000]
```
