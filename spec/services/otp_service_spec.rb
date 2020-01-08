# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OtpService do
  describe '#otp_qr_code' do
    it 'Generates an SVG QR code' do
      issuer = OtpService::ISSUER
      otp_secret = 'bseq4wbk7ycoeasjkxj6dd4njqz2zpfx'
      email = "#{Random.alphanumeric(rand(8..64))}@test.com"
      user = User.create!(email: email, password: 'secret', otp_secret: otp_secret)
      result = OtpService.otp_qr_code(user: user)
      expect(result.qrcode.instance_variable_get(:@data)).to eq("otpauth://totp/#{issuer}:#{email.downcase}?secret=#{otp_secret}&issuer=#{issuer}")
      svg = result.as_svg(module_size: 4).html_safe
      expect(svg).to include('<svg'), 'should generate SVG output'
      expect(svg).to include('width="196" height="196"'), 'generates QR code with fixed size'
    end
  end

  describe '#attempt_otp' do
    it 'Validates OTP attempt' do
      now = Time.now.utc.to_i
      otp_secret = 'bseq4wbk7ycoeasjkxj6dd4njqz2zpfx'
      totp = ROTP::TOTP.new(otp_secret)
      user = User.create!(email: 'test@test.com', password: 'secret', otp_secret: otp_secret, otp_grace_period_started_at: 1.day.ago)

      # Allowed to use codes from the previous timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(:success)

      # Reset failed attempts counter on successful login
      expect(user.reload.otp_failed_attempts).to eq(0)

      # Reset grace period on successful login
      expect(user.otp_grace_period_started_at).to eq(nil)

      # Allowed to use codes from the current timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(:success)

      # Not allowed to reuse codes
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

      # Do not increment failed attempts counter when reusing code
      expect(user.reload.otp_failed_attempts).to eq(0)

      # Not allowed to use codes older than the last successful timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

      # Not allowed to use code from 2 timesteps ago
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 60), at: now)).to eq(I18n.t('errors.messages.invalid'))

      # Not allowed to use code from the future
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now)).to eq(I18n.t('errors.messages.invalid'))

      # Increment the failed attempt counter on each failure
      expect(user.reload.otp_failed_attempts).to eq(2)

      # When ignore_failed: true, it should still return an error
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now, ignore_failed: true)).to eq(I18n.t('errors.messages.invalid'))

      # When ignore_failed: true, it shouldn't increment the failed attempts counter
      expect(user.reload.otp_failed_attempts).to eq(2)

      # Not allowed when number of attempts exceeded, even if correct
      user.update!(otp_failed_attempts: 999, otp_consumed_timestep: nil)
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(I18n.t('auth.too_many_failed_attempts'))
    end
  end
end
