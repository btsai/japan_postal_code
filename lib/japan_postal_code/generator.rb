# run the generation script like this:
# $> ruby lib/japan_postal_code.rb generate REGION_NAME, REGION_NAME, ...

# metro.marshal after loading uses about 14MB in memory, so tolerable for in-memory hash lookup
#   pid, size = `ps ax -o pid,rss | grep -E "^[[:space:]]*#{$$}"`.strip.split.map(&:to_i)
# tokyo uses about 12MB
# national uses about 50MB in memory

require_relative '../japan_postal_code'

class JapanPostalCode::Generator
  URL_BASE = 'http://www.post.japanpost.jp/zipcode/dl/kogaki/zip/'

  TOKYO = '13tokyo.zip'
  CHIBA = '12chiba.zip'
  SAITAMA = '11saitam.zip'
  KANAGAWA = '14kanaga.zip'
  OSAKA = '27osaka.zip'
  KYOTO = '26kyouto.zip'
  NARA = '29nara.zip'
  HYOGO = '28hyogo.zip'
  AICHI = '23aichi.zip'

  NATIONAL = ['ken_all.zip']
  KANTO = [TOKYO, CHIBA, SAITAMA, KANAGAWA]
  KANSAI = [OSAKA, KYOTO, NARA, HYOGO]
  NAGOYA = [AICHI]
  METRO = KANTO + KANSAI + NAGOYA

  def create_marshal_files(region_names)
    region_names.each do |region_name|
      JapanPostalCode.validate_region_name!(region_name)
      start_time = Time.now
      region_name, filename = check_if_generating_test_data(region_name)

      csv_file_data = download_unzip_csv_files(region_name)
      csv_rows = convert_to_utf8_csv_data(csv_file_data)
      marshalized = create_marshal_store_from_csv_data(csv_rows)
      save_marshal_file(marshalized, "#{filename}.marshal")

      puts "> Finished #{region_name}. (#{sprintf('%0.2f', (Time.now - start_time))}s)"
    end
  end

  private

  def check_if_generating_test_data(region_name)
    if region_name == 'test'
      @test_data = true
      ['national', 'test']
    else
      [region_name, region_name]
    end
  end

  def download_unzip_csv_files(region_name)
    regions = Array(self.class.const_get(region_name.upcase))
    regions.map do |region_file|
      `curl -s -X GET '#{URL_BASE}#{region_file}' | gzip -dc`
    end.join('')
  end

  def convert_to_utf8_csv_data(csv_file_data)
    # force shift-jis to utf-8
    puts "> Converting to UTF8 and reading file.."
    data = csv_file_data.force_encoding("SHIFT_JIS").encode("UTF-8")

    # csv and sort it
    puts "> CSV parsing..."
    csv_rows = CSV.parse(data)
    csv_rows.sort{ |a,b| a[2] <=> b[2] }
  end

  def create_marshal_store_from_csv_data(csv_rows)
    # create hash
    puts "> Creating hash..."
    code_count= 0
    @hash = { :old_codes => {}, :prefecture => {}, :city => {}, :area => {} }
    @counter = { :prefecture => 0, :city => 0, :area => 0 }  # performance booster - counting keys is slow

    csv_rows.each do |row|
      # if generating test data, only handle shibuya 150xxxx and hokkaido 001xxxx
      next if @test_data && !row[1].match(/^(001|150)/)

      postal_new7 = row[2].strip.to_i

      # store pointer to the 7 digit codes mapped to the older 3 or 5 digit codes
      postal_old3 = row[1].strip.to_i
      @hash[:old_codes][postal_old3] ||= []
      @hash[:old_codes][postal_old3] << postal_new7

      # unique lookup hash for the actual content
      prefecture = row[6].strip
      city = row[7].strip
      area = row[8].strip

      # store the postal region names into a unique hash and use int pointers to them
      prefecture_id = add_content(:prefecture, prefecture, postal_new7)
      city_id = add_content(:city, city, postal_new7)
      area_id = add_content(:area, area, postal_new7)

      # more than one set of addresses can be mapped to the same postal_7, so we store arrays of these pointers
      @hash[postal_new7] ||= []
      unless @hash[postal_new7].include?([prefecture_id, city_id, area_id])
        @hash[postal_new7] << [prefecture_id, city_id, area_id]
        code_count += 1
      end

    end

    invert_content_hashes_to_id_lookup

    puts "> Found #{code_count} 7-digit postal codes"

    # marshalize hash and save
    puts "> Marshalizing..."
    marshalized = Marshal.dump(@hash)
  end

  def add_content(type, content, postal_new7)
    id = @hash[type][content]
    unless id
      id = @counter[type]
      @hash[type][content] = id
      @counter[type] += 1
    end
    id
  end

  def invert_content_hashes_to_id_lookup
    [:prefecture, :city, :area].each do |type|
      assert_hashes_are_unique(type, @hash[type])
      @hash[type] = @hash[type].invert
    end
  end

  # testing to make sure that we have a uniq set of keys and values, no duplicates
  def assert_hashes_are_unique(type, content_hash)
    key_count, key_uniq_count = content_hash.keys.size, content_hash.keys.uniq.size
    value_count, value_uniq_count = content_hash.values.size, content_hash.values.uniq.size
    puts "> ERROR: #{type} names duplicated. #{[key_count, key_uniq_count].inspect}" unless key_count == key_uniq_count
    puts "> ERROR: #{type} ids duplicated. #{[value_count, value_uniq_count].inspect}" unless value_count == value_uniq_count
  end

  def save_marshal_file(marshalized, filename)
    puts "> Saving..."
    folder = File.dirname(__FILE__) + '/data'
    filepath = File.join(folder, filename)
    File.open(filepath, 'wb'){ |f| f.write(marshalized) }
    `gzip #{filepath} --force`
  end

end

if __FILE__ == $0
  exit unless ARGV[0] == 'generate'

  JapanPostalCode::Generator.new.create_marshal_files(ARGV[1..-1])
end

# explanation of JPO data here:
#   http://www.post.japanpost.jp/zipcode/dl/readme.html
#
# data format is:
#  0 全国地方公共団体コード(JIS X0401、X0402)………　半角数字
#  1 (旧)郵便番号(5桁)………………………………………　半角数字
#  2 郵便番号(7桁)………………………………………　半角数字
#  3 都道府県名　…………　半角カタカナ(コード順に掲載)　(注1)
#  4 市区町村名　…………　半角カタカナ(コード順に掲載)　(注1)
#  5 町域名　………………　半角カタカナ(五十音順に掲載)　(注1)
#  6 都道府県名　…………　漢字(コード順に掲載)　(注1,2)
#  7 市区町村名　…………　漢字(コード順に掲載)　(注1,2)
#  8 町域名　………………　漢字(五十音順に掲載)　(注1,2)
#  9  一町域が二以上の郵便番号で表される場合の表示　(注3)　(「1」は該当、「0」は該当せず)
# 10  小字毎に番地が起番されている町域の表示　(注4)　(「1」は該当、「0」は該当せず)
# 11  丁目を有する町域の場合の表示　(「1」は該当、「0」は該当せず)
# 12  一つの郵便番号で二以上の町域を表す場合の表示　(注5)　(「1」は該当、「0」は該当せず)
# 13  更新の表示（注6）（「0」は変更なし、「1」は変更あり、「2」廃止（廃止データのみ使用））
# 14  変更理由　(「0」は変更なし、「1」市政・区政・町政・分区・政令指定都市施行、「2」住居表示の実施、「3」区画整理、「4」郵便区調整等、「5」訂正、「6」廃止(廃止データのみ使用))

# data looks like:
#  0 - 13101
#  1 - 100
#  2 - 1000000
#  3 - ﾄｳｷｮｳﾄ
#  4 - ﾁﾖﾀﾞｸ
#  5 - ｲｶﾆｹｲｻｲｶﾞﾅｲﾊﾞｱｲ
#  6 - 東京都
#  7 - 千代田区
#  8 - 以下に掲載がない場合
#  9 - 0
# 10 - 0
# 11 - 0
# 12 - 0
# 13 - 0
# 14 - 0
