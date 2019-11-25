defmodule Project4Test do
  ExUnit.start(capture_log: true)
  use ExUnit.Case

  doctest TwitterClone.Main

  test "greets the world" do
    assert 1 + 1 == 2
  end

  test "Register User" do
    :ets.new(:start_up_reg, [:set, :public, :named_table])
    {userName, pid} = TwitterClone.Main.register_users(1, 10, 10)
    [row] = :ets.lookup(:start_up_reg, userName)
    {user_id, _} = row
    assert userName == user_id
  end
end
