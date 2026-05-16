require "test_helper"

class AuthorTest < ActiveSupport::TestCase
  test "valid with user and name" do
    a = Author.new(user: users(:one), name: "Virginia Woolf")
    assert a.valid?
  end

  test "requires name" do
    a = Author.new(user: users(:one), name: nil)
    assert_not a.valid?
    assert_includes a.errors[:name], "can't be blank"
  end

  test "name must be unique per user" do
    Author.create!(user: users(:one), name: "Montaigne")
    dup = Author.new(user: users(:one), name: "Montaigne")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "same name allowed for different users" do
    other_user = User.create!(email: "other2@example.com", password: "password123")
    Author.create!(user: users(:one), name: "Montaigne")
    a = Author.new(user: other_user, name: "Montaigne")
    assert a.valid?
  end

  test "name uniqueness is case-insensitive" do
    # "Seneca" is already in fixtures for users(:one) — just check dup is invalid
    dup = Author.new(user: users(:one), name: "seneca")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "to_s returns name" do
    a = Author.new(name: "Epictetus")
    assert_equal "Epictetus", a.to_s
  end
end
