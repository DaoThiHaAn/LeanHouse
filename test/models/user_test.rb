require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @landlord1 = User.create!(
      fullname: "Nguyen Van A",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "123 Street",
      tel_verified_at: Time.current
    )

    @landlord2 = User.create!(
      fullname: "Tran Van B",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "456 Street",
      tel_verified_at: Time.current
    )

    @tenant1 = User.create!(
      fullname: "Le Thi C",
      tel: "0911223344",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "789 Street",
      tel_verified_at: Time.current
    )
  end

  test "change_tel is invalid when new tel is the same as current tel" do
    validation_user = User.find(@landlord1.id)
    validation_user.tel = @landlord1.tel

    assert_not validation_user.valid?(:change_tel)
    assert_includes validation_user.errors[:tel], I18n.t("activerecord.errors.models.user.attributes.tel.same_as_current")
  end

  test "change_tel is invalid when new tel is already registered by another user in same role" do
    validation_user = User.find(@landlord1.id)
    validation_user.tel = @landlord2.tel

    assert_not validation_user.valid?(:change_tel)
    assert_includes validation_user.errors[:tel], I18n.t("activerecord.errors.models.user.attributes.tel.existed_acc")
  end

  test "change_tel is valid when new tel is registered by another user in a different role" do
    validation_user = User.find(@landlord1.id)
    validation_user.tel = @tenant1.tel

    assert validation_user.valid?(:change_tel)
  end

  test "change_tel is invalid when tel format is wrong or blank" do
    validation_user = User.find(@landlord1.id)

    validation_user.tel = "12345"
    assert_not validation_user.valid?(:change_tel)

    validation_user.tel = ""
    assert_not validation_user.valid?(:change_tel)
  end

  test "change_tel is valid when new tel is valid and unique in role" do
    validation_user = User.find(@landlord1.id)
    validation_user.tel = "0988776655"

    assert validation_user.valid?(:change_tel)
  end
end
