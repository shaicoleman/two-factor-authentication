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
    enforcement_status = OtpService.check_enforcement_status(user: current_user)
    redirect_to(:new_auth_two_factors) if enforcement_status == :enforced
  end
end
