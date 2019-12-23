# frozen_string_literal: true

class Users::OtpSessionsController < Devise::SessionsController
  def new
    if user_signed_in?
      return respond_with resource, location: after_sign_in_path_for(resource)
    end
    return redirect_to(new_user_session_path) unless session[:otp_user_id]

    @otp_form = OtpForm.new

    render 'devise/otp_sessions/new'
  end

  # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  # and https://github.com/tinfoil/devise-two-factor/blob/v3.1.0/lib/devise_two_factor/models/two_factor_authenticatable.rb
  def create
    @otp_form = OtpForm.new(otp_form_params)

    self.resource = User.find_by(id: session[:otp_user_id])
    return redirect_to(new_user_session_path) unless resource.present?
    return render 'devise/otp_sessions/new' unless @otp_form.valid?

    response = OtpService.attempt_otp(user: self.resource, otp_attempt: @otp_form.otp_attempt)
    unless response == :success
      @otp_form.errors.add(:otp_attempt, response)
      return render 'devise/otp_sessions/new'
    end

    sign_out
    sign_in(resource_name, resource)
    set_flash_message!(:notice, :signed_in)

    respond_with resource, location: after_sign_in_path_for(resource)
  end

  private

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end
