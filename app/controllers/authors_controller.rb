class AuthorsController < ApplicationController
  def show
    @author = Author.find(params[:id])
    @essays = @author.essays.recent
  end
end
