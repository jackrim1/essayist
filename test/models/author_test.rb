require "test_helper"

class AuthorTest < ActiveSupport::TestCase
  test "valid with just a name" do
    a = Author.new(name: "Virginia Woolf")
    assert a.valid?
  end

  test "requires name" do
    a = Author.new(name: nil)
    assert_not a.valid?
    assert_includes a.errors[:name], "can't be blank"
  end

  test "name must be globally unique" do
    Author.where("lower(name) = ?", "montaigne").delete_all
    Author.create!(name: "Montaigne")
    dup = Author.new(name: "Montaigne")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "name uniqueness is case-insensitive" do
    # "Seneca" already exists in fixtures
    dup = Author.new(name: "seneca")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "to_s returns name" do
    a = Author.new(name: "Epictetus")
    assert_equal "Epictetus", a.to_s
  end
end
