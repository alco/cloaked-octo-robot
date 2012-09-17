defmodule Web do
  def start() do
    #Server.start [port: 8000, handler: Handler.handle &1, &2]
    Server.start [port: 8000, handlers: [
      { "/", StaticHandler.handle &1, &2 },
      { "/dyn", Handler.handle &1, &2 }
    ]]
  end
end
