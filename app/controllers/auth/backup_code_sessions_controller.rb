# frozen_string_literal: true

class Auth::BackupCodeSessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    return redirect_to(after_sign_in_path_for(resource)) if user_signed_in?
    return redirect_to(:new_user_session) unless session[:otp_user_id]

    user = User.find_by(id: session[:otp_user_id])
    @backup_code_form = BackupCodeForm.new
    @attempts_remaining = OtpService.backup_codes_attempts_remaining(user: user)
  end

  def create
    @backup_code_form = BackupCodeForm.new(backup_code_form_params)

    user = User.find_by(id: session[:otp_user_id])
    return redirect_to(:new_user_session) unless user.present?
    unless @backup_code_form.valid?
      @attempts_remaining = OtpService.backup_codes_attempts_remaining(user: user)
      return render :new
    end

    response = OtpService.attempt_backup_code(user: user, backup_code_attempt: @backup_code_form.backup_code_attempt)
    unless response == :success
      @backup_code_form.errors.add(:backup_code_attempt, response)
      @attempts_remaining = OtpService.backup_codes_attempts_remaining(user: user)
      return render :new
    end

    sign_out
    sign_in(User, user)
    redirect_to after_sign_in_path_for(user)
  end

  private

  def backup_code_form_params
    params[:backup_code_form].permit(:backup_code_attempt)
  end
end
