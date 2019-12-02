class OtpService
  def self.otp_qr_code(user:)
    issuer = 'GoRails'
    label = "#{issuer}:#{user.email}"
    qrcode = RQRCode::QRCode.new(user.otp_provisioning_uri(label, issuer: issuer))
    qrcode.as_svg(module_size: 4).html_safe
  end

  def self.format_otp_secret(user:)
    user.otp_secret.gsub(/(.{4})(?=.)/, '\1 \2')
  end
end
