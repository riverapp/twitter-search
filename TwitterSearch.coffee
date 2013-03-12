# Plugin for Twitter that will retrieve Tweets from a user's timeline.
class Twitter

  # The constructor is required and will be given a delegate that can perform
  # certain actions which are specific to this plugin.
  constructor: (delegate) ->
    @delegate = delegate

    # Also set up the class-scope configuration variables such as access URLs
    # and OAuth credentials.
    @OAUTH_CONSUMER_KEY = 'A2LGbh5RqwVe4GYYCrgQ'
    @OAUTH_CONSUMER_SECRET = 'nSQMQ2YK3On7e3c9sp4DPMAKDKthzDVbBuUXwmh4HVo'

    @oauth_request_token_url = 'https://api.twitter.com/oauth/request_token'
    @oauth_authorize_token_url = 'https://api.twitter.com/oauth/authorize?oauth_token='
    @oauth_access_token_url = 'https://api.twitter.com/oauth/access_token'

    @search_url = 'https://api.twitter.com/1.1/search/tweets.json?q='
    @avatar_url = 'http://api.twitter.com/1/users/profile_image?size=bigger&screen_name='


  #### Authentication

  # **authRequirements** is called by River to find out how to create a new
  # stream instance.
  authRequirements: (callback) ->
    @requestToken (err, response) =>
      if err
        console.log err
        return callback(err)
      response = parseQueryString response
      console.log 'url: ' + @oauth_authorize_token_url + response.oauth_token
      callback {
        authType: 'oauth',
        url: @oauth_authorize_token_url + response.oauth_token
      }
      

  # Helper method to retrieve a request token from Twitter.
  requestToken: (callback) ->
    callbackURL = @delegate.callbackURL()
    HTTP.request({
      url: @oauth_request_token_url,
      method: 'POST',
      oauth: {
        oauth_consumer_key: @OAUTH_CONSUMER_KEY,
        oauth_consumer_secret: @OAUTH_CONSUMER_SECRET,
        oauth_version: '1.0',
        oauth_callback: callbackURL
      }
    }, callback)


  # **authenticate** is called by River with the parameters requested in
  # *authRequirements* and should result in a call to *createAccount*.
  #
  # Swap the request token for an access token, the call *createAccount*.
  authenticate: (params) ->
    HTTP.request {
      url: @oauth_access_token_url,
      method: 'POST',
      parameters: {
        'oauth_verifier': params.oauth_verifier
      },
      oauth: {
        oauth_consumer_key: @OAUTH_CONSUMER_KEY,
        oauth_consumer_secret: @OAUTH_CONSUMER_SECRET,
        oauth_token: params.oauth_token,
        oauth_version: '1.0'
      }
    }, (err, response) =>
      if err
        console.log err
        return
      response = parseQueryString response
      @createAccount response


  # Use the delegate to create an account with the user details returned by
  # Twitter.
  createAccount: (params) ->
    @delegate.createAccount {
      name: params.screen_name,
      identifier: params.user_id,
      secret: JSON.stringify({
        oauth_token: params.oauth_token,
        oauth_token_secret: params.oauth_token_secret
      })
    }

  
  # Called by River to get a list of updates to be displayed to the user.
  #
  # Make an HTTP request to the search API using the access token that
  # was stored in the account's *secret* field.
  #
  # Append the query from the settings
  update: (user, callback) ->
    secret = JSON.parse(user.secret)
    query = user.settings.query
    if not query
      callback('No search query configured', null)
    console.log(@search_url + encodeURIComponent(query))
    HTTP.request {
      url: @search_url + encodeURIComponent(query),
      method: 'GET',
      oauth: {
        oauth_consumer_key: @OAUTH_CONSUMER_KEY,
        oauth_consumer_secret: @OAUTH_CONSUMER_SECRET,
        oauth_token: secret.oauth_token,
        oauth_token_secret: secret.oauth_token_secret,
        oauth_version: '1.0'
      }
    }, (err, response) =>
      if err
        console.log err
        callback err, null
        return
      statuses = @parseStatuses response
      callback null, statuses


  # Helper method to parse the statuses returned from the timeline into an array
  # of **StatusUpdate** objects.
  #
  # Each update is checked to see if it is a retweet and formatted appropriately
  # if it is.
  parseStatuses: (rawStatuses) ->
    statuses = []
    rawStatuses = JSON.parse(rawStatuses).statuses
    for s in rawStatuses
      status = new StatusUpdate()
      if s.retweeted_status
        status.text = s.retweeted_status.text
        status.origin = s.retweeted_status.user.name
        status.originID = '@' + s.retweeted_status.user.screen_name
        status.originImageURL = @avatar_url + s.retweeted_status.user.screen_name
        status.detailText = '↳ Retweeted by ' + s.user.name
      else
        status.text = s.text
        status.origin = s.user.name
        status.originID = '@' + s.user.screen_name
        status.originImageURL = @avatar_url + s.user.screen_name
      status.createdDate = parseInt(new Date(s.created_at) / 1000)
      status.id = s.id.toString()
      statuses.push status
    return statuses
  

  # Return the update interval preferences in seconds. These settings are
  # appropriate for a Twitter client.
  updatePreferences: (callback) ->
    callback {
      'interval': 60,
      'min':      30,
      'max':      300
    }

  # Return a settings form that contains a text field for the search term to use
  # on Twitter.
  settings: (user, callback) ->
    callback [
      {
        "name": "Search",
        "type": "text",
        "identifier": "query",
        "placeholder": "@justinbieber, #ff"
      }
    ]
      
# All plugins must be registered with the global **PluginManager**. The
# plugin object passed should be a 'class' like object. This is easy with
# CoffeeScript. The identifier passed here must match that given in the
# plugin manifest file.
PluginManager.registerPlugin(Twitter, 'me.danpalmer.River.plugins.TwitterSearch')