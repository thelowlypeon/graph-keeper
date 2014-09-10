module BabyTooth
  class User
    @activities = {}

    def fitness_activities(_pages=[0])
      _page = _pages.is_a?(Integer) ? _pages : _pages.max

      @activities = Hash.new if @activities.nil?
      @activities[_page] = [] unless @activities.has_key?(_page)
      if @activities[_page].empty?
        uri = '/fitnessActivities'
        (0.._page).each do |page|
          if uri.is_a?(String)
            feed = BabyTooth::FitnessActivityFeed.new(self.access_token, uri)
            uri = feed.body.has_key?('next') ? feed['next'] : false
            @activities[page] = feed.fitness_activities
          else
            @activities[_page] = []
            break
          end
        end
      end

      @activities.values_at(*_pages).flatten
    end

  end
end
