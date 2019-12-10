class Users::TwoFactorsController < Devise::SessionsController
  skip_before_action :require_no_authentication
  before_action :authenticate_user!

  def new
    @otp_secret = User.generate_otp_secret
    render 'devise/two_factors/new'
  end

  def edit
    render 'devise/two_factors/edit'
  end
end
