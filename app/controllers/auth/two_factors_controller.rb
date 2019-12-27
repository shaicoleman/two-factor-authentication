class Auth::TwoFactorsController < ApplicationController
  def new
    @otp_secret = OtpService.generate_otp_secret(user: current_user)
    @otp_form = OtpForm.new
  end

  def create
    @otp_form = OtpForm.new(otp_form_params)
    return render :new unless @otp_form.valid?

    response = OtpService.attempt_otp(user: current_user, otp_attempt: @otp_form.otp_attempt, ignore_failed: true)
    unless response == :success
      @otp_form.errors.add(:otp_attempt, response)
      return render :new
    end
    current_user.update!(otp_required_for_login: true, otp_updated_at: Time.now.utc)

    redirect_to :auth_backup_codes
  end

  def edit
  end

  def destroy
    current_user.update!(otp_required_for_login: false, otp_secret: nil, consumed_timestep: nil, otp_updated_at: Time.now.utc)
    redirect_to :edit_user_registration
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end