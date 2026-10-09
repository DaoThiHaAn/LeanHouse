# frozen_string_literal: true

module AdminPortal
  class DashboardStatsService
    Result = Data.define(
      :total_landlords,
      :active_landlords,
      :total_tenants,
      :active_tenants,
      :total_houses,
      :room_houses,
      :bed_houses,
      :active_contracts,
      :new_contracts_this_month,
      :new_users_this_month,
      :new_landlords_this_month,
      :new_tenants_this_month,
      :new_houses_this_month,
      :new_room_houses_this_month,
      :new_bed_houses_this_month,
      :recent_users,
      :recent_houses
    ) do
      def locked_landlords
        total_landlords - active_landlords
      end

      def locked_tenants
        total_tenants - active_tenants
      end
    end

    def self.call(target_date: Date.current, include_recent: false)
      new(target_date: target_date, include_recent: include_recent).call
    end

    def self.recent_users(limit = 10)
      User.kept.order(created_at: :desc).limit(limit)
    end

    def self.recent_houses(limit = 10)
      House.where(is_deleted: false).order(created_at: :desc).limit(limit)
    end

    def initialize(target_date: Date.current, include_recent: false)
      @target_date = target_date
      @include_recent = include_recent
    end

    def call
      month_start = target_date.beginning_of_month.to_time
      month_end = target_date.end_of_month.to_time

      user_stats = User.kept.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COUNT(*) FILTER (WHERE role = 'landlord') AS total_landlords,
           COUNT(*) FILTER (WHERE role = 'landlord' AND is_active = true) AS active_landlords,
           COUNT(*) FILTER (WHERE role = 'tenant') AS total_tenants,
           COUNT(*) FILTER (WHERE role = 'tenant' AND is_active = true) AS active_tenants,
           COUNT(*) FILTER (WHERE created_at >= :start_time AND created_at <= :end_time) AS new_users_this_month,
           COUNT(*) FILTER (WHERE role = 'landlord' AND created_at >= :start_time AND created_at <= :end_time) AS new_landlords_this_month,
           COUNT(*) FILTER (WHERE role = 'tenant' AND created_at >= :start_time AND created_at <= :end_time) AS new_tenants_this_month",
          { start_time: month_start, end_time: month_end }
        ])
      ).take

      house_stats = House.where(is_deleted: false).select(
        ActiveRecord::Base.sanitize_sql_array([
          "COUNT(*) AS total_houses,
           COUNT(*) FILTER (WHERE mode = 'room') AS room_houses,
           COUNT(*) FILTER (WHERE mode = 'bed') AS bed_houses,
           COUNT(*) FILTER (WHERE created_at >= :start_time AND created_at <= :end_time) AS new_houses_this_month,
           COUNT(*) FILTER (WHERE mode = 'room' AND created_at >= :start_time AND created_at <= :end_time) AS new_room_houses_this_month,
           COUNT(*) FILTER (WHERE mode = 'bed' AND created_at >= :start_time AND created_at <= :end_time) AS new_bed_houses_this_month",
          { start_time: month_start, end_time: month_end }
        ])
      ).take

      contract_stats = Contract.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COUNT(*) FILTER (WHERE due_date >= :today AND end_date IS NULL) AS active_contracts,
           COUNT(*) FILTER (WHERE created_at >= :start_time AND created_at <= :end_time) AS new_contracts_this_month",
          { today: Date.current, start_time: month_start, end_time: month_end }
        ])
      ).take

      Result.new(
        total_landlords: user_stats.total_landlords.to_i,
        active_landlords: user_stats.active_landlords.to_i,
        total_tenants: user_stats.total_tenants.to_i,
        active_tenants: user_stats.active_tenants.to_i,
        total_houses: house_stats.total_houses.to_i,
        room_houses: house_stats.room_houses.to_i,
        bed_houses: house_stats.bed_houses.to_i,
        active_contracts: contract_stats.active_contracts.to_i,
        new_contracts_this_month: contract_stats.new_contracts_this_month.to_i,
        new_users_this_month: user_stats.new_users_this_month.to_i,
        new_landlords_this_month: user_stats.new_landlords_this_month.to_i,
        new_tenants_this_month: user_stats.new_tenants_this_month.to_i,
        new_houses_this_month: house_stats.new_houses_this_month.to_i,
        new_room_houses_this_month: house_stats.new_room_houses_this_month.to_i,
        new_bed_houses_this_month: house_stats.new_bed_houses_this_month.to_i,
        recent_users: include_recent ? self.class.recent_users : [],
        recent_houses: include_recent ? self.class.recent_houses : []
      )
    end

    private

    attr_reader :target_date, :include_recent
  end
end
