require 'sinatra'
require 'haml' # template engine
require 'json'
require 'line/bot'
require './db_connector'
require './weather_connector'

# please set env 'BASIC_AUTH_USERNAME', 'BASIC_AUTH_PASSWORD'

$db = DbConnector.new

use Rack::Auth::Basic do |username, password|
  username == ENV['BASIC_AUTH_USERNAME'] && password == ENV['BASIC_AUTH_PASSWORD']
end

# control part of MVC
# an HTTP method paired with a URL-matching pattern
get '/' do
  # page variable
  @version = RUBY_VERSION
  @os = RUBY_PLATFORM
  @env = {}
  ENV.each do |key, value|
    begin
      hash = JSON.parse(value)
      @env[key] = hash
    rescue
      @env[key] = value
    end
  end
  
  #There are many useful environment variables available in process.env,
  #please refer to the following document for detailed description:
  #http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html
  
  #VCAP_APPLICATION contains useful information about a deployed application.
  appInfo = @env["VCAP_APPLICATION"]

  #VCAP_SERVICES contains all the credentials of services bound to
  #this application. For details of its content, please refer to
  #the document or sample of each service.
  services = @env["VCAP_SERVICES"]
  #TODO: Get service credentials and communicate with bluemix services.

  # render template
  haml :hi
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

get '/send' do
  weather_conn = WeatherConnector.new
  $db.get_all_notification_info.each do |row|
    if row['is_enabled'] == 1 then
      forecast = weather_conn.get_weather(row['pref'], row['area'], row['url'], row['xpath'])
      puts forecast
      message = { type: 'text', text: forecast }
      p 'push message'
      p client.push_message(row['user_id'], message)
    end
  end
  "OK"
end

post '/callback' do
  p '*** callback ***'
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      user_id = event['source']['userId']
      reply_text = "使い方：\n\n・位置情報を送信してください。\n（トークルーム下部の「＋」をタップして、「位置情報」から送信できます。）\n\n"
      reply_text << "・「スタート」と入力すると、毎日朝７時に天気をお知らせします。\n\n"
      reply_text << "・「ストップ」と入力すると、お知らせを停止します。\n\n"
      reply_text << "・「天気」と入力すると、現在設定されている地域の天気をお知らせします。\n\n"

      case event.type
      when Line::Bot::Event::MessageType::Text
        case event.message['text']
        #when  /([0-2][0-9])([0-6][0-9])/
        #  hour, minute = $1.to_i, $2.to_i
        #  $db.set_time(user_id, hour, minute)
        #  reply_text = %{時刻を #{hour} 時 #{minute} 分にセットしました！}
        when 'スタート'
          $db.enable(user_id)
          info = $db.get_notification_info(user_id)
          reply_text = %{毎日朝７時に #{info['pref']} #{info['area']} の天気をお知らせします！}
          reply_text << "\nお知らせを停止するときは「ストップ」と入力してください。\n地域を設定するときは 位置情報 を送信してください。"
        when 'ストップ'
          $db.disable(user_id)
          reply_text = "お知らせを停止します！\n再開するときは「スタート」と入力してください。\n地域を設定するときは 位置情報 を送信してください。"
        when /.*天気.*/
          weather_conn = WeatherConnector.new
          begin
            info = $db.get_notification_info(user_id)
            reply_text = weather_conn.get_weather(info['pref'], info['area'], info['url'], info['xpath'])
          rescue => e
            p e
            reply_text = weather_conn.get_weather('神奈川県', '東部', 'http://www.drk7.jp/weather/xml/14.xml', 'weatherforecast/pref/area[1]') # TODO: 定数化
          end
        end

      when Line::Bot::Event::MessageType::Location
        latitude = event.message['latitude']
        longitude = event.message['longitude']
        pref, area = $db.set_location(user_id, latitude, longitude)
        reply_text = %{地域を #{pref} #{area} にセットしました！\n「天気」と入力すると、今日の天気がわかります。}

      end

      message = { type: 'text', text: reply_text }
      client.reply_message(event['replyToken'], message)
    end
  }

  "OK"
end
