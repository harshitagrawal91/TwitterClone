defmodule TwitterClone.Client do
    use GenServer
    require Logger

    def start_link(userId,noOfTweets,noToSubscribe,existingUser) do
        GenServer.start_link(__MODULE__, [userId,noOfTweets,noToSubscribe,existingUser])
    end

    def make_distributed([head | tail],l) do
        unless Node.alive?() do
            try do
                {ip_tuple,_,_} = head
                current_ip = to_string(:inet_parse.ntoa(ip_tuple))
                if current_ip === "127.0.0.1" do
                    if l > 1 do
                        make_distributed(tail,l-1)
                    else
                        IO.puts "Could not make current node distributed."
                    end
                else
                    server_node_name = String.to_atom("client@" <> current_ip)
                    Node.start(server_node_name)
                    Node.set_cookie(server_node_name,:monster)
                    Node.connect(String.to_atom("server@" <> current_ip))
                end
            rescue
                _ -> if l > 1, do: make_distributed(tail,l-1), else: IO.puts "Could not make current node distributed."
            end
        end
    end

    def init([userId,noOfTweets,noToSubscribe,existingUser]) do
        {:ok,iflist}=:inet.getif()
        make_distributed(Enum.reverse(iflist),length(iflist))
        :global.sync()

        if existingUser do
            IO.puts "User #{userId} :- reconnected"
            login_handler(userId)
        end

        #Register Account
        # IO.inspect(:global.whereis_name(:TwitterServer))
        GenServer.cast(:global.whereis_name(:TwitterServer), {:register_account, userId,self()})
        IO.puts "User #{userId} :- registered on server"
        # send(:global.whereis_name(:TwitterServer),{:registerUser,userId,self()})
        # receive do
        #     {:registerConfirmation} -> IO.puts "User #{userId} :- registered on server"
        # end
        client_handler(userId,noOfTweets,noToSubscribe)
        receive do: (_ -> :ok)
    end

    def login_handler(userId) do
        # send(:global.whereis_name(:TwitterServer),{:loginUser,userId,self()})
        IO.puts("Inside login-----------------------")
        GenServer.cast(:global.whereis_name(:TwitterServer), {:loginUser, userId,self()})
        for _ <- 1..5 do
            GenServer.cast(:global.whereis_name(:TwitterServer), {:tweet, "user#{userId} tweeting that #{randomizer(8)} does not make sense",userId})
            # send(:global.whereis_name(:TwitterServer),{:tweet,"user#{userId} tweeting that #{randomizer(8)} does not make sense",userId})
        end
        handle_liveView(userId)
    end

    def client_handler(userId,noOfTweets,noToSubscribe) do

        #Subscribe
        if noToSubscribe > 0 do
            subList = generate_subList(1,noToSubscribe,[])
            handle_zipf_subscribe(userId,subList)
        end

        start_time = System.system_time(:millisecond)
        #Mention
        userToMention = :rand.uniform(String.to_integer(userId))
        # send(:global.whereis_name(:TwitterServer),{:tweet,"user#{userId} tweeting @#{userToMention}",userId})
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweet, "user#{userId} tweeting @#{userToMention}",userId})

        #Hashtag
        # send(:global.whereis_name(:TwitterServer),{:tweet,"user#{userId} tweeting that #COP5615isgreat",userId})
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweet, "user#{userId} tweeting that #COP5615isgreat",userId})
        #Send Tweets
        for _ <- 1..noOfTweets do
            GenServer.cast(:global.whereis_name(:TwitterServer), {:tweet, "user#{userId} tweeting that #{randomizer(8)} does not make sense",userId})
            # send(:global.whereis_name(:TwitterServer),{:tweet,"user#{userId} tweeting that #{randomizer(8)} does not make sense",userId})
        end

        #ReTweet
        handle_retweet(userId)
        tweets_time_diff = System.system_time(:millisecond) - start_time

        #Queries
        start_time = System.system_time(:millisecond)
        handle_queries_subscribedto(userId)
        queries_subscribedto_time_diff = System.system_time(:millisecond) - start_time

        start_time = System.system_time(:millisecond)
        handle_queries_hashtag("#COP5615isgreat",userId)
        queries_hashtag_time_diff = System.system_time(:millisecond) - start_time

        start_time = System.system_time(:millisecond)
        handle_queries_mention(userId)
        queries_mention_time_diff = System.system_time(:millisecond) - start_time

        start_time = System.system_time(:millisecond)
        #Get All Tweets
        handle_get_my_tweets(userId)
        queries_myTweets_time_diff = System.system_time(:millisecond) - start_time

        tweets_time_diff = tweets_time_diff/(noOfTweets+3)
        send(:global.whereis_name(:start_up_process),{:performance_metric,tweets_time_diff,queries_subscribedto_time_diff,queries_hashtag_time_diff,queries_mention_time_diff,queries_myTweets_time_diff})

        #Live View
        handle_liveView(userId)
    end

    def generate_subList(count,noOfSubs,list) do
        if(count == noOfSubs) do
            [count | list]
        else
            generate_subList(count+1,noOfSubs,[count | list])
        end
    end

    def handle_zipf_subscribe(userId,subscribeToList) do
        Enum.each subscribeToList, fn accountId ->
            # send(:global.whereis_name(:TwitterServer),{:addSubscriber,userId,Integer.to_string(accountId)})
            GenServer.cast(:global.whereis_name(:TwitterServer), {:addSubscriber,userId,Integer.to_string(accountId)})
        end
    end

    def handle_retweet(userId) do
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsSubscribedTo,userId})
        # send(:global.whereis_name(:TwitterServer),{:tweetsSubscribedTo,userId})
        list = receive do
            {:repTweetsSubscribedTo,list} -> list
        end
        if list != [] do
            rt = hd(list)
            GenServer.cast(:global.whereis_name(:TwitterServer), {:tweet, rt <> " -RT",userId})
            # send(:global.whereis_name(:TwitterServer),{:tweet,rt <> " -RT",userId})
        end
    end

    def handle_liveView(userId) do
        receive do
            {:live,tweetString} -> IO.inspect tweetString, label:  "User #{userId} :- Live View -----"
        end
        handle_liveView(userId)
    end

    def handle_get_my_tweets(userId) do
        GenServer.cast(:global.whereis_name(:TwitterServer), {:getMyTweets,userId})
        # send(:global.whereis_name(:TwitterServer),{:getMyTweets,userId})
        receive do
            {:repGetMyTweets,list} -> IO.inspect list, label: "User #{userId} :- All my tweets"
        end
    end

    def handle_queries_subscribedto(userId) do
        # send(:global.whereis_name(:TwitterServer),{:tweetsSubscribedTo,userId})
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsSubscribedTo,userId})
        receive do
            {:repTweetsSubscribedTo,list} ->  if list != [], do: IO.inspect list, label: "User #{userId} :- Tweets Subscribed To"
        end
    end

    def handle_queries_hashtag(tag,userId) do
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsWithHashtag,tag,userId})
        # send(:global.whereis_name(:TwitterServer),{:tweetsWithHashtag,tag,userId})
        receive do
            {:repTweetsWithHashtag,list} -> IO.inspect list, label: "User #{userId} :- Tweets With #{tag}"
        end
    end

    def handle_queries_mention(userId) do
        #  send(:global.whereis_name(:TwitterServer),{:tweetsWithMention,userId})
        GenServer.cast(:global.whereis_name(:TwitterServer), {:tweetsWithMention,userId})
        receive do
            {:repTweetsWithMention,list} -> IO.inspect list, label: "User #{userId} :- Tweets With @#{userId}"
        end
    end

    def randomizer(l) do
      :crypto.strong_rand_bytes(l) |> Base.url_encode64 |> binary_part(0, l) |> String.downcase
    end

end
