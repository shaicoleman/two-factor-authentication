# frozen_string_literal: true

class BackupCodeForm < ActiveModelForm
  attr_accessor :backup_code_attempt
  attr_accessor :remember_me

  validates :backup_code_attempt, presence: true
end
