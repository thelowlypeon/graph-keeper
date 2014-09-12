#!/usr/bin/env ruby
# encoding: UTF-8

require 'sinatra/base'
require 'sinatra/assetpack'
require 'less'

class GraphKeeper < Sinatra::Base
  @@logged_in_users = {}

  enable :sessions
  set :session_secret, 'TODO make this a real secret hash or something'
  set :session, :domain => 'localhost' #TODO make this environment specific or in config.ru
  set :root, File.dirname(__FILE__) # You must set app root
  set :site_name, "Graph Keeper"

  helpers do
    def logged_in?
      !@@logged_in_users[session[:user]].nil?
    end

    def authorize!
      redirect '/authorize/' unless logged_in?
    end

    def logged_in_user
      @@logged_in_users[session[:user]] unless !logged_in?
    end

    def set_logged_in_user(user)
      if user.nil?
        @@logged_in_users[session[:user]] = nil
        session.delete :token
        session.delete :user
      else
        session[:user] = user['userID']
        @@logged_in_users[session[:user]] = user
      end
    end
  end

  def self.distance(value, unit)
    unit = :mile if unit.nil?
    case unit
    when :mile
      distance(value, :km) * 0.621371
    when :km
      value / 1000
    else #meter
      value
    end
  end
  Dir[File.join(settings.root, 'app', 'models', '*.rb')].each{|file| require file}

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
      '/js/*.js'
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

  get '/authorize/?' do
    redirect BabyTooth.authorize_url
  end
  get '/authorized/?' do
    token = BabyTooth.get_token(params[:code])
    if !token.nil? && token != ''
      session[:token] = token
      set_logged_in_user BabyTooth::User.new(session[:token])
      erb :authorization, :locals => {response: "logged in as #{logged_in_user['userID']}"}
      redirect '/graph/'
    else
      erb :authorization, :locals => { response: response }
    end
  end
  get '/logout/?' do
    if logged_in?
      set_logged_in_user nil
      BabyTooth::Client.new(session[:token], '/de-authorize')
    end
    redirect '/'
  end

  get '/graph/?' do
    authorize!
    erb :graph
  end

  get '/cache/?' do
    authorize!
    activities = logged_in_user.fitness_activities([0,1])
    erb :graph, :locals => { activities: activities }
  end

  get '/data.csv' do
    authorize!
    headers "Content-Disposition" => "attachment;data.csv",
            "Content-Type" => "application/octet-stream"
    results = Hash.new
    logged_in_user.fitness_activities(1..5).each do |activity|
      datestamp = activity.timestamp.to_i / 7 / 24 / 60 / 60 #strftime("%Y/%m/%d")
      results[activity['type']] ||= Hash.new
      results[activity['type']][datestamp] ||= 0
      results[activity['type']][datestamp] += activity.distance
    end
    #get max number of elements
    min_date = nil
    max_date = nil
    results.each do |type,data|
      data.each do |date,distance|
        min_date = date if min_date.nil? || date < min_date
        max_date = date if max_date.nil? || date > max_date
      end
    end
    result = "key,value,date\n"
    results.each do |type,data|
      data.each do |date, distance|
        results[type][date] = "#{type},#{distance},#{Time.at(date * 60 * 60 * 24 * 7).strftime('%Y/%W')}\n"
      end
      (min_date..max_date).each do |date|
        results[type][date] ||= "#{type},0,#{Time.at(date * 60 * 60 * 24 * 7).strftime('%Y/%W')}\n"
        result << results[type][date]
      end
    end
    result
  end

  run! if app_file == $0
end
