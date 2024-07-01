# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Author do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_least(3) }
end
