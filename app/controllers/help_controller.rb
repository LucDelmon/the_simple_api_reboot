# frozen_string_literal: true

# Controller for providing API help documentation
class HelpController < ApplicationController
  # rubocop:disable Metrics/MethodLength
  # GET /api/help
  def index
    help_info = {
      endpoints: {
        authors: {
          description: 'Manage authors in the system.',
          routes: [
            { method: 'GET', path: '/authors', description: 'List all authors.' },
            { method: 'GET', path: '/authors/:id', description: 'Show a specific author.' },
            { method: 'POST', path: '/authors', description: 'Create a new author.' },
            { method: 'PUT', path: '/authors/:id', description: 'Update an existing author.' },
            { method: 'DELETE', path: '/authors/:id', description: 'Delete an author.' },
          ],
          params: {
            create: { name: 'string' },
            update: { name: 'string' },
          },
        },
        books: {
          description: 'Manage books in the system.',
          routes: [
            { method: 'GET', path: '/books', description: 'List all books.' },
            { method: 'GET', path: '/books/:id', description: 'Show a specific book.' },
            { method: 'POST', path: '/books', description: 'Create a new book.' },
            { method: 'PUT', path: '/books/:id', description: 'Update an existing book.' },
            { method: 'DELETE', path: '/books/:id', description: 'Delete a book.' },
          ],
          params: {
            create: { title: 'string', page_count: 'integer', author_id: 'integer' },
            update: { title: 'string', page_count: 'integer', author_id: 'integer' },
          },
        },
      },
    }

    render json: help_info
  end
  # rubocop:enable Metrics/MethodLength
end
