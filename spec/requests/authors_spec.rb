# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/authors' do
  let(:valid_attributes) do
    {
      name: 'Fred',
    }
  end

  let(:invalid_attributes) do
    {
      name: 'f',
    }
  end

  let(:valid_author) do
    Author.create!(valid_attributes)
  end

  describe 'GET /index' do
    before { valid_author }

    it 'renders a successful response' do
      get(authors_url, as: :json)
      expect(response).to be_successful
    end
  end

  describe 'GET /show' do
    before { valid_author }

    it 'renders a successful response' do
      get(author_url(valid_author), as: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq valid_author.id
    end
  end

  describe 'POST /create' do
    let(:request) do
      post(
        authors_url,
        params: attributes,
        as: :json
      )
    end

    context 'with valid parameters' do
      let(:attributes) { valid_attributes }

      it 'creates a new Author' do
        expect { request }.to change(Author, :count).by(1)
      end

      it 'renders a JSON response with the new Author' do
        request
        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including('application/json'))
        expect(response.parsed_body['name']).to eq 'Fred'
      end
    end

    context 'with invalid parameters' do
      let(:attributes) { invalid_attributes }

      it 'does not create a new Author' do
        expect { request }.not_to change(Author, :count)
      end

      it 'renders a JSON response with errors for the new Author' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to match(a_string_including('application/json'))
      end
    end
  end

  describe 'PATCH /update' do
    let(:request) do
      patch(
        author_url(valid_author),
        params: new_attributes,
        as: :json
      )
    end

    before { valid_author }

    context 'with valid parameters' do
      let(:new_attributes) do
        { name: 'Jean' }
      end

      it 'updates the requested listing' do
        expect do
          request
          valid_author.reload
        end.to change(valid_author, :name).from('Fred').to('Jean')
      end

      it 'renders a JSON response with the listing' do
        request
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including('application/json'))
        expect(response.parsed_body['id']).to eq valid_author.id
      end
    end

    context 'with invalid parameters' do
      let(:new_attributes) do
        { name: 'd' }
      end

      it 'renders a JSON response with errors for the listing' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to match(a_string_including('application/json'))
      end
    end
  end

  describe 'DELETE /destroy' do
    let(:request) do
      delete(author_url(valid_author.id), as: :json)
    end

    before { valid_author }

    it 'destroys the requested listing' do
      expect { request }.to change(Author, :count).by(-1)
      expect { valid_author.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
