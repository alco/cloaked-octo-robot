defmodule Client do
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [ { :active, false } ]) do
      { :ok, sock } ->
        IO.puts "Did connect to server"
        sock
      other -> other
    end
  end

  def close(sock) do
    :gen_tcp.close(sock)
  end

  def send(sock, data) do
    :ok = :gen_tcp.send(sock, data)
    :gen_tcp.recv(sock, 0)
  end
end
