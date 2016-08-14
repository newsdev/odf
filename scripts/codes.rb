#!/usr/bin/env ruby

# ./scripts/codes.rb [PATH TO XLSX FILE] [COMPETITION SLUG] [VERSION]
# ./scripts/codes.rb source/Rio\ 2016\ ODF\ Olympic\ Common\ Codes\ v10.0.xlsx OG2016 10.0 

require 'rubyXL'
require 'json'
require 'csv'
require 'fileutils'

class CodesLoader
  def initialize(file, games = nil, version = nil)
    @file = file

    if file.match(/\/(\w+)_(\w{2})_(\d+\.\d+)\.xls/)
      @games = $1
      @version = $3
    end
    @games   = games   || @games
    @version = version || @version

    @data = {}

    raise "Please specify the competition and version." if @games.nil? || @version.nil?

    puts "Created loader for #{@games} v#{@version}"
  end

  def parse!
    workbook = RubyXL::Parser.parse(@file)
    sheets = workbook.worksheets

    sheets[0..-1].each do |sheet|
      if sheet.sheet_name == "Document Control"
        version_column = sheet.sheet_data[0..-1].map { |r| r.cells.map(&:value).index("Version") }.compact.first
        version = sheet.sheet_data[0..-1].map { |r| r.cells[version_column].value }.compact.select { |v| v.match(/^(\d+\.?)*$/) }.sort_by { |v| v.to_f }.last
        if version != @version
          raise "Source file is tagged at v#{version}, but loader is set to v#{@version}"
        end
      end
      next if ["SCH-Import", "Cover", "Document Control", "Change Log Detail", "Contents"].include? sheet.sheet_name

      name = sheet.sheet_name.gsub(' ', '_').sub(/^ODF_/, '').sub(/(GL|OG|PG)_/, '').gsub(/[-_]/, '')

      print "Parsing sheet #{sheet.sheet_name} as #{name}..."

      @data[name] = []
      sport_codes = (name == "SportCodes")

      # Keep track of columns that were removed via shading (the entire column
      # was shaded red, or as we're detecting it, the header cell was shaded
      # red).
      removed_columns = []
      sheet.sheet_data[0].cells.each_with_index do |cell, i|
        removed_columns << i if cell.fill_color.downcase == 'ffff0000'
      end

      sheet.sheet_data[0..-1].each_with_index do |row, idx|
        begin
          # Skip rows without cells.
          next unless row && row.cells.size > 0 && row.cells.first

          # Remove cells from any removed columns
          cells = []
          row.cells.each_with_index { |cell, i| cells << cell unless removed_columns.include?(i) }

          # Skip rows that are shaded red (they tend to included as a reference
          # of data that was removed).
          next if cells.first.fill_color.downcase == 'ffff0000'

          values = cells.map { |i| i ? i.value : nil }

          # Skip empty rows
          next unless values.compact.size > 0

          if sport_codes
            values[1].gsub!(/^@/, '')
          end

          @data[name] << values

        rescue Exception => e
          puts "ERROR: #{e.message}"
          puts e.backtrace
        end
      end

      puts " Loaded #{@data[name].length} rows."
    end
  end

  def write!
    raise "No version specified" if @version.nil? || @version.length == 0

    all_json_path = File.join('competitions', @games, 'codes', @version, 'json', 'all.json')
    all_json = File.exist?(all_json_path) ? JSON.load(File.read(all_json_path)) : {}

    @data.each do |name, values|
      headers = values.shift

      # CSV
      csv_path = output_path(name, 'csv')
      CSV.open(csv_path, 'w') do |csv|
        csv << headers
        values.each { |row| csv << row.dup.fill(nil, row.length, headers.length - row.length) }
      end
      puts "Wrote #{csv_path}"

      # JSON
      json_path = output_path(name, 'json')
      hash_values = values.map do |row|
        Hash[headers.zip(row)]
      end
      File.write(json_path, JSON.dump(hash_values))
      puts "Wrote #{json_path}"

      # Don't include split-out sport codes in all.json
      unless name.include?('/')
        all_json[name] = hash_values
      end
    end

    File.write(all_json_path, JSON.dump(all_json))
    puts "Wrote #{all_json_path}"
  end

  private

  def output_path(sheet, type)
    path = File.join('competitions', @games, 'codes', @version, type, "#{sheet}.#{type}")
    FileUtils.mkdir_p(File.dirname(path)) rescue nil
    path
  end
end

loader = CodesLoader.new(*ARGV)
loader.parse!
loader.write!
