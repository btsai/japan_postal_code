# -*- coding: utf-8 -*-
# data from this listing:
#   http://www.post.japanpost.jp/zipcode/dl/kogaki-zip.html
# see bottom of generator.rb file for more info about listing

require 'csv'
require 'nkf'

class JapanPostalCode

  MAX_RESULTS_SIZE = 10

  def self.validate_region_name!(region_name)
    if region_name.nil?
      raise 'Invalid region name.'
      puts "\nPlease pass in a region name from [national, metro, kanto, kansai, tokyo, kanagawa, chiba, saitama, osaka, nara, kyoto, hyogo, aichi, nagoya, test]"
      return false
    end
    true
  end

  def self.search(postal_code)
    if Rails.env.test?
      searcher = JapanPostalCode.new.load('metro')
    else
      searcher = Rails.cache.fetch('japan_postal_codes'){
        # if not in memcache, load it once
        JapanPostalCode.new.load('metro')
      }
    end
    searcher.lookup_by_code(postal_code)
  end

  attr_reader :mapping

  def load(region_name)
    JapanPostalCode.validate_region_name!(region_name)

    time = Time.now
    data_folder = File.dirname(__FILE__) + '/japan_postal_code/data'
    filepath = File.join(data_folder, region_name) + '.marshal'
    @mapping = Marshal.load(`gzip -dc #{filepath}`.chomp)

    message = "=> Loaded JapanPostalCode in #{Time.now - time}s"
    Rails.logger.info(message)
    puts message if Rails.env.development?

    return self
  end

  def lookup_by_code(postal_code, no_size_limit = nil)
    return [] if postal_code.nil?

    postal_code = ascii_number(postal_code)

    if postal_code.size < 3
      postal_code = sprintf('%03d', postal_code)
    end

    numeric_postal_code = postal_code.to_i

    if postal_code.size == 7
      # 7-digit codes map to an array of arrays of names
      # return a flattened array of postal_areas mapping to the array of 7-digit codes
      matches = @mapping[numeric_postal_code]
      return [] unless matches

      postal_areas = fetch_region_names(matches, numeric_postal_code)
      filtered_results(postal_areas, no_size_limit)

    else
      # shorter 3 or 5 digit codes map to an array of 7 digit codes
      # return array of postal_areas names for those codes
      matches = @mapping[:old_codes][numeric_postal_code]

      # if fails, try the first three digits
      return [] unless matches

      combined_areas = []
      matches.each do |postal_code_7|
        postal_areas = @mapping[postal_code_7]
        next unless postal_areas

        combined_areas += fetch_region_names(postal_areas, postal_code_7)
      end
      filtered_results(combined_areas, no_size_limit)

    end
  end

  private

  def filtered_results(array, no_size_limit)
    no_size_limit ?
      array.compact :
      array.compact.slice(0, MAX_RESULTS_SIZE)
  end

  def fetch_region_names(postal_areas, numeric_postal_code)
    postal_areas.map do |postal_area|
      prefecture_id, city_id, area_id = postal_area[0], postal_area[1], postal_area[2]

      code = sprintf('%07d', numeric_postal_code)
      prefecture = @mapping[:prefecture][prefecture_id] || ''
      city = @mapping[:city][city_id] || ''
      area = @mapping[:area][area_id] || ''

      [code, prefecture, city, area]
    end
  end

  JA_EN_MAPPING = {
    '　' => ' ',
    '０-９' => '0-9',
    'ａ-ｚ' => 'a-z',
    'Ａ-Ｚ' => 'A-Z',
    'ー' => '-',
  }

  def ascii_number(postal_code)
    ascii = NKF.nkf('-X -w', String(postal_code)).tr(
      JA_EN_MAPPING.keys.join(''), JA_EN_MAPPING.values.join('')
    )
    ascii.gsub('-', '').strip
  end

end

