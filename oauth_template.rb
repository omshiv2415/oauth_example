class OauthTemplate < Sinatra::Base

  # Configure the application here
  CONSUMER_KEY    = 'key'
  CONSUMER_SECRET = 'secret'
  CANVAS_URL      = 'http://canvas.dev'
  CLIENT_ID       = '1'
  CLIENT_SECRET   = 'NYEksooAX9Z7Mmvn7k5X3dZKmufZ7HS2fQoWRFYRjC6cbRGbGdWcwTXsPzMXfqtZ'
  REDIRECT_URI    = 'http://localhost:5000/oauth2response'

  enable :sessions
  set :protection, except: :frame_options

  # In a real application, these would be persistent. We'd also need to
  # encrypt the user tokens, because they're as valuable as a password.
  @@nonce_cache = []
  @@token_cache = {}

  # We're embedding this app inside Canvas, but could get an OAuth token and
  # make API calls from any app.
  use Rack::LTI,
    consumer_key: CONSUMER_KEY,
    consumer_secret: CONSUMER_SECRET,
    app_path: '/oauth/launch',
    config_path: '/lti/config.xml',
    launch_path: '/lti/launch',
    nonce_validator: ->(nonce) {
      !@@nonce_cache.include?(nonce) && @@nonce_cache << nonce
    },
    time_limit: 3_600, # one hour
    success: ->(params, session) {
      session[:user] = params['user_id']
    },
    extensions: {
      'canvas.instructure.com' => {
        course_navigation: {
          default: 'enabled',
          text: 'OAuth Tool'
        }
      }
    },
    title: 'OAuth Example App',
    description: <<-END
This app is an example of an LTI application that uses OAuth
to obtain a Canvas user's API token. This allows the app to
make API calls on behalf of the current user.
    END

  # Return a list of the current user's courses.
  get '/' do
    courses_api     = URI("#{CANVAS_URL}/api/v1/courses?access_token=#{current_token}")
    canvas_response = Net::HTTP.get(courses_api)
    @courses        = JSON.parse(canvas_response)

    erb :index
  end

  # Unless we've already got an API token, begin the OAuth process. Otherwise,
  # redirect to the app's main page.
  get '/oauth/launch' do
    redirect current_token ? '/' : "#{CANVAS_URL}/login/oauth2/auth?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URI}"
  end

  # Handle the OAuth redirect from Canvas. Make a POST request back to Canvas
  # to finish the OAuth process and save the token we receive.
  get '/oauth2response' do
    canvas_url = URI("#{CANVAS_URL}/login/oauth2/token")
    response = Net::HTTP.post_form(canvas_url, client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, client_secret: CLIENT_SECRET, code: params[:code])
    @@token_cache[session[:user]] = JSON.parse(response.body)['access_token']

    redirect '/'
  end

  private

  # Helper to retrieve the current user's API token.
  def current_token
    @@token_cache[session[:user]]
  end
end
