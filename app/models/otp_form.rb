# frozen_string_literal: true

class OtpForm < ActiveModelForm
  attr_accessor :otp_attempt
  attr_accessor :remember_me

  validates :otp_attempt, presence: true
end
