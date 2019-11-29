defmodule TwitterClone.Client do
  use GenServer
  require Logger

  def start_link(user_id, tweets_count, no_to_subscribe, existing_User) do
    GenServer.start_link(__MODULE__, [user_id, tweets_count, no_to_subscribe, existing_User])
  end

  def make_distributed([head | tail], l) do
    unless Node.alive?() do
      try do
        {ip_tuple, _, _} = head
        current_ip = to_string(:inet_parse.ntoa(ip_tuple))
        if current_ip === "127.0.0.1" do
          if l > 1 do
            make_distributed(tail, l - 1)
          else
            IO.puts "Attempt to make current node distributed is unsuccessful."
          end
        else
          server_node_name = String.to_atom("client@" <> current_ip)
          Node.start(server_node_name)
          Node.set_cookie(server_node_name, :monster)
          Node.connect(String.to_atom("server@" <> current_ip))
        end
      rescue
        _ -> if l > 1, do:
          make_distributed(tail, l - 1),
                       else: IO.puts "Attempt to make current node distributed is unsuccessful."
      end
    end
  end

  # def init([userId, noOfTweets, noToSubscribe, existingUser]) do
  def init([user_id, tweets_count, no_to_subscribe, existing_User]) do

    {:ok, iflist} = :inet.getif()
    make_distributed(Enum.reverse(iflist), length(iflist))
    :global.sync()

    if existing_User do
      IO.puts "Client #{user_id} connects again!!"
      login_handler(user_id)
    end

    GenServer.cast(:global.whereis_name(:TwitterServer), {:register_account, user_id, self()})
    IO.puts "Registration of Client #{user_id} completed"
    client_handler(user_id, tweets_count, no_to_subscribe)
    receive do: (_ -> :ok)
  end

  def login_handler(user_id) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:loginUser, user_id, self()})
    for _ <- 1..5 do
      GenServer.cast(
        :global.whereis_name(:TwitterServer),
        {:tweet, "Client#{user_id} tweets that #{randomizer(8)} is absurd", user_id}
      )
    end
    handle_live_view(user_id)
  end

  def client_handler(user_id, tweets_count, no_to_subscribe) do
    # Subscribe
    if no_to_subscribe > 0 do
      subList = generate_subList(1, no_to_subscribe, [])
      handle_zipf_subscribe(user_id, subList)
    end

    start_time = System.system_time(:millisecond)
    user_to_mention = user_id
                      |> String.to_integer
                      |> :rand.uniform

    :global.whereis_name(:TwitterServer)
    |> GenServer.cast(
         {:tweet, "Client#{user_id} tweets about @#{user_to_mention}", user_id}
       )

    :global.whereis_name(:TwitterServer)
    |> GenServer.cast(
         {:tweet, "Client#{user_id} tweets that UF CISE awesome", user_id}
       )

    #Send Tweets
    for _ <- 1..tweets_count do
      :global.whereis_name(:TwitterServer)
      |> GenServer.cast(
           {:tweet, "Client#{user_id} tweets that #{randomizer(8)} is absurd", user_id}
         )
    end

    #ReTweet
    user_id
    |> handle_re_tweet
    time_diff_tweet = System.system_time(:millisecond) - start_time

    #Queries
    start_time = System.system_time(:millisecond)
    handle_queries_subscribed_to(user_id)
    time_diff_queries_subscribed_to = System.system_time(:millisecond) - start_time

    start_time = System.system_time(:millisecond)
    handle_queries_hashtag("#COP5615 is one of the best subject", user_id)
    time_diff_queries_hash_tag = System.system_time(:millisecond) - start_time

    start_time = System.system_time(:millisecond)
    handle_queries_mention(user_id)
    time_diff_queries_mention = System.system_time(:millisecond) - start_time

    start_time = System.system_time(:millisecond)
    #Get All Tweets
    user_id
    |> handle_get_my_tweets
    time_diff_queries_my_tweets = System.system_time(:millisecond) - start_time

    time_diff_tweet = time_diff_tweet / (tweets_count + 3)
    send(
      :global.whereis_name(:start_up_process),
      {
        :performance_metric,
        time_diff_tweet,
        time_diff_queries_subscribed_to,
        time_diff_queries_hash_tag,
        time_diff_queries_mention,
        time_diff_queries_my_tweets
      }
    )

    #Live View
    user_id
    |> handle_live_view
  end

  def generate_subList(count, no_of_Subs, list) do
    if(count == no_of_Subs) do
      [count | list]
    else
      generate_subList(count + 1, no_of_Subs, [count | list])
    end
  end

  def handle_zipf_subscribe(user_id, subscribe_to_list) do
    Enum.each subscribe_to_list, fn account_id ->
      :global.whereis_name(:TwitterServer)
      |> GenServer.cast({:addSubscriber, user_id, Integer.to_string(account_id)})
    end
  end

  def handle_re_tweet(user_id) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsSubscribedTo, user_id})
    list = receive do
      {:repTweetsSubscribedTo, list} -> list
    end
    if list != [] do
      rt = hd(list)
      :global.whereis_name(:TwitterServer)
      |> GenServer.cast({:tweet, rt <> " -Right", user_id})
    end
  end

  def handle_live_view(user_id) do
    receive do
      {:live, tweet_string} ->
        IO.inspect tweet_string, label: "Client #{user_id} :- Streaming --------"
    end
    user_id
    |> handle_live_view
  end

  def handle_get_my_tweets(user_id) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:getMyTweets, user_id})
    receive do
      {:repGetMyTweets, list} ->
        IO.inspect list, label: "Client #{user_id} :- All of my tweets"
    end
  end

  def handle_queries_subscribed_to(user_id) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsSubscribedTo, user_id})
    receive do
      {:repTweetsSubscribedTo, list} ->
        if list != [], do: IO.inspect list, label: "Client #{user_id} :- Subscribed To \n"
    end
  end

  def handle_queries_hashtag(tag, user_id) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsWithHashtag, tag, user_id})
    receive do
      {:repTweetsWithHashtag, list} -> IO.inspect list, label: "Client #{user_id} :- Tweets With #{tag}"
    end
  end

  def handle_queries_mention(user_id) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsWithMention, user_id})
    receive do
      {:repTweetsWithMention, list} -> IO.inspect list, label: "Client #{user_id} :- Tweets With @#{user_id}"
    end
  end

  def randomizer(l) do
    :crypto.strong_rand_bytes(l)
    |> Base.url_encode64
    |> binary_part(0, l)
    |> String.downcase
  end
end
