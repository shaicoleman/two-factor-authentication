# frozen_string_literal: true

class Users::BackupCodeSessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token

  def new
    if user_signed_in?
      return respond_with resource, location: after_sign_in_path_for(resource)
    end
    return redirect_to(new_user_session_path) unless session[:otp_user_id]

    @backup_code_form = BackupCodeForm.new

    render 'devise/backup_code_sessions/new'
  end

  # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  # and https://github.com/tinfoil/devise-two-factor/blob/v3.1.0/lib/devise_two_factor/models/two_factor_authenticatable.rb
  def create
    @backup_code_form = BackupCodeForm.new(backup_code_form_params)

    self.resource = User.find_by(id: session[:otp_user_id])
    return redirect_to(new_user_session_path) unless resource.present?
    return render 'devise/backup_code_sessions/new' unless @backup_code_form.valid?

    response = OtpService.attempt_backup_code(user: self.resource, backup_code_attempt: @backup_code_form.backup_code_attempt)
    unless response == :success
      @backup_code_form.errors.add(:backup_code_attempt, response)
      return render 'devise/backup_code_sessions/new'
    end

    sign_out
    sign_in(resource_name, resource)
    set_flash_message!(:notice, :signed_in)

    respond_with resource, location: after_sign_in_path_for(resource)
  end

  private

  def backup_code_form_params
    params[:backup_code_form].permit(:backup_code_attempt)
  end
end
