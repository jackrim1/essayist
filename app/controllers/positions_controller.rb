class PositionsController < ApplicationController
  # PATCH /essays/:essay_id/position
  # Accepts JSON from navigator.sendBeacon; returns 204 No Content.
  def update
    essay    = current_user.essays.find(params[:essay_id])
    position = params[:position].to_f.clamp(0.0, 1.0)
    essay.update_column(:last_read_position, position)
    head :no_content
  end
end
