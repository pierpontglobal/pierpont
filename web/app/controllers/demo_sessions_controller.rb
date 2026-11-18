class DemoSessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.minute

  def create
    tag = SecureRandom.alphanumeric(4).upcase
    guest = User.create!(name: "Guest #{tag}", email_address: "guest-#{tag.downcase}-#{SecureRandom.hex(4)}@guests.pierpont.invalid",
                         password: SecureRandom.base58(24), demo: true)
    start_new_session_for guest
    back = params[:return_to].to_s
    redirect_to(back.start_with?("/") && !back.start_with?("//") ? back : root_path)
  end
end
