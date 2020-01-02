# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def update
    super
    if resource.valid? && resource.password.present?
      resource.update!(otp_failed_attempts: 0, otp_failed_backup_code_attempts: 0)
    end
  end
end
