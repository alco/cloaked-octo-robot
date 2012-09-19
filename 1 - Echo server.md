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
  def start(port // 8000)
  def accept_loop(sock)
  def spawn_client(sock)
  def client_loop(sock)
end
```

There are four functions. Let's implement them one by one. Note that all definitions should be placed between `defmodule` and `end` keywords. We simply omit them to avoid repetition.

```elixir
>>> Server: def start
```

This code defines a function of one argument. The default value for the argument is 8000. We to Erlang's gen_tcp.listen function to listen for incoming connections on the specified port. The function returns a new socket on which we will call gen_tcp.accept to start listening for incoming connections.

```elixir
>>> Server: def accept_loop
```

The function is called `accept_loop` for a reason. You want see familiar C-like `for` loops in Elixir. Instead, it approaches iteration with a recursive approach. Using this kind of tail-recursive pattern is characteristic of nearly every Elixir program out there.

The definition for spawn_client is as follows:

```elixir
>>> Server: def spawn_client
```

Here we merely redirecting the call to the built-in `spawn` function that spawns a new process and returns its identifier -- the pid.

```elixir
>>> Server: def client_loop
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
