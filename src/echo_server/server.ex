defmodule Server do
  @moduledoc """
  This is a basic echo server to demonstrate the usage of Erlang's gen_tcp
  module.

  It exports one public function start/1 that has an optional `port` argument.
  """

  @doc """
  Function for starting the server. Part of the public API.
  """
  # When invoked without arguments, `port` will have the value of 8000
  def start(port // 8000) do
    # :binary is used to get the packets as strings instead of charlists
    #
    # { :active, false } creates a passive socket, i.e. we'll need to call
    # :gen_tcp.recv to get incoming packets
    # See http://www.erlang.org/doc/man/inet.html#setopts-2 for more details.
    case :gen_tcp.listen(port, [:binary, {:active, false}]) do
      { :ok, sock } ->
        IO.puts "Listening on port #{port}..."
        accept_loop(sock)

      { :error, reason } ->
        IO.puts "Error starting the server: #{reason}"
    end
  end

  """
  This is a private function responsible for spawning new processes to handle
  incoming connections.
  """
  defp accept_loop(sock) do
    case :gen_tcp.accept(sock) do
      { :ok, client_sock } ->
        # Spawn a new process and make a recursive tail-call to continue
        # accepting new connections.
        spawn_client(client_sock)
        accept_loop(sock)

      { :error, reason } ->
        IO.puts "Failed to accept on socket: #{reason}"
    end
  end

  """
  Spawn a new process to handle communication over the socket
  """
  defp spawn_client(sock) do
    spawn __MODULE__, :client_start, [sock]
  end

  @doc false
  """
  This function needs to be public in order for `spawn` to be able to invoke it
  indirectly. By setting @doc to false, we exclude generating the docs for this
  function indicating that it's not a part of the public API.
  """
  def client_start(sock) do
    pid = Process.self

    # Get info about the client
    case :inet.peername(sock) do
      { :ok, { address, port } } ->
        IO.puts "Process #{inspect pid}: Got connection from a client: #{inspect address}:#{inspect port}"

      { :error, reason } ->
        IO.puts "Process #{inspect pid}: Got connection from an unknown client (#{reason})"
    end

    # Start the recieve loop
    client_loop(sock)
  end

  """
  The receive loop which waits for a packet from the client and sends it back,
  effectively turning it into an echo server.
  """
  defp client_loop(sock) do
    pid = Process.self

    # :gen_tcp.recv will block until some amount of data becomes available.
    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid}: Got packet #{packet}"
        :gen_tcp.send(sock, packet)
        client_loop(sock)

      { :error, reason } ->
        IO.puts "Process #{inspect pid}: Error receiving a packet: #{reason}"
        :gen_tcp.close(sock)
    end
  end
end
