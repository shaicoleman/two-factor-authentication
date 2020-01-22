# frozen_string_literal: true

class AddDeviseTwoFactorToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :otp_secret_ciphertext, :string
    add_column :users, :otp_backup_codes_ciphertext, :string

    add_column :users, :otp_consumed_timestep, :integer
    add_column :users, :otp_required_for_login, :boolean
    add_column :users, :otp_updated_at, :datetime

    add_column :users, :otp_backup_codes_updated_at, :datetime
    add_column :users, :otp_grace_period_started_at, :datetime

    add_column :users, :otp_failed_attempts, :integer, default: 0, null: false
    add_column :users, :otp_failed_backup_code_attempts, :integer, default: 0, null: false
  end
end
