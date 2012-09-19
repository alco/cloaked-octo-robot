defmodule Server do
  def start(options // nil) do
    port = (options && Keyword.get(options, :port)) || 0
    case :gen_tcp.listen(port, [:binary, { :active, false }]) do
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
        :gen_tcp.close(sock)
      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
        :gen_tcp.close(sock)
    end
  end
end

defmodule Handler do
  def handle("buy " <> data, state) do
    article = "a"
    count = Dict.get(state, data)
    if count != nil do
      article = "another"
    end
    { :reply, "You've got #{article} #{data}", Dict.update(state, data, 1, &1 + 1)  }
  end

  def handle("sell " <> data, state) do
    count = Dict.get(state, data, 0)
    if count > 0  do
      { :reply, "You have sold the #{data}", Dict.update(state, data, &1 - 1) }
    else
      { :reply, "You don't have a #{data}", state }
    end
  end

  def handle(data, _) do
    { :close, "Don't know what to do with #{data}" }
  end
end
