require './db_connector'
require 'net/http'
require 'uri'
require 'json'
require 'rexml/document'
require './weather_connector'

weather = WeatherConnector.new
puts weather.get_weather('神奈川県', '東部', 'http://www.drk7.jp/weather/xml/14.xml', 'weatherforecast/pref/area[1]')

def recreate
  $db = DbConnector.new
  $db.drop_table
  $db.init
  $db.get_all_area_info
end

def select_all
  $db = DbConnector.new
  $db.get_all_notification_info.each do |row|
    puts %{user_id: ${row['user_id']}, is_enabled: #{row['is_enabled']}}
  end
end

def create_pref_case_code
  for n in 1..47 do
  	num = format("%02d", n)
    uri = URI.parse(%{http://www.drk7.jp/weather/json/#{num}.js})
    json = Net::HTTP.get(uri)
  
    # JSONP parse http://moyashiki.hateblo.jp/entry/2015/11/16/222036
    json.gsub!(/^\w+\.callback\(/i,"")
    json.gsub!(/\);/,"")

    result = JSON.parse(json)
    #puts result['pref']['area']['東部']['info'][0]['weather']
    pref_without_prefix = result['pref']['id'].gsub(/県/,"")
    puts %{  when '#{result['pref']['id']}' '#{pref_without_prefix}'}
    #puts %{    return '#{result['pref']['id']}', '#{num}'}
    area = '['
    result['pref']['area'].each do |key, value|
      area << "'" << key << "', "
    end
    area << ']'
    area.gsub!(", ]", "]")
    puts %{    return '#{result['pref']['id']}', #{area}}
  end
end

def get_all_weather
  id = 0
  for n in 1..47 do
  	num = format("%02d", n)
  	url = %{http://www.drk7.jp/weather/xml/#{num}.xml}
    uri = URI.parse(url)
    xml = Net::HTTP.get(uri)

    doc = REXML::Document.new(xml)

    #weather = doc.elements['weatherforecast/pref/area[1]/info/weather']
    #max = doc.elements['weatherforecast/pref/area[1]/info/temperature/range[1]']
    #min = doc.elements['weatherforecast/pref/area[1]/info/temperature/range[2]']
    #per00to06 = doc.elements['weatherforecast/pref/area[1]/info/rainfallchance/period[1]']
    #per06to12 = doc.elements['weatherforecast/pref/area[1]/info/rainfallchance/period[2]']
    #per12to18 = doc.elements['weatherforecast/pref/area[1]/info/rainfallchance/period[3]']
    #per18to24 = doc.elements['weatherforecast/pref/area[1]/info/rainfallchance/period[4]']
    #puts weather.text
    #puts max.text
    #puts min.text
    #puts per00to06.text
    #puts per06to12.text
    #puts per12to18.text
    #puts per18to24.text
    #puts max.attributes['centigrade']
    #puts min.attributes['centigrade']
    
    area_num = 0
    pref_name = doc.elements['weatherforecast/pref'].attributes['id']
    
    doc.elements.each('weatherforecast/pref/area') do |area|
      area_name = area.attributes['id']
      latitude = area.elements['geo/lat'].text
      longitude = area.elements['geo/long'].text
      area_num = area_num + 1
      xpath = %{weatherforecast/pref/area[#{area_num}]}
      puts %{insert into area_info (id, pref, area, latitude, longitude, url, xpath) values (#{id}, '#{pref_name}', '#{area_name}', #{latitude}, #{longitude}, '#{url}', '#{xpath}');}
      id = id + 1
    end
  end
end

def get_weather
  	num = '14'
  	area = '東部'
    uri = URI.parse(%{http://www.drk7.jp/weather/json/#{num}.js})
    json = Net::HTTP.get(uri)
  
    # JSONP parse http://moyashiki.hateblo.jp/entry/2015/11/16/222036
    json.gsub!(/^\w+\.callback\(/i,"")
    json.gsub!(/\);/,"")

    result = JSON.parse(json)
    #puts result['pref']['area']['東部']['info'][0]['weather']

    info = result['pref']['area'][area]['info'][0]
    date = info['date']
    weather = info['weather']
    max = info['temperature']['range'][0]['content']
    min = info['temperature']['range'][1]['content']
    period = info['rainfallchance']['period']
    per00to06, txt00to06 = period[0]['content'], period[0]['hour']
    per06to12, txt06to12 = period[1]['content'], period[1]['hour']
    per12to18, txt12to18 = period[2]['content'], period[2]['hour']
    per18to24, txt18to24 = period[3]['content'], period[3]['hour']

    puts %{神奈川県 東部 の #{date} の天気は #{weather}}
    puts %{最高気温 #{max} ℃}
    puts %{最低気温 #{min} ℃}
    puts %{降水確率 #{txt00to06}時: #{per00to06} %, #{txt06to12}時: #{per06to12} %, #{txt12to18}時: #{per12to18} %, #{txt18to24}時: #{per18to24} %}
end

#reply_text = "メッセージありがとうございます！\n申し訳ありませんが、個別のご返信はできません。。\n現在の天気予報が知りたい場合は「天気」と入力してください。"
#puts reply_text

#get_weather
#select_all
#create_pref_case_code
#recreate
#get_all_weather


