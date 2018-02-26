require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

namespace :batch do
  task event_crawl: :environment do
    Event.import_events!
  end

  task bot_tweet: :environment do
    future_events = Event.where("? < started_at AND started_at < ?", Time.current, 1.year.since).order("started_at ASC").select{|event| event.hackathon_event? }
    future_events.each do |event|
      if !TwitterBot.exists?(from: event)
        TwitterBot.tweet!(text: event.generate_tweet_text, from: event, options: {lat: event.lat, long: event.lon})
      end
    end
    QiitaBot.post_or_update_article!(events: future_events)
    EventCalendarBot.insert_or_update_calender!(events: future_events)
  end

  task regist_calender: :environment do
    client_id = Google::Auth::ClientId.from_file(Rails.root.to_s + "/client_secret.json")
    p client_id
  end
end