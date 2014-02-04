# -*- coding: utf-8 -*-
require 'minitest/autorun'  # using minitest 4.3
require_relative '../lib/japan_postal_code'

class JapanPostalCodeTest < Minitest::Unit::TestCase

  NATIONAL = JapanPostalCode.new.load('national')

  def test_load
    begin
      loader = JapanPostalCode.new.load('test')
    rescue
      puts "If you're missing the test file, run the generator to create the test file."
    end
    assert(!loader.mapping.nil? && loader.mapping.is_a?(Hash),
      "Should load marshalized hash")
    assert(loader.mapping[1500031],
      "Should have sakuragaoka-cho data")
    assert(loader.is_a?(JapanPostalCode),
      "Should return self so it can be used as is")
  end

  def test_ascii_number
    codes = JapanPostalCode.new
    assert_equal(12345, codes.send(:ascii_number, '12345').to_i,
      "Should handle ascii text number")
    assert_equal(12345, codes.send(:ascii_number, '１２３４５').to_i,
      "Should handle ja text number")
    assert_equal(123, codes.send(:ascii_number, '00123').to_i,
      "Should remove front prefix zeroes")
    assert_equal(123, codes.send(:ascii_number, '００１２３').to_i,
      "Should remove ja front prefix zeroes")
    assert_equal(12300, codes.send(:ascii_number, '12300').to_i,
      "Should not remove suffix zeroes")
    assert_equal(12300, codes.send(:ascii_number, '１２３００').to_i,
      "Should not remove ja suffix zeroes")
    assert_equal(12345, codes.send(:ascii_number, '１2３4５').to_i,
      "Should handle mixed ascii and ja")
  end

  def test_lookup_by_code_new_7_digit_code
    assert_equal([['1500031', '東京都', '渋谷区', '桜丘町']], NATIONAL.lookup_by_code('1500031'),
      "Should return code, prefecture, city, and area for Sakuragokacho")
    assert_equal([["0010000", "北海道", "札幌市北区", "以下に掲載がない場合"]], NATIONAL.lookup_by_code('0010000'),
      "Should return code, prefecture, city, and area for Sapporo Kita-ku")
  end

  def test_lookup_by_code_new_7_digit_code_ignores_hyphens_and_spaces_ascii
    assert_equal([['1500031', '東京都', '渋谷区', '桜丘町']], NATIONAL.lookup_by_code(' 150-0031 '),
      "Should return code, prefecture, city, and area for Sakuragokacho")
  end

  def test_lookup_by_code_new_7_digit_code_ignores_hyphens_and_spaces_ja
    assert_equal([['1500031', '東京都', '渋谷区', '桜丘町']], NATIONAL.lookup_by_code('　１５０ー００３１　'),
      "Should return code, prefecture, city, and area for Sakuragokacho")
  end

  def test_cities_are_not_mixed_within_3_digit_code
    mapping = NATIONAL.mapping

    cities = mapping[:old_codes][150].map do |code|
      mapping[code].map{ |pid, cid, aid| mapping[:city][cid] }
    end.flatten.uniq
    assert_equal(['渋谷区'], cities,
      "Should only find Shibuya-ku")

    cities = mapping[:old_codes][1].map do |code|
      mapping[code].map{ |pid, cid, aid| mapping[:city][cid] }
    end.flatten.uniq
    assert_equal(['札幌市北区'], cities,
      "Should only find Sapporo Kita-ku")
  end

  def test_lookup_by_code_returns_max_10_by_default
    assert_equal(61, NATIONAL.lookup_by_code('150', true).size,
      "Should return 61 if no_limit option is true")
    assert_equal(10, NATIONAL.lookup_by_code('150').size,
      "Should return 10 if no_limit option is nil")
  end

  def test_lookup_by_code_takes_string_or_int
    assert_equal(61, NATIONAL.lookup_by_code('150', true).size,
      "Should return 61 with string postal code")
    assert_equal(10, NATIONAL.lookup_by_code(150).size,
      "Should also return 61 with int postal code")
  end

  def test_lookup_by_code_old_3_digit_code_shibuya
    matches = NATIONAL.lookup_by_code('150', true)

    codes = matches.map{ |m| m[0] }.uniq
    assert_equal(61, codes.size,
      "Should find 61 uniq 7-digit codes in 150")

    prefectures = matches.map{ |m| m[1] }.compact.uniq
    assert_equal(['東京都'], prefectures,
      "Should only find Tokyo")

    cities = matches.map{ |m| m[2] }.compact.uniq
    assert_equal(['渋谷区'], cities,
      "Should only find Shibuya-ku")

    areas = matches.map{ |m| m[3] }.compact.uniq
    assert_equal(61, areas.size,
      "Should find 61 uniq postal areas in 150")

    assert_equal('桜丘町', areas[8],
      "Should have Sakuragokacho")
  end

  def test_lookup_by_code_old_5
    matches = NATIONAL.lookup_by_code('16305', true)
    codes = matches.map{ |m| m[0] }.uniq
    assert_equal(51, codes.size,
      "Should find 51 uniq 7-digit codes in 16305")

    prefectures = matches.map{ |m| m[1] }.compact.uniq
    assert_equal(['東京都'], prefectures,
      "Should only find Tokyo")

    cities = matches.map{ |m| m[2] }.compact.uniq
    assert_equal(['新宿区'], cities,
      "Should only find Shinjuku-ku")

    areas = matches.map{ |m| m[3] }.compact.uniq
    assert_equal(51, areas.size,
      "Should find 51 uniq postal areas in 150")
  end

  def test_lookup_by_code_pads_leading_zeroes_before_lookup
    codes = NATIONAL.lookup_by_code('001', true).map(&:first)
    assert(codes.size > 0,
      "Should find codes for '001'")
    assert_equal(codes, NATIONAL.lookup_by_code('1', true).map(&:first),
      "Should return same for '001' as for '1'")
  end

  def test_lookup_with_invalid_code_return_blank_array
    assert_equal([], NATIONAL.lookup_by_code('9999999'),
      "Should not find any code for 9999999")
    assert_equal([], NATIONAL.lookup_by_code('invalid_string'),
      "Should not find any code for invalid_string")
  end

end
