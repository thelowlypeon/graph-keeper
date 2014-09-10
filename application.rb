#!/usr/bin/env ruby
# encoding: UTF-8

require 'sinatra/base'
require 'sinatra/assetpack'
require 'less'

class GraphKeeper < Sinatra::Base
  enable :sessions
  set :session_secret, 'TODO make this a real secret hash or something'
  set :session, :domain => 'localhost' #TODO make this environment specific or in config.ru

  set :root, File.dirname(__FILE__) # You must set app root
  set :site_name, "Graph Keeper"

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

  helpers do
    def logged_in?
      session.has_key?(:profile) && !session[:profile].nil?
    end

    def authorize!
      redirect '/authorize/' unless logged_in?
    end
  end

  get '/' do
    erb :index
  end

  get '/authorize/?' do
    redirect BabyTooth.authorize_url
  end
  get '/authorized/?' do
    token = BabyTooth.get_token(params[:code])
    if !token.nil? && token != ''
      session[:token] = token
      session[:user] = BabyTooth::User.new(session[:token])
      session[:profile] = session[:user].profile
      redirect '/graph/'
    else
      erb :authorization, :locals => { response: response }
    end
  end
  get '/logout/?' do
    if logged_in?
      session.delete :token
      session.delete :user
      session.delete :profile
      BabyTooth::Client.new(session[:token], '/de-authorize')
    end
    redirect '/'
  end

  get '/graph/?' do
    authorize!
    erb :graph
  end

  get '/cache/?' do
    uri = '/fitnessActivities'
    activities = []
    feed = BabyTooth::FitnessActivityFeed.new(session[:token], uri)
    #break unless feed.body.has_key?('items') && feed['items']
    feed['items'].each do |activity|
      begin
        timestamp = Date.strptime(activity["start_time"],"%a, %e %b %Y %H:%M%S")
      rescue
        timestamp = "unable to parse #{activity["start_time"]}"
      end
      data = { timestamp: timestamp, distance: activity["total_distance"], type: activity["type"] }
      activities << data
    end
    uri = feed['next'] ? feed['next'] : false
    erb :graph, :locals => { activities: activities, items: feed['items'] }
  end
  run! if app_file == $0
end
