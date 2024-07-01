# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Book do
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:page_count) }
  it { is_expected.to validate_numericality_of(:page_count).is_greater_than(0).only_integer }
  it { is_expected.to belong_to(:author) }
end
