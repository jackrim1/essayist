require "test_helper"

class AuthorMatcherTest < ActiveSupport::TestCase
  def make_essay(author_string)
    Essay.create!(
      title:       "Test Essay #{SecureRandom.hex(4)}",
      author_name: author_string
    )
  end

  # ── creates new Author ───────────────────────────────────────────────────────

  test "creates a new Author when none exists" do
    Author.where(name: "Michel de Montaigne").delete_all
    essay = make_essay("Michel de Montaigne")
    assert_difference "Author.count", 1 do
      AuthorMatcher.resolve(essay)
    end
    assert Author.exists?(name: "Michel de Montaigne")
  end

  test "links essay to newly created Author" do
    Author.where("lower(name) = ?", "virginia woolf").delete_all
    essay = make_essay("Virginia Woolf")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_not_nil essay.author_id
    assert_equal "Virginia Woolf", essay.author_name
  end

  # ── exact match ─────────────────────────────────────────────────────────────

  test "links to existing Author on exact name match" do
    author = Author.find_or_create_by!(name: "George Orwell")
    essay  = make_essay("George Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id
  end

  # ── fuzzy match: superset ───────────────────────────────────────────────────

  test "matches longer name to shorter canonical (extra middle name)" do
    Author.where("lower(name) = ?", "george bernard orwell").delete_all
    author = Author.find_or_create_by!(name: "George Orwell")
    essay  = make_essay("George Bernard Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id,
      "George Bernard Orwell should match canonical George Orwell"
  end

  test "matches shorter name to longer canonical" do
    Author.where("lower(name) = ?", "george orwell").delete_all
    author = Author.find_or_create_by!(name: "George Bernard Orwell")
    essay  = make_essay("George Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id,
      "George Orwell should match canonical George Bernard Orwell"
  end

  test "matches when article/prefix differs" do
    Author.where("lower(name) = ?", "joanne rowling").delete_all
    author = Author.find_or_create_by!(name: "J.K. Rowling")
    essay  = make_essay("Joanne Rowling")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id
  end

  # ── no false positives ──────────────────────────────────────────────────────

  test "does not match unrelated authors" do
    Author.where("lower(name) IN (?)", ["george orwell", "george wells"]).delete_all
    Author.create!(name: "George Orwell")
    essay = make_essay("George Wells")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert Author.exists?(name: "George Wells")
    assert_equal "George Wells", Author.find(essay.author_id).name
  end

  test "does not match when only one short word overlaps" do
    Author.where("lower(name) IN (?)", ["samuel johnson", "samuel beckett"]).delete_all
    Author.create!(name: "Samuel Johnson")
    essay = make_essay("Samuel Beckett")
    before_count = Author.count
    AuthorMatcher.resolve(essay)
    assert_equal before_count + 1, Author.count
  end

  # ── canonical name normalisation ────────────────────────────────────────────

  test "normalises essay author string to canonical name" do
    Author.where("lower(name) = ?", "george bernard orwell").delete_all
    Author.find_or_create_by!(name: "George Orwell")
    essay = make_essay("George Bernard Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal "George Orwell", essay.author_name,
      "Author string should be normalised to the canonical Author name"
  end

  # ── idempotent ──────────────────────────────────────────────────────────────

  test "calling resolve twice does not create duplicate Authors" do
    Author.where("lower(name) = ?", "michel de montaigne").delete_all
    essay = make_essay("Michel de Montaigne")
    AuthorMatcher.resolve(essay)
    before_count = Author.count
    assert_no_difference "Author.count" do
      AuthorMatcher.resolve(essay)
    end
  end

  # ── blank author ─────────────────────────────────────────────────────────────

  test "does nothing when author string is blank" do
    essay = Essay.create!(title: "No Author", author_name: nil)
    before_count = Author.count
    assert_no_difference "Author.count" do
      AuthorMatcher.resolve(essay)
    end
    essay.reload
    assert_nil essay.author_id
  end
end
