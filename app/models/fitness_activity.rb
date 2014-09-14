module BabyTooth
  class FitnessActivities < Client
    def accept
      "application/vnd.com.runkeeper.FitnessActivityFeed+json" #don't get all the GPS coords
    end
  end

  class FitnessActivity
    def accept
      "application/vnd.com.runkeeper.FitnessActivitySummary+json" #don't get all the GPS coords
    end

    def [](key)
      if self.respond_to? key
        self.send(key) 
      else
        super
      end
    end

    def initalize(access_token, params)
      if params.is_a? String
        super
      else
        super access_token, params['uri']
        self.body = params
      end
    end

    def distance unit = nil
      GraphKeeper.distance self['total_distance'], unit
    end

    def timestamp
      begin
        Time.strptime(self["start_time"],"%a, %e %b %Y %H:%M:%S")
      rescue
        "unable to parse #{self["start_time"]}"
      end
    end

    def runkeeper_id
      /\/?fitnessActivities\/([\d]+)\/?/.match(self['uri'])[1]
    end

    def to_hash
      {runkeeper_id:   self.runkeeper_id,
       user_id:        self['userID'],
       uri:            self['uri'], #api uri
       url:            self['activity'], #runkeeper url
       type:           self['type'],
       duration:       self['duration'],
       start_time:     timestamp,
       total_distance: self['total_distance'],
       total_calories: self['total_calories']}
    end
  end
end

class Activity
  include MongoMapper::Document
  key :runkeeper_id, Integer
  key :uri, String
  key :url, String
  key :type, String
  key :duration, Float
  key :start_time, Time
  key :total_distance, Float
  key :total_calories, Float
  belongs_to :user

  def self.find id
    self.where(runkeeper_id: id).first
  end

  def id
    self.runkeeper_id
  end
end
