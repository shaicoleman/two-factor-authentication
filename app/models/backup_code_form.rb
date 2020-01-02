# frozen_string_literal: true

class BackupCodeForm < ActiveModelForm
  attr_accessor :backup_code_attempt
  attr_accessor :remember_me

  before_validation :strip_whitespace
  validates :backup_code_attempt, presence: true, length: { is: 8 }, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def strip_whitespace
    backup_code_attempt.remove!(/\s+/)
  end
end
