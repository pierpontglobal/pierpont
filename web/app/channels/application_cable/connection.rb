module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Anonymous viewers still get live bids; Turbo stream names are signed.
    def connect
      self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user
    end
  end
end
