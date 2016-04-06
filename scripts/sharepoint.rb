#!/usr/bin/env ruby

# ./scripts/sharepoint.rb sync_documents
# Download relevant documents from the RIO 2016 Sharepoint, namely test XML

# ./scripts/sharepoint.rb get_xml
# Extract XML files and compressed folders with XML from downloaded Sharepoint
# files into an output folder, renaming each using a consistent format.

require 'net/http'
require 'json'
require 'zlib'
require 'stringio'
require 'pp'
require 'fileutils'
require 'shellwords'
require 'zip'
require 'tempfile'
require 'io/console'

class SharePoint

  def initialize(*args)
    @documents = {}
    @base_folder = '/sites/00161/Lists/Documentos'
    @local_directory = File.expand_path('../../portals/rio2016', __FILE__)

    puts "Running #{args[0]}..."
    method(args.first).call(*args[1..-1] || [])
  end

  def setup_http
    if !@sharepoint
      @sharepoint = Net::HTTP.new('rio2016.sharepoint.com', 443)
      @sharepoint.use_ssl = true
      @sharepoint.read_timeout = 500

      print "Username: "
      @username = ENV['username'] || STDIN.gets.chomp
      print "Password: "
      @password = ENV['password'] || STDIN.noecho(&:gets).chomp
      puts

      @cookie_cache = File.join(@local_directory, '_cookie')
      if File.exists?(@cookie_cache) && ((Time.now - File.mtime(@cookie_cache)) / 60 / 60 / 24 < 1)
        @sharepoint_cookie = File.read(@cookie_cache)
        puts "Loaded cookie"
      else
        login
      end
    end
  end

  def login
    @online = Net::HTTP.new('login.microsoftonline.com', 443)
    @online.use_ssl = true
    @online.read_timeout = 500
    @online_cookie = nil

    @live = Net::HTTP.new('login.live.com', 443)
    @live.use_ssl = true
    @live.read_timeout = 500
    @live_cookie = nil

    puts "logging in..."
    headers = {
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Encoding" => "gzip, deflate, sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "no-cache",
      "Connection" => "keep-alive",
      "Host" => "rio2016.sharepoint.com",
      "Pragma" => "no-cache",
      "Upgrade-Insecure-Requests" => "1",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36",
    }
    sharepoint_login = "https://rio2016.sharepoint.com/_forms/default.aspx?ReturnUrl=%2fsites%2f00161%2f_layouts%2f15%2fAuthenticate.aspx%3fSource%3d%252Fsites%252F00161%252FSitePages%252FCommunity%2520Home%252Easpx&Source=cookie"
    request = Net::HTTP::Get.new(URI(sharepoint_login))
    headers.each { |k,v| request[k] = v }
    puts sharepoint_login
    resp, data = @sharepoint.request(request)
    @sharepoint_cookie = resp['set-cookie']

    online_login = resp['Location']
    request = Net::HTTP::Get.new(URI(online_login))
    headers['Host'] = 'login.microsoftonline.com'
    headers.each { |k,v| request[k] = v }
    puts online_login
    resp, data = @online.request(request)
    body = Zlib::GzipReader.new(StringIO.new(resp.body.to_s)).read
    live_login = body.match(/authUrl": '(.+?)'/)[1].gsub(/\\u([\da-fA-F]{4})/) {|m| [$1].pack("H*").unpack("n*").pack("U*")} + "&pcexp=&username=#{@username.sub('@', '%40')}&popupui="
    @online_cookie = resp['set-cookie']

    request = Net::HTTP::Get.new(URI(live_login))
    headers['Host'] = 'login.live.com'
    # headers.delete('Cookie')
    headers.each { |k,v| request[k] = v }
    puts live_login
    resp, data = @live.request(request)
    body = Zlib::GzipReader.new(StringIO.new(resp.body.to_s)).read
    headers['Cookie'] = @live_cookie = resp['set-cookie']

    @ppft = body.match(/PPFT.*? value="(.*?)"/)[1]
    live_login_post = body.match(/urlPost:'(.+?)'/)[1]

    encoded_data = URI.encode_www_form({
      "loginfmt" => @username,
      "passwd" => @password,
      "KMSI" => "1",
      "SI" => "Sign in",
      "login" => @username,
      "type" => "11",
      "PPSX" => "Passport",
      "idsbho" => "1",
      "sso" => "0",
      "NewUser" => "1",
      "i1" => "0",
      "i2" => "1",
      "i4" => "0",
      "i7" => "0",
      "i12" => "1",
      "i13" => "1",
      "i17" => "0",
      "i18" => "__Login_Strings|1,__Login_Core|1,",
      "i3" => "112504",
      "i14" => "189",
      "i15" => "461",
      "LoginOptions" => "3",
      "PPFT" => @ppft,
    })

    headers['Cookie'] = @live_cookie = "MSPRequ=lt=#{resp['Set-Cookie'].match(/lt=(\d+)/)[1]}&co=1&id=N; MSPOK=$uuid-#{resp['Set-Cookie'].match(/MSPOK=\$uuid-([-\w]+)/)[1]}; CkTst=G#{Time.new.to_i * 1000}; wlidperf=FR=L&ST=#{Time.new.to_i * 1000}"

    puts live_login_post
    resp, data = @live.post(live_login_post, encoded_data, headers)
    body = Zlib::GzipReader.new(StringIO.new(resp.body.to_s)).read

    encoded_data = URI.encode_www_form({
      'wctx' => body.match(/id="wctx" value="(.*?)"/)[1].gsub('&amp;', '&'),
      'NAP'  => body.match(/id="NAP" value="(.*?)"/)[1],
      'wresult' => body.match(/id="wresult" value="(.*?)"/m)[1].gsub('&quot;', '"'),
      'wa' => 'wsignin1.0',
      'ANON' => body.match(/id="ANON" value="(.*?)"/m)[1]
    })
    headers = {
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Encoding" => "gzip, deflate",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "no-cache",
      "Connection" => "keep-alive",
      "Cookie" => "flight-uxoptin=true; x-ms-gateway-slice=productionb; stsservicecookie=ests",
      "Host" => "login.microsoftonline.com",
      "Origin" => "https://login.live.com",
      "Pragma" => "no-cache",
      "Referer" => live_login_post,
      "Upgrade-Insecure-Requests" => "1",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36",
    }
    puts '/login.srf'
    resp, data = @online.post('/login.srf', encoded_data, headers)
    body = Zlib::GzipReader.new(StringIO.new(resp.body.to_s)).read

    encoded_data = URI.encode_www_form({
      "t" => body.match(/id="t" value="(.*?)"/)[1]
    })
    headers = {
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Encoding" => "gzip, deflate",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "no-cache",
      "Connection" => "keep-alive",
      "Cookie" => @sharepoint_cookie,
      "Host" => "rio2016.sharepoint.com",
      "Origin" => "https://login.microsoftonline.com",
      "Pragma" => "no-cache",
      "Referer" => "https://login.microsoftonline.com/login.srf",
      "Upgrade-Insecure-Requests" => "1",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36"
    }
    resp, data = @sharepoint.post('/_forms/default.aspx?apr=1&wa=wsignin1.0', encoded_data, headers)

    @sharepoint_cookie = resp['set-cookie'].match(/rtFa=.*?;/)[0] + resp['set-cookie'].match(/FedAuth=.*?;/)[0]

    File.write(@cookie_cache, @sharepoint_cookie)
    puts "Stored cookie in #{@cookie_cache}"
  end

  def get_headers
    @headers = {
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip, deflate, sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "no-cache",
      "Connection" => "keep-alive",
      "Content-Type" => "application/x-www-form-urlencoded; charset=utf-8",
      "Host" => "rio2016.sharepoint.com",
      "Referer" => "https://rio2016.sharepoint.com/sites/00161/_layouts/15/start.aspx",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36",
      "X-Requested-With" => "XMLHttpRequest",
      "Cookie" => @sharepoint_cookie
    }
  end

  def sync_documents(folder = '', depth = 0)
    setup_http

    if folder == ''
      puts "Syncing #{@base_folder}..."
    else
      puts ('  ' * depth) + folder
    end

    docs = {}
    url = "/sites/00161/Lists/Documentos/Forms/AllItems.aspx?RootFolder=#{URI.encode(@base_folder + folder)}&FolderCTID=0x0120008710D697DFA2E749AA0B76C1AE8641CE&View=%7B4C60D80D%2D39B6%2D484B%2D8F73%2D477769723ECF%7D&AjaxDelta=1"
    resp, data = @sharepoint.get(url, get_headers)

    sleep 1

    startIndex = resp.body.index('var WPQ2ListData')
    endIndex = resp.body.index('var WPQ2SchemaData')
    if !startIndex && !endIndex
      raise "List data not found"
    end
    list_data = JSON.parse(resp.body[(startIndex + 19)...(endIndex - 1)])

    list_data['Row'].each do |row|
      # puts row['FileLeafRef']
      docs[row['FileLeafRef']] = if row['ContentType'] == 'Folder'
        sync_documents(File.join(folder, row['FileLeafRef']), depth + 1)
      else
        print ('  ' * depth) + '  - ' + row['FileLeafRef']
        download(row['FileRef']) unless exists_locally?(row['FileRef'])
        puts ' ✓'
      end
    end

    return docs
  end

  def get_xml(path, destination)
    "Looking for files in '#{path}' and saving to '#{destination}'..."
    destination = File.expand_path(destination)

    # loop over zip files
    Dir.glob(File.join(@local_directory, path, '**', '*.zip')).each do |filepath|
      extract_zip(path, destination, filepath)
    end

    # loop over xml files
    Dir.glob(File.join(@local_directory, path, '**', '*.xml')).each do |filepath|
      name = get_name(File.read(filepath))
      next if name.nil?
      fpath = File.join(destination, name)
      FileUtils.mkdir_p(File.dirname(fpath))
      FileUtils.cp(filepath, fpath) unless File.exist?(fpath)
    end
  end

  def extract_zip(path, destination, filepath)
    return if File.extname(filepath).match(/\.(txt|pdf)$/)
    return if !File.exist?(filepath) || File.size(filepath) == 0

    Zip::File.open(filepath) do |zipfile|
      zipfile.each do |f|
        next unless f.file?

        case File.extname(f.name)
        when /\.(txt|pdf)$/
          next
        when '.zip'
          temppath = Tempfile.new(File.basename(f.name)).path
          zipfile.extract(f, temppath) unless File.exist?(temppath)
          extract_zip(path, destination, temppath)
          next
        end

        name = get_name(zipfile.read(f))
        if name.nil?
          puts "ERROR: empty file? #{f.name}"
          next
        end

        fpath = File.join(destination, name)
        FileUtils.mkdir_p(File.dirname(fpath))
        zipfile.extract(f, fpath) unless File.exist?(fpath)
        puts " - #{fpath}"
      end
    end
  rescue Zip::Error => e
    puts "Error: #{e.message}"
    puts "#{path}, #{destination}, #{filepath}"
  rescue Exception => e
    puts "Error: #{path}, #{destination}, #{filepath}"
    raise e
  end

  private

  def download(path)
    print ' downloading... '
    headers = {
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Encoding" => "gzip, deflate, sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Cache-Control" => "no-cache",
      "Connection" => "keep-alive",
      "Host" => "rio2016.sharepoint.com",
      "Pragma" => "no-cache",
      "Referer" => "https://rio2016.sharepoint.com/sites/00161/_layouts/15/start.aspx",
      "Upgrade-Insecure-Requests" => "1",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36",
      "Cookie" => @sharepoint_cookie
    }
    download_url = "/sites/00161/_layouts/15/download.aspx?SourceUrl=#{URI.encode(path)}&FldUrl=&Source=https%3A%2F%2Frio2016%2Esharepoint%2Ecom%2Fsites%2F00161%2FLists%2FDocumentos%2FForms%2FAllItems%2Easpx"
    resp, data = @sharepoint.get(download_url, headers)
    print "#{resp.code} "

    if resp.code == "200"
      File.open(local_path(path), 'w') do |file|
        file.write(resp.body)
      end
      print `ls -lh #{local_path(path).shellescape} | awk '{print $5}'`.strip
    end
    sleep 0.5
  end

  def exists_locally?(path)
    File.exists?(local_path(path))
  end

  def local_path(path)
    path = File.join(@local_directory, path.sub(/#{@base_folder}/, ''))
    FileUtils.mkdir_p(File.dirname(path)) unless File.directory?(File.dirname(path))
    path
  end

  def get_name(xml)
    attrs = Hash[xml.match(/<OdfBody (.*?)>/m)[0].scan(/(\w+?)=['"](.*?)['"]/)]

    File.join(
      attrs['Date'].gsub!('-',''),
      attrs['DocumentCode'][0,2],
      %w(Date Time DocumentCode DocumentSubcode DocumentType DocumentSubtype Version Serial).map { |k| attrs[k] }.join('-') + '.xml'
    )
  rescue Exception => e
    puts "EXCEPTION: #{e.message}"
    puts e.backtrace
    puts xml
    nil
  end

end

sharepoint = SharePoint.new(*ARGV)
# sharepoint.method(ARGV[0]).call(*ARGV[1..-1])
# documents = sharepoint.sync_documents(*ARGV)
# sharepoint.get_xml(*ARGV)
