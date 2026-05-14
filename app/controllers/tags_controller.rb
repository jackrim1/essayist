class TagsController < ApplicationController
  def index
    q = params[:q].to_s.strip.downcase.gsub(/[^a-z0-9-]/, "")

    scope = current_user.tags
      .left_joins(:highlight_tags)
      .group("tags.id")
      .limit(10)
      .select("tags.*, COUNT(highlight_tags.id) AS usage_count")

    scope = scope.where("name LIKE ?", "#{q}%") if q.present?
    scope = scope.order(q.present? ? :name : "COUNT(highlight_tags.id) DESC")

    render json: scope.map { |t| { name: t.name, count: Tag.format_count(t.usage_count.to_i) } }
  end

  def show
    @tag        = current_user.tags.find_by!(name: params[:name])
    @highlights = @tag.highlights.includes(:essay, :tags).order("essays.title", :created_at)
  end
end
