# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OtpService do
  describe "#otp_qr_code" do
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
end
