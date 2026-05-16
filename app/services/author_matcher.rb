# Finds or creates an Author record for an essay and links them.
# Normalises the essay's author string to the Author's canonical name.
# Safe to call multiple times (idempotent).
class AuthorMatcher
  # Minimum overlap fraction against the shorter name's significant words.
  MATCH_THRESHOLD = 0.8

  def self.resolve(essay)
    new(essay).resolve
  end

  def initialize(essay)
    @essay = essay
    @user  = essay.user
  end

  def resolve
    return if @essay.author_name.blank?

    candidate_words = significant_words(normalise(@essay.author_name))
    return if candidate_words.empty?

    existing = @user.authors.all
    matched  = existing.find { |a| fuzzy_match?(candidate_words, significant_words(normalise(a.name))) }

    if matched
      link(matched)
    else
      author = @user.authors.create!(name: @essay.author_name.strip)
      link(author)
    end
  rescue ActiveRecord::RecordNotUnique
    # Race condition — another thread created this author concurrently; retry find.
    matched = @user.authors.find_by(name: @essay.author_name.strip)
    link(matched) if matched
  end

  private

  def link(author)
    @essay.update_columns(author_id: author.id, author_name: author.name)
  end

  # True when candidate_words fuzzy-matches against existing_words.
  # Uses word-containment: all words from the shorter list appear in the longer list,
  # then falls back to threshold fraction if containment isn't perfect.
  def fuzzy_match?(candidate_words, existing_words)
    return false if candidate_words.empty? || existing_words.empty?

    # minmax_by with equal sizes returns the same element twice — use explicit split
    shorter = candidate_words.size <= existing_words.size ? candidate_words : existing_words
    longer  = candidate_words.size <= existing_words.size ? existing_words  : candidate_words

    matches = shorter.count { |w| longer.include?(w) }

    # Containment: every word in the shorter name appears in the longer
    return true if matches == shorter.size

    # Threshold fallback
    matches.to_f / shorter.size >= MATCH_THRESHOLD
  end

  def normalise(str)
    str.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squish
  end

  def significant_words(str)
    str.split.select { |w| w.length >= 3 }
  end
end
