# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/help' do
  describe 'GET /index' do
    it 'renders a successful response' do
      get(help_url, as: :json)
      expect(response).to be_successful
      expect(response.parsed_body).to include(
        'endpoints' => a_kind_of(Hash)
      )
    end
  end
end
