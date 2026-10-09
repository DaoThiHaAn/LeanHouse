# frozen_string_literal: true

module AdminPortal
  class DashboardController < BaseController
    def show
      @stats = DashboardStatsService.call
    end

    def recent_users
      @recent_users = DashboardStatsService.recent_users(10)
    end

    def recent_houses
      @recent_houses = DashboardStatsService.recent_houses(10)
    end
  end
end
