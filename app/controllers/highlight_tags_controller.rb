class HighlightTagsController < ApplicationController
  before_action :set_highlight

  def create
    name = params[:name].to_s.strip.downcase.gsub(/[^a-z0-9-]/, "")
    return head :unprocessable_entity if name.blank?

    tag           = current_user.tags.find_or_create_by!(name: name)
    @highlight_tag = @highlight.highlight_tags.find_or_initialize_by(tag: tag)
    @created       = @highlight_tag.new_record?
    @highlight_tag.save! if @created

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def destroy
    @highlight_tag = @highlight.highlight_tags.find(params[:id])
    @highlight_tag.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def set_highlight
    @highlight = current_user.highlights.find(params[:highlight_id])
  end
end
