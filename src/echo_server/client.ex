defmodule Client do
  @moduledoc """
  A simple TCP client.
  """

  @doc """
  Connect to the given address and return a socket suitable for sending data.

    address -- a 4-tuple with IP address components
    port    -- port number on the remote server

  """
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [{:active, false}]) do
      { :ok, sock } ->
        sock

      { :error, reason } ->
        IO.puts "Error establishing connection"
    end
  end

  @doc """
  Close connection.
  """
  def close(sock) do
    :gen_tcp.close(sock)
  end

  @doc """
  Send data to the server and wait for a reply.
  """
  def send(sock, data) do
    :ok = :gen_tcp.send(sock, data)
    :gen_tcp.recv(sock, 0)
  end
end
