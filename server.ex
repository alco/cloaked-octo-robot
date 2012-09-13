defmodule Server do
  def start(port // 8000) do
    case :gen_tcp.listen(port, [:binary, { :active, false }]) do
      { :ok, sock } ->
        IO.puts "Listening on port #{port}..."
        accept_loop(sock)
      other -> other
    end
  end

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

  def spawn_client(sock) do
    spawn __MODULE__, :client_loop, [sock]
  end

  def client_loop(sock) do
    pid = Process.self

    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Process #{inspect pid} got packet #{packet}"
        :gen_tcp.send(sock, packet)
        client_loop(sock)
      { :error, reason } ->
        IO.puts "Process #{inspect pid} did recieve error #{reason}"
        :gen_tcp.close(sock)
    end
  end
end
