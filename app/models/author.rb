# frozen_string_literal: true

# Basic model for authors
class Author < ApplicationRecord
  validates :name, presence: true, length: { minimum: 3 }
end
