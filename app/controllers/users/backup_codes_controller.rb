class Users::BackupCodesController < Devise::SessionsController
  skip_before_action :require_no_authentication
  before_action :authenticate_user!

  def index
    @backup_codes = OtpService.generate_backup_codes(user: current_user)
    render 'devise/backup_codes/index'
  end
end
