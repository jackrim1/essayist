class PositionsController < ApplicationController
  # PATCH /essays/:essay_id/position
  # Accepts JSON from navigator.sendBeacon; returns 204 No Content.
  def update
    essay    = Essay.find(params[:essay_id])
    position = params[:position].to_f.clamp(0.0, 1.0)
    progress = current_user.essay_progresses.find_or_initialize_by(essay_id: essay.id)
    progress.update!(last_read_position: position)
    head :no_content
  end
end
