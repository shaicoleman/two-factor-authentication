class OtpService
  def self.otp_qr_code(user:)
    issuer = 'GoRails'
    label = "#{issuer}:#{user.email}"
    qrcode = RQRCode::QRCode.new(user.otp_provisioning_uri(label, issuer: issuer))
    qrcode.as_svg(module_size: 4).html_safe
  end

  def self.attempt_otp(user:, otp_attempt:)
    matching_timestep = verify_with_drift_v2(otp: user.otp, otp_attempt: otp_attempt,
                                             drift: user.class.otp_allowed_drift)
    unless matching_timestep
      user.class.increment_counter(:failed_otp_attempts, user.id)
      return :code_invalid
    end
    if user.consumed_timestep.to_i >= matching_timestep
      return :code_already_used
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

  def self.format_otp_secret(user:)
    user.otp_secret.gsub(/(.{4})(?=.)/, '\1 \2')
  end
end
