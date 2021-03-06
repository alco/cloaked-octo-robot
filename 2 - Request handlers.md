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

Let's add handlers by allowing the user to pass `[handler: fn]` as an option. Inside the server implementation we will pass the handler all the way down to the `client_loop`. Since Elixir is a functional language, we can't easily store the options in some place and read them later inside the `client_loop` function. It is possible, but we'll take a functional approach and simply pass the argument to the subsequent function calls. Thus, most of the code remains the same save for the `spawn_client` function which extracts the `handler` from the provided options:

```elixir
  defp spawn_client(sock, options) do
    # Retrieve the handler function (if any) from the options
    handler =
      if options === nil do
        nil
      else
        Keyword.get(options, :handler)
      end
    spawn __MODULE__, :client_start, [sock, handler]
  end
```

Here's an updated `client_loop` that receives data from the socket, passes it to the handler and sends return values from the handler back to the client.

```elixir
  defp client_loop(sock, handler) do
    pid = Process.self

    # :gen_tcp.recv will block until some amount of data becomes available.
    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{packet}"
        if handler do
          case handler.(packet) do
            { :reply, data } ->
              :gen_tcp.send(sock, data)
              client_loop(sock, handler)

            { :close, reply } ->
              :gen_tcp.send(sock, reply)
              # note: no recursive call here
          end
        else
          # Work like an echo server by default
          :gen_tcp.send(sock, packet)
          client_loop(sock, handler)
        end

      { :error, reason } ->
        IO.puts "Process #{inspect pid}: Error receiving a packet: #{reason}"
    end

    # If no recursive call has been done, then we finish our business with the client.
    :gen_tcp.close(sock)
  end
```

Our handler takes one argument and returns a tuple of the specified form: it is either `{ :reply, data }` or `{ :close, data }`. The former one indicates that we should send `data` to the client and continue listening waiting for more data to arrive. The second tuple form indicates that we should close the connection after sending `data` to the client.

If no handler was provided, the server works as an echo server from our previous program (the `else` branch of the `if` block).


## The Handler Module ##

Now let's define a handler module. Unlike Erlang, Elixir does not impose the rule that each module should be defined in its own file, but we'll do it anyway to emphasize the fact that handlers are independent of the server implementation.

```elixir
# handler_stateless.ex
defmodule Handler do
  @moduledoc """
  A stateless handler that performs a simplistic transformation of its input.
  """

  @doc """
  This is a multi-clause function, it has a separate definition for each of the two cases we support.
  """
  def handle("bye" <> _rest) do
    { :close, "Good bye, my friend" }
  end

  # default case
  def handle(data) do
    { :reply, "Understood: #{data}" }
  end
end
```

Our handler has two clauses to demonstrate both forms of return values described earlier. Finally, let's perform a quick test run to see how our new server handles the job. We compile our server and handler modules, launch the server and interacted with it using `netcat` in a separate terminal window.

```
# Client
λ nc localhost 8000
hello
Understood: hello
bye
Good bye, my friend
```

Server side:

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

This simplistic example already shows us how little amount of code in Elixir can give sufficient results. Let's take this one step further and add some state to our handler to make it more practical.


## A Stateful Handler ##

While having stateful connection is usually frowned upon in the mainstream web programming community, it is nothing special in the Erlang and Elixir land. By having one (or more) process per client, nothing restrains you from keeping some state within that process. Keeping state for a connection you'll have easier time handling database quieries and the like by only issuing them only per client session, since the most frequently used state can be kept in memory within an Erlang process.

Let's add some state to our server. This will change the signature of `client_loop` function and the way our `Handler` module is defined. Let's begin with the `client_loop` function.

```elixir
# server.ex
  def client_loop(sock, handler, state // Orddict.new) do  # <--
    pid = Process.self

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{packet}"
        if handler do
          case handler.(packet, state) do                  # <--
            { :reply, data, new_state } ->                 # <--
              :gen_tcp.send(sock, data)
              client_loop(sock, handler, new_state)        # <--

            { :close, reply } ->
              :gen_tcp.send(sock, reply)
          end
        else
          # Work like an echo server by default
          :gen_tcp.send(sock, packet)
          client_loop(sock, handler, state)                # <--
        end

      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
    end

    # If no recursive call has been done, then we finish our business with the client.
    :gen_tcp.close(sock)
  end
```

The important parts (marked with arrows) are the function signature and the `case` block that follows `if handler do`. We have added a third argument -- `state` -- and initialized it with an empty `Orddict`. The block that invokes our handler has also been reworked to accomodate for the additional argument. Notice also that recursive calls have been changed to pass the state variable to each successive call, effectively keeping the state of the connection during its lifetime.

Let's look at the modified Handler code.

```elixir
# handler.ex
defmodule Handler do
  @moduledoc """
  A stateful handler that keeps track of the number of items owned by the
  client.
  """

  @doc """
  `handle` is a multi-clause function, it has a separate definition for each of
  the verbs we support and an extra clause for the default case.
  """
  def handle("buy " <> data, state) do
    count = Dict.get(state, data)
    article =
      if count && count > 0 do
        "another"
      else
        "a"
      end

    # Increment the counter for `data`
    { :reply, "You've got #{article} #{data}", Dict.update(state, data, 1, &1 + 1)  }
  end

  """
  The second `handle` clause that decrements the specified counter.
  """
  def handle("sell " <> data, state) do
    count = Dict.get(state, data, 0)
    if count > 0  do
      { :reply, "You have sold the #{data}", Dict.update(state, data, &1 - 1) }
    else
      { :reply, "You don't have a #{data}", state }
    end
  end

  """
  Default case
  """
  def handle(data, _) do
    { :close, "Don't know what to do with #{data}" }
  end
end
```

We have changed the return values of the handler as well to return updated state object that will subsequently get passed to a recursive call of `client_loop`. All in all, the idea is quite simple in itself, but it allows for much flexibility in designing you own connection protocols.

Let's look at a sample test session for the updated server.

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

```
# Server
λ elixirc server.ex handler.ex
Compiled handler.ex
Compiled server.ex

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

