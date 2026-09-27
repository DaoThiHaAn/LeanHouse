# frozen_string_literal: true

class ServiceUsageLogConfirmer
  class << self
    def confirm(log:, user:)
      log.update!(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by: user
      )
      notify_tenants(log)
    end

    def confirm_all(scope:, user:)
      unconfirmed_scope = scope.unconfirmed
      logs_to_confirm = unconfirmed_scope.to_a
      unconfirmed_scope.update_all(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by_id: user.id
      )
      logs_to_confirm.each { |log| notify_tenants(log) }
      logs_to_confirm.size
    end

    private

    def notify_tenants(log)
      tenants = log.room.active_staying_tenant_users
      return if tenants.empty?

      ServiceUsageLogConfirmedNotifier.with(log: log).deliver_later(tenants)
    end
  end
end
