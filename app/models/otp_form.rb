class OtpForm < ActiveModelForm
  attr_accessor :otp_attempt
  attr_accessor :remember_me

  before_validation :strip_whitespace
  validates :otp_attempt, presence: true, length: { is: 6 }, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def strip_whitespace
    otp_attempt.remove!(/\s+/)
  end
end
