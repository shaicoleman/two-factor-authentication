# frozen_string_literal: true

class Auth::OtpSessionsController < ApplicationController
  def new
    if user_signed_in?
      return respond_with resource, location: after_sign_in_path_for(resource)
    end
    return redirect_to(new_user_session_path) unless session[:otp_user_id]

    @otp_form = OtpForm.new
  end

  def create
    @otp_form = OtpForm.new(otp_form_params)

    user = User.find_by(id: session[:otp_user_id])
    return redirect_to(new_user_session_path) unless user.present?
    return render 'auth/otp_sessions/new' unless @otp_form.valid?

    response = OtpService.attempt_otp(user: user, otp_attempt: @otp_form.otp_attempt)
    unless response == :success
      @otp_form.errors.add(:otp_attempt, response)
      return render 'auth/otp_sessions/new'
    end

    sign_out
    sign_in(User, user)
    redirect_to after_sign_in_path_for(user), notice: I18n.t('devise.sessions.signed_in')
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end
