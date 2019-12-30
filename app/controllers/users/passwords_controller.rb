# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def update
    super
    resource.update!(failed_otp_attempts: 0, failed_backup_code_attempts: 0) if resource.valid? && resource.password.present?
  end
end
