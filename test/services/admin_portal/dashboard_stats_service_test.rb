# frozen_string_literal: true

require "test_helper"

class AdminPortal::DashboardStatsServiceTest < ActiveSupport::TestCase
  test "calculates dashboard KPI statistics accurately" do
    result = AdminPortal::DashboardStatsService.call

    assert_kind_of AdminPortal::DashboardStatsService::Result, result
    assert_operator result.total_landlords, :>=, 0
    assert_operator result.active_landlords, :>=, 0
    assert_operator result.total_tenants, :>=, 0
    assert_operator result.active_tenants, :>=, 0
    assert_operator result.total_houses, :>=, 0
    assert_operator result.room_houses, :>=, 0
    assert_operator result.bed_houses, :>=, 0
    assert_operator result.active_contracts, :>=, 0
    assert_operator result.new_contracts_this_month, :>=, 0
    assert_operator result.new_users_this_month, :>=, 0
    assert_operator result.new_houses_this_month, :>=, 0
    assert_respond_to result.recent_users, :each
    assert_respond_to result.recent_houses, :each
    assert_equal (result.total_landlords - result.active_landlords), result.locked_landlords
    assert_equal (result.total_tenants - result.active_tenants), result.locked_tenants
  end

  test "recent_users returns latest kept users up to specified limit" do
    users = AdminPortal::DashboardStatsService.recent_users(5)
    assert_respond_to users, :each
    assert_operator users.size, :<=, 5
  end

  test "recent_houses returns latest non-deleted houses up to specified limit" do
    houses = AdminPortal::DashboardStatsService.recent_houses(5)
    assert_respond_to houses, :each
    assert_operator houses.size, :<=, 5
  end

  test "call with include_recent loads recent records into result" do
    result = AdminPortal::DashboardStatsService.call(include_recent: true)
    assert_respond_to result.recent_users, :each
    assert_respond_to result.recent_houses, :each
  end
end

