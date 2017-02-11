require 'net/http'
require 'uri'
require 'rexml/document'

# Usage: 
#   weather = WeatherConnector.new
#   puts weather.get_weather('神奈川県', '東部', 'http://www.drk7.jp/weather/xml/14.xml', 'weatherforecast/pref/area[1]', 0)

class WeatherConnector
  def get_weather(pref, area, url, xpath, day_offset)
    uri = URI.parse(url)
    xml = Net::HTTP.get(uri)
    doc = REXML::Document.new(xml)

    case day_offset
    when 0
      xpath_prefix = xpath + '/info[1]' # today
    when 1
      xpath_prefix = xpath + '/info[2]' # tomorrow
    when 2
      xpath_prefix = xpath + '/info[3]' # day after tomorrow
    when 3
      xpath_prefix = xpath + '/info[4]' # two days after tomorrow
    else
      xpath_prefix = xpath + '/info[1]' # today
    end

    date = doc.elements[xpath_prefix].attributes['date']
    weather = doc.elements[xpath_prefix + '/weather'].text
    max = doc.elements[xpath_prefix + '/temperature/range[1]'].text
    min = doc.elements[xpath_prefix + '/temperature/range[2]'].text
    per00to06 = doc.elements[xpath_prefix + '/rainfallchance/period[1]'].text
    per06to12 = doc.elements[xpath_prefix + '/rainfallchance/period[2]'].text
    per12to18 = doc.elements[xpath_prefix + '/rainfallchance/period[3]'].text
    per18to24 = doc.elements[xpath_prefix + '/rainfallchance/period[4]'].text
    txt00to06 = doc.elements[xpath_prefix + '/rainfallchance/period[1]'].attributes['hour']
    txt06to12 = doc.elements[xpath_prefix + '/rainfallchance/period[2]'].attributes['hour']
    txt12to18 = doc.elements[xpath_prefix + '/rainfallchance/period[3]'].attributes['hour']
    txt18to24 = doc.elements[xpath_prefix + '/rainfallchance/period[4]'].attributes['hour']
    
    message = ''
    message << %{#{pref} #{area} の #{date} の天気は #{weather}\n}
    message << %{最高気温 #{max} ℃\n}
    message << %{最低気温 #{min} ℃\n}
    message << %{降水確率 #{txt00to06}時: #{per00to06} %, #{txt06to12}時: #{per06to12} %, #{txt12to18}時: #{per12to18} %, #{txt18to24}時: #{per18to24} %}
    return message
  end
end
