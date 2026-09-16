# frozen_string_literal: true

class AccountDeletion
  Result = Struct.new(:success, :error, :blockers, keyword_init: true) do
    def success?
      success == true
    end
  end

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return Result.new(success: false, error: :user_not_found) unless @user

    check = AccountDeletionCheck.call(@user)
    unless check.can_delete?
      return Result.new(success: false, error: :cannot_delete, blockers: check.blockers)
    end

    ActiveRecord::Base.transaction do
      @user.discard!
    end

    Result.new(success: true)
  rescue StandardError => e
    Rails.logger.error "[AccountDeletion] Failed to delete user ##{@user.id}: #{e.message}"
    Result.new(success: false, error: e.message)
  end
end
