# tengine-dynamic-upstream-test
Testing tengine's dynamic upstream module

When using [upstream dynamic's tengine module](https://tengine.taobao.org/document/http_upstream_dynamic.html), `upstream_response_time` and `upstream_addr` nginx variables behaves extrangely.

Despite the fallback configuration I use, the `upstream_response_time` and register two values, even if the connection was kept alive.  
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
Creating tengine-dynamic-upstream-test_tengine_server_1 ... done
Attaching to tengine-dynamic-upstream-test_tengine_server_1
tengine_server_1  | GET /test-simple 	[upstream_response_time:0.033] [upstream_addr:172.217.172.46:80] [status:404] [request_time:0.034]
tengine_server_1  | GET /test-dynamic 	[upstream_response_time:0.003, 0.034] [upstream_addr:, 172.217.172.46:80] [status:404] [request_time:0.036]
```
