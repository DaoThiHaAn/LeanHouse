class SyncVietqrBanksJob < ApplicationJob
  queue_as :default

  def perform
    Bank.sync_from_vietqr!
  end
end
