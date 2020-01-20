# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  has_many :notifications, foreign_key: :recipient_id
  has_many :services

  attr_encrypted :otp_secret,       key: Digest::SHA256.digest(Rails.application.secrets.encryption_key)
  attr_encrypted :otp_backup_codes, key: Digest::SHA256.digest(Rails.application.secrets.encryption_key),
                                    marshal: true, marshaler: JSON
end
