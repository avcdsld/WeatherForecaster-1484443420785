require 'mysql2'

# please set env 'MYSQL_HOST', 'MYSQL_USERNAME', 'MYSQL_PASSWORD', 'MYSQL_DATABASE'

class DbConnector
  DEFAULT_HOUR = 7
  DEFAULT_MINUTE = 0
  DEFAULT_AREA_ID = 1

  def initialize
    connect
    result = @@client.query(%{ select table_name from information_schema.tables where table_schema = '#{ENV["MYSQL_DATABASE"]}'; })
    init if result.size == 0
  end

  def connect
    @@client = Mysql2::Client.new(:host => ENV["MYSQL_HOST"], :username => ENV["MYSQL_USERNAME"], :password => ENV["MYSQL_PASSWORD"], :encoding => 'utf8', :database => ENV["MYSQL_DATABASE"])
  end

  def execute_sql(sql)
    begin
      return @@client.query(sql)
    rescue => e
      p e
      connect
      return @@client.query(sql)
    end
  end

  def init
    create_table
    insert_area_info
  end

  def create_table
  	p 'create_table'
    execute_sql(%{ 
      create table notification_info (
        user_id varchar(64) primary key, 
        hour int, 
        minute int, 
        area_id int,
        is_enabled boolean default false) })
    execute_sql(%{ 
      create table area_info (
        id int primary key, 
        pref varchar(32),
        area varchar(32),
        latitude double,
        longitude double,
        url varchar(64),
        xpath varchar(64)) })
  end

  def insert_area_info
    File.open('./sql.txt', 'r:utf-8') do |f|
      f.each_line do |sql|
        execute_sql(sql)
      end
    end
  end

  def drop_table
  	p 'drop_table'
    execute_sql('drop table notification_info')
    execute_sql('drop table area_info')
  end

  def enable(user_id)
  	p 'enable_user'
  	execute_sql(%{
  	  insert into notification_info (user_id, hour, minute, area_id, is_enabled) 
  	    values ('#{user_id}', #{DEFAULT_HOUR}, #{DEFAULT_MINUTE}, '#{DEFAULT_AREA_ID}', true) 
  	    on duplicate key update user_id = values(user_id), is_enabled = values(is_enabled) })
  end

  def disable(user_id)
  	p 'disable_user'
  	execute_sql(%{
  	  insert into notification_info (user_id, hour, minute, area_id, is_enabled) 
  	    values ('#{user_id}', #{DEFAULT_HOUR}, #{DEFAULT_MINUTE}, '#{DEFAULT_AREA_ID}', false) 
  	    on duplicate key update user_id = values(user_id), is_enabled = values(is_enabled) })
  end

  def set_time(user_id, hour, minute)
  	p 'set_time'
  	execute_sql(%{
  	  insert into notification_info (user_id, hour, minute) 
        values ('#{user_id}', #{hour}, #{minute}) 
        on duplicate key update user_id = values(user_id), hour = values(hour), minute = values(minute) })
  end

  def set_location(user_id, latitude, longitude)
  	p 'set_location'
  	result = execute_sql(%{
  	  select * from area_info 
  	    order by abs(latitude - #{latitude}) + abs(longitude - #{longitude}) asc }).first
    puts %{#{result['id']}, #{result['pref']}, #{result['area']}, #{result['latitude']}, #{result['longitude']}}
  	execute_sql(%{
  	  insert into notification_info (user_id, area_id) 
        values ('#{user_id}', #{result['id']}) 
        on duplicate key update user_id = values(user_id), area_id = values(area_id) })
    return result['pref'], result['area']
  end

  def get_all_notification_info
    p 'get_all_notification_info'
    results = execute_sql('select * from notification_info join area_info on notification_info.area_id = area_info.id')
    results.each do |row|
      puts "--------------------"
      p row
    end
    return results
  end

  def get_notification_info(user_id)
    p 'get_notification_info(user_id)'
    results = execute_sql(%{select * from notification_info join area_info on notification_info.area_id = area_info.id where user_id = '#{user_id}'})
    return results.first
  end

  def get_all_area_info
    p 'get_all_area_info'
    results = execute_sql('select * from area_info')
    results.each do |row|
      puts "--------------------"
      p row
    end
    return results
  end
end
