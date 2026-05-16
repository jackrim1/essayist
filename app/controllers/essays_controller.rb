class EssaysController < ApplicationController
  before_action :set_essay, only: %i[show edit update destroy]

  def index
    @essays            = Essay.recent
    @highlight_counts  = current_user.highlights.group(:essay_id).count
    @recent_highlights = current_user.highlights.recent(10).includes(:essay)
    progress_records   = current_user.essay_progresses.where(essay_id: @essays.map(&:id))
    @progress          = progress_records.index_by(&:essay_id)
  end

  def search
    q = params[:q].to_s.strip
    essays = q.length >= 2 ? Essay.search_by(q).limit(8) : Essay.none
    render json: essays.map { |e|
      { id: e.id, title: e.title, author_name: e.author_name, path: essay_path(e) }
    }
  end

  def show
    @highlights = @essay.highlights.for_essay(@essay).includes(:tags)
    @duplicates = @essay.potential_duplicates
    @progress   = current_user.essay_progresses.find_or_initialize_by(essay_id: @essay.id)
  end

  def new
    @essay = Essay.new
  end

  def create
    @essay              = Essay.new(essay_params)
    @essay.uploaded_by  = current_user

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
    @essay = Essay.find(params[:id])
  end

  def essay_params
    params.require(:essay).permit(:title, :author_name, :original_file, :source_url)
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
