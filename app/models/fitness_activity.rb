module BabyTooth
  class FitnessActivity
    def [](key)
      if self.respond_to? key
        self.send(key) 
      else
        super
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
  end
end
