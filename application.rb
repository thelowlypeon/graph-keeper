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

  helpers do
    def logged_in?
      !session[:user].nil?
    end

    def authorize!
      redirect '/authorize/' unless logged_in?
    end

    def logged_in_user
      User.find(session[:user]) unless !logged_in?
    end

    def set_logged_in_user(user)
      if user.nil?
        session.delete :token
        session.delete :user
      else
        session[:user] = user['userID']
        if !User.find(session[:user])
          User.create(user.to_hash).save
        end
        if !logged_in_user
          raise "There was an error finding or create user #{user['userID']}"
        else
          logged_in_user
        end
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
      #erb :authorization, :locals => {response: "logged in as #{logged_in_user.runkeeper_id}"}
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
    Activity.collection.remove
    activities = logged_in_user.activities! session[:token], (0..25)
    "done, got #{activities.count} activities"
  end

  get '/data.csv' do
    authorize!
    headers "Content-Disposition" => "attachment;data.csv",
            "Content-Type" => "application/octet-stream"

    bucket_size = 7 * 24 * 60 * 60 #weeks
    y = params.has_key?('y') && (Activity.keys.keys.include?(params['y']) || Activity.respond_to?(params['y'])) ? params['y'].to_sym : :total_distance
    z = params.has_key?('z') && (Activity.keys.keys.include?(params['z']) || Activity.respond_to?(params['z'])) ? params['z'].to_sym : :type
    scale = params.has_key?('scale') && params['scale'] =~ /^[\d\.]+/ ? params['scale'].to_f : (y == :total_distance ? 0.000621371 : 1)

    results = Hash.new
    logged_in_user.activities.each do |activity|
      datestamp = activity.start_time.to_i / bucket_size
      z_value = activity.send(z)
      y_value = activity.send(y) * scale
      results[z_value] ||= Hash.new
      results[z_value][datestamp] ||= 0
      results[z_value][datestamp] += y_value
    end
    #get max number of elements
    min_date = nil
    max_date = nil
    results.each do |z_value,data|
      data.each do |date,value|
        min_date = date if min_date.nil? || date < min_date
        max_date = date if max_date.nil? || date > max_date
      end
    end
    result = "key,value,date\n"
    results.each do |z_value,data|
      data.each do |date, value|
        results[z_value][date] = "#{z_value},#{value},#{Time.at(date * bucket_size).strftime('%Y-W%U-0')}\n"
      end
      (min_date..max_date).each do |date|
        results[z_value][date] ||= "#{z_value},0,#{Time.at(date * bucket_size).strftime('%Y-W%U-0')}\n"
        result << results[z_value][date]
      end
    end
    result
  end

  run! if app_file == $0
end
