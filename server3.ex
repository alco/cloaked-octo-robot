defmodule Server do
  def start(options // nil) do
    port = (options && Keyword.get(options, :port)) || 0
    case :gen_tcp.listen(port, [{ :active, false }, { :packet, :http }]) do
      { :ok, sock } ->
        IO.puts "Listening on port #{port}..."
        accept_loop(sock, options)
      other -> other
    end
  end

  def accept_loop(sock, options) do
    case :gen_tcp.accept(sock) do
      { :ok, client_sock } ->
        pid = spawn_client(client_sock, options)

        case :inet.peername(sock) do
          { :ok, { address, port } } ->
            IO.puts "Process #{inspect pid} Got connection from a client: #{inspect address}:#{inspect port}"
          other ->
            IO.puts "Process #{inspect pid} Got connection from an unknown client"
        end

        accept_loop(sock, options)
      other -> other
    end
  end

  def spawn_client(sock, options) do
    handler = if options === nil do
      nil
    else
      Keyword.get(options, :handler)
    end
    spawn __MODULE__, :client_loop, [sock, handler]
  end

  @doc false
  def client_loop(sock, handler, state // nil) do
    pid = Process.self
    if state === nil do
      state = Orddict.new
    end

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{inspect packet}"
        if handler do
          case handler.(packet, state) do
            { :ok, new_state } ->
              client_loop(sock, handler, new_state)

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
        :gen_tcp.close(sock)
      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
        :gen_tcp.close(sock)
    end
  end
end

defmodule Handler do
  def handle(data, state) do
    case data do
      { :http_request, method, path, http_ver } ->
        IO.puts "#{method} at path #{inspect path}"
        { :ok, state }

      { :http_header, _, header, _, value } ->
        IO.puts "Header #{header} with value #{value}"
        { :ok, state }

      :http_eoh ->
        IO.puts "End of headers"
        { :reply, "HTTP/1.0 200 OK", state }

      _ ->  # default case
        { :close, "HTTP/1.0 503 Internal Server Error" }
    end
  end
end

  #Server.start [port: 8000, handler: Handler.handle &1, &2]
