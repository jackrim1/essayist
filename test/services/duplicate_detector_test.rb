require "test_helper"

class DuplicateDetectorTest < ActiveSupport::TestCase
  SAMPLE = "The quick brown fox jumps over the lazy dog. " * 10

  test "simhash returns a 64-bit integer for normal content" do
    hash = DuplicateDetector.simhash(SAMPLE)
    assert_kind_of Integer, hash
    assert hash >= 0
    assert hash < 2**64
  end

  test "simhash returns nil for blank content" do
    assert_nil DuplicateDetector.simhash("")
    assert_nil DuplicateDetector.simhash(nil)
  end

  test "simhash returns nil for content with fewer than 20 words" do
    assert_nil DuplicateDetector.simhash("too short")
  end

  test "identical documents produce identical simhash" do
    assert_equal DuplicateDetector.simhash(SAMPLE), DuplicateDetector.simhash(SAMPLE)
  end

  test "strips HTML before hashing" do
    html    = '<p class="prose-page">' + SAMPLE + "</p>"
    plain   = SAMPLE
    assert_equal DuplicateDetector.simhash(html), DuplicateDetector.simhash(plain)
  end

  test "nearly identical documents have low hamming distance" do
    original = SAMPLE * 3
    tweaked  = original.sub("quick", "fast").sub("lazy", "sleepy")
    h1 = DuplicateDetector.simhash(original)
    h2 = DuplicateDetector.simhash(tweaked)
    assert DuplicateDetector.hamming_distance(h1, h2) <= DuplicateDetector::THRESHOLD,
      "Expected similar docs to be within threshold"
  end

  test "completely different documents are not similar" do
    text1 = ("alpha beta gamma delta epsilon " * 20)
    text2 = ("zulu yankee xray whiskey victor " * 20)
    h1 = DuplicateDetector.simhash(text1)
    h2 = DuplicateDetector.simhash(text2)
    assert_not DuplicateDetector.similar?(h1, h2), "Expected different docs to not be similar"
  end

  test "hamming_distance of identical hashes is 0" do
    h = DuplicateDetector.simhash(SAMPLE)
    assert_equal 0, DuplicateDetector.hamming_distance(h, h)
  end

  test "hamming_distance returns 64 for nil inputs" do
    assert_equal 64, DuplicateDetector.hamming_distance(nil, 12345)
  end

  test "similar? returns true for identical hashes" do
    h = DuplicateDetector.simhash(SAMPLE)
    assert DuplicateDetector.similar?(h, h)
  end
end
