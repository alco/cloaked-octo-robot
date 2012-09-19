Echo server
===========

Let's start by implementing an echo server using TCP socket functionality provided by Erlang's `gen_tcp` module.

The server will open a listening socket and wait for a client to connect. Once a new connection is requested, the server spawns a new process to handle it. Erlang processes are cheap and lightweight, so by using this approach we can support a large number of simultaneous connections.

This is a common way to handle multiple concurrent tasks in Erlang. You create a process that runs concurrently with all other processes. The processes can talk to each other by means of sending messages. By contrast to older languages, you don't have to manages the system resources yourself, the implementation already does this for you. All in all, this creates a programming model that is much easier and intuitive, allowing us to write more sophisticated software with less effort and less bugs in it.


## The Server Module ##

Our module has the following outline:

```elixir
# server.ex
defmodule Server do
  # The only public function
  def start(port // 8000)

  # Implementation details
  defp accept_loop(sock)
  defp spawn_client(sock)
  def  client_start(sock)
  defp client_loop(sock)
end
```

There is a single public function, the rest is implementation details.

> Note: Technically, `client_start` is also public, but we specify `@doc false` for it, so it's not considered to be a part of the module API.

Let's start with the `start` function.

```elixir
>>> server.ex: def start
```

`start` is a function of one argument (with a default value of 8000). It obtains a socket suitable for accepting incoming connections on the specified port and passes it on to `accept_loop`.

```elixir
>>> server.ex: def accept_loop
```

`accept_loop` demonstrates an idiomatic recursive tail-call loop in Elixir. `:get_tcp.accept` will block until a new connection is accepted. Once it returns, we'll spawn a new process to handle it and do a recursive tail-call to `accept_loop` to keep listening for new connections. Because this is a tail-call, it does not consume additional stack space, so this loop might go on indefinitely, no matter how many connections are made to the server.

Next, let's look at `spawn_client` and `client_start`.

```elixir
>>> server.ex: def spawn_client

>>> server.ex: def client_start
```

In `spawn_client` we're merely invoking the built-in `spawn` function that creates a new process and returns its identifier -- the pid. The newly spawned process will start running the `client_start` function with `sock` as its argument.

`client_start` outputs some debug info and passes the control flow over to `client_loop`. This last function is going to be the heart of the process, accepting packets from the client and sending back replies. As you might have guessed, it will also do a recursive tail-call of itself to keep receiving new packets until the connection is closed.

```elixir
>>> server.ex: def client_loop
```

This is another loop that continuosly receives data from the client and sends it back to the client.

Now, you might be thinking that having two infinite loops should not work. But remember that we have spawned a new process and started executing `client_loop` in it. In Elixir all processes share execution time or run in parallel if hardware allows. So both of our loops are running simultaneously. With each new client we'll get another client_loop running in its own process. If you look at process explorer you'll see that the Elixir process (beam.smp) hardly uses any CPU at all. That's because both our loops are spending most of their time waiting for in IO operation. This is a very common scenario in real world production systems.

## The Client Module ##

We'll be testing our server using netcat (`nc`) and later a web browser, but let's first write a client in Elixir for demonstration purposes.

```elixir
# client.ex
>>> defmodule Client
```

Start an iex session and run the server in it:

```
λ iex server.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start
Listening on port 8000...
```

In another terminal window, launch the client:

```
λ iex client.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> sock = Client.connect({127,0,0,1}, 8000)
#Port<0.2718>
iex(2)> Client.send(sock, "abc")
{:ok,'abc'}
iex(3)> Client.close(sock)
:ok
```

This confirms that our server accepts data from the client and sends it back as is.

Note that you can edit a module and recompile it without leaving the Elixir shell. Let's output a message in the client when it connects to the server. Introduce the following change inside the definition of `connect`:

```elixir
def connect(address, port) do
  case :gen_tcp.connect(address, port, [ { :active, false } ]) do
    { :ok, sock } ->
      IO.puts "Did connect to server"     # <-- add this
      sock
    other -> other
  end
end
```

```
iex(2)> sock = Client.connect({127,0,0,1}, 8000)
#Port<0.2740>

# Edit the client code...

iex(3)> c("client.ex")
.../client.ex:1: redefining module Client
[Client]
iex(4)> sock = Client.connect({127,0,0,1}, 8000)
Did connect to server
#Port<0.2818>
iex(5)>
```

For the server, changing the code is a little more involved, because it's waiting in a loop. However, it is possible to reload the code for a running Elixir application. We'll take a look at how this can be implemented in a later article.
