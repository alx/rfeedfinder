require 'net/http'
require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'timeout'

require File.dirname(__FILE__) + "/rfeedfinder/version"


class Rfeedfinder
  # 
  # Takes:
  # * +init_values+ (hash) 
  #   * +:proxy+: (string) proxy information to use. Defaults to a blank string
  #   * +:user_agent+: (string) user agent to identify as. Defaults to Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION
  #   * +:from+: (string) contact info to the responsible person. FIXME: Is this correct? Defaults to rfeedfinder@googlegroups.com
  #   * +:keep_data+: (boolean) if the data downloaded for the feeds should be returned along with the URLs. Defaults to false
  #   * +:use_google+: (boolean) tries to find a URL using a google "I'm feeling lucky" search. Defaults to false
  # 
  #   
  #   Example:
  #   
  #   Rfeedfinder.new({:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
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
  # * +options+ (hash) 
  #   * +:proxy+: (string) proxy information to use. Defaults to a blank string
  #   * +:user_agent+: (string) user agent to identify as. Defaults to Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION
  #   * +:from+: (string) contact info to the responsible person. FIXME: Is this correct? Defaults to rfeedfinder@googlegroups.com
  #   * +:keep_data+: (boolean) if the data downloaded for the feeds should be returned along with the URLs. Defaults to false
  #   * +:use_google+: (boolean) tries to find a URL using a google "I'm feeling lucky" search. Defaults to false
  # 
  #   
  #   Example:
  #   
  #   Rfeedfinder.feeds("www.google.com", {:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
  #     
  # Returns:
  # * array of urls
  # * array of hashes if the :keep_data option is true
  #   Example:
  #   [{:url => "url1", :data => "some data"},{:url => "url2", :data => "feed data"}]
  # 
  # Raises:
  # * ArgumentError if +uri+ is not a valid URL, and :use_google => false
  # * ArgumentError if :use_google => true but it's not your lucky day
  # 
  def self.feeds(uri, options = {})
    
    # We have to create a hash for the data
    # if the user has asked us to keep the data
    options[:data] = {} if options[:keep_data]  

    options[:original_uri] = uri if !Rfeedfinder.isAValidURL?(uri) and options[:use_google]
    
    uri = URI.decode(uri)
    options[:recurs] = [uri] if options[:recurs].nil?
    fulluri = Rfeedfinder.makeFullURI(uri)

    raise ArgumentError, "#{fulluri} is not a valid URI." \
      if !Rfeedfinder.isAValidURL?(fulluri) and !options[:use_google]
    
    # Add youtube support
    if fulluri =~ /youtube\.com\/user\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/user/#{$1}/videos.rss"
    end
    if fulluri =~ /youtube\.com\/tag\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/tag/#{$1}/videos.rss"
    end
        
    data = Rfeedfinder.open_doc(fulluri, options)
    return [] if data.nil?

    # If we used the google link finder, then we should set the new URL
    fulluri = options[:google_link] if options[:google_link]
  
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
    
    # nope, it's a page, try LINK tags first
    outfeeds = Rfeedfinder.getLinks(data, fulluri).select {|link| Rfeedfinder.isFeed?(link, options)}
      
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
  # * +options+ (hash) 
  #   * +:proxy+: (string) proxy information to use. Defaults to a blank string
  #   * +:user_agent+: (string) user agent to identify as. Defaults to Ruby/#{RUBY_VERSION} - Rfeedfinder VERSION
  #   * +:from+: (string) contact info to the responsible person. FIXME: Is this correct? Defaults to rfeedfinder@googlegroups.com
  #   * +:keep_data+: (boolean) if the data downloaded for the feeds should be returned along with the URLs. Defaults to false
  #   * +:use_google+: (boolean) tries to find a URL using a google "I'm feeling lucky" search. Defaults to false
  # 
  #   
  #   Example:
  #   
  #   Rfeedfinder.feeds("www.google.com", {:proxy => "http://127.0.0.1:1234",
  #                    :user_agent => "MyApp",
  #                    :from => "contant@domain.com",
  #                    :referer => "http://domain.com"})
  #                    
  #     
  # Returns:
  # * one URL as a string or nil
  # * one hash if the :keep_data option is true
  #   Example:
  #   {:url => "url1", :data => "some data"}
  # 
  # Raises:
  # * ArgumentError if +uri+ is not a valid URL, and :use_google => false
  # * ArgumentError if :use_google => true but it's not your lucky day
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
    # We return false if the user only wants one result
    # and we already have found it so there aren't made
    # any additional external calls
    return false if options[:only_first] and options[:already_found_one]
    
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
    
    if Rfeedfinder.isFeedData?(data)
      options[:already_found_one] = true if options[:only_first]
      return true
    else
      return false
    end
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
    return Rfeedfinder.searchLinks(data, baseuri, "[@rel='alternate'][@type*='xml'][@href*='http']")
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
    
    if !Rfeedfinder.isAValidURL?(link) and options[:use_google]
      # Used google lucky script as found on 
      # http://www.leancrew.com/all-this/2006/07/lucky-linking/
      # It doesn't work to well...
      # TODO: Improve it somehow. The real google function works a lot better!
      # TODO: Build in support for languages through parameter "hl" (=> "en" by default)
      prefix = "http://www.google.com/search?q="
      suffix = "&btnI=I'm+Feeling+Lucky"
      goodURL = URI.escape(prefix + options[:original_uri] + suffix)
      puts "Checking #{goodURL}"
      response = Net::HTTP.get_response(URI.parse(goodURL))
      link = response.to_hash['location'].first
      options[:google_link] = link
      raise ArgumentError, "Google couldn't save us. We couldn't find anything for #{options[:original_uri]}" if link.nil?
    end
    
    begin
      
      Timeout::timeout(20) do
      
        data = Hpricot(open(link, {
               "User-Agent" => options[:user_agent],
               "From" => options[:from],
               "Referer" => options[:referer],
               :proxy => options[:proxy]
               }), :xml => true)
      
      end

    rescue OpenURI::HTTPError

      begin

        Timeout::timeout(20) do
          
          html = Net::HTTP.get(URI.parse(link))
          data = Hpricot(html, :xml => true) if html.to_s !~ /404 Not Found/

        end

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

  def self.isAValidURL?(url_to_check)
    return false if url_to_check == nil

    # The protocols that we allow are the following
    protocol_whitelist = ["http", "https"]
    # I guess we could have included some more, but that doesn't really
    # make sense anyway as these are the ones that should be used.
    # We'll see if the need arises and then add more later if needed.

    re = Regexp.new("(#{protocol_whitelist.join('|')}):" + \
      "\/\/([[:alpha:][:digit:].]{2,})([.]{1})([[:alpha:]]{2,4})(\/)")

    # For the sake of the regular expression check we add a back slash
    # at the end of the URL
    url_to_check += "/"
    return true unless (re =~ url_to_check) == nil
    false
  end

end