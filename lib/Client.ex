defmodule TwitterClone.Client do
  use GenServer
  require Logger

  def start_link(user_id, twt_cnt, no_to_subscribe, existing_User) do
    GenServer.start_link(__MODULE__, [user_id, twt_cnt, no_to_subscribe, existing_User])
  end

  def create_network([start | last], l) do
    unless Node.alive?() do
      try do
        {row, _, _} = start
        addr = to_string(:inet_parse.ntoa(row))
        if addr === "127.0.0.1" do
          if l > 1 do
            create_network(last, l - 1)
          else
            IO.puts "Attempt to make current node distributed is unsuccessful."
          end
        else
          server_node_name = String.to_atom("client@" <> addr)
          Node.start(server_node_name)
          Node.set_cookie(server_node_name, :monster)
          Node.connect(String.to_atom("server@" <> addr))
        end
      rescue
        _ -> if l > 1, do:
          create_network(last, l - 1),
                       else: IO.puts "Attempt to make current node distributed is unsuccessful."
      end
    end
  end

  # def init([userId, noOfTweets, noToSubscribe, existingUser]) do
  def init([usr, cnt, nums_subs, cur_usr]) do

    {:ok, iflist} = :inet.getif()
    create_network(Enum.reverse(iflist), length(iflist))
    :global.sync()

    if cur_usr do
      IO.puts "Client #{usr} connects again!!"
      process_after_login(usr)
    end

    GenServer.cast(:global.whereis_name(:TwitterServer), {:register_account, usr, self()})
    IO.puts "Registration of Client #{usr} completed"
    process_req(usr, cnt, nums_subs)
    receive do: (_ -> :ok)
  end

  def process_after_login(usr) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:loginUser, usr, self()})
    for _ <- 1..5 do
      GenServer.cast(
        :global.whereis_name(:TwitterServer),
        {:tweet, "Client#{usr} tweets that #{randomizer(8)} is absurd", usr}
      )
    end
    handle_live_view(usr)
  end

  def process_req(usr, twt_cnt, no_to_subscribe) do
    # Subscribe
    if no_to_subscribe > 0 do
      subList = generate_subList(1, no_to_subscribe, [])
      Enum.each subList, fn account_id ->
        :global.whereis_name(:TwitterServer)
        |> GenServer.cast({:addSubscriber, usr, Integer.to_string(account_id)})
      end
    end

    user_to_mention = usr
                      |> String.to_integer
                      |> :rand.uniform

    :global.whereis_name(:TwitterServer)
    |> GenServer.cast(
         {:tweet, "Client#{usr} tweets about @#{user_to_mention}", usr}
       )

    :global.whereis_name(:TwitterServer)
    |> GenServer.cast(
         {:tweet, "Client#{usr} tweets that UF CISE awesome", usr}
       )

    #Send Tweets
    for _ <- 1..twt_cnt do
      :global.whereis_name(:TwitterServer)
      |> GenServer.cast(
           {:tweet, "Client#{usr} tweets that #{randomizer(8)} is absurd", usr}
         )
    end

    start_time = System.system_time(:millisecond)
    #ReTweet

    twt_tm_dff = reTweet(usr, start_time)
    #Queries
    qury_sbs_tm_df = sendQuery(usr, start_time)

    start_time = System.system_time(:millisecond)

    process_task(usr, start_time, twt_tm_dff, twt_cnt,
      qury_sbs_tm_df)

    #Live View
    usr
    |> handle_live_view
  end

  def sendQuery(usr, start) do
    start_time = System.system_time(:millisecond)
    handle_queries_subscribed_to(usr)
    qury_sbs_tm_df = System.system_time(:millisecond) - start
    qury_sbs_tm_df
  end

  def process_task(usr, start_time, twt_tm_dff, twt_cnt,
        qury_sbs_tm_df) do
    handle_queries_hashtag("#COP5615isgreat", usr)
    hs_tg_tm_dff_qry = System.system_time(:millisecond) - start_time

    start_time = System.system_time(:millisecond)
    handle_queries_mention(usr)
    qury_mntn_tm_df = System.system_time(:millisecond) - start_time

    start_time = System.system_time(:millisecond)

    getAllTweets(
      usr,
      start_time,
      twt_tm_dff,
      twt_cnt,
      qury_sbs_tm_df,
      hs_tg_tm_dff_qry,
      qury_mntn_tm_df
    )

  end

  def getAllTweets(
        usr,
        start_time,
        twt_tm_dff,
        twt_cnt,
        qury_sbs_tm_df,
        hs_tg_tm_dff_qry,
        qury_mntn_tm_df
      ) do
    #Get All Tweets
    usr
    |> handle_get_my_tweets
    qury_twt_tm_dff_self = System.system_time(:millisecond) - start_time

    twt_tm_dff = twt_tm_dff / (twt_cnt + 3)
    send(
      :global.whereis_name(:start_up_process),
      {
        :performance_metric,
        twt_tm_dff,
        qury_sbs_tm_df,
        hs_tg_tm_dff_qry,
        qury_mntn_tm_df,
        qury_twt_tm_dff_self
      }
    )
  end

  def reTweet(usr, start) do
    usr
    |> handle_re_tweet
    twt_tm_dff = System.system_time(:millisecond) - start
    twt_tm_dff
  end

  def generate_subList(count, no_of_Subs, list) do
    if(count == no_of_Subs) do
      [count | list]
    else
      generate_subList(count + 1, no_of_Subs, [count | list])
    end
  end


  def handle_re_tweet(usr) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsSubscribedTo, usr})
    list = receive do
      {:repTweetsSubscribedTo, list} -> list
    end
    if list != [] do
      rt = hd(list)
      :global.whereis_name(:TwitterServer)
      |> GenServer.cast({:tweet, rt <> " -Right", usr})
    end
  end

  def handle_live_view(usr) do
    receive do
      {:live, tweet_string} ->
        IO.inspect tweet_string, label: "Client #{usr} :- Streaming --------"
    end
    usr
    |> handle_live_view
  end


  def handle_get_my_tweets(usr) do
    GenServer.cast(:global.whereis_name(:TwitterServer), {:getMyTweets, usr})

    receive do
      {:repGetMyTweets, list} ->
        IO.inspect list, label: "Client #{usr} :- All of my tweets"
    end
  end

  def handle_queries_subscribed_to(usr) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsSubscribedTo, usr})
    receive do
      {:repTweetsSubscribedTo, list} ->
        if list != [], do: IO.inspect list, label: "Client #{usr} :- Subscribed To \n"

    end
  end

  def handle_queries_hashtag(tag, usr) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsWithHashtag, tag, usr})
    receive do
      {:repTweetsWithHashtag, list} -> IO.inspect list, label: "Client #{usr} :- Tweets With #{tag}"
    end
  end

  def handle_queries_mention(usr) do
    :global.whereis_name(:TwitterServer)
    |> GenServer.cast({:tweetsWithMention, usr})
    receive do
      {:repTweetsWithMention, list} -> IO.inspect list, label: "Client #{usr} :- Tweets With @#{usr}"
    end
  end

  def randomizer(l) do
    :crypto.strong_rand_bytes(l)
    |> Base.url_encode64
    |> binary_part(0, l)
    |> String.downcase
  end
end
