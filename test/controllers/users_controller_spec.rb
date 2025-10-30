# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe '#create' do
    context 'the parameter "user[name]" is not blank' do
      let(:valid_params) { { user: { name: 'Luc' } } }

      it 'creates a new user' do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'renders an empty response' do
        post :create, params: valid_params
        expect(response.body).to be_empty
      end

      it 'renders a response with status 200' do
        post :create, params: valid_params
        expect(response).to have_http_status(200)
      end
    end

    context 'the parameter "user[name]" is blank' do
      let(:invalid_params) { { user: { name: '' } } }

      it 'does not create a new user' do
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
      end

      it 'renders a json response' do
        post :create, params: invalid_params
        expect(response.content_type).to eq 'application/json; charset=utf-8'
      end

      it 'renders a response with status code 422' do
        post :create, params: invalid_params
        expect(response).to have_http_status(422)
      end

      it 'renders a json object {"errors": {"name": ["can\'t be blank"]}}' do
        method_call
        json_response = JSON.parse(response.body)
        expect(json_response).to eq('errors' => { 'name' => ["can't be blank"] })
      end
    end
  end
end
