defmodule Server do
  @moduledoc """
  A more advanced server that allows users to set up their own handlers to
  process data coming from the clients.
  """

  @doc """
  Function for starting the server. List of available options:

    * port    -- number of the port to listen on
    * handler -- a function of one argument

  """
  def start(options // nil) do
    port = (options && Keyword.get(options, :port)) || 8000
    case :gen_tcp.listen(port, [:binary, {:active, false}]) do
      { :ok, sock } ->
        IO.puts "Listening on port #{port}..."
        accept_loop(sock, options)

      { :error, reason } ->
        IO.puts "Error starting the server: #{reason}"
    end
  end

  """
  A private function responsible for spawning new processes to handle incoming
  connections.
  """
  defp accept_loop(sock, options) do
    case :gen_tcp.accept(sock) do
      { :ok, client_sock } ->
        # Spawn a new process and make a recursive tail-call to continue
        # accepting new connections.
        spawn_client(client_sock, options)
        accept_loop(sock, options)

      { :error, reason } ->
        IO.puts "Failed to accept on socket: #{reason}"
    end
  end

  """
  Spawn a new process to handle communication over the socket
  """
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

  @doc false
  """
  This function needs to be public in order for `spawn` to be able to invoke it
  indirectly. By setting @doc to false, we exclude generating the docs for this
  function indicating that it's not a part of the public API.
  """
  def client_start(sock, handler) do
    pid = Process.self

    # Get info about the client
    case :inet.peername(sock) do
      { :ok, { address, port } } ->
        IO.puts "Process #{inspect pid}: Got connection from a client: #{inspect address}:#{inspect port}"

      { :error, reason } ->
        IO.puts "Process #{inspect pid}: Got connection from an unknown client (#{reason})"
    end

    # Start the recieve loop
    client_loop(sock, handler)
  end

  """
  The receive loop which waits for a packet from the client, then invokes the
  handler function and sends its return value back to the client.
  """
  def client_loop(sock, handler, state // Orddict.new) do
    pid = Process.self

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{packet}"
        if handler do
          case handler.(packet, state) do
            { :reply, data, new_state } ->
              :gen_tcp.send(sock, data)
              client_loop(sock, handler, new_state)

            { :close, reply } ->
              :gen_tcp.send(sock, reply)
          end
        else
          # Work like an echo server by default
          :gen_tcp.send(sock, packet)
          client_loop(sock, handler, state)
        end

      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
    end

    # If no recursive call has been done, then we end our affair with the client.
    :gen_tcp.close(sock)
  end
end
