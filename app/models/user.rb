class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :highlights,        dependent: :destroy
  has_many :tags,              dependent: :destroy
  has_many :recommendations,   dependent: :destroy
  has_many :essay_progresses,  dependent: :destroy
  has_many :essays, through: :essay_progresses

  FONT_SIZES  = %w[text-sm text-base text-lg text-xl text-2xl].freeze
  VIEW_MODES  = %w[infinite paged].freeze
  THEMES      = %w[system light dark].freeze

  # Convenience readers with safe defaults
  def font_size  = preferences.fetch("font_size",  "text-base")
  def view_mode  = preferences.fetch("view_mode",  "infinite")
  def theme      = preferences.fetch("theme",      "system")

  def update_preferences(patch)
    cleaned = patch.slice("font_size", "view_mode", "theme")
    update!(preferences: preferences.merge(cleaned))
  end
end
