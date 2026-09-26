require "test_helper"

class LandlordDashboardBroadcastJobTest < ActiveJob::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901230001")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Job Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
  end

  test "enqueues landlord dashboard broadcast job" do
    assert_enqueued_with(job: LandlordDashboardBroadcastJob, args: [ @house.id ]) do
      LandlordDashboardBroadcastJob.perform_later(@house.id)
    end
  end

  test "performs landlord dashboard broadcast without errors" do
    assert_nothing_raised do
      perform_enqueued_jobs do
        LandlordDashboardBroadcastJob.perform_later(@house.id)
      end
    end
  end

  test "gracefully handles nonexistent house_id" do
    assert_nothing_raised do
      perform_enqueued_jobs do
        LandlordDashboardBroadcastJob.perform_later(999_999_999)
      end
    end
  end
end
