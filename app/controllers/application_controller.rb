# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :require_2fa
  before_action :authenticate_user!

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
  end

  def require_2fa
    return unless user_signed_in?

    is_first_request = session[:otp_enforcement].blank?
    enforcement_status = session[:otp_enforcement]&.to_sym || OtpService.check_enforcement_status(user: current_user)
    session[:otp_enforcement] ||= enforcement_status
    return unless enforcement_status == :enforced || (enforcement_status == :grace_period && is_first_request)

    redirect_to(:new_auth_two_factors)
  end
end
