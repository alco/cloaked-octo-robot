defmodule Handler do
  @moduledoc """
  A stateful handler that keeps track of the number of items owned by the
  client.
  """

  @doc """
  `handle` is a multi-clause function, it has a separate definition for each of
  the verbs we support and an extra clause for the default case.
  """
  def handle("buy " <> data, state) do
    count = Dict.get(state, data)
    article =
      if count && count > 0 do
        "another"
      else
        "a"
      end

    # Increment the counter for `data`
    { :reply, "You've got #{article} #{data}", Dict.update(state, data, 1, &1 + 1)  }
  end

  """
  The second `handle` clause that decrements the specified counter.
  """
  def handle("sell " <> data, state) do
    count = Dict.get(state, data, 0)
    if count > 0  do
      { :reply, "You have sold the #{data}", Dict.update(state, data, &1 - 1) }
    else
      { :reply, "You don't have a #{data}", state }
    end
  end

  """
  Default case
  """
  def handle(data, _) do
    { :close, "Don't know what to do with #{data}" }
  end
end
