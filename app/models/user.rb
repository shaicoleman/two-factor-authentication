class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :masqueradable, :registerable, :recoverable, :rememberable, :trackable,
         :validatable, :omniauthable

  has_many :notifications, foreign_key: :recipient_id
  has_many :services

  attr_encrypted :otp_secret, key: Rails.application.secrets.otp_key,
    mode: :per_attribute_iv_and_salt unless self.attr_encrypted?(:otp_secret)

  attr_encrypted :otp_backup_codes, key: Rails.application.secrets.otp_key,
    marshal: true, marshaler: JSON,
    mode: :per_attribute_iv_and_salt unless self.attr_encrypted?(:otp_backup_codes)
end
