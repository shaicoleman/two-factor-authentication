class User < ApplicationRecord
  devise :two_factor_authenticatable, otp_secret_encryption_key: Rails.application.secrets.otp_key,
         otp_allowed_drift: 30, otp_secret_length: 32

  devise :two_factor_backupable, otp_backup_code_length: 16, otp_number_of_backup_codes: 5


  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :masqueradable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  has_many :notifications, foreign_key: :recipient_id
  has_many :services

  # OTP will be checked through the controler
  def otp_required_for_login
    false
  end
end
