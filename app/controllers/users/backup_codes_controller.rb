class Users::BackupCodesController < Devise::SessionsController
  skip_before_action :require_no_authentication
  before_action :authenticate_user!

  def index
    @backup_codes = current_user.otp_backup_codes
    @backup_codes = OtpService.generate_backup_codes(user: current_user) if @backup_codes.blank?
    render 'devise/backup_codes/index'
  end

  def create
    OtpService.generate_backup_codes(user: current_user)
    redirect_to action: :index
  end
end
