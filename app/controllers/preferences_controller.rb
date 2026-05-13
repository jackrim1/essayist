class PreferencesController < ApplicationController
  # PATCH /preferences — syncs reader settings from localStorage to the DB
  def update
    current_user.update_preferences(preferences_params)
    head :no_content
  end

  private

  def preferences_params
    params.require(:user).require(:preferences).permit(:font_size, :view_mode, :theme)
  end
end
