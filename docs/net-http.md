# Net::HTTP

`RubyProxyHeaders::NetHTTP.patch!` prepends a small wrapper around the installed `Net::HTTP#connect`. The gem does not replace that method with its own copy. Call `patch!` once before opening connections.

Proxy header names are documented at <https://docs.proxymesh.com/>.

## Usage

```ruby
require 'uri'
require 'ruby_proxy_headers/net_http'

RubyProxyHeaders::NetHTTP.patch!

uri = URI('https://api.ipify.org?format=json')
proxy = URI('http://user:pass@proxy.example.com:31280')

http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
http.use_ssl = true
http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }

response = http.request(Net::HTTP::Get.new(uri))
puts response.body
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

`last_proxy_connect_response_headers` is case-insensitive. The same headers are on `RubyProxyHeaders.proxy_connect_response_headers` for the current thread.

An `https://` proxy needs net-http 0.5 or newer, which is what `proxy_use_ssl` requires. Set `http.proxy_use_ssl = true` for that proxy.
