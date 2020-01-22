# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  has_many :notifications, foreign_key: :recipient_id
  has_many :services

  encrypts :otp_secret,       key: Rails.application.secrets.encryption_key
  encrypts :otp_backup_codes, key: Rails.application.secrets.encryption_key, type: :json
end
