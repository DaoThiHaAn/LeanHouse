class PhoneRecycling
  Result = Struct.new(:success, :user, :error, :old_tel, keyword_init: true) do
    def success?
      success == true
    end
  end

  def initialize(user, admin: nil, reason: nil)
    @user = user
    @admin = admin
    @reason = reason
  end

  def call
    return Result.new(success: false, user: @user, error: "User not found") unless @user
    return Result.new(success: false, user: @user, error: "Phone number has already been recycled") if @user.tel_recycled?

    original_tel = @user.tel
    recycled_tel = "#{original_tel}_recycled_#{@user.id}_#{Time.current.to_i}"

    ActiveRecord::Base.transaction do
      @user.update!(
        tel: recycled_tel,
        is_active: false,
        tel_verified_at: nil,
        otp_code: nil,
        otp_sent_at: nil
      )

      admin_info = @admin ? "Admin ##{@admin.id} (#{@admin.fullname})" : "System"
      reason_info = @reason.presence || "Recycled SIM / Phone re-assignment"
      Rails.logger.info "[PhoneRecycling] User ##{@user.id} (#{@user.fullname}) phone #{original_tel} recycled by #{admin_info}. Reason: #{reason_info}"
    end

    Result.new(success: true, user: @user, error: nil, old_tel: original_tel)
  rescue ActiveRecord::RecordInvalid, StandardError => e
    Rails.logger.error "[PhoneRecycling] Failed to recycle phone for User ##{@user&.id}: #{e.message}"
    Result.new(success: false, user: @user, error: e.message, old_tel: @user&.tel)
  end
end
