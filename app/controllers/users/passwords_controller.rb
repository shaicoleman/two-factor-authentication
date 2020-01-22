# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def update
    super
    return unless resource.valid? && resource.password.present?

    OtpService.reset_attempts(user: resource)
    sign_out if Devise.sign_in_after_reset_password
  end
end
