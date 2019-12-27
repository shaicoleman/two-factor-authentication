class OtpService
  ISSUER = 'OTPExample'
  DRIFT = 30.seconds

  def self.otp_qr_code(issuer: ISSUER, user:)
    otpauth_url = ROTP::TOTP.new(user.otp_secret, { issuer: issuer }).provisioning_uri(user.email)
    qrcode = nil
    # Find the highest level of error correction that fits a fixed size QR code
    %i[h q m l].each do |level|
      qrcode ||= suppress(RQRCodeCore::QRCodeRunTimeError) { RQRCode::QRCode.new(otpauth_url, level: level, size: 8) }
    end
    qrcode ||= RQRCode::QRCode.new(otpauth_url, level: :l)
    qrcode.as_svg(module_size: 4).html_safe
  end

  def self.attempt_otp(user:, otp_attempt:, ignore_failed: false)
    otp = ROTP::TOTP.new(user.otp_secret)
    matching_timestep = otp.verify(otp_attempt, drift_behind: DRIFT)&.div(otp.interval)
    unless matching_timestep
      user.class.increment_counter(:failed_otp_attempts, user.id) unless ignore_failed
      return I18n.t('errors.messages.invalid')
    end
    if user.consumed_timestep.to_i >= matching_timestep
      return I18n.t('auth.otp_sessions.otp_code_already_used_error')
    end
    user.update!(failed_otp_attempts: 0, failed_backup_code_attempts: 0, consumed_timestep: matching_timestep)
    :success
  end

  def self.attempt_backup_code(user:, backup_code_attempt:)
    if "!#{backup_code_attempt}".in?(user.otp_backup_codes)
      return I18n.t('auth.backup_code_sessions.backup_code_already_used_error')
    end
    unless backup_code_attempt.in?(user.otp_backup_codes)
      user.class.increment_counter(:failed_backup_code_attempts, user.id)
      return I18n.t('errors.messages.invalid')
    end

    backup_codes = user.otp_backup_codes.map { |code| (code == backup_code_attempt ? "!#{code}" : code) }
    user.update!(otp_backup_codes: backup_codes, failed_otp_attempts: 0, failed_backup_code_attempts: 0)
    :success
  end

  def self.generate_otp_secret(user:)
    otp_secret = ROTP::Base32.random.downcase
    user.update!(otp_secret: otp_secret, otp_updated_at: Time.now.utc)
    otp_secret
  end

  def self.generate_backup_codes(user:, count: 10, length: 8)
    codes = (count * 2).times.map { format("%0#{length}i", SecureRandom.random_number(10**length)) }.uniq.take(count)
    user.update!(otp_backup_codes: codes, otp_backup_codes_updated_at: Time.now.utc)
    codes
  end

  def self.remaining_backup_codes(user:)
    user.otp_backup_codes&.count { |code| !code.starts_with?('!') } || 0
  end

  def self.format_otp_secret(code)
    code&.gsub(/(.{4})(?=.)/, '\1 \2') || I18n.t('errors.messages.invalid')
  end

  def self.format_backup_code(code)
    return I18n.t('auth.backup_codes.already_used') if code.starts_with?('!')

    code&.gsub(/(.{4})(?=.)/, '\1 \2') || I18n.t('errors.messages.invalid')
  end
end
