require "test_helper"
require "minitest/mock"

class SyncVietqrBanksJobTest < ActiveJob::TestCase
  test "perform calls Bank.sync_from_vietqr!" do
    called = false
    Bank.stub :sync_from_vietqr!, -> { called = true; 1 } do
      SyncVietqrBanksJob.perform_now
    end
    assert called
  end
end
