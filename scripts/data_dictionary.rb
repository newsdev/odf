require 'pp'
require 'open-uri'
require 'json'
require 'nokogiri'

urls = %w(
  http://odf.olympictech.org/2016-Rio/general/HTML/GL/ODF_GL_main.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/AR/ODF%20Archery%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/AT/ODF%20Athletics%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/BD/ODF%20Badminton%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/BK/ODF%20Basketball%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/BV/ODF%20Beach%20Volleyball%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/BX/ODF%20Boxing%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CS/ODF%20Canoe%20Slalom%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CF/ODF%20Canoe%20Sprint%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CB/ODF%20Cycling%20BMX%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CM/ODF%20Cycling%20Mountain%20Bike%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CR/ODF%20Cycling%20Road%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/CT/ODF%20Cycling%20Track%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/DV/ODF%20Diving%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/EQ/ODF%20Equestrian%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/FB/ODF%20Football%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/FE/ODF%20Fencing%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/GO/ODF%20Golf%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/GA/ODF%20Artistic%20Gymnastics%20Data%20Dictionary2.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/GR/ODF%20Rhythmic%20Gymnastics%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/GT/ODF%20Trampoline%20Gymnastics%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/HB/ODF%20Handball%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/HO/ODF%20Hockey%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/JU/ODF%20Judo%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/MP/ODF%20Modern%20Pentathlon%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/OW/ODF%20Marathon%20Swimming%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/RO/ODF%20Rowing%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/RU/ODF%20Rubgy%20Sevens%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/SA/ODF%20Sailing%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/SH/ODF%20Shooting%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/SW/ODF%20Swimming%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/SY/ODF%20Synchronised%20Swimming%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/TT/ODF%20Table%20Tennis%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/TK/ODF%20Taekwondo%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/TE/ODF%20Tennis%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/TR/ODF%20Triathlon%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/VO/ODF%20Volleyball%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/WP/ODF%20Water%20Polo%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/WL/ODF%20Weightlifting%20Data%20Dictionary3.html
  http://odf.olympictech.org/2016-Rio/OG/HTML/WR/ODF%20Wrestling%20Data%20Dictionary3.html
)

def get_url(url)
  puts "fetching #{url}"
  filepath = File.expand_path('../tmp/cache/' + url.gsub(/[^A-Za-z0-9]/, ''), __FILE__)
  if File.exists?(filepath)
    return File.read(filepath)
  else
    contents = open(url).read
    File.write(filepath, contents)
    return contents
  end
end


data = {}
urls.each do |url|
  puts url
  html = Nokogiri::HTML(get_url(url))
  data[url.match(/HTML\/([A-Z]{2})\//)[1]] = discipline = {}

  document_types = html.xpath("//h3")
  document_types.each do |dt|
    values = dt.parent.xpath(".//h3[@id='#{dt.attr('id')}']/following::h4").detect { |h| h.content.match(/^2\.2\.\d+\.5/) }
    puts dt.xpath(".//h4")
    puts values
    next unless values

    table = dt.parent.xpath(".//h3[@id='#{dt.attr('id')}']/following::table")[0]
    next unless table

    dt_name = table.xpath(".//tr").map do |tr|
      tr.xpath(".//td")[1].content if tr.xpath(".//td")[1]
    end.compact.detect { |c| c.match(/DT_/) }

    next unless dt_name

    dt_name.strip!
    puts dt_name
    node = values
    discipline[dt_name] = {}

    sub_element = nil
    element_name = nil
    puts "resetting"
    current_element = nil
    current_type = nil
    current_subtype = nil

    begin
      if node.name == 'table'
        puts node
        content = node.xpath(".//p[@class='TableContents' or @class='Normal']").first.content
        headers = node.xpath(".//p[@class='TableHeading']")

        if content.match(/^Element:/) || headers.length > 0 && (content = headers.first.content).match(/^Element/)
          puts "setting to #{content}"
          current_element = discipline[dt_name]
          element_name = content.sub(/^Element: /, '').sub(/\([^\(\)]+\)$/, '').strip
          element_name.split(' /').each do |node|
            current_element[:children] ||= {}
            current_element[:children][node] ||= []
            # current_element[:children][node] << (current_element = {})
            # current_element = (current_element[node] ||= {})
          end

        elsif headers.length > 0
          table_type = headers.first.content == 'Attribute' ? :attributes : :children
          case table_type
          when :attributes
            current_element[:children]
            node.xpath(".//tr").each do |row|
              text = row.xpath(".//p[@class='TableContents']").map(&:content).map { |t| t.gsub("\u00A0", " ").strip }
              if text.length > 0
                current_element[:attributes] ||= {}
                current_element[:attributes][text[0]] = {
                  mandatory: text[1] == 'M',
                  value: text[2],
                  description: text[3]
                }
              end
            end

          when :children
            indented = 0
            current_type = nil
            node.xpath(".//tr").each do |row|
              # text = row.xpath(".//p[@class='TableContents']").map { |p| p.children.first.content.strip }
              graphs = row.xpath(".//td").select { |p| (p.xpath(".//p[@class='TableContents']").length > 0) || (p.attr('style') || '').match(/b5b5b5/) }
              text = graphs.map { |p| p.content.gsub("\u00A0", " ").strip }
              # text = graphs.map { |p| p.children.first.content.strip }

              # if row.xpath(".//p").any? { |p| (p.parent.attr('style') || '').match(/b5b5b5/) && !(p.attr('class') || '').match(/TableContents/) }
              #   puts row
              #   raise
              # end
              #

              if t = text.detect { |t| t.match(/Sub Element/) }
                # Parse out Sub Element
                sub_element = t.sub("Sub Element: ", "").sub(element_name + ' /', "").strip
                puts 'setting subtype ' + sub_element
                current_type[sub_element] = current_subtype = {attributes: {}}
              end

              puts "indented?: #{row.xpath('.//td').first}"
              if rowspan = row.xpath(".//td").first.attr('rowspan')
                indented = rowspan.to_i
                puts "indented: #{indented}"
              end

              puts "#{graphs.length} / #{text.length}"
              case text.length
              when 0
              when 1
              when 2

              when 3
                if text[0] != 'Attribute'
                  current_subtype[text[0]] = {
                    value: text[1],
                    description: text[2]
                  }
                end

              when 4
                if indented > 0
                  if text[0] != 'Attribute'
                    current_type[:attributes][text[0]] = {
                      mandatory: text[1] == 'M',
                      value: text[2],
                      description: text[3]
                    }
                  end
                else
                  current_element[:children] ||= {}
                  current_element[:children][ ] ||= []
                  current_element[:children][] << current_type = {
                    type: text[0],
                    code: text[1],
                    description: text[3],
                    attributes: {}
                  }
                end
              when 5
              end
  
              indented -= 1
              puts "-indented: #{indented}"
            end
          end
  
        end
      end
      node = node.next
    end while !%w(h1 h2 h3 h4).include?(node.next.name)
  
  end
end

# pp data; nil
