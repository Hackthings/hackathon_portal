module MeetupOperation
  MEETUP_SEARCH_URL = 'https://api.meetup.com/find/upcoming_events'

  PAGE_PER = 100

  def self.find_event(keywords: [])
    return(
      RequestParser.request_and_parse_json(
        url: MEETUP_SEARCH_URL,
        params: {
          key: ENV.fetch('MEETUP_API_KEY', ''),
          text: keywords.join('|'),
          sign: true,
          page: PAGE_PER,
        },
        options: {
          follow_redirect: true,
        },
      )
    )
  end

  def self.import_events_from_keywords!(keywords:)
    events_response = self.find_event(keywords: keywords)
    res_events = events_response['events'] || []
    current_url_events = Event.where(url: res_events.map { |res| res['link'] }.compact).index_by(&:url)
    res_events.each do |res|
      Event.transaction do
        if current_url_events[url: res['link'].to_s].present?
          meetup_event = current_url_events[url: res['link'].to_s]
        else
          meetup_event = Event.new(url: res['link'].to_s)
        end
        start_time = Time.at(res['time'].to_i / 1_000)
        if res['duration'].present?
          end_time = start_time + (res['duration'] / 1_000).second
        else
          end_time = start_time + 2.day
        end
        vanue_hash = res['venue'] || {}
        fee_hash = res['fee'] || {}
        group_hash = res['group'] || {}
        meetup_event.merge_event_attributes(
          attrs: {
            state: :active,
            informed_from: :meetup,
            event_id: res['id'],
            title: Sanitizer.basic_sanitize(res['name'].to_s),
            description: Sanitizer.basic_sanitize(res['description'].to_s),
            started_at: start_time,
            ended_at: end_time,
            limit_number: res['rsvp_limit'],
            address: vanue_hash['address_1'],
            place: vanue_hash['name'].to_s,
            lat: vanue_hash['lat'],
            lon: vanue_hash['lon'],
            cost: fee_hash['amount'].to_i,
            max_prize: 0,
            currency_unit: fee_hash['currency'] || 'JPY',
            owner_id: group_hash['id'],
            owner_nickname: group_hash['urlname'],
            owner_name: Sanitizer.basic_sanitize(group_hash['name'].to_s),
            attend_number: res['yes_rsvp_count'] || res['attendance_count'],
            substitute_number: res['waitlist_count'],
          },
        )
        meetup_event.save!
        meetup_event.import_hashtags!(hashtag_strings: meetup_event.search_hashtags)
      end
    end
  end
end
