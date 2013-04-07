#coding: utf-8

require 'yaml'
require 'date'
require 'google/api_client'
require 'pp'

OAUTH_YAML_PATH = File.expand_path('~/.google-api.yaml')

oauth_yaml = YAML.load_file(OAUTH_YAML_PATH)

client = Google::APIClient.new
client.authorization.client_id = oauth_yaml["client_id"]
client.authorization.client_secret = oauth_yaml["client_secret"]
client.authorization.scope = oauth_yaml["scope"]
client.authorization.refresh_token = oauth_yaml["refresh_token"]
client.authorization.access_token = oauth_yaml["access_token"]

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

def get_schedules(calendar_api)

  def get_date(event, calendar)
    if event.start.date
      DateTime.parse(event.start.date).strftime('%a %b %d')
    else
      event.start.dateTime.strftime('%a %b %d %H:%M')
    end
  end

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
      {
        :summary => event.summary,
        :date => get_date(event, calendar),
        :color => colors.calendar.to_hash[calendar.colorId]['background'],
      }
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
      :time => schedule[:date],
      :text => schedule[:summary],
      :moreinfo => "#{index} / #{schedules.size}",
      :color => schedule[:color],
    })

  end
end
