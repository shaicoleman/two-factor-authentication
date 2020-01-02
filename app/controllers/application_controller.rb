# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :require_2fa

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
  end

  def require_2fa
    return unless user_signed_in?

    enforcement_status, = OtpService.check_enforcement_status(user: current_user)
    session[:otp_enforcement] ||= enforcement_status
    # session[:otp_enforcement] returns a symbol when first set, and a string in subsequent requests
    # We only match against the :grace_period symbol so it will only redirect on the first request
    redirect_to(:new_auth_two_factors) if session[:otp_enforcement].in?(['enforced', :enforced, :grace_period])
  end
end
