require 'net/http'
require 'rubygems'
require 'htmlentities'
require 'open-uri'
require 'hpricot'
require 'timeout'

require File.dirname(__FILE__) + "/rfeedfinder/version"


class Rfeedfinder
  # 
  # Takes:
  # * +init_values+ (hash) containing proxy, and
  #   and user-agent information.
  #   You can also have the script return the data
  #   it has downloaded for the feed addresses it returns
  #   by adding :keep_data => true to the options hash
  #   
  #   Example:
  #   
  #   Rfeedfinder.new({:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
  #   Defaults to:
  #   
  #     :proxy => ""
  #     :user_agent => "User-Agent" => "Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION"
  #     :from => "rfeedfinder@googlegroups.com"
  #     :referer => "http://rfeedfinder.rubyforge.org/"
  # 
  # Returns a new instance of Rfeedfinder 
  # 
  def initialize(init_values = {})
    @options = init_values
  end

  # 
  # Takes:
  # * +uri+ (string)
  # 
  # Returns:
  # * array of urls
  # 
  def feeds(uri)
    Rfeedfinder.feeds(uri, @options.dup)
  end

  # 
  # Takes:
  # * +uri+ (string)
  # 
  # Returns:
  # * url (string)
  # 
  def feed(uri)
    result = Rfeedfinder.feed(uri, @options.dup)
  end

  # 
  # Takes:
  # * +uri+ (string): The URI to check
  # * +options+ (hash) containing proxy, and
  #   and user-agent information.
  #   You can also have the script return the data
  #   it has downloaded for the feed addresses it returns
  #   by adding :keep_data => true to the options hash
  #   
  #   Example:
  #   
  #   Rfeedfinder.feeds("www.google.com", {:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
  #   Defaults to:
  #   
  #     :proxy => ""
  #     :user_agent => "User-Agent" => "Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION"
  #     :from => "rfeedfinder@googlegroups.com"
  #     :referer => "http://rfeedfinder.rubyforge.org/"
  #     
  # Returns:
  # * array of urls
  # * array of hashes if the :keep_data option is true
  #   Example:
  #   [{:url => "url1", :data => "some data"},{:url => "url2", :data => "feed data"}]
  # 
  def self.feeds(uri, options = {})
    
    # We have to create a hash for the data
    # if the user has asked us to keep the data
    options[:data] = {} if options[:keep_data]  
      
    uri = HTMLEntities.decode_entities(uri)
    _recurs = [uri] if _recurs.nil?
    fulluri = Rfeedfinder.makeFullURI(uri)
    
    # Add youtube support
    if fulluri =~ /youtube\.com\/user\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/user/#{$1}/videos.rss"
    end
    if fulluri =~ /youtube\.com\/tag\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/tag/#{$1}/videos.rss"
    end
    
    data = Rfeedfinder.open_doc(fulluri, options)
    return [] if data.nil?

    # is this already a feed?
    if Rfeedfinder.isFeedData?(data)
      feedlist = [fulluri]
      Rfeedfinder.verifyRedirect(feedlist)
      return feedlist
    end
    
    #verify redirection
    newuri = Rfeedfinder.tryBrokenRedirect(data)
    if !newuri.nil? and !newuri.empty?
      options[:recurs] = [] unless options[:recurs]
      unless options[:recurs].include?(newuri)
        options[:recurs] << newuri
        return feeds(newuri, options)
      end
    end
     
    #verify frameset
    frames = Rfeedfinder.getFrameLinks(data, fulluri)
    frames.each {|newuri|
      if !newuri.nil? and !newuri.empty?
        options[:recurs] = [] unless options[:recurs]
        unless options[:recurs].include?(newuri)
          options[:recurs] << newuri
          return feeds(newuri, options)
        end
      end
    }

    # TODO: fix so if the user only wants one feed
    # then we don't download all the feeds
    # options[:only_first] == true ...
    
    # nope, it's a page, try LINK tags first
    outfeeds = Rfeedfinder.getLinks(data, fulluri).select do |link| 
      if options[:only_first]
        # We only want the first url which leeds to a feed
        # We don't want to call isFeed? to often, 
        # because it initiates a download
        if options[:already_found_one]
          # return false so we don't include any more link
          false
        else
          if Rfeedfinder.isFeed?(link, options)
            options[:already_found_one] = true
            true
          else
            false
          end
        end
      else
        # Do as normal
        Rfeedfinder.isFeed?(link, options)
      end
    end
      
    #_debuglog('found %s feeds through LINK tags' % len(outfeeds))
    if outfeeds.empty?
      # no LINK tags, look for regular <A> links that point to feeds
      begin
        links = Rfeedfinder.getALinks(data, fulluri)
      rescue
        links = []
      end
      
      # Get local links
      links, locallinks = Rfeedfinder.getLocalLinks(links, fulluri)

      # TODO:
      # implement support for :only_first down her

      # look for obvious feed links on the same server
      selected_feeds = locallinks.select{|link| Rfeedfinder.isFeedLink?(link) and Rfeedfinder.isFeed?(link, options)}
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "1 #{link}"}
      
      # look harder for feed links on the same server
      selected_feeds = locallinks.select{|link| Rfeedfinder.isXMLRelatedLink?(link) and Rfeedfinder.isFeed?(link, options)} if outfeeds.empty?
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "2 #{link}"}

      # look for obvious feed links on another server
      selected_feeds = links.select {|link| Rfeedfinder.isFeedLink?(link) and Rfeedfinder.isFeed?(link, options)} if outfeeds.empty?
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "3 #{link}"}

      # look harder for feed links on another server
      selected_feeds = links.select {|link| Rfeedfinder.isXMLRelatedLink?(link) and Rfeedfinder.isFeed?(link, options)} if outfeeds.empty?
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "4 #{link}"}
    end
    
    if outfeeds.empty?
      # no A tags, guessing
      # filenames used by popular software:
      guesses = ['atom.xml', # blogger, TypePad
        'feed/', # wordpress
        'feeds/posts/default', # blogspot
        'feed/main/rss20', # fotolog
        'index.atom', # MT, apparently
        'index.rdf', # MT
        'rss.xml', # Dave Winer/Manila
        'index.xml', # MT
        'index.rss'] # Slash
        
      guesses.each { |guess|  
        uri = URI.join(fulluri, guess).to_s
        outfeeds << uri if Rfeedfinder.isFeed?(uri, options)
      }
    end
    
    # try with adding ending slash
    if outfeeds.empty? and fulluri !~ /\/$/
      outfeeds = Rfeedfinder.feeds(fulluri + "/", options)
    end
        
    # Verify redirection
    Rfeedfinder.verifyRedirect(outfeeds)
    
    # This has to be used until proper :only_first support has been built in
    outfeeds = outfeeds.first if options[:only_first] and outfeeds.size > 1
    
    if options[:keep_data]
      output = []
      outfeeds.each do |feed|
        output << {:url => feed, :data => options[:data][feed]}
      end
      return output
    else
      return outfeeds
    end
  end


  # 
  # Takes:
  # * +uri+ (string): The URI to check
  # * +options+ (hash) containing proxy, and
  #   and user-agent information.
  #   You can also have the script return the data
  #   it has downloaded for the feed addresses it returns
  #   by adding :keep_data => true to the options hash
  #   
  #   Example:
  #   
  #   Rfeedfinder.feeds("www.google.com", {:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
  #   Defaults to:
  #   
  #     :proxy => ""
  #     :user_agent => "User-Agent" => "Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION"
  #     :from => "rfeedfinder@googlegroups.com"
  #     :referer => "http://rfeedfinder.rubyforge.org/"
  #     
  # Returns:
  # * one URL as a string or nil
  # * one hash if the :keep_data option is true
  #   Example:
  #   {:url => "url1", :data => "some data"}
  # 
  def self.feed(uri, options = {})
    options[:only_first] = true
    feedlist = Rfeedfinder.feeds(uri, options)
    unless feedlist.empty?
      return feedlist[0]
    else
      return nil
    end
  end

  # 
  # Takes:
  # * +data+ (string)
  # 
  # Returns:
  # * +true+ if the data has a rss, rdf or feed tag
  # * +false+ if the data has a html tag
  # 
  def self.isFeedData?(data)
    # if no html tag and rss, rdf or feed tag, it's a feed
    # puts data
    return ((data/"html|HTML").empty? and (!(data/:rss).nil? or !(data/:rdf).nil? or !(data/:feed).nil?))
  end

  # 
  # Takes:
  # * +uri+ (string)
  # 
  # Downloads the URI and checkes the content
  # with the +isFeedData?+ class method
  # 
  # Returns:
  # * +true+ if the uri points to a feed
  # * +false+ if not
  # 
  def self.isFeed?(uri, options)
    uri.gsub!(/\/\/www\d\./, "//www.")
    begin
      protocol = URI.split(uri)
      return false if !protocol[0].index(/^[http|https]/)
    rescue
      # URI error
      return false
    end
    
    data = Rfeedfinder.open_doc(uri, options)
    return false if data.nil?
    
    return Rfeedfinder.isFeedData?(data)
  end

  protected
  def self.makeFullURI(uri)
    uri = uri.strip.sub(/^feed(.*)/, 'http\1').downcase
    if /^http|https/.match(uri)
      return uri
    else
      return "http://" << uri
    end
  end

  def self.getLinks(data, baseuri)
    return Rfeedfinder.searchLinks(data, baseuri, "[@rel=alternate]&[@type=xml]&[@href=http]")
  end

  def self.getALinks(data, baseuri)
    return Rfeedfinder.searchLinks(data, baseuri, "a")
  end
  
  def self.getFrameLinks(data, baseuri)
    links = Rfeedfinder.searchLinks(data, baseuri, "frame")
    links += Rfeedfinder.searchLinks(data, baseuri, "FRAME")
    return links
  end
  
  def self.searchLinks(data, baseuri, regexp)
    links = []
    data.search(regexp).map!{|link| 
      if !link.to_s.strip.empty? and link.kind_of? Hpricot::Elem and !(link.kind_of? Hpricot::Text)
        uri = link[:href].to_s
        uri = link[:HREF].to_s if uri.empty?
        uri = link[:src].to_s if uri.empty?
        uri = link[:SRC].to_s if uri.empty?
        if !uri.strip.empty? and uri !~ /^javascript/
          uri = URI.join(baseuri, uri).to_s if uri !~ /^http:\/\//
          links << uri 
        end
      end
    }
    #links.each{|link| puts "Rfeedfinder.searchLinks: #{link}"}
    return links.uniq
  end

  def self.getLocalLinks(links, baseuri)
    locallinks = []
    links.each do |link|
      locallinks << URI.join(baseuri, link).to_s if link =~ /^\//
    end
    links = links.select{|link| link !~ /^\//} #remove local links from link array
    return [links, locallinks]
  end

  def self.isFeedLink?(link)
    return link.downcase =~ /\.rss$|\.rdf$|\.xml$|\.atom$/
  end

  def self.isXMLRelatedLink?(link)
    return link.downcase =~ /rss|rdf|xml|atom/
  end

  def self.tryBrokenRedirect(data)
    newuris = (data/:newLocation)
    if !newuris.empty?
      return newuris[0].strip
    end
  end
  
  def self.verifyRedirect(feedlist)
    feedlist.each do |feed|
      begin
       response = Net::HTTP.get_response(URI.parse(feed))
       #puts "Verify #{feed} - code: #{response.code}"
       if response.code == "302"
         newuri = response.body.match(/<a href=\"([^>]+)\">/)[1]
         
         feedlist.delete(feed)
         feedlist << newuri
         feedlist.uniq!
       end
     rescue
       # rescue net error
     end
    end
    return feedlist
  end
  
  def self.open_doc(link, options)

    # Setting default values for missing options
    options[:proxy] = URI.parse(options[:proxy]) if options[:proxy]  
    options[:user_agent] = options[:user_agent] || "Ruby/#{RUBY_VERSION} - " + \
      "Rfeedfinder #{Rfeedfinder::VERSION::STRING}"
    options[:from] = options[:from] || "rfeedfinder@googlegroups.com"
    options[:referer] = options[:referer] || "http://rfeedfinder.rubyforge.org/"
      
    data = nil
    begin
      Timeout::timeout(20) {
        data = Hpricot(open(link, {
               "User-Agent" => options[:user_agent],
               "From" => options[:from],
               "Referer" => options[:referer],
               :proxy => options[:proxy]
               }), :xml => true)
      }
    rescue OpenURI::HTTPError
      begin
        Timeout::timeout(20) {
          html = Net::HTTP.get(URI.parse(link))
          data = Hpricot(html, :xml => true) if html.to_s !~ /404 Not Found/
        }
      rescue Timeout::Error
        return nil
      rescue => err
        puts "Error while opening #{link} with Hpricot: #{err.class} " << $!
        return nil
      end
    rescue Timeout::Error 
      return nil
    rescue => err
      puts "Error while opening #{link} with Hpricot: #{err.class} " << $!
      return nil
    end
    
    # Store the data for the URL if the user has requested it
    options[:data][link] = data.to_original_html if options[:keep_data]
    
    return data
  end
end