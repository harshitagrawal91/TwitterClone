# Functionalities implemented
1. Register account and delete account
2. Send tweet. Tweets can have hashtags (e.g. #COP5615isgreat) and mentions
  (@bestuser). You can use predefines categories of messages for hashtags.
3. Subscribe to user's tweets.
4. Re-tweets (so that your subscribers get an interesting tweet you got by other
  means).
5. Allow querying tweets subscribed to, tweets with specific hashtags, tweets in
  which the user is mentioned (my mentions).
6. If the user is connected, deliver the above types of tweets live (without querying).
  
# Bonus implementation
1. Simulate periods of live connection and disconnection for users.
2. Simulate a Zipf distribution on the number of subscribers. For accounts with a lot
  of subscribers, increase the number of tweets. Make some of these messages’
  re-tweets.


# How to Run
Start a name server as a daemon:<br/>
  epmd -d
  
Run the project:
(Run Server) <br/>
  mix run proj4.exs
  
(Run Client) <br/>
  mix run proj4.exs num_user num_msg num_of_disconnection 
  
  num_of_disconnection should be less than num_user 
  
  mix run proj4.exs 10 20 5
  
(Run Test)<br/>
  mix test


# Team members
Harshit Agrawal--9041-1685<br/>
Shantanu Ghosh--4311-4360
