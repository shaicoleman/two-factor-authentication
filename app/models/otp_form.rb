class OtpForm
  include ActiveModel::Model

  attr_accessor :otp_attempt
  attr_accessor :remember_me

  validates :otp_attempt, presence: true, length: { is: 6 }, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
