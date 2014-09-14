class GraphKeeper
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
          redirect '/loading/'
        end
        if !logged_in_user
          raise "There was an error finding or create user #{user['userID']}"
        else
          logged_in_user
        end
      end
    end

    def bucket
      params['bucket'] ||= settings.default_bucket
    end

    def bucket_size
      case bucket
        when 'years'
          365 * 24 * 60 * 60
        when 'quarters'
          91 * 24 * 60 * 60
        when 'months'
          30 * 24 * 60 * 60
        when 'days'
          24 * 60 * 60
        else
          7 * 24 * 60 * 60
      end
    end

    def date_format(render_hidden = false)
      case bucket
        when 'years'
          "%Y-" + (render_hidden ? "1-1" : "%m-%d")
        when 'quarters'
          "%Y-%m-" + (render_hidden ? "1" : "%d")
        when 'months'
          "%Y-%m-" + (render_hidden ? "1" : "%d")
        when 'days'
          "%Y-%m-%d"
        else
          "%Y-%W-" + (render_hidden ? "0" : "%w")
      end
    end
  end
end
