class AddDeviseTwoFactorBackupableToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :encrypted_otp_backup_codes, :string
    add_column :users, :encrypted_otp_backup_codes_iv, :string
    add_column :users, :otp_backup_codes_updated_at, :datetime

    add_column :users, :failed_backup_code_attempts, :integer, default: 0, null: false
  end
end
