defmodule TwitterClone.Main do
  def main(args) do
    params = parse_args(args)
    if(params == "start_server") do
      start_server([])
    else
      start_server(params)
    end
  end

  defp parse_args(args) do
    {_, parameters, _} = OptionParser.parse(args)

    parameters
  end

  def start_server([]) do
    TwitterClone.Server.start_link()
    receive do: (_ -> :ok)
  end

  def start_server(params) do
    {users_count, tweets, disconnect_clients_count} = parse_params(params)
    disconnected_clients = disconnect_clients_count * (0.01) * users_count
    :ets.new(:start_up_reg, [:set, :public, :named_table])

    converging_pid = fn ->
      converging(users_count, users_count, 0, 0, 0, 0, 0)
    end
    async_pid = converging_pid
                |> Task.async

    :global.register_name(:start_up_process, async_pid.pid)
    start_time = System.system_time(:millisecond)
    register_users(1, users_count, tweets)

    Task.await(async_pid, :infinity)
    IO.puts "Initial Task Completion Time in total: #{
      System.system_time(:millisecond) - start_time
    } milliseconds"

    simulate_disconnection(users_count, disconnected_clients)
    receive do: (_ -> :ok)
  end

  def parse_params(params) do
    users_count = params
                  |> Enum.at(0)
                  |> String.to_integer
    tweets = params
             |> Enum.at(1)
             |> String.to_integer
    disconnect_clients_count = params
                               |> Enum.at(2)
                               |> String.to_integer
    {users_count, tweets, disconnect_clients_count}
  end

  def converging(
        0,
        users_count,
        avg_time_to_tweet,
        query_tweet_subs_to,
        query_tweets_by_hashtag,
        query_tweets_by_mention,
        query_all_relevant_tweets
      ) do
    IO.puts "Average avg_time_to_tweet: #{avg_time_to_tweet / users_count} milliseconds"
    IO.puts "Average query_tweet_subs_to: #{query_tweet_subs_to / users_count} milliseconds"
    IO.puts "Average query_tweets_by_hashtag: #{query_tweets_by_hashtag / users_count} milliseconds"
    IO.puts "Average query_tweets_by_mention: #{query_tweets_by_mention / users_count} milliseconds"
    IO.puts "Average query_all_relevant_tweets: #{query_all_relevant_tweets / users_count} milliseconds"
  end

  def converging(
        users_val,
        users_count,
        avg_time_to_tweet,
        query_tweet_subs_to,
        query_tweets_by_hashtag,
        query_tweets_by_mention,
        query_all_relevant_tweets
      ) do
    # Receive convergence messages
    receive do
      {
        :performance_metric,
        _avg_time_to_tweet,
        _query_tweet_subs_to,
        _query_tweets_by_hashtag,
        _query_tweets_by_mention,
        _query_all_relevant_tweets
      } ->
        converging(
          users_val - 1,
          users_count,
          avg_time_to_tweet + _avg_time_to_tweet,
          query_tweet_subs_to + _query_tweet_subs_to,
          query_tweets_by_hashtag + _query_tweets_by_hashtag,
          query_tweets_by_mention + _query_tweets_by_mention,
          query_all_relevant_tweets + _query_all_relevant_tweets
        )
    end
  end

  def register_users(count, noOfClients, tweets) do
    userName = Integer.to_string(count)
    #    noOfTweets = round(Float.floor(totalSubscribers / count))
    totalSubscribers = tweets * count
    IO.inspect(tweets)
    IO.inspect(tweets)
    IO.inspect(count)
    noToSubscribe = round(Float.floor(totalSubscribers / (noOfClients - count + 1))) - 1
    pid = spawn(fn -> TwitterClone.Client.start_link(userName, tweets, noToSubscribe, false) end)
    :ets.insert(:start_up_reg, {userName, pid})
    if (count != noOfClients) do
      register_users(count + 1, noOfClients, tweets) end
  end

  def whereis(userId) do
    [tup] = :ets.lookup(:start_up_reg, userId)
    elem(tup, 1)
  end

  def simulate_disconnection(users_count, disconnected_clients) do
    Process.sleep(1000)
    disconnectList = handle_disconnection(users_count, disconnected_clients, 0, [])
    Process.sleep(1000)
    Enum.each disconnectList, fn userName ->
      pid = spawn(fn -> TwitterClone.Client.start_link(userName, -1, -1, true) end)
      :ets.insert(:start_up_reg, {userName, pid})
    end
    simulate_disconnection(users_count, disconnected_clients)
  end

  def handle_disconnection(users_count, disconnected_clients, clientsDisconnected, disconnectList) do
    if clientsDisconnected < disconnected_clients do
      disconnectClient = :rand.uniform(users_count)
      disconnectClientId = whereis(Integer.to_string(disconnectClient))
      if disconnectClientId != nil do
        userId = Integer.to_string(disconnectClient)
        disconnectList = [userId | disconnectList]
        # send(:global.whereis_name(:TwitterServer),{:disconnectUser,userId})
        GenServer.cast(:global.whereis_name(:TwitterServer), {:disconnectUser, userId})
        :ets.insert(:start_up_reg, {userId, nil})
        Process.exit(disconnectClientId, :kill)
        IO.puts "Simulator :- User #{userId} has been disconnected"
        handle_disconnection(users_count, disconnected_clients, clientsDisconnected + 1, disconnectList)
      else
        handle_disconnection(users_count, disconnected_clients, clientsDisconnected, disconnectList)
      end
    else
      disconnectList
    end
  end

  def randomizer(l) do
    :crypto.strong_rand_bytes(l)
    |> Base.url_encode64
    |> binary_part(0, l)
    |> String.downcase
  end
end
