working_dir: src/request_handlers
---
Request Handlers
================

Our server is working fine but it implements a very limited functionality. In order to make it more useful, we will allow users to define custom handlers. A handler is a function that is called by the server whenever it recieves a new logical set of data. This approach allows us to have a single server module used by different applications. Moreover, decoupling components in this way makes it easier to change them independent of one another. So we can build the application logic without ever changing the server or we can improve the server which will be beneficial for all applications that use it.

Here's an updated server interface that supports passing custom options to its `start` function.

```elixir
# server_stateless.ex
defmodule Server do
  # The only public function
  def start(options)

  # Implementation details
  defp accept_loop(sock, options)
  defp spawn_client(sock, options)
  def  client_start(sock, handler)
  defp client_loop(sock, handler)
end
```

By introducing a second parameter in the start function we'll be able to further customize the server by adding new options without breaking old code.

Let's add handlers by allowing the user to pass `[handler: fn]` as an option. Inside the server implementation we will pass the handler all the way down to the client_loop. Since Elixir is a functional language, we can't easily store the options in some place and read them later inside the client_loop function. Functional approach dictates a slightly different thinking, hence the solution we've chosen.

Here's an updated client_loop that receives data from the socket, passes it to the handler and sends replies from the handler back to the client.

```elixir
>>> server_stateless.ex: def client_loop
```

Let's also define a sample handler module. Unlike Erlang, Elixir does not impose a rule that each module should be defined in its own file, but we'll do it anyway to make an emphasis on the fact that handlers are independent of the server itself.

```elixir
# handler_stateless.ex
>>> handler_stateless.ex: *
```

A test session:

```
# Server
λ elixirc server_stateless.ex handler_stateless.ex
Compiled handler_stateless.ex
Compiled server_stateless.ex

λ iex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start [handler: Handler.handle &1]
Listening on port 8000...
Process <0.37.0>: Got connection from a client: {127,0,0,1}:53795
Process <0.37.0> got packet hello

Process <0.37.0> got packet bye
```

```
# Client
λ nc localhost 8000
hello
Understood: hello
bye
Good bye, my friend
```

## Adding state to the connection ##

While have a stateful connection is usually frowned upon in the mainstream community that uses PHP, Ruby, Python or similar for building web applications, it is nothing special in the Erlang and Elixir land. You can have a single or multiple processes per client, nothing restrains you from keeping some state within that process. This will let you have easier time with handling db quieries and the like since the most frequently used state can be kept in memory within an Erlang process.

Let's add some state to our server.

```
>>> defmodule Handler
```

Sample sessions:

```
# Server
λ iex server2.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start [port: 8000, handler: Handler.handle &1, &2]
Listening on port 8000...
Process <0.41.0> Got connection from an unknown client
Process <0.41.0> got packet hello

Process <0.42.0> Got connection from an unknown client
Process <0.42.0> got packet buy pony

Process <0.42.0> got packet buy pony

Process <0.42.0> got packet sell pony

Process <0.42.0> got packet sell pony

Process <0.42.0> got packet sell pony

Process <0.42.0> got packet sell lamp

Process <0.42.0> did recieve error closed
```

```
# Client
λ nc localhost 8000
hello
Don't know what to do with hello

λ nc localhost 8000
buy pony
You've got a pony
buy pony
You've got another pony
sell pony
You have sold the pony
sell pony
You have sold the pony
sell pony
You don't have a pony
sell lamp
You don't have a lamp
^C
```
