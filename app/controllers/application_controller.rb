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
    return if current_user.otp_required_for_login?
    return unless OtpService::REQUIRE_2FA

    current_user.update!(otp_grace_period_started_at: Time.now.utc) if current_user.otp_grace_period_started_at.blank?

    if Time.now.utc > current_user.otp_grace_period_started_at + OtpService::GRACE_PERIOD
      return redirect_to(:new_auth_two_factors)
    end
  end
end
