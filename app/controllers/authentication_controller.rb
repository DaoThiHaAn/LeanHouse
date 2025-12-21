class AuthenticationController < ApplicationController
  def sign_up
    @user = User.new
  end

  def log_in
  end

  def log_out
    # TODO
  end
end
