defmodule Project4Test do
  ExUnit.start(capture_log: true)
  use ExUnit.Case

  # doctest TwitterClone.Main
  setup_all do
    TwitterClone.Server.init_ets()
    :ok
  end
  test "greets the world" do
    assert 1 + 1 == 2
  end
  test "Register User" do
    user_id=5
    user_id2=7
    IO.puts("Testing User registaration")
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id2, self()},10)
    [tup] = :ets.lookup(:clientsregistry, user_id)
            assert(user_id == elem(tup, 0))
    [tup] = :ets.lookup(:clientsregistry, user_id2)
    assert(user_id2 == elem(tup, 0))
  end
  test "Disconnect User" do
    IO.puts("Testing User Disconnection")
    user_id=10
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:disconnectUser, user_id},10)
    [tup] = :ets.lookup(:clientsregistry, user_id)
            assert(nil == elem(tup, 1))
  end
  test "Delete User" do
    IO.puts("Testing User Deletion")
    user_id=11
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:deleteUser, user_id},10)
    assert(:ets.lookup(:clientsregistry, user_id)==[])

  end
  test "Login User" do
    IO.puts("Testing User Login")
    user_id=12
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:loginUser, user_id,self()},10)
    [tup] = :ets.lookup(:clientsregistry, user_id)
            assert(self() == elem(tup, 1))

  end
  test "addSubscriber User" do
    IO.puts("Testing User Subscription")
    user_id=15
    user_id2=17
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id2, self()},10)

     TwitterClone.Server.handle_cast({:addSubscriber, user_id, Integer.to_string(user_id2)},10)
    [tup] = :ets.lookup(:subscribedto, user_id)
    assert(["17"] == elem(tup, 1))
    [tup] = :ets.lookup(:followers,  Integer.to_string(user_id2))
    # IO.inspect(elem(tup, 1))
    assert([15] == elem(tup, 1))
  end
  test "tweet" do
    user_id=18
    user_id2=19
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id2, self()},10)

     TwitterClone.Server.handle_cast({:addSubscriber, user_id, Integer.to_string(user_id2)},10)
    IO.puts("Testing User Tweet")
    TwitterClone.Server.handle_cast({:tweet, "Client#{user_id} tweets that #check is absurd", user_id},10)
    [tup] = :ets.lookup(:tweets, user_id)
    IO.puts("Testing get my tweet")
    assert(["Client18 tweets that #check is absurd"] == elem(tup, 1))
    IO.puts("Testing hashtags")
    [tup] = :ets.lookup(:hashtags_mentions, "#check")
    assert(["Client18 tweets that #check is absurd"] == elem(tup, 1))
  end

  test "tweet with mentions" do
    user_id=20
    user_id2=21
    IO.puts("Testing User Tweet mentions")
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id, self()},10)
    {noreply,state} =  TwitterClone.Server.handle_cast({:register_account, user_id2, self()},10)

     TwitterClone.Server.handle_cast({:addSubscriber, user_id, Integer.to_string(user_id2)},10)

    TwitterClone.Server.handle_cast({:tweet, "Client#{user_id} tweets that @#{user_id2} is doing homework", user_id},10)

    [tup]=:ets.lookup(:hashtags_mentions, "@21")
    assert(["Client20 tweets that @21 is doing homework"] == elem(tup, 1))

  end

end
