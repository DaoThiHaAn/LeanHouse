module AdminPortal
  class NotificationsController < BaseController
    def index
      @level = params[:level].presence_in(%w[info warning urgent])
      @audience = params[:audience].presence_in(%w[all landlords tenants])
      @from_date = params[:from_date].presence
      @to_date = params[:to_date].presence

      scope = Noticed::Event.where(type: "CustomAnnouncementNotifier")
      scope = scope.where("params->>'level' = ?", @level) if @level.present?
      scope = scope.where("params->>'target_audience' = ?", @audience) if @audience.present?

      if @from_date.present? || @to_date.present?
        begin
          start_time = @from_date.present? ? Date.parse(@from_date.to_s).beginning_of_day : nil
          end_time = @to_date.present? ? Date.parse(@to_date.to_s).end_of_day : nil

          if start_time && end_time
            start_time, end_time = end_time.beginning_of_day, start_time.end_of_day if start_time > end_time
            scope = scope.where(created_at: start_time..end_time)
          elsif start_time
            scope = scope.where("created_at >= ?", start_time)
          elsif end_time
            scope = scope.where("created_at <= ?", end_time)
          end
        rescue Date::Error, ArgumentError
          # ignore invalid dates
        end
      end

      @total_broadcasts = scope.count
      @total_recipients_delivered = scope.sum(:notifications_count).to_i

      @events = scope.order(created_at: :desc).page(params[:page]).per(15)

      if turbo_frame_request?
        render partial: "table"
      end
    end

    def new
      @form = BroadcastNotificationForm.new
      load_audience_counts
    end

    def create
      @form = BroadcastNotificationForm.new(broadcast_notification_params)

      unless @form.valid?
        flash.now[:alert] = t("admin.notifications.missing_fields")
        load_audience_counts
        return render :new, status: :unprocessable_entity
      end

      if @form.recipient_count.zero?
        flash.now[:alert] = t("admin.notifications.no_recipients")
        load_audience_counts
        return render :new, status: :unprocessable_entity
      end

      # Idempotency guard: prevent duplicate broadcast within a 5-second window
      recent_duplicate = Noticed::Event.where(type: "CustomAnnouncementNotifier", record: current_admin)
                                       .where("created_at >= ?", 5.seconds.ago)
                                       .where("params->>'title' = ? AND params->>'target_audience' = ?", @form.title, @form.target_audience)
                                       .exists?

      if recent_duplicate
        return redirect_to admin_notifications_path, notice: t("admin.notifications.create_success", count: @form.recipient_count)
      end

      BroadcastCustomNotificationJob.perform_later(
        admin_id: current_admin.id,
        target_audience: @form.target_audience,
        title: @form.title,
        message: @form.message,
        url: @form.url,
        level: @form.level
      )

      redirect_to admin_notifications_path, notice: t("admin.notifications.create_success", count: @form.recipient_count)
    end

    def show
      @event = Noticed::Event.where(type: "CustomAnnouncementNotifier").find(params[:id])
      @notifications = @event.notifications.includes(:recipient).order(created_at: :desc).page(params[:page]).per(25)
      @read_count = @event.notifications.where.not(read_at: nil).count
      @total_count = @event.notifications_count.to_i
      @read_rate = @total_count.positive? ? ((@read_count.to_f / @total_count) * 100).round(1) : 0.0
    end

    private

    def broadcast_notification_params
      raw = params.key?(:broadcast_notification) ? params.require(:broadcast_notification) : params
      raw.permit(:target_audience, :title, :message, :url, :level)
    end

    def load_audience_counts
      @all_users_count = User.active.where.not(role: :admin).count
      @landlords_count = User.active.where(role: :landlord).count
      @tenants_count = User.active.where(role: :tenant).count
    end
  end
end
