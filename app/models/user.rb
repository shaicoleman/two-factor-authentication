class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :masqueradable, :registerable, :recoverable, :rememberable, :trackable,
         :validatable, :omniauthable

  has_many :notifications, foreign_key: :recipient_id
  has_many :services

  attr_encrypted :otp_secret,       key: Digest::SHA256.digest(Rails.application.secrets.otp_key)
  attr_encrypted :otp_backup_codes, key: Digest::SHA256.digest(Rails.application.secrets.otp_key),
                                    marshal: true, marshaler: JSON
end
