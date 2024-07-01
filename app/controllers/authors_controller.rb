# frozen_string_literal: true

# Basic controller for authors
class AuthorsController < ApplicationController
  before_action :set_author, only: %i[show update destroy]

  # GET /authors
  # @return [JSON, nil]
  def index
    @authors = Author.all

    render json: @authors
  end

  # GET /authors/1
  # @return [JSON, nil]
  def show
    render json: @author
  end

  # POST /authors
  # @return [JSON, nil]
  def create
    @author = Author.new(author_params)

    if @author.save
      render json: @author, status: :created, location: @author
    else
      render json: @author.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /authors/1
  # @return [JSON, nil]
  def update
    if @author.update(author_params)
      render json: @author
    else
      render json: @author.errors, status: :unprocessable_entity
    end
  end

  # DELETE /authors/1
  # @return [JSON, nil]
  def destroy
    @author.destroy!
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  # @return [Author]
  def set_author
    @author = Author.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  # @return [ActionController::Parameters]
  def author_params
    params.require(:author).permit(:name)
  end
end
