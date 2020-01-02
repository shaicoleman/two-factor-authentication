# frozen_string_literal: true

class Auth::TwoFactorsController < ApplicationController
  skip_before_action :require_2fa

  def new
    @enforcement_status, @deadline = OtpService.check_enforcement_status(user: current_user)
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
    session[:otp_enforcement] = :already_enabled

    redirect_to :auth_backup_codes
  end

  def edit
    return redirect_to :new_auth_two_factors unless current_user.otp_required_for_login
  end

  def destroy
    current_user.update!(otp_required_for_login: false, otp_secret: nil, otp_consumed_timestep: nil, otp_updated_at: Time.now.utc)
    redirect_to :edit_user_registration
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end
