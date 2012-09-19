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
    handlers = if options === nil do
      nil
    else
      Keyword.get(options, :handlers)
    end
    spawn __MODULE__, :client_loop, [sock, handlers]
  end

  @doc false
  def client_loop(sock, handlers, state // nil) do
    pid = Process.self
    if state === nil do
      state = [request: HTTPRequest.new, handler: nil]
    end

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{inspect packet}"
        #        handler = case packet do
        #          { :http_request, method, pathspec, http_ver } ->
        #            IO.puts "#{method} at path #{inspect pathspec}"
        #            choose_handler(handlers, method, elem(pathspec, 2))
        #          _ ->
        #            Keyword.get state, :handler
        #        end
        [{_, handler}|_] = handlers

        IO.puts "Chosen handler = #{inspect handler}"
        IO.puts "packet = #{inspect packet}"
        IO.puts "state = #{inspect state}"

        if handler do
          req = Keyword.get(state, :request)
          case handler.(packet, req) do
            { :ok, new_state } ->
              client_loop(sock, handlers, [handler: handler, request: new_state])

            { :reply, status, data, new_state } ->
              response_header = format_status(status)
              :gen_tcp.send(sock, encode_http(response_header, data))

            { :close, reply } ->
              :gen_tcp.send(sock, reply)
          end
        end
        :gen_tcp.close(sock)
      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
        :gen_tcp.close(sock)
    end
  end

  def choose_handler(handlers, _method, path) do
    IO.puts "Handlers: #{inspect handlers}"
    IO.puts "Path: #{path}"
    handler = Enum.find handlers, fn(x) ->
      elem(x, 1) == path
    end
    if handler do
      elem(handler, 2)
    else
      nil
    end
  end

  defp format_status(status, resp // HTTPResponse.new)

  defp format_status(:ok, resp) do
    resp = resp.status(200).status_str("OK")
    resp.update_headers(fn(x) -> Dict.put x, "Date", to_binary(:httpd_util.rfc1123_date()) end)
  end

  defp format_status(:not_found, resp) do
    resp = resp.status(404).status_str("Not Found")
    resp.update_headers(fn(x) -> Dict.put x, "Date", to_binary(:httpd_util.rfc1123_date()) end)
  end

  defp format_status(:fail, resp) do
    resp = resp.status(501).status_str("Not Implemented")
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

      { :http_error, reason } ->
        IO.puts "DECODE ERROR: #{reason}"
        { :close, "400 Bad Request" }

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
    { :reply, :ok, "Dynamic OK", state }
  end
end

defmodule StaticHandler do
  def handle(data, state) do
    IO.puts "#!@#$ Invoking StaticHandler.handle/2"

    case data do
      { :http_request, method, path, http_ver } ->
        #IO.puts "#{method} at path #{inspect path}"
        new_state = state.method(method).path(path)
        { :ok, new_state }

      { :http_header, _, header, _, value } ->
        #IO.puts "Header #{header} with value #{value}"
        new_state = state.update_headers(Dict.put &1, atom_to_binary(header), value)
        { :ok, new_state }

      { :http_error, reason } ->
        IO.puts "DECODE ERROR: #{reason}"
        { :close, "400 Bad Request" }

      :http_eoh ->
        #IO.puts "End of headers"
        #IO.inspect state

        handle_request(state.method, state.path, state.headers, state)
  #{ :reply, "HTTP/1.0 200 OK", state }

      _ ->  # default case
        { :close, "HTTP/1.0 503 Internal Server Error" }
    end
  end

  def format_response(state) do
    { :reply, :ok, "Static OK", state }
  end

  def handle_request(:HEAD, path, _, state) do
    IO.puts "HEAD at #{inspect path}"
    stat = get_local_file_stat(path)
    if stat === nil do
      { :reply, :not_found, "", state }
    else
      content_length = stat.size
      { :reply, :ok, content_length, state }
    end
  end

  def handle_request(:GET, path, _, state) do
    IO.puts "GET at #{inspect path}"
    file_data = get_local_file(resolve_path_to_local(path))
    if file_data === nil do
      { :reply, :not_found, "", state }
    else
      { file_size, content } = file_data
      { :reply, :ok, content, state }
    end
  end

  def handle_request(:POST, path, _, state) do
    IO.puts "POST at #{inspect path}"
    { :reply, :ok, "Static POST OK", state }
  end

  def handle_request(method, path, headers, state) do
    IO.puts "->>> Unimplemented method #{method} for path #{inspect path} with headers #{inspect headers}"
    { :reply, :fail, "FAIL", state }
  end

  defp resolve_path_to_local(pathspec) do
    #    '*' |
    #    {absoluteURI, http|https, Host=HttpString, Port=integer()|undefined, Path=HttpString} |
    #    {scheme, Scheme=HttpString, HttpString} |
    #    {abs_path, HttpString} | HttpString
    case pathspec do
      :* ->
        nil
      { :absoluteURI, _scheme, _host, _port, _path } ->
        IO.puts "Got absoluteURI #{inspect pathspec}"
        nil
      { :scheme, _scheme, _string } ->
        IO.puts "Got scheme #{inspect pathspec}"
        nil
      { :abs_path, string } ->
        string
    end
  end

  defp get_local_file_stat(path) do
    if path === nil do
      nil
    else
      if :filename.pathtype(path) == :absolute do
        "/" <> path = path
      end
      path = :filename.join("static", path)
      cond do
        not File.regular?(path) ->
          nil
        true ->
          File.stat(path)
      end
    end
  end

  defp get_local_file(path) do
    if path === nil do
      nil
    else
      if :filename.pathtype(path) == :absolute do
        "/" <> path = path
      end
      path = :filename.join("static", path)
      cond do
        not File.regular?(path) ->
          nil
        true ->
          { :ok, data } = File.read(path)
          { size(data), data }
      end
    end
  end
end
