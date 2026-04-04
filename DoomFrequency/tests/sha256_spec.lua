local shared = require("DoomFrequency.42.media.lua.shared.DoomFrequencyShared")

describe("DoomFrequencyUtils.sha256", function()
  -- NIST / RFC 6234 test vectors, verified against Python hashlib.sha256
  it("hashes the empty string", function()
    assert.are.equal(
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      DoomFrequencyUtils.sha256("")
    )
  end)

  it("hashes 'abc'", function()
    assert.are.equal(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      DoomFrequencyUtils.sha256("abc")
    )
  end)

  it("hashes 'hello world'", function()
    assert.are.equal(
      "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9",
      DoomFrequencyUtils.sha256("hello world")
    )
  end)

  it("hashes a pangram (> 55 bytes, forces a second block)", function()
    assert.are.equal(
      "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
      DoomFrequencyUtils.sha256("The quick brown fox jumps over the lazy dog")
    )
  end)

  it("hashes 'DoomFrequency'", function()
    assert.are.equal(
      "6700e4e6d8598d63a16f3f7279ad1031ec224a34996a9a68b03392bd5a319402",
      DoomFrequencyUtils.sha256("DoomFrequency")
    )
  end)

  it("produces a 64-character lowercase hex string", function()
    local result = DoomFrequencyUtils.sha256("any input")
    assert.are.equal(64, #result)
    assert.is_truthy(result:match("^[0-9a-f]+$"))
  end)
end)
