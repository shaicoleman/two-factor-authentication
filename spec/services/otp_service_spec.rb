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
      user = User.create!(email: 'test@test.com', password: 'secret', otp_secret: otp_secret)

      # Allowed to use codes from the previous timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(:success)
      expect(user.reload.otp_failed_attempts).to eq(0)

      # Allowed to use codes from the current timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(:success)

      # not allowed to reuse codes
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))
      expect(user.reload.otp_failed_attempts).to eq(0)

      # not allowed to use codes older than the last successful timestep
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

      # not allowed to use code from 2 timesteps ago
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 60), at: now)).to eq(I18n.t('errors.messages.invalid'))

      # not allowed to use code from the future
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now)).to eq(I18n.t('errors.messages.invalid'))
      expect(user.reload.otp_failed_attempts).to eq(2)

      # when ignore_failed: true, do not increment otp_failed_attempts
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now, ignore_failed: true)).to eq(I18n.t('errors.messages.invalid'))
      expect(user.reload.otp_failed_attempts).to eq(2)

      # not allowed when number of attempts exceeded, even if correct
      user.update!(otp_failed_attempts: 999, otp_consumed_timestep: nil)
      expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to eq(I18n.t('auth.too_many_failed_attempts'))
    end
  end
end
