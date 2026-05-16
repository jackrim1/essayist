class RecommendationsController < ApplicationController
  before_action :set_essay, only: [:create]
  before_action :set_recommendation, only: [:show]

  def create
    kind = params[:kind].to_s
    unless Recommendation::KINDS.include?(kind)
      return redirect_to @essay, alert: "Invalid recommendation type."
    end

    recommendation = @essay.recommendations.create!(
      user:   current_user,
      kind:   kind,
      status: :pending
    )

    GenerateRecommendationsJob.perform_later(recommendation.id)
    redirect_to recommendation_path(recommendation)
  end

  def show
    @essay = @recommendation.essay
  end

  private

  def set_essay
    @essay = current_user.essays.find(params[:essay_id])
  end

  def set_recommendation
    @recommendation = current_user.recommendations.find(params[:id])
  end
end
