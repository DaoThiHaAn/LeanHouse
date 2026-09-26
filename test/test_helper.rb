require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  skip "/test/"
  skip "/config/"
  skip "/db/"

  # Group code into clean tabs in coverage/index.html
  group "Models", "app/models"
  group "Services", "app/services"
  group "Controllers", "app/controllers"
  group "Helpers", "app/helpers"
  group "Jobs", "app/jobs"
  group "Notifiers", "app/notifiers"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel
    parallelize(workers: :number_of_processors)

    def create_landlord(tel: "0901234567", password: "Password123", fullname: "Nguyen Van Chu Nha")
      user = User.create!(
        fullname: fullname,
        tel: tel,
        sex: "M",
        bday: 25.years.ago.to_date,
        address: "123 Le Loi, Quan 1, TP.HCM",
        role: "landlord",
        password: password,
        password_confirmation: password,
        terms_accepted: "1",
        tel_verified_at: Time.current,
        is_active: true
      )
      Landlord.create!(id: user.id)
      user
    end

    def create_tenant(tel: "0907654321", password: "Password123", fullname: "Tran Thi Nguoi Thue")
      user = User.create!(
        fullname: fullname,
        tel: tel,
        sex: "F",
        bday: 22.years.ago.to_date,
        address: "456 Nguyen Trai, Quan 5, TP.HCM",
        role: "tenant",
        password: password,
        password_confirmation: password,
        terms_accepted: "1",
        tel_verified_at: Time.current,
        is_active: true
      )
      Tenant.create!(id: user.id)
      user
    end
  end
end
