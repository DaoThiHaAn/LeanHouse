require "test_helper"

class PhoneRecyclingTest < ActiveSupport::TestCase
  def setup
    @admin = Admin.create!(
      email: "admin_test_recycle@leanhouse.vn",
      fullname: "Recycle Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @user = User.create!(
      fullname: "Old Phone Owner",
      tel: "0912345678",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "123 Nguyen Trai, Q5",
      role: "landlord",
      is_active: true,
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
  end

  test "successfully recycles phone number and locks old account" do
    original_tel = @user.tel

    result = PhoneRecycling.new(@user, admin: @admin, reason: "New owner bought SIM").call

    assert result.success?
    assert_equal original_tel, result.old_tel

    @user.reload
    assert_not @user.is_active?
    assert_nil @user.tel_verified_at
    assert_nil @user.otp_code
    assert @user.tel_recycled?
    assert_equal original_tel, @user.display_tel
    assert_includes @user.tel, "#{original_tel}_recycled_"
  end

  test "allows new user to register with recycled phone number" do
    original_tel = @user.tel

    result = PhoneRecycling.new(@user, admin: @admin).call
    assert result.success?

    # New user registers with the exact same phone number and role
    new_user = User.new(
      fullname: "New Phone Owner",
      tel: original_tel,
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Le Duan, Q1",
      role: "landlord",
      terms_accepted: "1"
    )

    assert new_user.valid?(:create), "New user should be valid with recycled phone number: #{new_user.errors.full_messages}"
    assert new_user.save
    assert_equal original_tel, new_user.tel
  end

  test "fails when trying to recycle already recycled phone" do
    result1 = PhoneRecycling.new(@user, admin: @admin).call
    assert result1.success?

    result2 = PhoneRecycling.new(@user, admin: @admin).call
    assert_not result2.success?
    assert_includes result2.error, "already been recycled"
  end

  test "preserves user associations and data integrity when phone is recycled" do
    house = House.create!(
      landlord: @landlord,
      name: "Old House",
      mode: :room,
      address_l1: "789 Tran Hung Dao",
      address_l2: "Ward 5",
      address_l3: "District 5",
      floors_count: 1,
      inv_creation_date: 1
    )

    result = PhoneRecycling.new(@user, admin: @admin).call
    assert result.success?

    @user.reload
    assert_equal 1, House.where(landlord_id: @user.id).count
    assert_equal house.id, House.find_by(landlord_id: @user.id).id
  end
end
