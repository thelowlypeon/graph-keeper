#!/usr/bin/env ruby
# encoding: UTF-8
require 'dotenv'
Dotenv.load #TODO move this to config.ru

require 'sinatra/base'
require 'sinatra/assetpack'
require 'baby_tooth'
require 'less'

BabyTooth.configure do |config|
  config.access_token_url  = "http://runkeeper.com/apps/token"
  config.authorization_url = "http://runkeeper.com/apps/authorize"
  config.client_id         = ENV['CLIENT_ID'] #TODO more specific names
  config.client_secret     = ENV['CLIENT_SECRET']
  config.redirect_uri      = ENV['REDIRECT_URI']
  config.site              = "http://api.runkeeper.com"
end

class GraphKeeper < Sinatra::Base
  enable :sessions
  set :session_secret, 'TODO make this a real secret hash or something'
  set :session, :domain => 'localhost' #TODO make this environment specific or in config.ru

  set :root, File.dirname(__FILE__) # You must set app root
  configure do
    set :site_name, "Graph Keeper"
  end

  register Sinatra::AssetPack

  assets {
    serve '/js',     from: 'app/js'        # Default
    serve '/css',    from: 'app/css'       # Default
    serve '/images', from: 'app/images'    # Default

    # The second parameter defines where the compressed version will be served.
    # (Note: that parameter is optional, AssetPack will figure it out.)
    # The final parameter is an array of glob patterns defining the contents
    # of the package (as matched on the public URIs, not the filesystem)
    js :app, '/js/app.js', [
      '/js/vendor/**/*.js',
      '/js/lib/**/*.js'
    ]

    css :application, '/css/application.css', [
      '/css/*.css'
    ]

    js_compression  :jsmin    # :jsmin | :yui | :closure | :uglify
    css_compression :simple   # :simple | :sass | :yui | :sqwish
  }

  get '/' do
    erb :index
  end
  get '/authorize' do
    redirect BabyTooth.authorize_url
  end
  get '/authorized' do
    token = BabyTooth.get_token(params[:code])
    if !token.nil? && token != ''
      session[:token] = token
      session[:profile] = BabyTooth::User.new(session[:token]).profile
      redirect '/'
    else
      erb :authorization, :locals => { respose: reponse }
    end
  end
  get '/logout' do
    session[:token] = nil
    session[:profile] = nil
    redirect '/'
  end
  run! if app_file == $0
end
