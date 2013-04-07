#coding: utf-8

require 'yaml'
require 'date'
require 'google/api_client'
require 'pp'

client = Google::APIClient.new
client.authorization.client_id = settings.calendar[:client_id]
client.authorization.client_secret = settings.calendar[:client_secret]
client.authorization.scope = settings.calendar[:scope]
client.authorization.refresh_token = settings.calendar[:refresh_token]
client.authorization.access_token = settings.calendar[:access_token]

if client.authorization.refresh_token && client.authorization.expired?
  client.authorization.fetch_access_token!
end

class GoogleCalendarAPI

  def initialize(client)
    @client = client
    @service = client.discovered_api('calendar', 'v3')
  end

  def get_paged_items(options={})
    items = []
    result = @client.execute(options)
    while true
      items += result.data.items
      break unless result.data.next_page_token

      options[:parameters] ||= {}
      options[:parameters]['pageToken'] = result.data.next_page_token
      result = @client.execute(options)
    end

    items
  end

  def get_calendar_list()
    get_paged_items(:api_method => @service.calendar_list.list)
  end

  def get_events(calendar_id, parameters={})
    parameters['calendarId'] ||= calendar_id
    get_paged_items(:api_method => @service.events.list,
                    :parameters => parameters)
  end

  def get_colors()
    @client.execute(:api_method => @service.colors.get).data
  end

end

class Time
  def to_datetime
    ::DateTime.civil(year, month, day, hour, min, sec, Rational(utc_offset, 86400))
  end unless method_defined?(:to_datetime)
end

class CalendarSchedule

  attr_accessor :start_date, :end_date, :summary, :color

  def initialize(event, color)
    if event.start.date
      @start_date = Date.parse(event.start.date) # Date
      @end_date = Date.parse(event.end.date) # Date
      @all_day = true
    else
      @start_date = event.start.dateTime.to_datetime # DateTime
      @end_date = event.end.dateTime.to_datetime # DateTime
      @all_day = false
    end

    @summary = event.summary
    @color = color
  end

  def all_day?
    @all_day
  end

  def done?
    @end_date < now
  end

  def to_date_string(now = DateTime.now, today = Date.today)
    tomorrow = today + 1

    to_relative = lambda {|datetime|
      if datetime.instance_of?(Date)

        if datetime == today
          "Today"
        elsif datetime == tomorrow
          "Tomorrow"
        else
          datetime.strftime('%a %b %d')
        end

      elsif datetime.instance_of?(DateTime)

        date_part = Date.new(datetime.year, datetime.month, datetime.day)

        if date_part == today
          datetime.strftime('%H:%M')
        else
          "#{to_relative[date_part]} #{datetime.strftime('%H:%M')}"
        end
      end
    }

    if all_day?
      if start_date < today
        if end_date < tomorrow
          "Done"
        elsif end_date == tomorrow # ends today
          "Until today"
        else
          "Going until #{to_relative[end_date]}"
        end

      elsif start_date == today
        if end_date == tomorrow # ends today
          "Today"
        else
          "From today until #{to_relative[end_date]}"
        end

      else
        to_relative[start_date]
      end

    else
      if end_date < now
        "Done"
      elsif start_date < now
        "Going until #{to_relative[end_date]}"
      else
        to_relative[start_date]
      end

    end
  end

end

def get_schedules(calendar_api)

  timeMin = Date.today.rfc3339
  timeMax = (Date.today + 7).rfc3339

  schedules = []

  colors = calendar_api.get_colors

  calendar_api.get_calendar_list.each do |calendar|
    #puts "#{calendar.id} #{calendar.summary} #{calendar.timeZone}"

    events = calendar_api.get_events(calendar.id,
                                     :timeMin => timeMin, :timeMax => timeMax,
                                     :singleEvents => true)

    schedules += events.reject{|event| event.status == 'cancelled' }.map{|event|
      CalendarSchedule.new(event, colors.calendar.to_hash[calendar.colorId]['background'])
    }
  end

  schedules
end

calendar_api = GoogleCalendarAPI.new(client)

schedules = nil
index = 0

SCHEDULER.every '15m', :first_in => 0 do |job|
  schedules = get_schedules(calendar_api)
end

SCHEDULER.every '10s', :first_in => 0 do |job|
  next if schedules.nil? # Not loaded yet

  if schedules.size == 0
    send_event('calendar', {
      :time => '',
      :text => 'No schedule',
      :moreinfo => '',
    })

  else
    index = 0 if index >= schedules.size
    schedule = schedules[index]
    index += 1

    send_event('calendar', {
      :time => schedule.to_date_string,
      :text => schedule.summary,
      :moreinfo => "#{index} / #{schedules.size}",
      :color => schedule.color,
    })

  end
end
