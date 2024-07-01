# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/books' do
  let(:valid_attributes) do
    {
      title: 'Book Title',
      page_count: 100,
      author_id: Author.create!(name: 'Jean').id,
    }
  end

  let(:invalid_attributes) do
    {
      title: 'Book Title',
      page_count: 0,
    }
  end

  let(:valid_book) do
    Book.create!(valid_attributes)
  end

  describe 'GET /index' do
    before { valid_book }

    it 'renders a successful response' do
      get(books_url, as: :json)
      expect(response).to be_successful
    end
  end

  describe 'GET /show' do
    before { valid_book }

    it 'renders a successful response' do
      get(book_url(valid_book), as: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq valid_book.id
    end
  end

  describe 'POST /create' do
    let(:request) do
      post(
        books_url,
        params: attributes,
        as: :json
      )
    end

    context 'with valid parameters' do
      let(:attributes) { valid_attributes }

      it 'creates a new book' do
        expect { request }.to change(Book, :count).by(1)
      end

      it 'renders a JSON response with the new book' do
        request
        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including('application/json'))
        expect(response.parsed_body['title']).to eq 'Book Title'
      end
    end

    context 'with invalid parameters' do
      let(:attributes) { invalid_attributes }

      it 'does not create a new book' do
        expect { request }.not_to change(Book, :count)
      end

      it 'renders a JSON response with errors for the new book' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to match(a_string_including('application/json'))
      end
    end
  end

  describe 'PATCH /update' do
    let(:request) do
      patch(
        book_url(valid_book),
        params: new_attributes,
        as: :json
      )
    end

    before { valid_book }

    context 'with valid parameters' do
      let(:new_attributes) do
        { page_count: 36 }
      end

      it 'updates the requested listing' do
        expect do
          request
          valid_book.reload
        end.to change(valid_book, :page_count).from(100).to(36)
      end

      it 'renders a JSON response with the listing' do
        request
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including('application/json'))
        expect(response.parsed_body['id']).to eq valid_book.id
      end
    end

    context 'with invalid parameters' do
      let(:new_attributes) do
        { page_count: 0 }
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
      delete(book_url(valid_book.id), as: :json)
    end

    before { valid_book }

    it 'destroys the requested listing' do
      expect { request }.to change(Book, :count).by(-1)
      expect { valid_book.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
