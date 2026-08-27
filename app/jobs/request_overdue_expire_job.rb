class RequestOverdueExpireJob < ApplicationJob
  queue_as :default

  def perform
    Request.expire_overdue!
  end
end
