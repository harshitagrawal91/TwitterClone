defmodule TwitterEngine do
    use GenServer
    require Logger

    def start_link() do
        GenServer.start_link(__MODULE__, :ok)
    end

    def query_to_storage(userId) do
        if :ets.lookup(:clientsregistry, userId) == [] do
            nil
        else
            [tup] = :ets.lookup(:clientsregistry, userId)
            elem(tup, 1)
        end
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
                    server_node_name = String.to_atom("server@" <> current_ip)
                    Node.start(server_node_name)
                    Node.set_cookie(server_node_name,:monster)
                end
            rescue
                _ -> if l > 1, do: make_distributed(tail,l-1), else: IO.puts "Could not make current node distributed."
            end
        end
    end
    def init_ets() do
        :ets.new(:clientsregistry, [:set, :public, :named_table])
        :ets.new(:tweets, [:set, :public, :named_table])
        :ets.new(:hashtags_mentions, [:set, :public, :named_table])
        :ets.new(:subscribedto, [:set, :public, :named_table])
        :ets.new(:followers, [:set, :public, :named_table])

    end
    def init(:ok) do
        {:ok,iflist}=:inet.getif()
        make_distributed(Enum.reverse(iflist),length(iflist))
        init_ets()
        :global.register_name(:TwitterServer,self())
        IO.inspect(:global.whereis_name(:TwitterServer))
        IO.puts "Server Started"
        {:ok, nil}
    end

    def  handle_cast({:register_account, userId,pid}, state) do
        :ets.insert(:clientsregistry, {userId, pid})
        :ets.insert(:tweets, {userId, []})
        :ets.insert(:subscribedto, {userId, []})
        if :ets.lookup(:followers, userId) == [], do: :ets.insert(:followers, {userId, []})
        {:noreply, state}
    end
    def handle_cast({:tweet,tweetString,userId}, state) do
        [tup] = :ets.lookup(:tweets, userId)
        list = elem(tup,1)
        list = [tweetString | list]
        :ets.insert(:tweets,{userId,list})

        hashtagsList = Regex.scan(~r/\B#[a-zA-Z0-9_]+/, tweetString) |> Enum.concat
        Enum.each hashtagsList, fn hashtag ->
	        insert_tags(hashtag,tweetString)
        end
        mentionsList = Regex.scan(~r/\B@[a-zA-Z0-9_]+/, tweetString) |> Enum.concat
        Enum.each mentionsList, fn mention ->
	        insert_tags(mention,tweetString)
            userName = String.slice(mention,1, String.length(mention)-1)
            if query_to_storage(userName) != nil, do: send(query_to_storage(userName),{:live,tweetString})
        end

        [{_,followersList}] = :ets.lookup(:followers, userId)
        Enum.each followersList, fn follower ->
	        if query_to_storage(follower) != nil, do: send(query_to_storage(follower),{:live,tweetString})
        end
        {:noreply, state}
    end

    def  handle_cast({:tweetsSubscribedTo, userId}, state) do
        subscribedTo = get_subscribed_to(userId)
        list = generate_tweet_list(subscribedTo,[])
        send(query_to_storage(userId),{:repTweetsSubscribedTo,list})
        {:noreply, state}
    end
    def  handle_cast({:tweetsWithHashtag, hashTag, userId}, state) do
        [tup] = if :ets.lookup(:hashtags_mentions, hashTag) != [] do
            :ets.lookup(:hashtags_mentions, hashTag)
        else
            [{"#",[]}]
        end
        list = elem(tup, 1)
        send(query_to_storage(userId),{:repTweetsWithHashtag,list})
        {:noreply, state}
    end
    def  handle_cast({:tweetsWithMention, userId}, state) do
        [tup] = if :ets.lookup(:hashtags_mentions, "@" <> userId) != [] do
            :ets.lookup(:hashtags_mentions, "@" <> userId)
        else
            [{"#",[]}]
        end
        list = elem(tup, 1)
        send(query_to_storage(userId),{:repTweetsWithMention,list})
        {:noreply, state}
    end
    def  handle_cast({:getMyTweets, userId}, state) do
        [tup] = :ets.lookup(:tweets, userId)
        list = elem(tup, 1)
        send(query_to_storage(userId),{:repGetMyTweets,list})
        {:noreply, state}
    end
    def  handle_cast({:disconnectUser, userId}, state) do
        :ets.insert(:clientsregistry, {userId, nil})
        {:noreply, state}
    end
    def  handle_cast({:deleteUser, userId}, state) do
        :ets.delete(:clientsregistry, userId)
        {:noreply, state}
    end
    def  handle_cast({:loginUser, userId,pid}, state) do
        :ets.insert(:clientsregistry, {userId, pid})
        {:noreply, state}
    end

    def  handle_cast({:addSubscriber,userId,subId}, state) do
        [tup] = :ets.lookup(:subscribedto, userId)
        # IO.inspect(elem(tup, 1))
        list = elem(tup, 1)
        list = [subId | list]
        :ets.insert(:subscribedto, {userId, list})
        add_followers(subId,userId)
        {:noreply, state}
    end

    def get_tweets(userId) do
        if :ets.lookup(:tweets, userId) == [] do
            []
        else
            [tup] = :ets.lookup(:tweets, userId)
            elem(tup, 1)
        end
    end

    def get_subscribed_to(userId) do
        [tup] = :ets.lookup(:subscribedto, userId)
        elem(tup, 1)
    end

    def get_followers(userId) do
        [tup] = :ets.lookup(:followers, userId)
        elem(tup, 1)
    end


    def add_followers(userId,foll) do
        if :ets.lookup(:followers, userId) == [], do: :ets.insert(:followers, {userId, []})
        [tup] = :ets.lookup(:followers, userId)
        list = elem(tup, 1)
        list = [foll | list]
        :ets.insert(:followers, {userId, list})
        [_tup] = :ets.lookup(:followers, userId)
        # IO.inspect(tup)
    end


    def insert_tags(tag,tweetString) do
        [tup] = if :ets.lookup(:hashtags_mentions, tag) != [] do
            :ets.lookup(:hashtags_mentions, tag)
        else
            [nil]
        end
        if tup == nil do
            :ets.insert(:hashtags_mentions,{tag,[tweetString]})
        else
            list = elem(tup,1)
            list = [tweetString | list]
            :ets.insert(:hashtags_mentions,{tag,list})
        end
        # IO.inspect(:ets.lookup(:hashtags_mentions, tag))
    end


    def generate_tweet_list([head | tail],tweetlist) do
        tweetlist = get_tweets(head) ++ tweetlist
        generate_tweet_list(tail,tweetlist)
    end

    def generate_tweet_list([],tweetlist), do: tweetlist
end
