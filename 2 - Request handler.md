Handling requests
=================

Our server is working fine but it implements a very limited functionality. In order to make it more useful, we will allow users to define custom handlers. A handler is a function that is called by the server whenever it recieves a new logical set of data. This approach allows us to have a single server module used by different applications. The application logic is implemented in the handlers while improving the server is beneficial for all applications based on it.

Here's our updated server interface that supports passing custom info to its start method.

```elixir
defmodule Server do
  def start(port // 8000, options)
  def accept_loop(sock, options)
  def spawn_client(sock, options)
  def client_loop(sock, handler)
end
```

By introducing a second parameter in the start function we can customize the server by adding new options without breaking old code.

Let's add handlers by allowing the user to pass `[handler: fn]` as an option. Inside the server implementation we will pass the handler all the way down to the client_loop. Since Elixir is a functional language, we can't easily store the options in some place and read them later inside the client_loop function. Functional approach dictates a slightly different thinking, hence the solution we've chosen.

Here's an updated client_loop that receives data from the socket, passes it to the handler and sends replies from the handler back to the client.

```elixir
>>> Server: def client_loop
```

Let's also define a sample handler module. It can be placed in a separate file, but we'll put it right after the server in the same file this time.

```elixir
>>> defmodule Handler
```

A test session:

```
# Server
λ iex server2.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start [port: 8000, handler: Handler.handle &1]
Listening on port 8000...
Process <0.41.0> Got connection from an unknown client
Process <0.41.0> got packet hello

Process <0.42.0> Got connection from an unknown client
Process <0.42.0> got packet buy pony

Process <0.42.0> got packet buy bottle

Process <0.42.0> got packet sell pony

Process <0.42.0> got packet sell chicken

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
buy bottle
You've got a bottle
sell pony
You have sold the pony
sell chicken
You have sold the chicken
^C
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
