Echo server
===========

Let's start by implementing an echo server using TCP socket functionality provided by the Erlang's `gen_tcp` module.

We'll defined separate modules for the server and for the client. The server will be listening on a port and when a new client has connected, it will spawn a new process to handle the new connection.

This is a common way to handle multiple concurrent tasks in Elixir. You create a process that runs concurrently with all other processes. The processes can talk to each other by means of sending messages. By contrast to older languages, you don't have to manages the system resources yourself, the language does this for you.

## The Server Module ##

Our module has the following outline:

```elixir
# server.ex
defmodule Server do
  def start(port // 8000)
  def accept_loop(sock)
  def spawn_client(sock)
  def client_loop(sock)
end
```

There are four functions. Let's implement them one by one. Note that all definitions should be placed between `defmodule` and `end` keywords. We simply omit them to avoid repetition.

```elixir
def start(port // 8000) do
  case :gen_tcp.listen(port, [:binary, { :active, false }]) do
    { :ok, sock } ->
      IO.puts "Listening on port #{port}..."
      accept_loop(sock)
    other -> other
  end
end
```

This code defines a function of one argument. The default value for the argument is 8000. We to Erlang's gen_tcp.listen function to listen for incoming connections on the specified port. The function returns a new socket on which we will call gen_tcp.accept to start listening for incoming connections.

```elixir
def accept_loop(sock) do
  case :gen_tcp.accept(sock) do
    { :ok, client_sock } ->
      pid = spawn_client(client_sock)

    case :inet.peername(sock) do
      { :ok, { address, port } } ->
        IO.puts "Process #{inspect pid} Got connection from a client: #{inspect address}:#{inspect port}"
      other ->
        IO.puts "Process #{inspect pid} Got connection from an unknown client"
    end

      accept_loop(sock)
    other -> other
  end
end
```

The function is called `accept_loop` for a reason. You want see familiar C-like `for` loops in Elixir. Instead, it approaches iteration with a recursive approach. Using this kind of tail-recursive pattern is characteristic of nearly every Elixir program out there.

The definition for spawn_client is as follows:

```elixir
def spawn_client(sock) do
  spawn __MODULE__, :client_loop, [sock]
end
```

Here we merely redirecting the call to the built-in `spawn` function that spawns a new process and returns its identifier -- the pid.

```elixir
def client_loop(sock) do
  pid = Process.self

  case :gen_tcp.recv(sock, 0) do
    { :ok, packet } ->
      IO.puts "Process #{inspect pid} got packet #{packet}"
      :gen_tcp.send(sock, packet)
      client_loop(sock)
    { :error, reason } ->
      IO.puts "Process #{inspect pid} recv error #{reason}"
      :gen_tcp.close(sock)
  end
end
```

This is another loop that continuosly receives data from the client and sends it back to the client.

Now, you might be thinking that having two infinite loops should not work. But remember that we have spawned a new process and started executing `client_loop` in it. In Elixir all processes share execution time or run in parallel if hardware allows. So both of our loops are running simultaneously. With each new client we'll get another client_loop running in its own process. If you look at process explorer you'll see that the Elixir process (beam.smp) hardly uses any CPU at all. That's because both our loops are spending most of their time waiting for in IO operation. This is a very common scenario in real world production systems.

## The Client Module ##

Our client is very simple, so it can be demonstrated in a single code block:

```elixir
# client.ex
defmodule Client do
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [ { :active, false } ]) do
      { :ok, sock } ->
        sock
      other -> other
    end
  end

  def close(sock) do
    :gen_tcp.close(sock)
  end

  def send(sock, data) do
    :ok = :gen_tcp.send(sock, data)
    :gen_tcp.recv(sock, 0)
  end
end
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
