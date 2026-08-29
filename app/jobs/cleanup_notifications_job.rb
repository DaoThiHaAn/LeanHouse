class CleanupNotificationsJob < ApplicationJob
  queue_as :default

  def perform(read_days: 30, unread_days: 180)
    read_cutoff   = read_days.to_i.days.ago
    unread_cutoff = unread_days.to_i.days.ago

    # 1. Delete read notifications older than read_days
    Noticed::Notification.where.not(read_at: nil)
                         .where("created_at < ?", read_cutoff)
                         .in_batches(of: 1000) do |batch|
      batch.delete_all
    end

    # 2. Delete unread notifications older than unread_days
    Noticed::Notification.where(read_at: nil)
                         .where("created_at < ?", unread_cutoff)
                         .in_batches(of: 1000) do |batch|
      batch.delete_all
    end

    # 3. Clean up orphaned events (events with no corresponding notifications remaining)
    Noticed::Event.where.not(id: Noticed::Notification.select(:event_id))
                  .in_batches(of: 1000) do |batch|
      batch.delete_all
    end
  end
end
