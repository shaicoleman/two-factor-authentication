class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token

  # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    if user_signed_in? && current_user&.attributes['otp_required_for_login']
      current_user_id = current_user.id
      sign_out
      session[:otp_user_id] = current_user_id
      byebug
      return redirect_to(:new_user_otp_session)
    else
      return respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
