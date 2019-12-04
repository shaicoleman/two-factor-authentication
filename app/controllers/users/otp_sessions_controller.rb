class Users::OtpSessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token

  def new
    return respond_with resource, location: after_sign_in_path_for(resource) if user_signed_in?
    return redirect_to(new_user_session_path) unless session[:otp_user_id]

    @otp_form = OtpForm.new

    render 'devise/otp_sessions/new'
  end

  # # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  def create
    @otp_form = OtpForm.new
    @otp_form.otp_attempt = params[:otp_form].require(:otp_attempt)

    self.resource = User.find_by(id: session[:otp_user_id])
    return redirect_to(new_user_session_path) unless self.resource.present?

    sign_out
    sign_in(resource_name, resource)
    set_flash_message!(:notice, :signed_in)

    respond_with resource, location: after_sign_in_path_for(resource)
  end

  #   self.resource = warden.authenticate!(auth_options)
  #   set_flash_message!(:notice, :signed_in)
  #   sign_in(resource_name, resource)
  #   if user_signed_in? && current_user&.attributes['otp_required_for_login']
  #     current_user_id = current_user.id
  #     sign_out
  #     session[:otp_user_id] = current_user_id
  #     return redirect_to(:new_otp_session)
  #   else
  #     return respond_with resource, location: after_sign_in_path_for(resource)
  #   end
  # end
end
