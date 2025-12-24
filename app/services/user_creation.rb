class UserCreation
  def initialize(user_params)
    @user = User.new(user_params)
  end

  def call
    ActiveRecord::Base.transaction do
      @user.save!
      if @user.role == "landlord"
        Landlord.create!(user: @user, tel: @user.tel)
      else
        Tenant.create!(user: @user, tel: @user.tel)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  attr_reader :user
end
