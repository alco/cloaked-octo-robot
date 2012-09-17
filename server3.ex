defmodule Server do
  def start(options // nil) do
    port = (options && Keyword.get(options, :port)) || 0
    case :gen_tcp.listen(port, [{ :active, false }, { :packet, :http_bin }]) do
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
      state = HTTPRequest.new
    end

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{inspect packet}"
        if handler do
          case handler.(packet, state) do
            { :ok, new_state } ->
              client_loop(sock, handler, new_state)

            { :reply, status, data, new_state } ->
              response_header = format_status(status)
              :gen_tcp.send(sock, encode_http(response_header, data))

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

  defp format_status(:ok, resp // HTTPResponse.new) do
    resp = resp.status(200).status_str("OK")
    resp.update_headers(fn(x) -> Dict.put x, "Date", to_binary(:httpd_util.rfc1123_date()) end)
  end

  defp encode_http(resp, data) do
    headers = Enum.reduce resp.headers, "", fn({ name, value }, acc) ->
      acc <> "#{name}: #{inspect value}\n"
    end

    if data do
      headers = headers <> "Content-Length: #{size data}"
    end

"""
HTTP/1.0 #{resp.status} #{resp.status_str}
#{headers}

#{data}
"""
  end
end

defrecord HTTPRequest, method: :undefined, path: "/", headers: Orddict.new
defrecord HTTPResponse, status: 0, status_str: "", headers: Orddict.new, data: ""

defmodule Handler do
  def handle(data, state) do
    case data do
      { :http_request, method, path, http_ver } ->
        IO.puts "#{method} at path #{inspect path}"
        new_state = state.method(method).path(path)
        { :ok, new_state }

      { :http_header, _, header, _, value } ->
        IO.puts "Header #{header} with value #{value}"
        new_state = state.update_headers(Dict.put &1, atom_to_binary(header), value)
        { :ok, new_state }

      :http_eoh ->
        IO.puts "End of headers"
        IO.inspect state
        format_response(state)
  #{ :reply, "HTTP/1.0 200 OK", state }

      _ ->  # default case
        { :close, "HTTP/1.0 503 Internal Server Error" }
    end
  end

  def format_response(state) do
    { :reply, :ok, "", state }
  end
end

  #Server.start [port: 8000, handler: Handler.handle &1, &2]
