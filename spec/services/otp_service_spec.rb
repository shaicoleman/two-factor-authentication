# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OtpService do
  it '#otp_qr_code' do
    otp_secret = ROTP::Base32.random.downcase
    issuer = 'ISSUER'
    email = "#{Random.alphanumeric(rand(8..64))}@test.com"
    user = User.create!(email: email, password: 'secret', otp_secret: otp_secret)
    result = OtpService.otp_qr_code(user: user, issuer: issuer)

    # Generates QR code with correct TOTP URL
    expect(result.qrcode.instance_variable_get(:@data)).to \
      eq("otpauth://totp/#{issuer}:#{email.downcase}?secret=#{otp_secret}&issuer=#{issuer}")

    # Generates QR code as SVG
    svg = result.as_svg(module_size: 4)
    expect(svg).to include('<svg')

    # Generates a fixed size QR code, regardless of the email length
    expect(svg).to include('width="196" height="196"')
  end

  it '#attempt_otp' do
    now = Time.now.utc.to_i
    otp_secret = ROTP::Base32.random.downcase
    totp = ROTP::TOTP.new(otp_secret)
    user = User.create!(email: 'test@test.com', password: 'secret', otp_secret: otp_secret, otp_failed_attempts: 3,
                        otp_failed_backup_code_attempts: 3, otp_grace_period_started_at: 1.day.ago)

    # Accepts a code from the previous timestep
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to eq(:success)

    # Accepts a code from the current timestep, ignoring whitespace
    expect(OtpService.attempt_otp(user: user, otp_attempt: "#{totp.at(now)} ", at: now)).to eq(:success)

    # Resets failed attempts counters on successful login
    expect(user.reload.otp_failed_attempts).to eq(0)
    expect(user.reload.otp_failed_backup_code_attempts).to eq(0)

    # Resets grace period on successful login
    expect(user.otp_grace_period_started_at).to eq(nil)

    # Rejects reused codes
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to \
      eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

    # Rejects codes older than the last successful timestep
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 30), at: now)).to \
      eq(I18n.t('auth.otp_sessions.otp_code_already_used_error'))

    # Keeps unchanged failed attempts counter when attempting to reuse code
    expect(user.reload.otp_failed_attempts).to eq(0)

    # Rejects codes from 2 timesteps ago
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now - 60), at: now)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Rejects codes from the future
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Increments the failed attempt counter on each failure
    expect(user.reload.otp_failed_attempts).to eq(2)

    # When ignore_failed: true, rejects invalid code
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now + 30), at: now, ignore_failed: true)).to \
      eq(I18n.t('errors.messages.invalid'))

    # When ignore_failed: true, keeps unchanged the failed attempts counter
    expect(user.reload.otp_failed_attempts).to eq(2)

    # Rejects codes that aren't 6 digits
    expect(OtpService.attempt_otp(user: user, otp_attempt: '!123456', at: now)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Keeps unchange the failed attempt counter for codes that aren't 6 digits
    expect(user.reload.otp_failed_attempts).to eq(2)

    # Rejects valid code when number of attempts exceeded
    user.update!(otp_failed_attempts: 999, otp_consumed_timestep: nil)
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now)).to \
      eq(I18n.t('auth.too_many_failed_attempts'))

    # When ignore_failed: true, ignores failed attempts counter
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now), at: now, ignore_failed: true)).to eq(:success)

    # When ignore_failed: true, resets failed attempts to 0 on success
    expect(user.reload.otp_failed_attempts).to eq(0)

    # Reject when otp_secret is nil
    user.update!(otp_secret: nil)
    expect(OtpService.attempt_otp(user: user, otp_attempt: totp.at(now))).to eq(I18n.t('errors.messages.invalid'))
  end

  it '#attempt_backup_code' do
    user = User.create!(email: 'test@test.com', password: 'secret', otp_failed_attempts: 3,
                        otp_failed_backup_code_attempts: 3, otp_grace_period_started_at: 1.day.ago)
    codes = OtpService.generate_backup_codes(user: user)

    # Accepts an unused valid code, ignoring whitespace
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: "#{codes.first} ")).to \
      eq(:success)

    # Resets failed attempts counters on successful login
    expect(user.reload.otp_failed_attempts).to eq(0)
    expect(user.reload.otp_failed_backup_code_attempts).to eq(0)

    # Resets grace period on successful login
    expect(user.otp_grace_period_started_at).to eq(nil)

    # Rejects reused codes
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.first)).to \
      eq(I18n.t('auth.backup_code_sessions.backup_code_already_used_error'))

    # Keeps unchanged failed attempts counter when attempting to reuse code
    expect(user.reload.otp_failed_backup_code_attempts).to eq(0)

    # Rejects invalid codes
    invalid_code = ('00000000'..'99999999').find { |code| !code.in?(codes) }
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: invalid_code)).to \
      eq(I18n.t('errors.messages.invalid'))

    # Increments failed attempt counter on failure
    expect(user.reload.otp_failed_backup_code_attempts).to eq(1)

    # Rejects codes that aren't 8 digits, rejects used codes as stored in DB
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: "!#{codes.first}")).to \
      eq(I18n.t('errors.messages.invalid'))

    # Keeps unchanged the failed attempt counter for codes that aren't 8 digits
    expect(user.reload.otp_failed_backup_code_attempts).to eq(1)

    # Rejects valid code when number of attempts exceeded
    user.update!(otp_failed_backup_code_attempts: 999)
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.last)).to \
      eq(I18n.t('auth.too_many_failed_attempts'))

    # Reject when otp_backup_codes is nil
    user.update!(otp_backup_codes: nil)
    expect(OtpService.attempt_backup_code(user: user, backup_code_attempt: '')).to eq(I18n.t('errors.messages.invalid'))
  end

  it '#generate_otp_secret' do
    user = User.create!(email: 'test@test.com', password: 'secret')
    OtpService.generate_otp_secret(user: user)

    # Generates a new secret each time
    expect(user.otp_secret).not_to eq(OtpService.generate_otp_secret(user: user))

    # Generates a secret in correct length and format
    expect(user.otp_secret).to match(/^[a-z0-9]{32}$/)

    # Updates otp_updated_at
    expect(user.otp_updated_at).to be_within(1.second).of(Time.now.utc)

    # Stores secret encrypted
    expect(user.encrypted_attributes.keys).to include(:otp_secret)
  end

  it '#generate_backup_codes' do
    user = User.create!(email: 'test@test.com', password: 'secret')
    OtpService.generate_backup_codes(user: user)

    # Generate new backup codes each time
    expect(user.otp_backup_codes).not_to eq(OtpService.generate_backup_codes(user: user))

    # Generates 8 digits codes
    expect(user.otp_backup_codes.first).to match(/^\d{8}$/)

    # Ensures codes are unique
    OtpService.generate_backup_codes(user: user, length: 2, count: 12)
    expect(user.otp_backup_codes.uniq.count).to eq(12)

    # Updates otp_backup_codes_updated_at
    expect(user.otp_backup_codes_updated_at).to be_within(1.second).of(Time.now.utc)

    # Stores codes encrypted
    expect(user.encrypted_attributes.keys).to include(:otp_backup_codes)
  end

  it '#backup_codes_available' do
    user = User.create!(email: 'test@test.com', password: 'secret')
    codes = OtpService.generate_backup_codes(user: user)

    # Returns 10 available codes after generating new backup codes
    expect(OtpService.backup_codes_available(user: user)).to eq(10)

    # Returns 9 available codes after using a code
    OtpService.attempt_backup_code(user: user, backup_code_attempt: codes.first)
    expect(OtpService.backup_codes_available(user: user)).to eq(9)
  end

  it '#format_otp_secret' do
    # Formats number in groups of 4 characters
    expect(OtpService.format_otp_secret('lgdod5kkcwdjwhjcx5u6ecv2vwtfpx54')).to \
      eq('lgdo d5kk cwdj whjc x5u6 ecv2 vwtf px54')

    # Returns invalid message when nil
    expect(OtpService.format_otp_secret(nil)).to eq(I18n.t('errors.messages.invalid'))
  end

  it '#format_backup_codes' do
    # Formats number in groups of 4 digits
    expect(OtpService.format_backup_codes(['12345678', '23456789'])).to eq(['1234 5678', '2345 6789'])

    # Returns "already used" message for used codes
    expect(OtpService.format_backup_codes(['!12345678'])).to eq([I18n.t('auth.backup_codes.already_used')])

    # Returns invalid message when nil
    expect(OtpService.format_backup_codes(nil)).to eq([I18n.t('errors.messages.invalid')])
  end

  it '#check_enforcement_status' do
    user = User.create!(email: 'test@test.com', password: 'secret', otp_required_for_login: true)

    # Returns :already_enabled when 2FA is already enabled
    expect(OtpService.check_enforcement_status(user: user)).to eq(:already_enabled)
  end
end
