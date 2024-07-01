# frozen_string_literal: true

# Basic model for books
class Book < ApplicationRecord
  validates :title, :page_count, presence: true
  validates :page_count, numericality: { greater_than: 0, only_integer: true }

  belongs_to :author
end
