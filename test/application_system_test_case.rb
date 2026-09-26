require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  def sign_in_as(user, password: "Password123")
    visit login_path

    if user.landlord?
      find("[data-role-selector-value='landlord']", wait: 5).click
    else
      find("[data-role-selector-value='tenant']", wait: 5).click
    end

    fill_in "user[tel]", with: user.tel
    fill_in "user[password]", with: password

    find("button[type='submit']").click
  end
end
