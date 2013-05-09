class OauthTemplate < Sinatra::Base

  enable :sessions

  @@nonce_cache = []
  @@token_cache = {}

  use Rack::Protection, except: :frame
  use Rack::LTI,
    consumer_key: ENV['CONSUMER_KEY'] || 'key',
    consumer_secret: ENV['CONSUMER_SECRET'] || 'secret',
    app_path: '/',
    config_path: '/lti/config.xml',
    launch_path: '/lti/launch',
    nonce_validator: ->(nonce) {
      !@@nonce_cache.include?(nonce) && @@nonce_cache << nonce
    },
    time_limit: 3_600, # one hour
    success: ->(params, session) {
      session[:launch_params] = params
    },
    title: 'OAuth Example App',
    description: <<-END
      This app is an example of an LTI application that uses OAuth
      to obtain a Canvas user's API token. This allows the app to
      make API calls on behalf of the current user.
    END

  get '/' do
    'Hello, world!'
  end
end
