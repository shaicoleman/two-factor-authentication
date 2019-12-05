# frozen_string_literal: true

class Users::OtpSessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token

  def new
    if user_signed_in?
      return respond_with resource, location: after_sign_in_path_for(resource)
    end
    return redirect_to(new_user_session_path) unless session[:otp_user_id]

    @otp_form = OtpForm.new

    render 'devise/otp_sessions/new'
  end

  # Based on https://github.com/plataformatec/devise/blob/v4.7.1/app/controllers/devise/sessions_controller.rb
  # and https://github.com/tinfoil/devise-two-factor/blob/v3.1.0/lib/devise_two_factor/models/two_factor_authenticatable.rb
  def create
    @otp_form = OtpForm.new(otp_form_params)

    self.resource = User.find_by(id: session[:otp_user_id])
    return redirect_to(new_user_session_path) unless resource.present?
    return render 'devise/otp_sessions/new' unless @otp_form.valid?

    matching_timestep = verify_with_drift_returning_timestep(otp: resource.otp, otp_attempt: @otp_form.otp_attempt,
                                                             drift: resource.class.otp_allowed_drift)
    unless matching_timestep
      @otp_form.errors.add(:otp_attempt, 'is invalid')
      resource.class.increment_counter(:failed_otp_attempts, resource.id)
      return render 'devise/otp_sessions/new'
    end
    if resource.consumed_timestep >= matching_timestep
      @otp_form.errors.add(:otp_attempt, 'already used')
      return render 'devise/otp_sessions/new'
    end

    sign_out
    sign_in(resource_name, resource)
    resource.update_columns(failed_otp_attempts: 0, consumed_timestep: matching_timestep)
    set_flash_message!(:notice, :signed_in)

    respond_with resource, location: after_sign_in_path_for(resource)
  end

  private

  # Based on https://github.com/mdp/rotp/blob/v2.1.2/lib/rotp/totp.rb#L43
  def verify_with_drift_returning_timestep(otp:, otp_attempt:, drift:, time: Time.now.utc)
    time = time.to_i
    times = (time - drift..time + drift).step(otp.interval).to_a
    times << time + drift if times.last < time + drift
    times.detect { |ti| otp.verify(otp_attempt, ti) }&.div(otp.interval)
  end

  def otp_form_params
    params[:otp_form].permit(:otp_attempt)
  end
end
