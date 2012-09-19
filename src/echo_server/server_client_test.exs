defmodule ClientTest do
  @doc """
  Send a message every second while n > 0
  """
  def send_loop(sock, n) do
    if n > 0 do
      receive do
      after
        1000 ->
          { :ok, reply } = Client.send(sock, "Hello, server #{n}")
          IO.puts "Process #{inspect Process.self}: Got reply from server: #{reply}"
      end
      send_loop(sock, n - 1)
    else
      nil
    end
  end
end

# Start the server in a separate process
spawn Server, :start, []

# Wait for the server process to start
receive do
after
  1000 -> :ok
end

# Establish connection with the server
sock = Client.connect({127,0,0,1}, 8000)

# Start sending packets
ClientTest.send_loop(sock, 5)

IO.puts "All done"
