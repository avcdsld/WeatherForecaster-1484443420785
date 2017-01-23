require 'net/http'
require 'uri'
require 'rexml/document'
require './db_connector'

def recreate_table
  $db = DbConnector.new
  $db.drop_table
  $db.init
  $db.get_all_area_info
end

def create_sql
  id = 0
  for n in 1..47 do
  	num = format("%02d", n)

  	url = %{http://www.drk7.jp/weather/xml/#{num}.xml}
    uri = URI.parse(url)
    xml = Net::HTTP.get(uri)
    doc = REXML::Document.new(xml)

    area_num = 0
    pref_name = doc.elements['weatherforecast/pref'].attributes['id']
    doc.elements.each('weatherforecast/pref/area') do |area|
      area_num = area_num + 1
      area_name = area.attributes['id']
      latitude = area.elements['geo/lat'].text
      longitude = area.elements['geo/long'].text
      xpath = %{weatherforecast/pref/area[#{area_num}]}
      puts %{insert into area_info (id, pref, area, latitude, longitude, url, xpath) values (#{id}, '#{pref_name}', '#{area_name}', #{latitude}, #{longitude}, '#{url}', '#{xpath}');}
      id = id + 1
    end
  end
end

#recreate_table
#create_sql
