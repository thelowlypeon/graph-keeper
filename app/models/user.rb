module BabyTooth
  class Client
    def accept
      "application/vnd.com.runkeeper.#{resource_class_name}+json"
    end

    protected
      def retrieve_body
        response = connection.get(path) do |request|
          request.headers['Authorization'] = "Bearer #{access_token}"
          request.headers['Accept'] = accept
        end

        if response.body.is_a?(Hash)
          response.body
        else
          JSON.parse(response.body)
        end
      end
  end

  class User
    @activities = {}

    def to_hash
      {runkeeper_id:   self['userID'],
       name:           profile.name,
       small_picture:  profile.small_picture,
       medium_picture: profile.medium_picture,
       large_picture:  profile.large_picture,
       normal_picture: profile.normal_picture,
       elite:          profile.elite,
       gender:         profile.gender,
       profile_url:    profile.profile,
       birthday:       profile['birthday'],
       location:       profile['location']}
    end
  end
end

class User
  include MongoMapper::Document
  key :runkeeper_id,   Integer
  key :name,           String
  key :birthday,       Date
  key :small_picture,  String
  key :medium_picture, String
  key :large_picture,  String
  key :normal_picture, String
  key :location,       String
  key :elite,          Boolean, default: false
  key :gender,         String
  key :profile_url,    String
  key :last_fetch,     Time
  many :activities
  timestamps!

  def self.set_fetch_limit(limit)
    @@fetch_limit = limit
  end

  def self.find id
    self.where(runkeeper_id: id).first
  end

  def id
    self.runkeeper_id
  end

  def activities!(token)
    if can_fetch?
      uri = '/fitnessActivities'
      while uri != false
        feed = BabyTooth::FitnessActivities.new(token, uri)
        feed['items'].each do |activity_hash|
          if found = Activity.where(uri: activity_hash['uri']).first
            found.update_attributes!(activity_hash)
          else
            self.activities.create(activity_hash).save
          end
        end

        if feed.body.has_key?('next') && feed['next'] != ''
          uri = feed['next']
        else
          break
        end
      end
      self.last_fetch = Time.now
      self.save
    end

    self.activities
  end

  def can_fetch?
    self.last_fetch.nil? || Time.now - self.last_fetch > @@fetch_limit
  end
end
