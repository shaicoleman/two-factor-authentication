class AddDeviseTwoFactorBackupableToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :otp_backup_codes, :string, array: true
    add_column :users, :failed_backup_code_attempts, :integer, default: 0, null: false
  end
end
