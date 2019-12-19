class AddDeviseTwoFactorToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :encrypted_otp_secret, :string
    add_column :users, :encrypted_otp_secret_iv, :string
    add_column :users, :encrypted_otp_secret_salt, :string
    add_column :users, :consumed_timestep, :integer
    add_column :users, :otp_required_for_login, :boolean
    add_column :users, :failed_otp_attempts, :integer, default: 0, null: false
    add_column :users, :otp_updated_at, :datetime
    add_column :users, :password_changed_at, :datetime
  end
end
