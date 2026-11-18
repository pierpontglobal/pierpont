class CleanupGuestsJob < ApplicationJob
  queue_as :default

  def perform
    User.where(demo: true, bot: false).where("created_at < ?", 1.day.ago).find_each(&:destroy)
  end
end
