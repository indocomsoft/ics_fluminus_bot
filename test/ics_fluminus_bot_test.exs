defmodule IcsFluminusBotTest do
  use ExUnit.Case
  doctest IcsFluminusBot

  test "greets the world" do
    assert IcsFluminusBot.hello() == :world
  end
end
