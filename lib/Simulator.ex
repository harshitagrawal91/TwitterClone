defmodule Simulator do
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
    TwitterEngine.start_link()
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

    handle_discnneted_usrs(users_count, disconnected_clients)
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
        arg_avg_time_to_tweet,
        arg_query_tweet_subs_to,
        arg_query_tweets_by_hashtag,
        arg_query_tweets_by_mention,
        arg_query_all_relevant_tweets
      } ->
        converging(
          users_val - 1,
          users_count,
          avg_time_to_tweet + arg_avg_time_to_tweet,
          query_tweet_subs_to + arg_query_tweet_subs_to,
          query_tweets_by_hashtag + arg_query_tweets_by_hashtag,
          query_tweets_by_mention + arg_query_tweets_by_mention,
          query_all_relevant_tweets + arg_query_all_relevant_tweets
        )
    end
  end

  def register_users(count, user_count, tweets) do
    userName = Integer.to_string(count)
    subscrbr_count = tweets * count
    subscrptn_number = ((subscrbr_count / (user_count - count + 1))
                        |> Float.floor
                        |> round) - 1
    pid = spawn(fn -> Client.start_link(userName, tweets, subscrptn_number, false) end)
    :ets.insert(:start_up_reg, {userName, pid})
    if (count != user_count) do
      register_users(
        count + 1,
        user_count,
        tweets
      )
    end
  end

  def query_to_storage(user_id) do
    [row] = :ets.lookup(:start_up_reg, user_id)
    elem(row, 1)
  end

  def handle_discnneted_usrs(
        users_count,
        disconnected_clients
      ) do
    Process.sleep(1000)
    discnneted_lst = process_discnnection(users_count, disconnected_clients, 0, [])
    Process.sleep(1000)
    Enum.each discnneted_lst,
              fn userName ->
                pid = spawn(
                  fn -> Client.start_link(userName, -1, -1, true)
                  end
                )
                :ets.insert(:start_up_reg, {userName, pid})
              end
    handle_discnneted_usrs(users_count, disconnected_clients)
  end

  def process_discnnection(
        users_count,
        disconnected_clients,
        users_discnected,
        discnected_set
      ) do
    if users_discnected < disconnected_clients do
      disconnctd_usr = :rand.uniform(users_count)
      disconnctd_usr_id = disconnctd_usr
                          |> Integer.to_string
                          |> query_to_storage
      if disconnctd_usr_id != nil do
        usr_id = disconnctd_usr
                 |> Integer.to_string
        discnected_set = [usr_id | discnected_set]
        GenServer.cast(:global.whereis_name(:TwitterServer), {:disconnectUser, usr_id})
        :ets.insert(:start_up_reg, {usr_id, nil})
        Process.exit(disconnctd_usr_id, :kill)
        IO.puts "Process disconnection :- Client #{usr_id} lost connection"
        process_discnnection(
          users_count,
          disconnected_clients,
          users_discnected + 1,
          discnected_set
        )
      else
        process_discnnection(users_count, disconnected_clients, users_discnected, discnected_set)
      end
    else
      discnected_set
    end
  end
end
