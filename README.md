### Japan Postal Code Lookup


#### Overview

Yahoo provides a nice web API for personal developers and SOME business uses at:
* Reference: http://developer.yahoo.co.jp/webapi/map/openlocalplatform/v1/zipcodesearch.html
* API url: http://search.olp.yahooapis.jp/OpenLocalPlatform/V1/zipCodeSearch

However, this is not available through https because their SSL certificate wildcards to olp.yahooapis.jp and Firefox and other browsers block mixed content by default.

So your only choice is to wrap your own, and I couldn't find any existing gems.

Fortunately the Japan Post Office (JPO) provides downloads of their entire postal code data, updated on a monthly basis at:
* http://www.post.japanpost.jp/zipcode/dl/kogaki-zip.html

#### This only runs on Ruby 1.9 or above.


#### Usage

This library has two components:


##### Generator Class

This is generator class that downloads the zip format file from the JPO site and strips out the relevant data and saves it in a Ruby marshalized file (also zipped).
  You must have gzip on your machine (both generation machine and reading machine)

Generate with:
```
ruby lib/japan_postal_code.rb generate REGION_NAME
```

Where REGION_NAME is in downcase of:
* TOKYO
* CHIBA
* SAITAMA
* KANAGAWA
* OSAKA
* KYOTO
* NARA
* HYOGO
* AICHI
* NATIONAL
* KANTO = [TOKYO, CHIBA, SAITAMA, KANAGAWA]
* KANSAI = [OSAKA, KYOTO, NARA, HYOGO]
* NAGOYA = [AICHI]
* METRO = KANTO + KANSAI + NAGOYA

The generated file will be saved in lib/japan_postal_code/data (the library depends on this folder relationship).


##### Reader Class

This is reader class that performs the lookup based on postal code or area name and returns an array of matched postal areas.

Use the reader class by:
```
loader = JapanPostalCode.new.load('REGION_NAME')
```

Then lookup by:
```
postal_areas = loader.lookup_by_code(POSTAL_CODE)
```
Where POSTAL_CODE is a String of format:
* 3 or 5 digits (old postal system), or 7 digits (new postal system)
* ASCII or Japanese numbers (mixed ok)

Return values are of format:
```
[
  [7-digit postal code, prefecture name, city name, postal area name],
  ... other matches
]

e.g.

[
  ['1500031', '東京都', '渋谷区', '桜丘町']
]
```


