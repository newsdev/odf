#!/usr/bin/env ruby

# ./src/codes.rb [PATH TO XLSX FILE] [COMPETITION SLUG]

require 'rubyXL'
require 'json'
require 'csv'
require 'fileutils'

class Loader
  def initialize(file, games, version = nil)
    @file = file
    @games = games
    @version = version

    @data = {}

    puts "Created loader for #{@games}"
  end

  def parse!
    workbook = RubyXL::Parser.parse(@file)
    sheets = workbook.worksheets

    sheets[0..-1].each do |sheet|
      next if ["Cover", "Document Control", "Change Log Detail", "Contents"].include? sheet.sheet_name

      name = sheet.sheet_name.gsub(' ', '_').sub(/^ODF_/, '').sub(/(GL|OG|PG)_/, '').gsub(/[-_]/, '')

      print "Parsing sheet #{sheet.sheet_name} as #{name}..."

      @data[name] = []
      sport_codes = (name == "SportCodes")

      sheet.sheet_data[0..-1].each_with_index do |row, idx|
        begin
          next unless row && row.cells.size > 0
          # Skip rows that are shaded red
          next if row.cells.first.fill_color.downcase == 'ffff0000'

          values = row.cells.map { |i| i.value if i }

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

    if @data['Version']
      @version = @data['Version'][1][0]
    end
  end

  def write!
    raise "No version specified" if @version.nil? || @version.length == 0

    all_json_path = File.join('competitions', @games, 'codes', @version, 'json', 'all.json')
    all_json = File.exist?(all_json_path) ? JSON.load(File.read(all_json_path)) : {}

    @data.each do |name, values|
      # CSV
      csv_path = output_path(name, 'csv')
      CSV.open(csv_path, 'w') do |csv|
        values.each { |row| csv << row }
      end
      puts "Wrote #{csv_path}"

      # JSON
      json_path = output_path(name, 'json')
      headers = values[0]
      hash_values = values[1..-1].map do |row|
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

loader = Loader.new(*ARGV)
loader.parse!
loader.write!


