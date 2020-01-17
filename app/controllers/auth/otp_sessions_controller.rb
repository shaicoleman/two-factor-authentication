# frozen_string_literal: true

class Auth::OtpSessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    return redirect_to(after_sign_in_path_for(resource)) if user_signed_in?
    return redirect_to(:new_user_session) unless session[:otp_user_id]

    user = User.find_by(id: session[:otp_user_id])
    @otp_form = OtpForm.new
    @attempts_remaining = OtpService.otp_attempts_remaining(user: user)
  end

  def create
    @otp_form = OtpForm.new(otp_form_params)

    user = User.find_by(id: session[:otp_user_id])
    return redirect_to(:new_user_session) unless user.present?
    unless @otp_form.valid?
      @attempts_remaining = OtpService.otp_attempts_remaining(user: user)
      return render :new
    end

    response = OtpService.attempt_otp(user: user, otp_attempt: @otp_form.otp_attempt)
    unless response == :success
      @otp_form.errors.add(:otp_attempt, response)
      @attempts_remaining = OtpService.otp_attempts_remaining(user: user)
      return render :new
    end

    sign_out
    sign_in(User, user)
    redirect_to after_sign_in_path_for(user)
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt, :remember_me)
  end
end
