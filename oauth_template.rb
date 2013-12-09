require 'json'
require 'net/http'

class OauthTemplate < Sinatra::Base

  # Configure the application here

  # LTI authentication settings - these would be set to something actually
  # secret in production or pulled from a persistent data store.
  CONSUMER_KEY    = 'key'
  CONSUMER_SECRET = 'secret'

  # OAuth settings
  #   - CANVAS_URL - The URL of your Canvas instance
  #   - CLIENT_ID - Your developer key id (given by Instructure)
  #   - CLIENT_SECRET - Your developer key secret
  #   - REDIRECT_URI - The URI canvas should direct to when the OAuth process
  #                    is done (i.e. this application).
  #
  # Valid examples of thse values are included in the commented block below.
  CANVAS_URL      = 'TODO'
  CLIENT_ID       = 'TODO'
  CLIENT_SECRET   = 'TODO'
  REDIRECT_URI    = 'TODO'

  #CANVAS_URL      = 'http://canvas.dev'
  #CLIENT_ID       = '1'
  #CLIENT_SECRET   = 'NYEksooAX9Z7Mmvn7k5X3dZKmufZ7HS2fQoWRFYRjC6cbRGbGdWcwTXsPzMXfqtZ'
  #REDIRECT_URI    = 'http://localhost:5000/oauth2response'

  # Use sessions to store user data
  enable :sessions

  # Allow the app to be embedded in an iframe
  set :protection, except: :frame_options

  # In a real application, the following two values would be persistent. We'd
  # also need to encrypt the user tokens, because they're as valuable as a
  # password.

  # OAuth nonces are stored so they cannot be replayed by a malicious user.
  @@nonce_cache = []

  # User tokens are stored so that a user only needs to authorized this
  # application once.
  @@token_cache = {}

  # We're embedding this app inside Canvas, but could get an OAuth token and
  # make API calls from any app. This configuration block is specific to
  # Rack::LTI - if your application isn't using it you'll need to handle XML
  # configuration, redirects, and request validation another way.
  #
  # Learn more about Rack::LTI at http://github.com/zachpendleton/rack-lti
  use Rack::LTI,
    # Pass the consumer key and secret we created above.
    consumer_key: CONSUMER_KEY,
    consumer_secret: CONSUMER_SECRET,

    # This is the URL to redirect to on a valid launch.
    app_path: '/oauth/launch',

    # This is the URL that hosts the tool's XML configuration.
    config_path: '/lti/config.xml',

    # This is the URL clients (e.g. Canvas) will POST launch requests to.
    launch_path: '/lti/launch',

    # A function for ensuring that our nonces are valid.
    nonce_validator: ->(nonce) {
      !@@nonce_cache.include?(nonce) && @@nonce_cache << nonce
    },

    # Fail request older than 1 hour.
    time_limit: 3_600, # one hour

    # On a successful launch, take the user's ID from the launch and store
    # it in the session before redirecting.
    success: ->(params, req, res) {
      req.env['rack.session'][:user] = params['user_id']
    },

    # Use Instructure's course_navigation extension to display a link to
    # the tool in Canvas' course navigation.
    extensions: {
      'canvas.instructure.com' => {
        course_navigation: {
          default: 'enabled',
          text: 'OAuth Tool'
        }
      }
    },

    # The title and description of the tool. Visible in the configuration.
    title: 'OAuth Example App',
    description: <<-END
This app is an example of an LTI application that uses OAuth
to obtain a Canvas user's API token. This allows the app to
make API calls on behalf of the current user.
    END

  # Return a list of the current user's courses.
  get '/' do
    # Make a request to Canvas using the current user's API token.
    courses_api     = URI("#{CANVAS_URL}/api/v1/courses?access_token=#{current_token}")
    canvas_response = Net::HTTP.get(courses_api)
    @courses        = JSON.parse(canvas_response)

    # Render the index template in views/index.erb.
    erb :index
  end

  # We redirect to this endpoint after a successful launch. It checks for a
  # current user token and, if found, redirects to the index action. If we don't
  # have a token, we redirect to Canvas so the user can authorize our app.
  get '/oauth/launch' do
    if current_token
      redirect '/'
    else
      redirect "#{CANVAS_URL}/login/oauth2/auth?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URI}"
    end
  end

  # Once a user has authorized our application in Canvas, they are redirected
  # here. 
  get '/oauth2response' do
    # We make one more request to Canvas to exchange our temporary token for a
    # permanent user token.
    canvas_url = URI("#{CANVAS_URL}/login/oauth2/token")
    response = Net::HTTP.post_form(canvas_url, client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, client_secret: CLIENT_SECRET, code: params[:code])

    # Once we have the token, we store it in @@token_cache so it can be reused.
    @@token_cache[session[:user]] = JSON.parse(response.body)['access_token']

    # Redirect to the index to launch the application.
    redirect '/'
  end

  private

  # Helper method to retrieve the current user's API token.
  def current_token
    @@token_cache[session[:user]]
  end
end
