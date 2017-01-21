#!/usr/bin/env ruby

# also requires several libraries:
# brew install poppler ghostscript psutils
require 'pdf-reader'
require 'json'

data = {}

Dir.glob('competitions/OG2016/oris/*.pdf').each do |file|
  output_file = file.sub(/\/([^\/]*?.pdf)$/, "/reporters/\\1")

  next if File.exists?(output_file)
  reader = PDF::Reader.new(file)
  sport = File.basename(file).match(/^(\w{2})/)[1]
  data[sport] ||= []
  puts sport

  cache_file = "tmp/#{sport}.json"
  if File.exists?(cache_file)
    data[sport] = JSON.parse(File.read(cache_file));

  else
    last_type = nil
    current_section = nil

    reader.pages.each_with_index do |page, index|
      begin
        page.text.split("\n").each do |line|
          if match = line.match(/^\s*((?:C|N)\d\d\w{0,4}) - (.*?)\.+(\d+)/)
            code = match[1]
            name = match[2]
            page_number = match[3].to_i

            if last_type
              last_type['end'] = page_number - 1
            end
            this_type = {'code' => code, 'name' => name.strip, 'start' => page_number}
            data[sport] << this_type
            last_type = this_type

          elsif (match = line.match(/\s*(.*) - (.*?)\.+(\d+)/)) && last_type
            last_type['end'] = match[3].to_i
            last_type = nil
          end
        end

        # Finished a section
        if current_section && current_section['end'] < index + 1
          puts current_section
          current_section = nil
        end

        begin
          current_section ||= data[sport].detect { |t| t['start'] == index + 1 }
        rescue Exception => e
          puts 'exception'
          puts data[sport]
        end
        if current_section
          page_text = `pdftotext #{file} -f #{index + 1} -l #{index + 1} -`
          page_lines = page_text.force_encoding('ISO-8859-1').split("\n")
          is_metadata_page = page_lines[3] && page_lines[2].match(/^#{current_section['code']}/) && !!page_lines[3].match(/^Description/)
          current_section['metadata_start'] ||= index + 1 if is_metadata_page
        end

      rescue Exception => e
        puts "Error parsing page #{index + 1}: #{e.message}"
        puts e.backtrace
        raise e
      end
    end

    File.write(cache_file, JSON.dump(data[sport]));
  end

  ps_file = file.sub(/pdf$/, 'ps')

  toc = ""
  page_ranges = []
  relative_index = 1
  data[sport].each do |document|
    relative_end = (document['metadata_start'] || document['end']) - 1
    toc += "[/Title (#{document['code']} - #{document['name'].gsub(/\(|\)/, '')}) /Page #{relative_index} /OUT pdfmark\n"
    page_ranges << [document['start'], relative_end].uniq.join('-')
    relative_index += relative_end - document['start'] + 1
  end

  if !File.exists?(ps_file)
    cmd = "pdftops #{file}"
    puts cmd
    `#{cmd}`
  end

  cmd = "cat #{ps_file} | psselect -p#{page_ranges.join(',')} > tmp/out1.ps"
  puts cmd
  `#{cmd}`

  puts toc

  temp = File.read('tmp/out1.ps')
  temp.sub!(/%%EndSetup/, "[/PageMode /UseOutlines /Page 1 /View [/XYZ null null null] /DOCVIEW pdfmark\n%%EndSetup")
  temp.sub!(/%%Page:/, toc + "%%Page:")
  File.write('tmp/out2.ps', temp)

  File.rm(output_file) rescue nil
  cmd = "cat tmp/out2.ps | ps2pdf - #{output_file}"
  puts cmd
  `#{cmd}`
  puts "Wrote #{output_file}"
  #`rm #{ps_file}`
end

File.write('competitions/OG2016/oris/reporters/metadata.json', JSON.dump(data))

Event-level
C0 - Schedule
C2 - Historic Results
C3 - Competitors
C4 - Pre-competition seeding
C5 - Day-of-competition seeding, lineups
C6 - Score sheets
C7 - Results
C8 - Post-event summary
C9 - Official results

Competition-level
N0 - Competition Format
N1 - Historic Results
N2 - Officials
N5 - Lineups
N6 - Lineups
N8 - Highlights
N9 - Post-competition events

#
# data = {}
# Dir.glob('tmp/*.json').each do |sport|
#   sport_code = sport.match(/(\w{2})\.json/)[1]
#   puts sport_code
#   data[sport_code] = {
#     'docs' => JSON.parse(File.read(sport)),
#     'pdf' => File.basename(Dir.glob("competitions/OG2016/oris/#{sport_code}*.pdf")[0])
#   }
# end
# File.write('competitions/OG2016/oris/metadata.json', JSON.dump(data))
