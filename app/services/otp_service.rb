# frozen_string_literal: true

class OtpService
  DRIFT_BEHIND = 30.seconds
  DRIFT_AHEAD = 0.seconds
  MAX_FAILED_OTP_ATTEMPTS = 12
  MAX_FAILED_BACKUP_CODE_ATTEMPTS = 12
  WARN_OTP_ATTEMPTS_LEFT = 9
  WARN_BACKUP_CODE_ATTEMPTS_LEFT = 9
  BACKUP_CODES_COUNT = 10
  BACKUP_CODE_LENGTH = 8
  MIN_QR_CODE_SIZE = 8
  REQUIRE_2FA = true
  GRACE_PERIOD = 1.day

  # Generate a QR code with the maximum error correction that fits a fixed size
  # Size 8 should be enough to accomodate a 32 character issuer and a 64 character email
  def self.otp_qr_code(issuer:, user:, min_qr_code_size: MIN_QR_CODE_SIZE)
    otpauth_url = ROTP::TOTP.new(user.otp_secret, issuer: issuer).provisioning_uri(user.email)
    %i[h q m l].each do |level|
      suppress(RQRCodeCore::QRCodeRunTimeError) do
        return RQRCode::QRCode.new(otpauth_url, level: level, size: min_qr_code_size)
      end
    end
    RQRCode::QRCode.new(otpauth_url, level: :l)
  end

  def self.attempt_otp(user:, otp_attempt:, ignore_failed: false, at: Time.now.utc)
    otp_attempt = otp_attempt.remove(/\s+/)
    return I18n.t('errors.messages.invalid') unless otp_attempt.match?(/\A\d{6}\z/)

    if user.otp_failed_attempts >= MAX_FAILED_OTP_ATTEMPTS && !ignore_failed
      return I18n.t('auth.too_many_failed_attempts')
    end

    otp = ROTP::TOTP.new(user.otp_secret)
    matching_timestamp = otp.verify(otp_attempt, at: at, drift_behind: DRIFT_BEHIND, drift_ahead: DRIFT_AHEAD)
    matching_timestep = matching_timestamp&.div(otp.interval)
    unless matching_timestep
      user.class.increment_counter(:otp_failed_attempts, user.id) unless ignore_failed
      return I18n.t('errors.messages.invalid')
    end

    if user.otp_consumed_timestep.to_i >= matching_timestep
      return I18n.t('auth.otp_sessions.otp_code_already_used_error')
    end

    user.update!(otp_failed_attempts: 0, otp_failed_backup_code_attempts: 0, otp_consumed_timestep: matching_timestep,
                 otp_grace_period_started_at: nil)
    :success
  end

  def self.attempt_backup_code(user:, backup_code_attempt:)
    backup_code_attempt = backup_code_attempt.remove(/\s+/)
    return I18n.t('errors.messages.invalid') unless backup_code_attempt.match?(/\A\d{#{BACKUP_CODE_LENGTH}}\z/)

    if user.otp_failed_backup_code_attempts >= MAX_FAILED_BACKUP_CODE_ATTEMPTS
      return I18n.t('auth.too_many_failed_attempts')
    end

    if "!#{backup_code_attempt}".in?(user.otp_backup_codes)
      return I18n.t('auth.backup_code_sessions.backup_code_already_used_error')
    end

    unless backup_code_attempt.in?(user.otp_backup_codes)
      user.class.increment_counter(:otp_failed_backup_code_attempts, user.id)
      return I18n.t('errors.messages.invalid')
    end

    backup_codes = user.otp_backup_codes.map { |code| (code == backup_code_attempt ? "!#{code}" : code) }
    user.update!(otp_backup_codes: backup_codes, otp_failed_attempts: 0, otp_failed_backup_code_attempts: 0,
                 otp_grace_period_started_at: nil)
    :success
  end

  def self.generate_otp_secret(user:)
    otp_secret = ROTP::Base32.random.downcase
    user.update!(otp_secret: otp_secret, otp_updated_at: Time.now.utc)
    otp_secret
  end

  def self.generate_backup_codes(user:, count: BACKUP_CODES_COUNT, length: BACKUP_CODE_LENGTH)
    codes = []
    while codes.length < count
      code = format("%0#{length}i", SecureRandom.random_number(10**length))
      codes << code unless code.in?(codes)
    end
    user.update!(otp_backup_codes: codes, otp_backup_codes_updated_at: Time.now.utc)
    codes
  end

  def self.otp_attempts_remaining(user:)
    attempts_remaining = MAX_FAILED_OTP_ATTEMPTS - user.reload.otp_failed_attempts
    I18n.t('auth.attempts_remaining', count: attempts_remaining) if attempts_remaining <= WARN_OTP_ATTEMPTS_LEFT
  end

  def self.backup_codes_attempts_remaining(user:)
    attempts_remaining = MAX_FAILED_BACKUP_CODE_ATTEMPTS - user.reload.otp_failed_backup_code_attempts
    I18n.t('auth.attempts_remaining', count: attempts_remaining) if attempts_remaining <= WARN_BACKUP_CODE_ATTEMPTS_LEFT
  end

  def self.backup_codes_available(user:)
    user.otp_backup_codes&.count { |code| !code&.starts_with?('!') } || 0
  end

  def self.format_otp_secret(code)
    code&.gsub(/(.{4})(?=.)/, '\1 \2') || I18n.t('errors.messages.invalid')
  end

  def self.format_backup_code(code)
    return I18n.t('auth.backup_codes.already_used') if code&.starts_with?('!')

    code&.gsub(/(.{4})(?=.)/, '\1 \2') || I18n.t('errors.messages.invalid')
  end

  def self.check_enforcement_status(user:)
    return if user.otp_required_for_login?
    return :already_enabled if user.otp_required_for_login?
    return :not_enforced unless OtpService::REQUIRE_2FA

    user.update!(otp_grace_period_started_at: Time.now.utc) if user.otp_grace_period_started_at.blank?
    return :enforced if Time.now.utc >= enforcement_deadline(user: user)

    :grace_period
  end

  def self.enforcement_deadline(user:, grace_period: OtpService::GRACE_PERIOD)
    user.otp_grace_period_started_at + grace_period
  end
end
