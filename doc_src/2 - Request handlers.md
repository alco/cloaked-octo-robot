working_dir: src/request_handlers
---
Request Handlers
================

Our server is working fine but it implements a very limited functionality. In order to make it more useful, we will allow users to define custom handlers. A handler is a function that is called by the server each time it recieves a new logical set of data. This approach allows us to have a single server module used by different applications. Moreover, decoupling components in this way makes it easier to change them independent of one another. We can build the application logic without ever changing the server and we can improve the server, independently, which will be beneficial for all applications that use it.


## The Server Module ##

Here's an updated server interface that supports passing options to its `start` function.

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

We have replaced the `port` parameter with a more generic `options`. In this way we'll be able to further customize the server by adding new options without breaking old code.

Let's add handlers by allowing the user to pass `[handler: fn]` as an option. Inside the server implementation we will pass the handler all the way down to the `client_loop`. Since Elixir is a functional language, we can't easily store the options in some place and read them later inside the `client_loop` function. It is possible, but we'll take a functional approach and simply pass the argument to the subsequent function calls. Thus, most of the code remains the same save for the `spawn_client` function which extract the `handler` option:

```
>>> server_stateless.ex: def spawn_client
```

Here's an updated `client_loop` that receives data from the socket, passes it to the handler and sends replies from the handler back to the client.

```elixir
>>> server_stateless.ex: def client_loop
```

Our handler takes one argument and returns a tuple of the specified form: it is either `{ :reply, data }` or `{ :close, data }`. The former one indicates that we should send `data` to the client and continue listening for more data. The second tuple form indicates that we should close the connection after sending `data` to the client.

If no handler was provided, the server works as an echo server from our previous program (the `else` branch of the `if` block).


## The Handler Module ##

Now let's define a handler module. Unlike Erlang, Elixir does not impose the rule that each module should be defined in its own file, but we'll do it anyway to emphasize the fact that handlers are independent of the server implementation.

```elixir
# handler_stateless.ex
>>> handler_stateless.ex: *
```

Our handler has two clauses to demonstrate the both forms of return values described earlier. Finally, let's do a quick test session to see how our new server handles the job.

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

We compiled our server and handler modules, launched the server and interacted with it using netcat in a separate terminal window:

```
# Client
λ nc localhost 8000
hello
Understood: hello
bye
Good bye, my friend
```

This simplistic example already shows us how a little amount of code in Elixir can give sufficient results. Let's take this one step further and add state to our handler to make it more practical.

## A Stateful Handler ##

While having stateful connection is usually frowned upon in the mainstream web programming community, it is nothing special in the Erlang and Elixir land. By having one (or more) process per client, nothing restrains you from keeping some state within that process. Keeping state for a connection you'll have easier time handling database quieries and the like by only issuing them only per client session, since the most frequently used state can be kept in memory within an Erlang process.

Let's add some state to our server. This will change the signature of `client_loop` function and the way our `Handler` module is defined. Let's begin with the `client_loop` function.

```
# server.ex
>>> server.ex: def client_loop
```

The important parts are the function signature and the `case` block that follows `if handler do`. We have added a third argument -- `state` -- and initialized it with an empty `Orddict`. The block that invokes our handler has also been reworked to accomodate for the additional argument. Notice also that recursive calls have been changed to keep the state.

Let's look at the modified Handler code.

```
# handler.ex
>>> handler.ex: *
```

We have changed the return values of the handler as well to allow to return updated state object that will subsequently get passed to the recursive call of `client_loop`. All in all, the idea is quite simple in itself, but it allows for much flexibility in designing you own connection protocols.

Let's look at a sample test session for the updated server.

```
# Server
λ iex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start [handler: Handler.handle &1, &2]
Listening on port 8000...
Process <0.37.0>: Got connection from a client: {127,0,0,1}:54030
Process <0.37.0> got packet hello

Process <0.38.0>: Got connection from a client: {127,0,0,1}:54032
Process <0.38.0> got packet buy pony

Process <0.38.0> got packet buy pony

Process <0.38.0> got packet sell pony

Process <0.38.0> got packet sell pony

Process <0.38.0> got packet sell lamp

Process <0.38.0> did recieve error closed
```

```
# Client
λ nc localhost 8000
buy pony
You've got a pony
buy pony
You've got another pony
sell pony
You have sold the pony
sell pony
You have sold the pony
sell lamp
You don't have a lamp
^D
```
