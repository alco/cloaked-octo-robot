defmodule Server do
  def start() do
    case :gen_tcp.listen(8000, [:binary, { :packet, :raw }, { :active, false }]) do
      { :ok, sock } ->
        accept_loop(sock)
      other -> other
    end
  end

  def accept_loop(sock) do
    case :gen_tcp.accept(sock) do
      { :ok, client_sock } ->
        spawn_client(client_sock)
        accept_loop(sock)
      other -> other
    end
  end

  def spawn_client(sock) do
    spawn __MODULE__, :client_loop, [sock]
  end

  def client_loop(sock) do
    case :gen_tcp.recv(sock, 0) do
      { :ok, packet } ->
        IO.puts "Got packet #{packet}"
        client_loop(sock)
      { :error, reason } ->
        IO.puts "Recv error #{reason}"
        :gen_tcp.close(sock)
    end
  end
end
