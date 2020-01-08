# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OtpService do
  it '#otp_qr_code' do
    otp_secret = 'bseq4wbk7ycoeasjkxj6dd4njqz2zpfx'
    issuer = 'ISSUER'
    email = "#{Random.alphanumeric(rand(8..64))}@test.com"
    user = User.create!(email: email, password: 'secret', otp_secret: otp_secret)
    result = OtpService.otp_qr_code(user: user, issuer: issuer)

    # QR should have the correct TOTP URL
    expect(result.qrcode.instance_variable_get(:@data)).to \
      eq("otpauth://totp/#{issuer}:#{email.downcase}?secret=#{otp_secret}&issuer=#{issuer}")

    # Should generate SVG output successfully
    svg = result.as_svg(module_size: 4)
    expect(svg).to include('<svg')

    # QR code should have a fixed size, regardless of the length of the email
    expect(svg).to include('width="196" height="196"')
  end

  it '#attempt_otp' do
    now = Time.now.utc.to_i
    otp_secret = 'bseq4wbk7ycoeasjkxj6dd4njqz2zpfx'
    totp = ROTP::TOTP.new(otp_secret)
    user = User.create!(email: 'test@test.com', password: 'secret', otp_secret: otp_secret,
                        otp_failed_attempts: 3, otp_grace_period_started_at: 1.day.ago)

    # Allowed to use codes from the previous timestep
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(:success)

    # Allowed to use codes from the current timestep
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(:success)

    # Reset failed attempts counter on successful login
    expect(user.reload.otp_failed_attempts).to eq(0)

    # Reset grace period on successful login
    expect(user.otp_grace_period_started_at).to eq(nil)

    # Not allowed to reuse codes
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to \
      eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

    # Not allowed to use codes older than the last successful timestep
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to \
      eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

    # Do not increment failed attempts counter when attempting to reuse code
    expect(user.reload.otp_failed_attempts).to eq(0)

    # Not allowed to use code from 2 timesteps ago
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 60), at: now)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Not allowed to use code from the future
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Increment the failed attempt counter on each failure
    expect(user.reload.otp_failed_attempts).to eq(2)

    # When ignore_failed: true, it should still return an error
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now, ignore_failed: true)).to \
      eq(I18n.t('errors.messages.invalid'))

    # When ignore_failed: true, it shouldn't increment the failed attempts counter
    expect(user.reload.otp_failed_attempts).to eq(2)

    # Not allowed when number of attempts exceeded, even if correct
    user.update!(otp_failed_attempts: 999, otp_consumed_timestep: nil)
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to \
      eq(I18n.t('auth.too_many_failed_attempts'))
  end

  it '#attempt_backup_code' do
    user = User.create!(email: 'test@test.com', password: 'secret', otp_failed_backup_code_attempts: 3,
                        otp_grace_period_started_at: 1.day.ago)
    codes = OtpService.generate_backup_codes(user: user)

    # Should succeed with an unused valid code
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.first)).to \
      eq(:success)

    # Reset failed attempts counter on successful login
    expect(user.reload.otp_failed_backup_code_attempts).to eq(0)

    # Reset grace period on successful login
    expect(user.otp_grace_period_started_at).to eq(nil)

    # Should fail when trying to reuse a code
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.first)).to \
      eq(I18n.t('auth.backup_code_sessions.backup_code_already_used_error'))

    # Do not increment failed attempts counter when attempting to reuse code
    expect(user.reload.otp_failed_backup_code_attempts).to eq(0)

    # Not allowed to use invalid codes
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: 'invalid')).to \
      eq(I18n.t('errors.messages.invalid'))

    # Increment the failed attempt counter on failure
    expect(user.reload.otp_failed_backup_code_attempts).to eq(1)

    # Not allowed when number of attempts exceeded, even if correct
    user.update!(otp_failed_backup_code_attempts: 999)
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.last)).to \
      eq(I18n.t('auth.too_many_failed_attempts'))
  end
end
