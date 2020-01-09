# frozen_string_literal: true

class Auth::BackupCodesController < ApplicationController
  FILENAME = 'two-factors-backup-codes.txt'

  def index
    OtpService.generate_backup_codes(user: current_user) if @current_user.otp_backup_codes.blank?
    @backup_codes = OtpService.format_backup_codes(current_user.otp_backup_codes)
  end

  def create
    OtpService.generate_backup_codes(user: current_user)
    redirect_to action: :index
  end

  def print
    @backup_codes = OtpService.format_backup_codes(current_user.otp_backup_codes)
    render layout: 'print'
  end

  def download
    @backup_codes = OtpService.format_backup_codes(current_user.otp_backup_codes)
    txt = render_to_string(template: 'auth/backup_codes/download.text')
    txt_crlf = txt.gsub(/\n/, "\r\n") # Only Windows 1809 and later supports UNIX line ending in Notepad
    send_data txt_crlf, type: 'text/plain; charset=UTF-8', filename: FILENAME
  end
end
