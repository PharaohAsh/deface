require 'nokogiri'
require 'cgi'

module Deface
  class Parser
    # converts erb to markup
    #
    def self.erb_markup!(source)

      #all opening html tags that contain <% %> blocks
      source.scan(/<\w+[^<>]+(?:<%.*?%>[^<>]*)+/m).each do |line|

        #regexs to catch <% %> inside attributes id="<% something %>" - with double, single or no quotes
        erb_attrs_regexs = [/([\w-]+)(\s?=\s?)(")([^"]*<%.*?%>[^"]*)/m,
          /([\w-]+)(\s?=\s?)(')([^']*<%.*?%>[^']*)'/m,
          /([\w-]+)(\s?=\s?)()(<%.*?%>)(?:\s|>|\z)/m]

        replace_line = erb_attrs_regexs.inject(line.clone) do |replace_line, regex|

          replace_line = line.scan(regex).inject(replace_line) do |replace_line, match|
            replace_line.sub("#{match[0]}#{match[1]}#{match[2]}#{match[3]}#{match[2]}") { |m| m = " data-erb-#{match[0]}=\"#{CGI.escapeHTML(match[3])}\"" }
          end

          replace_line
        end


        i = -1
        #catch all <% %> inside tags id <p <%= test %>> , not inside attrs
        replace_line.scan(/(<%.*?%>)/m).each do |match|
          replace_line.sub!(match[0]) { |m| m = " data-erb-#{i += 1}=\"#{CGI.escapeHTML(match[0])}\"" }
        end

        source.sub!(line) { |m| m = replace_line }
      end

      #replaces all <% %> not inside opening html tags
      replacements = [ {"<%=" => "<code erb-loud>"},
                       {"<%"  => "<code erb-silent>"},
                       {"%>"  => "</code>"} ]

      replacements.each{ |h| h.each { |replace, with| source.gsub! replace, with } }

      source.scan(/(<code.*?>)((?:(?!<\/code>)[\s\S])*)(<\/code>)/).each do |match|
        source.sub!("#{match[0]}#{match[1]}#{match[2]}") { |m| m = "#{match[0]}#{CGI.escapeHTML(match[1])}#{match[2]}" }
      end

      source
    end

    # undoes ERB markup generated by Deface::Parser::ERB
    #
    def self.undo_erb_markup!(source)
      replacements = [ {"<code erb-silent>" => '<%'},
                       {"<code erb-loud>"   => '<%='},
                       {"</code>"           => '%>'}]

      replacements.each{ |h| h.each { |replace, with| source.gsub! replace, with } }

      source.scan(/data-erb-(\d+)+=(['"])(.*?)\2/m).each do |match|
        source.gsub!("data-erb-#{match[0]}=#{match[1]}#{match[2]}#{match[1]}") { |m| m = CGI.unescapeHTML(match[2]) }
      end

      source.scan(/data-erb-([\w-]+)+=(["'])(.*?)\2/m).each do |match|
        source.gsub!("data-erb-#{match[0]}=#{match[1]}#{match[2]}#{match[1]}") { |m| "#{match[0]}=#{match[1]}#{CGI.unescapeHTML(match[2])}#{match[1]}" }
      end

      #un-escape changes from Nokogiri and erb-markup!
      source.scan(/(<%.*?)((?:(?!%>)[\s\S])*)(%>)/).each do |match|
        source.gsub!("#{match[0]}#{match[1]}#{match[2]}") { |m| m = "#{match[0]}#{ CGI.unescapeHTML match[1] }#{match[2]}" }
      end

      source
    end

    def self.convert(source)
      erb_markup!(source)

      if source =~ /(<html.*?)((?:(?!>)[\s\S])*)(>)/
        Nokogiri::HTML::Document.parse(source)
      else
        Nokogiri::HTML::DocumentFragment.parse(source)
      end
    end

  end
end
