class OtpService
  ISSUER = 'OTPExample'

  def self.otp_qr_code(user:)
    otpauth_url = user.otp_provisioning_uri(label(user: user), issuer: ISSUER)
    qrcode = RQRCode::QRCode.new(otpauth_url, level: :l)
    qrcode.as_svg(module_size: 4).html_safe
  end

  def self.attempt_otp(user:, otp_attempt:, ignore_failed: false)
    matching_timestep = verify_with_drift_v2(otp: user.otp, otp_attempt: otp_attempt,
                                             drift: user.class.otp_allowed_drift)
    unless matching_timestep
      user.class.increment_counter(:failed_otp_attempts, user.id) unless ignore_failed
      return I18n.t('errors.messages.invalid')
    end
    if user.consumed_timestep.to_i >= matching_timestep
      return I18n.t('two_factors.otp_code_already_used')
    end
    user.update_columns(failed_otp_attempts: 0, consumed_timestep: matching_timestep)
    :success
  end

  # Based on https://github.com/mdp/rotp/blob/v2.1.2/lib/rotp/totp.rb#L43
  def self.verify_with_drift_v2(otp:, otp_attempt:, drift:, time: Time.now.utc)
    time = time.to_i
    times = (time - drift..time + drift).step(otp.interval).to_a
    times << time + drift if times.last < time + drift
    times.detect { |ti| otp.verify(otp_attempt, ti) }&.div(otp.interval)
  end

  def self.generate_backup_codes(user:, count: 10, length: 8)
    codes = count.times.map { format("%0#{length}i", SecureRandom.random_number(10**length)) }
    user.update!(otp_backup_codes: codes, otp_backup_codes_updated_at: Time.now.utc)
    codes
  end

  def self.format_otp_secret(user:)
    user.otp_secret.gsub(/(.{4})(?=.)/, '\1 \2')
  end

  def self.format_backup_code(backup_code)
    backup_code.gsub(/(.{4})(?=.)/, '\1 \2')
  end

  def self.label(user:)
    "#{ISSUER}:#{user.email}"
  end
end
