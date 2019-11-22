defmodule TwitterClone.Main do
    def main(args) do
      args |> parse_args |> delegate
    end

    defp parse_args(args) do
      {_,parameters,_} = OptionParser.parse(args)

      parameters
    end

    def delegate([]) do
        # Task.start fn -> TwitterClone.Server.start_link() end
        TwitterClone.Server.start_link()
        receive do: (_ -> :ok)
    end

    def delegate(parameters) do
        IO.inspect(parameters)
        numClients = String.to_integer(Enum.at(parameters,0))
        maxSubcribers = String.to_integer(Enum.at(parameters,1))
        disconnectClients = String.to_integer(Enum.at(parameters,2))
        clientsToDisconnect = disconnectClients * (0.01) * numClients
        :ets.new(:mainregistry, [:set, :public, :named_table])

        convergence_task = Task.async(fn -> converging(numClients,numClients,0,0,0,0,0) end)
        :global.register_name(:mainproc,convergence_task.pid)
        start_time = System.system_time(:millisecond)

        createUsers(1,numClients,maxSubcribers)

        Task.await(convergence_task, :infinity)
        IO.puts "Time taken for initial simulation to complete: #{System.system_time(:millisecond) - start_time} milliseconds"

        simulate_disconnection(numClients,clientsToDisconnect)
        receive do: (_ -> :ok)
    end

    def converging(0,totalClients,tweets_time_diff,queries_subscribedto_time_diff,queries_hashtag_time_diff,queries_mention_time_diff,queries_myTweets_time_diff) do
        IO.puts "Avg. time to tweet: #{tweets_time_diff/totalClients} milliseconds"
        IO.puts "Avg. time to query tweets subscribe to: #{queries_subscribedto_time_diff/totalClients} milliseconds"
        IO.puts "Avg. time to query tweets by hashtag: #{queries_hashtag_time_diff/totalClients} milliseconds"
        IO.puts "Avg. time to query tweets by mention: #{queries_mention_time_diff/totalClients} milliseconds"
        IO.puts "Avg. time to query all relevant tweets: #{queries_myTweets_time_diff/totalClients} milliseconds"
    end

    def converging(numClients,totalClients,tweets_time_diff,queries_subscribedto_time_diff,queries_hashtag_time_diff,queries_mention_time_diff,queries_myTweets_time_diff) do
      # Receive convergence messages
      receive do
        {:perfmetrics,a,b,c,d,e} -> converging(numClients-1,totalClients,tweets_time_diff+a,queries_subscribedto_time_diff+b,queries_hashtag_time_diff+c,queries_mention_time_diff+d,queries_myTweets_time_diff+e)
      end
    end

    def createUsers(count,noOfClients,totalSubscribers) do
        userName = Integer.to_string(count)
        noOfTweets = round(Float.floor(totalSubscribers/count))
        noToSubscribe = round(Float.floor(totalSubscribers/(noOfClients-count+1))) - 1
        pid = spawn(fn -> TwitterClone.Client.start_link(userName,noOfTweets,noToSubscribe,false) end)
        :ets.insert(:mainregistry, {userName, pid})
        if (count != noOfClients) do createUsers(count+1,noOfClients,totalSubscribers) end
    end

    def whereis(userId) do
        [tup] = :ets.lookup(:mainregistry, userId)
        elem(tup, 1)
    end

    def simulate_disconnection(numClients,clientsToDisconnect) do
        Process.sleep(1000)
        disconnectList = handle_disconnection(numClients,clientsToDisconnect,0,[])
        Process.sleep(1000)
        Enum.each disconnectList, fn userName ->
            pid = spawn(fn -> TwitterClone.Client.start_link(userName,-1,-1,true) end)
            :ets.insert(:mainregistry, {userName, pid})
        end
        simulate_disconnection(numClients,clientsToDisconnect)
    end

    def handle_disconnection(numClients,clientsToDisconnect,clientsDisconnected,disconnectList) do
        if clientsDisconnected < clientsToDisconnect do
            disconnectClient = :rand.uniform(numClients)
            disconnectClientId = whereis(Integer.to_string(disconnectClient))
            if disconnectClientId != nil do
                userId = Integer.to_string(disconnectClient)
                disconnectList = [userId | disconnectList]
                # send(:global.whereis_name(:TwitterServer),{:disconnectUser,userId})
                GenServer.cast(:global.whereis_name(:TwitterServer), {:disconnectUser,userId})
                :ets.insert(:mainregistry, {userId, nil})
                Process.exit(disconnectClientId,:kill)
                IO.puts "Simulator :- User #{userId} has been disconnected"
                handle_disconnection(numClients,clientsToDisconnect,clientsDisconnected+1,disconnectList)
            else
                handle_disconnection(numClients,clientsToDisconnect,clientsDisconnected,disconnectList)
            end
        else
            disconnectList
        end
    end

    def randomizer(l) do
      :crypto.strong_rand_bytes(l) |> Base.url_encode64 |> binary_part(0, l) |> String.downcase
    end
end
