class Users::TwoFactorsController < Devise::SessionsController
  skip_before_action :require_no_authentication
  before_action :authenticate_user!

  def new
    @otp_secret = User.generate_otp_secret
    current_user.update!(otp_secret: @otp_secret)
    @otp_form = OtpForm.new
    render 'devise/two_factors/new'
  end

  def create
    @otp_form = OtpForm.new(otp_form_params)
    return render 'devise/two_factors/new' unless @otp_form.valid?

    response = OtpService.attempt_otp(user: current_user, otp_attempt: @otp_form.otp_attempt, ignore_failed: true)
    unless response == :success
      @otp_form.errors.add(:otp_attempt, response)
      return render 'devise/two_factors/new'
    end
    current_user.update!(otp_required_for_login: true)

    redirect_to :user_backup_codes
  end

  def edit
    render 'devise/two_factors/edit'
  end

  def destroy
    current_user.update!(otp_required_for_login: false)
    redirect_to :edit_user_registration
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end
