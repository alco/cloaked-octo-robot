defmodule Handler do
  @moduledoc """
  A stateless handler that performs a simplistic transformation of its input.
  """

  @doc """
  This is a multi-clause function, it has a separate definition for each of the two cases we support.
  """
  def handle("bye" <> _rest) do
    { :close, "Good bye, my friend" }
  end

  # default case
  def handle(data) do
    { :reply, "Understood: #{data}" }
  end
end
