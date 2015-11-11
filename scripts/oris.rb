#!/usr/bin/env ruby

# ./src/oris.rb

require 'io/console'
require 'net/http'
require 'fileutils'

class OrisLoader
  COMPETITIONS = {
    "OG2014" => {
      "slug" => "Sochi2014",
      "disciplines" => {
        "AS" => "Alpine Skiing",
        "BS" => "Bobsleigh",
        "BT" => "Biathlon",
        "CC" => "Cross-Country Skiing",
        "CU" => "Curling",
        "FR" => "Freestyle Skiing",
        "FS" => "Figure Skating",
        "IH" => "Ice Hockey",
        "LG" => "Luge",
        "NC" => "Nordic Combined",
        "SB" => "Snowboard",
        "SJ" => "Ski Jumping",
        "SN" => "Skeleton",
        "SS" => "Speed Skating",
        "ST" => "Short Track Speed Skating"
      }
    },
    "OG2016" => {
      "slug" => "rio2016",
      "disciplines" => {
        "AR" => "Archery",
        "AT" => "Athletics",
        "BD" => "Badminton",
        "BK" => "Basketball",
        "BV" => "Beach Volleyball",
        "BX" => "Boxing",
        "CS" => "Canoe Slalom",
        "CF" => "Canoe Sprint",
        "CB" => "Cycling BMX",
        "CM" => "Cycling Mountain Bike",
        "CR" => "Cycling Road",
        "CT" => "Cycling Track",
        "DV" => "Diving",
        "EQ" => "Equestrian",
        "FE" => "Fencing",
        "FB" => "Football",
        "GO" => "golf",
        "GA" => "Gymnastics  Artistic",
        "GR" => "Gymnastics Rhythmic",
        "GT" => "Gymnastics Trampoline",
        "HB" => "Handball",
        "HO" => "Hockey",
        "JU" => "Judo",
        "OW" => "marathon swimming",
        "MP" => "Modern Pentathlon",
        "RO" => "Rowing",
        "RU" => "Rugby Sevens",
        "SA" => "Sailing",
        "SH" => "Shooting",
        "SW" => "Swimming",
        "SY" => "Synchronised Swimming",
        "TT" => "Table Tennis",
        "TK" => "Taekwondo",
        "TE" => "Tennis",
        "TR" => "Triathlon",
        "VB" => "Volleyball",
        "WP" => "Water Polo",
        "WL" => "Weightlifting",
        "WR" => "Wrestling",
      }
    }
  }

  SLEEP = 30

  def initialize(competition)
    @competition = competition
    @config = COMPETITIONS[competition]

    print "Username: "
    @username = STDIN.gets.chomp
    print "Password: "
    @password = STDIN.noecho(&:gets).chomp
  end

  def run
    setup_http
    load_login
    do_login
    scrape_disciplines
  end

  def setup_http
    @http = Net::HTTP.new('extranet.olympic.org', 80)
    @http.use_ssl = false
    @http.read_timeout = 500

    @login_path = "/Public/Login.aspx?ReturnUrl=%2f_layouts%2fAuthenticate.aspx%3fSource%3d%252f&Source=%2f"
  end

  def load_login
    puts "Loading login page to get ASP.NET form variables..."

    resp, data = @http.get(@login_path)
    puts "  #{resp.code} #{resp.message}"

    @form_data = {}
    form = resp.body.match(/<form name="aspnetForm"(.*)?<\/div>/m)[1]
    form.scan(/<input type="hidden" name="(.*?)" .*? value="(.*?)"/).each do |key, value|
      @form_data[key] = value
    end

    username_field = resp.body.match(/"(.*?login\$UserName)"/)[1]
    password_field = resp.body.match(/"(.*?login\$password)"/)[1]
    @form_data[username_field] = @username
    @form_data[password_field] = @password

    @form_data[password_field.sub("password", "login")] = "Login"
    @form_data[password_field.sub("password", "RememberMe")] = "on"

    @form_data["__EVENTTARGET"] = ""
    @form_data["__EVENTARGUMENT"] = ""
    @form_data["__spDummyText1"] = ""
    @form_data["__spDummyText2"] = ""

    sleep(SLEEP)
  end

  def do_login
    puts "Logging into Extranet to get cookie..."

    @encoded_data = URI.encode_www_form(@form_data)
    @headers = {
      'Referer' => "http://extranet.olympic.org/#{@login_path}",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Charset" => "ISO-8859-1,utf-8;q=0.7,*;q=0.3",
      "Accept-Encoding" => "gzip,deflate,sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "max-age=0",
      "Connection" => "keep-alive",
      "Content-Length" => "2928",
      "Content-Type" => "application/x-www-form-urlencoded",
      "Cookie" => "__utma=239469661.1049090165.1360184229.1360206296.1360213475.4; __utmc=239469661; __utmz=239469661.1360213475.4.4.utmcsr=en.wikipedia.org|utmccn=(referral)|utmcmd=referral|utmcct=/wiki/Alpine_skiing_at_the_2010_Winter_Olympics_%E2%80%93_Men%27s_downhill",
      "Host" => "extranet.olympic.org",
      "Origin" => "http://extranet.olympic.org",
      #"Referer" => "http://extranet.olympic.org/Public/login.aspx?ReturnUrl=%2f_layouts%2fAuthenticate.aspx%3fSource%3d%252f&Source=%2f",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.57 Safari/537.17"
    }

    resp, data = @http.post(@login_path, @encoded_data, @headers)
    puts "  #{resp.code} #{resp.message}"

    @cookie = resp.header['Set-Cookie'].split('; ')[0]

    sleep(SLEEP)
  end

  def scrape_disciplines
    puts "Scraping #{@config["disciplines"].keys.length} disciplines..."

    @config["disciplines"].each do |code, name|
      load_discipline(code, name)
    end
  end

  def load_discipline(code, name)
    puts name
    puts "  Loading #{name} ORIS file directory to get pdf path..."

    oris_path = discipline_oris_path(name)
    resp, data = make_get(oris_path)

    puts "  Downloading #{name} ORIS pdf..."
    pdf_path = resp.body.match(/HREF="(\/oris\/#{@config["slug"]}\/#{URI.encode(name)}\/PublishedDocuments\/ORIS\/.+?)"/)[1]

    resp, data = make_get(pdf_path)
    pdf_data = resp.body

    filepath = output_path(code, name)
    puts "  Saving pdf to #{filepath} (size #{pdf_data.size})..."
    open(filepath, 'w') do |file|
      file.write(pdf_data)
    end
  end

  private

  def discipline_oris_path(name)
    name = URI.encode(name)
    "http://extranet.olympic.org/oris/#{@config["slug"]}/#{name}/PublishedDocuments/Forms/AllItems.aspx?RootFolder=%2foris%2f#{@config["slug"]}%2f#{name}%2fPublishedDocuments%2fORIS"
  end

  def make_get(path)
    headers = {
      'Cookie' => @cookie,
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Charset" => "ISO-8859-1,utf-8;q=0.7,*;q=0.3",
      "Accept-Encoding" => "gzip,deflate,sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "max-age=0",
      "Connection" => "keep-alive",
      "Host" => "extranet.olympic.org",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.57 Safari/537.17"
    }

    resp, data = @http.get(path, headers)

    if resp.body[0] == "\x1f"
      sio = StringIO.new(resp.body)
      gz = Zlib::GzipReader.new(sio)
      resp.body = gz.read
      puts "    #{resp.code} #{resp.message} (gzipped)"
    else
      puts "    #{resp.code} #{resp.message}"
    end

    sleep(SLEEP)

    [resp, data]
  end

  def output_path(code, name)
    path = File.join('competitions', @competition, 'oris', "#{code}-#{name.gsub(' ', '')}.pdf")
    FileUtils.mkdir_p(File.dirname(path)) rescue nil
    path
  end
end

loader = OrisLoader.new(*ARGV)
loader.run
