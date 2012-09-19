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

This is the core of the client process. It continuosly receives data from the socket and sends it back to the client.another loop that continuosly receives data from the client and sends it back to the client.

Remember that we have spawned a new process and started executing `client_loop` in it. In Erlang, all processes share execution time or run in parallel if hardware allows. With each new client we'll call another `client_loop` that will be running in its own process. Since most of the time the loops are spending waiting for an IO operation to complete, the whole server is very conservative with regards to the amount of system resources it requires. This is a very common scenario in real world production systems (node.js, for instance, is built around the concept of giving up control of the current execution frame while an IO operation is running).

This concludes our server implementation. It didn't take much code to build something useable and able to serve to hundreds or thousands of client easily. Let's do a quick test run to see how it works.

## Testing The Server ##

We'll be using netcat to establish a raw socket connection to the server running locally. If you don't have netcat, telnet will do.

```
$ iex server.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> Server.start
Listening on port 8000...
```

Our server is now listening for an incoming connection. Open another terminal window and launch netcat in it:

```
$ nc localhost 8000
hello
hello
?
?
123
123
^D
```

And on the server side we get the following output:

```
Listening on port 8000...
Process <0.39.0>: Got connection from a client: {127,0,0,1}:57124
Process <0.39.0>: Got packet hello

Process <0.39.0>: Got packet ?

Process <0.39.0>: Got packet 123

Process <0.39.0>: Error receiving a packet: closed
```

Our server is working as expected: for each message that we send to it, it sends back its exact copy. When the connection is closed by the client, our `client_loop` function returns and the process associated with that connection is terminated.

## Exercises ##

  *

  *

  *

## The Client Module ##

Let us also write a client in Elixir for the sake of covering both ends of `gen_tcp` functionality: listening and connecting.

```elixir
# client.ex
>>> client.ex: *
```

The code is self explanatory. We're using `connect` to establish connection with the server. Then we invoke the already familiar `send` and `receive` functions send and receive data over the socket.

Now we can write an automated test script to see how both server and client modules work in tandem.

```elixir
# server_client_test.exs
>>> server_client_test.exs: *
```

Sample output:

```
$ elixir server_client_test.exs
Listening on port 8000...
Process <0.37.0>: Got connection from a client: {127,0,0,1}:57375
Process <0.37.0>: Got packet Hello, server 5
Process <0.2.0>: Got reply from server: Hello, server 5
Process <0.37.0>: Got packet Hello, server 4
Process <0.2.0>: Got reply from server: Hello, server 4
Process <0.37.0>: Got packet Hello, server 3
Process <0.2.0>: Got reply from server: Hello, server 3
Process <0.37.0>: Got packet Hello, server 2
Process <0.2.0>: Got reply from server: Hello, server 2
Process <0.37.0>: Got packet Hello, server 1
Process <0.2.0>: Got reply from server: Hello, server 1
All done
```

## Interlude: Recompiling On The Go ##

If you're testing a module from the Elixir shell, you can edit a module and recompile it without leaving the shell. Let's try that out with the client. Start the server in one terminal window and open iex in another one:

```
$ iex client.ex
Interactive Elixir (0.6.0) - press Ctrl+C to exit
Erlang R15B01 (erts-5.9.1) [source] [64-bit] [smp:4:4] [async-threads:0] [hipe] [kernel-poll:false]

iex(1)> sock = Client.connect({127,0,0,1}, 8000)
#Port<0.2740>

#
# Now add the following line inside `connect` just before returning the socket.
#
#   IO.puts "Did connect to server"
#

iex(2)> c("client.ex")
.../client.ex:1: redefining module Client
[Client]
iex(3)> sock = Client.connect({127,0,0,1}, 8000)
Did connect to server
#Port<0.2818>
```

On the server side, changing the code is a little bit more involved, because it's hanging in a loop. However, it is possible to reload the code for a running Elixir application. We'll take a look at how this can be implemented in a later article.

## Further Reading ##

  * http://learnyousomeerlang.com/buckets-of-sockets
