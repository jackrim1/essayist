class EssaysController < ApplicationController
  before_action :set_essay, only: %i[show edit update destroy]

  def index
    @essays = current_user.essays.recent
  end

  def show
    @highlights = @essay.highlights.for_essay(@essay).includes(:tags)
  end

  def new
    @essay = current_user.essays.build
  end

  def create
    @essay = current_user.essays.build(essay_params)

    if @essay.save
      extract_text_now_then_enqueue_llm
      redirect_to @essay, notice: "Essay uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @essay.update(essay_params)
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
    params.require(:essay).permit(:title, :author, :view_mode, :original_file)
  end

  def extract_text_now_then_enqueue_llm
    return unless @essay.original_file.attached?

    @essay.original_file.open do |file|
      html = PdfExtractor.initial_html(file.path)
      if html.present?
        words = PdfExtractor.word_count(html)
        @essay.update_columns(content: html, word_count: words)
      end
    end

    LlmFormatEssayJob.perform_later(@essay.id)
  end
end
