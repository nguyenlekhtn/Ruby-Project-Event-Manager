require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representative by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_phone_number_list(list)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = 'output/number.txt'

  File.open(filename, 'w') do |file|
    list.each do |number|
      file.puts number unless number == 'bad number'
    end
  end
end

def format_phone_number(phone_number)
  phone_number.chars.select { |char| char.match(/^[0-9]$/) }.join
end

def clean_homephone(phone_number)
  formatted = format_phone_number(phone_number)
  length = formatted.length
  bad_number = 'bad number'
  case length
  when 0...10
    bad_number
  when 10
    formatted
  when 11
    formatted[0] == '1' ? formatted[1..] : bad_number
  else
    bad_number
  end
end

def parse_time(time_class, string, format)
  time_class.strptime(string, format)
rescue ArgumentError
  nil
end

def find_top_occurrences(arr, range)
  freq = arr.tally
  freq.sort_by { |_k, v| v }.reverse[0, range].map { |x| x[0] }
end

puts 'EventManager initialized.'
filename = 'event_attendees.csv'
contents = CSV.open(
  filename,
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hours = []
wdays = []
homephones = []
regdate_format = '%m/%d/%y %k:%M'

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  homephones << clean_homephone(row[:homephone])

  time = parse_time(Time, row[:regdate], regdate_format)
  date = parse_time(Date, row[:regdate], regdate_format)

  hours << time.hour unless time.nil?
  wdays << date.wday unless date.nil?
end

# Save registers' homephone to disk
save_phone_number_list(homephones)

# Find the most occurreanes of hours
finding_hours = find_top_occurrences(hours, 2)
puts "Most people registed at #{finding_hours.join(' and ')} o'clock"

# Find days of the weeks most people register
finding_wdays = find_top_occurrences(wdays, 2)
wnames = Date::DAYNAMES.values_at(*finding_wdays)
puts "Most people registed on #{wnames.join(' and ')}"
