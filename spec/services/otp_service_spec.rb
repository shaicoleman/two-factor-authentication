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
      now = Time.now.to_i / 30 * 30

      otp_secret = 'bseq4wbk7ycoeasjkxj6dd4njqz2zpfx'
      user = User.create!(email: 'test@test.com', password: 'secret', otp_secret: otp_secret)

      # Allowed to use codes from the previous timestep
      otp_attempt = ROTP::TOTP.new(otp_secret).at(now - 30)
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(:success)
      expect(user.reload.otp_failed_attempts).to eq(0)

      # Allowed to use codes from the current timestep
      otp_attempt = ROTP::TOTP.new(otp_secret).at(now)
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(:success)

      # not allowed to reuse codes
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))
      expect(user.reload.otp_failed_attempts).to eq(0)

      # not allowed to use codes older than the last successful timestep
      otp_attempt = ROTP::TOTP.new(otp_secret).at(now - 30)
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

      # not allowed to use code from 2 timesteps ago
      otp_attempt = ROTP::TOTP.new(otp_secret).at(now - 60)
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(I18n.t('errors.messages.invalid'))
      expect(user.reload.otp_failed_attempts).to eq(1)

      # not allowed to use code from the future
      otp_attempt = ROTP::TOTP.new(otp_secret).at(now + 30)
      expect(OtpService.attempt_otp(user: user, otp_attempt: otp_attempt)).to eq(I18n.t('errors.messages.invalid'))
      expect(user.reload.otp_failed_attempts).to eq(2)
    end
  end
end
