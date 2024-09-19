class Challenge < ApplicationRecord
  validates :number, :description, :points, presence: true
  validates :points, :number, numericality: { only_integer: true }
  validates :number, :description, uniqueness: true
end
