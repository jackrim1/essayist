class EssaysController < ApplicationController
  before_action :set_essay, only: %i[show edit update destroy]

  def index
    @essays = current_user.essays.recent
  end

  def show
    @highlights  = @essay.highlights.for_essay(@essay).includes(:tags)
    @duplicates  = @essay.potential_duplicates
  end

  def new
    @essay = current_user.essays.build
  end

  def create
    @essay = current_user.essays.build(essay_params)

    if @essay.save
      AuthorMatcher.resolve(@essay)
      if @essay.original_file.attached?
        extract_text_now_then_enqueue_llm
      elsif @essay.source_url.present?
        ImportEssayFromUrlJob.perform_later(@essay.id, @essay.source_url)
      end
      redirect_to @essay, notice: "Essay saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @essay.update(essay_params)
      AuthorMatcher.resolve(@essay)
      redirect_to @essay, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @essay.destroy!
    redirect_to essays_path, notice: "Essay removed."
  end

  private

  def set_essay
    @essay = current_user.essays.find(params[:id])
  end

  def essay_params
    params.require(:essay).permit(:title, :author_name, :view_mode, :original_file, :source_url)
  end

  def extract_text_now_then_enqueue_llm
    return unless @essay.original_file.attached?

    @essay.original_file.open do |file|
      html = PdfExtractor.initial_html(file.path)
      if html.present?
        words = PdfExtractor.word_count(html)
        @essay.update_columns(content: html, word_count: words, content_simhash: DuplicateDetector.simhash(html))
      end
    end

    LlmFormatEssayJob.perform_later(@essay.id)
  end
end
