require "digest"

# Detects near-duplicate essays using SimHash — a locality-sensitive hashing
# technique where similar documents produce hashes with low Hamming distance.
#
# Algorithm:
#   1. Normalize content (strip HTML, lowercase, collapse whitespace)
#   2. For each word, compute a 64-bit hash and vote +1/-1 on each bit position
#   3. Final bit is 1 if the sum for that position is positive
#
# Documents with Hamming distance ≤ THRESHOLD are considered potential duplicates.
# At threshold 10 this catches documents that are ~85%+ similar.
module DuplicateDetector
  THRESHOLD = 10

  def self.simhash(content)
    words = normalize(content).split
    return nil if words.size < 20

    v = Array.new(64, 0)
    words.each do |word|
      h = Digest::SHA256.hexdigest(word).to_i(16)
      64.times { |i| v[i] += h[i] == 1 ? 1 : -1 }
    end

    result = 0
    v.each_with_index { |sum, i| result |= (1 << i) if sum > 0 }
    # PostgreSQL bigint is signed 64-bit; convert unsigned result to signed range.
    result >= (1 << 63) ? result - (1 << 64) : result
  end

  def self.hamming_distance(a, b)
    return 64 if a.nil? || b.nil?
    # Mask to unsigned 64-bit before counting so negative (signed) values work correctly.
    xor = (a ^ b) & 0xFFFFFFFFFFFFFFFF
    xor.to_s(2).count("1")
  end

  def self.similar?(a, b)
    hamming_distance(a, b) <= THRESHOLD
  end

  def self.normalize(content)
    Nokogiri::HTML.fragment(content.to_s).text
      .downcase
      .gsub(/[^a-z0-9\s]/, " ")
      .squish
  end
end
