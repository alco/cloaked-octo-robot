Intro to HTTP
=============

You have noticed that in our request handler from the previous section we did a simple request parsing in order to determine which reply to send. Although this is extremely rudimentary, these are the beginning of a communication protocol.

It helps to have a protocol that is widely adopted. Different applications can be built using one protocol and they will be automatically compatible with each other.

HTTP is such a protocol for the web. Web server implement it, browsers implement it. While TCP/IP makes Internet work by providing a reliable transport layer, HTTP is the glue that makes the World Wide Web and its descendants possible.

So let's look at the basics of HTTP that we'll implement in our server. If you're already familiar with the material, you may safely skip to the next section.


The high-level model of an HTTP connection is a channel between a server and a client. The server is constantly listening on an 80 port for incoming connections. The client first connection to the server via a TCP/IP socket. The it sends a request in the defined format. The server parser the request, does what's appropriate to satisfy it and sends a response back to the client.

The request has the following form:

```
<verb> <path> HTTP/1.0
<Header1>: <Value1>
...
<HeaderN>: <ValueN>
```

`<verb>` is one of the supported request types that include GET, HEAD, POST and a bunch of others.
`<path>` is a path to the desired resource.
After the initial line, a varying number of headers may follow (including zero). Headers provide additional information necessary for performing the request on the server side. An example is sending an ETag or a date of modification of a resource that has already been downloaded once. The server may then check that that resource has not changed and return an appropriate response. Otherwise, it would resend the updated version of the resources in its entirety.

The response has the following form:

```
HTTP/1.0 <status number> <status word>
<Header1>: <Value1>
...
<HeaderN>: <ValueN>

<content>
```

## Implementing HTTP server ##

Luckily for us, the gen_tcp module already supports HTTP parsing. We'll still need to encode our replies to send back to the client though. All we'll be left to do then is to set up a framework for handling different types of requests and call appropriate handlers to process them.

After HTTP parsing our request handler will get a record of the following form:

```elixir
defrecord HTTPRequest, method: "GET", path: "/", headers: Orddict.new
iex(2)> r = HTTPRequest.new
HTTPRequest[headers: {Orddict,[]}, method: "GET", path: "/"]
```

As packets arrive, we will recieve one header at a time and accumulate it in our state. Once the whole request has been processed, we'll pass it on to the handler to get a reply. Then we'll format the reply into an HTTP response and send it back to the client.

To iterate over the headers we can use Enum module to our help.

```elixir
Enum.reduce headers, Orddict.new, fn({ name, value }, acc) ->
  case name do
    "Host" ->
      acc = Dict.put acc, "Host", value
    other ->
      IO.puts "Unhandled header #{inspect other}"
  end
  acc
end
```
