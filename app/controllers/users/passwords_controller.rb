# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def update
    super
    if resource.valid? && resource.password.present?
      OtpService.reset_attempts(user: resource)
    end
  end
end
