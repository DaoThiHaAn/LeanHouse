class ContractOverdueCloseJob < ApplicationJob
  queue_as :default

  def perform
    ContractClosing.close_overdue!
    GC.start
  end
end
