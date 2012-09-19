defmodule ClientTest do
  @doc """
  Send a message every second until n > 0
  """
  def send_loop(sock, n) do
    if n > 0 do
      receive do
      after
        1000 ->
          { :ok, reply } = Client.send(sock, "Hello, server")
          IO.puts "Got reply from server: #{reply}"
      end
      send_loop(sock, n - 1)
    else
      nil
    end
  end
end

# Start the server in a separate process
spawn Server, :start, []

# Establish connection with the server
sock = Client.connect({127,0,0,1}, 8000)

# Start sending packets
ClientTest.send_loop(sock, 10)
