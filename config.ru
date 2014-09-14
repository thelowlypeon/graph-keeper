# encoding: UTF-8
require 'dotenv'
Dotenv.load

require 'baby_tooth'
BabyTooth.configure do |config|
  config.access_token_url  = "http://runkeeper.com/apps/token"
  config.authorization_url = "http://runkeeper.com/apps/authorize"
  config.client_id         = ENV['RUNKEEPER_CLIENT_ID']
  config.client_secret     = ENV['RUNKEEPER_CLIENT_SECRET']
  config.redirect_uri      = ENV['RUNKEEPER_REDIRECT_URI']
  config.site              = "http://api.runkeeper.com"
end

require 'mongo_mapper'
url = URI(ENV['MONGOMAPPER_CONFIG'])
::MongoMapper.connection = Mongo::Connection.new(url.host, url.port)
::MongoMapper.database = url.path.gsub(/^\//, '')
::MongoMapper.database.authenticate(url.user, url.password) if url.user && url.password

require './application.rb'
run GraphKeeper
