require "test_helper"

class AuthorMatcherTest < ActiveSupport::TestCase
  # Each test uses a fresh user to avoid fixture author interference.
  def fresh_user
    @_user ||= User.create!(
      email:    "matcher#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
  end

  def make_essay(author_string, user: fresh_user)
    user.essays.create!(
      title:             "Test Essay",
      author_name:       author_string,
      last_read_position: 0,
      view_mode:         :infinite
    )
  end

  # ── creates new Author ───────────────────────────────────────────────────────

  test "creates a new Author when none exists" do
    essay = make_essay("Michel de Montaigne")
    assert_difference "fresh_user.authors.count", 1 do
      AuthorMatcher.resolve(essay)
    end
    assert_equal "Michel de Montaigne", fresh_user.authors.last.name
  end

  test "links essay to newly created Author" do
    essay = make_essay("Virginia Woolf")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_not_nil essay.author_id
    assert_equal "Virginia Woolf", essay.author_name
  end

  # ── exact match ─────────────────────────────────────────────────────────────

  test "links to existing Author on exact name match" do
    author = fresh_user.authors.create!(name: "George Orwell")
    essay  = make_essay("George Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id
  end

  # ── fuzzy match: superset ───────────────────────────────────────────────────

  test "matches longer name to shorter canonical (extra middle name)" do
    author = fresh_user.authors.create!(name: "George Orwell")
    essay  = make_essay("George Bernard Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id,
      "George Bernard Orwell should match canonical George Orwell"
  end

  test "matches shorter name to longer canonical" do
    author = fresh_user.authors.create!(name: "George Bernard Orwell")
    essay  = make_essay("George Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id,
      "George Orwell should match canonical George Bernard Orwell"
  end

  test "matches when article/prefix differs" do
    author = fresh_user.authors.create!(name: "J.K. Rowling")
    essay  = make_essay("Joanne Rowling")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal author.id, essay.author_id
  end

  # ── no false positives ──────────────────────────────────────────────────────

  test "does not match unrelated authors" do
    fresh_user.authors.create!(name: "George Orwell")
    essay = make_essay("George Wells")
    AuthorMatcher.resolve(essay)
    assert_equal 2, Author.where(user: fresh_user).count
    essay.reload
    assert_equal "George Wells", fresh_user.authors.find(essay.author_id).name
  end

  test "does not match when only one short word overlaps" do
    fresh_user.authors.create!(name: "Samuel Johnson")
    essay = make_essay("Samuel Beckett")
    AuthorMatcher.resolve(essay)
    assert_equal 2, Author.where(user: fresh_user).count
  end

  # ── canonical name normalisation ────────────────────────────────────────────

  test "normalises essay author string to canonical name" do
    author = fresh_user.authors.create!(name: "George Orwell")
    essay  = make_essay("George Bernard Orwell")
    AuthorMatcher.resolve(essay)
    essay.reload
    assert_equal "George Orwell", essay.author_name,
      "Author string should be normalised to the canonical Author name"
  end

  # ── idempotent ──────────────────────────────────────────────────────────────

  test "calling resolve twice does not create duplicate Authors" do
    essay = make_essay("Michel de Montaigne")
    AuthorMatcher.resolve(essay)
    assert_no_difference "Author.where(user: fresh_user).count" do
      AuthorMatcher.resolve(essay)
    end
  end

  # ── blank author ─────────────────────────────────────────────────────────────

  test "does nothing when author string is blank" do
    essay = fresh_user.essays.create!(
      title: "No Author", author_name: nil,
      last_read_position: 0, view_mode: :infinite
    )
    assert_no_difference "Author.where(user: fresh_user).count" do
      AuthorMatcher.resolve(essay)
    end
    essay.reload
    assert_nil essay.author_id
  end
end
