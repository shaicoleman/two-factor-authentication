# frozen_string_literal: true

class Auth::LockedOutController < ApplicationController
  skip_before_action :authenticate_user!

  def index
  end
end
