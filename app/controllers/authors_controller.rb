class AuthorsController < ApplicationController
  def show
    @author = current_user.authors.find(params[:id])
    @essays = @author.essays.recent
  end
end
