class HighlightsController < ApplicationController
  before_action :set_essay

  def create
    @highlight = @essay.highlights.build(highlight_params)
    @highlight.user = current_user

    if @highlight.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @essay }
      end
    else
      render turbo_stream: turbo_stream.update(
        "highlight-toolbar",
        partial: "highlights/toolbar",
        locals:  { highlight: @highlight, essay: @essay }
      ), status: :unprocessable_entity
    end
  end

  def destroy
    highlight = current_user.highlights.find(params[:id])
    highlight.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("highlight_#{highlight.id}") }
      format.html         { redirect_to @essay }
    end
  end

  private

  def set_essay
    @essay = Essay.find(params[:essay_id])
  end

  def highlight_params
    permitted = params.require(:highlight).permit(:content, :color, :note)
    raw_anchor = params.dig(:highlight, :anchor)
    anchor = raw_anchor.is_a?(String) ? JSON.parse(raw_anchor) : {}
    permitted.merge(anchor: anchor)
  rescue JSON::ParserError
    permitted.merge(anchor: {})
  end
end
