# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  skip_before_action :require_2fa
  skip_before_action :authenticate_user!

  # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    if user_signed_in? && current_user&.otp_required_for_login
      otp_user_id = current_user.id
      sign_out
      session[:otp_user_id] = otp_user_id
      redirect_to(:new_auth_otp_session)
    else
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
