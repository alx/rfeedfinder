require 'net/http'
require 'rubygems'
require 'htmlentities'
require 'open-uri'
require 'hpricot'
require 'timeout'

require 'rfeedfinder/version'

module Rfeedfinder

  module_function
  
  def makeFullURI(uri)
    uri = uri.strip.sub(/^feed(.*)/, 'http\1').downcase
    if /^http|https/.match(uri)
      return uri
    else
      return "http://" << uri
    end
  end

  def getLinks(data, baseuri)
    return searchLinks(data, baseuri, "[@rel=alternate]&[@type=xml]&[@href=http]")
  end

  def getALinks(data, baseuri)
    return searchLinks(data, baseuri, "a")
  end
  
  def getFrameLinks(data, baseuri)
    links = searchLinks(data, baseuri, "frame")
    links += searchLinks(data, baseuri, "FRAME")
    return links
  end
  
  def searchLinks(data, baseuri, regexp)
    links = []
    data.search(regexp).map!{|link| 
      if !link.to_s.strip.empty? and link.kind_of? Hpricot::Elem and !(link.kind_of? Hpricot::Text)
        uri = link[:href].to_s
        uri = link[:src].to_s if uri.empty?
        uri = link[:SRC].to_s if uri.empty?
        if !uri.strip.empty? and uri !~ /^javascript/
          uri = URI.join(baseuri, uri).to_s if uri !~ /^http:\/\//
          links << uri 
        end
      end
    }
    #links.each{|link| puts "searchLinks: #{link}"}
    return links.uniq
  end

  def getLocalLinks(links, baseuri)
    locallinks = []
    links.each do |link|
      locallinks << URI.join(baseuri, link).to_s if link =~ /^\//
    end
    links = links.select{|link| link !~ /^\//} #remove local links from link array
    return [links, locallinks]
  end

  def isFeedLink?(link)
    return link.downcase =~ /\.rss$|\.rdf$|\.xml$|\.atom$/
  end

  def isXMLRelatedLink?(link)
    return link.downcase =~ /rss|rdf|xml|atom/
  end

  def tryBrokenRedirect(data)
    newuris = (data/:newLocation)
    if !newuris.empty?
      return newuris[0].strip
    end
  end
  
  def verifyRedirect(feedlist)
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

  def isFeedData?(data)
    # if no html tag and rss, rdf or feed tag, it's a feed
    return ((data/"html|HTML").empty? and (!(data/:rss).nil? or !(data/:rdf).nil? or !(data/:feed).nil?))
  end

  def isFeed?(uri)
    uri.gsub!(/\/\/www\d\./, "//www.")
    begin
      protocol = URI.split(uri)
      return false if !protocol[0].index(/^[http|https]/)
    rescue
      # URI error
      return false
    end
    
    data = open_doc(uri)
    return false if data.nil?
    
    return isFeedData?(data)
  end

  def getFeedsFromSyndic8(uri)
    feeds = []
    begin
      server = Syndic8.new
      feedids = server.find_feeds(uri)
      infolist = server.feed_info(feedids, ['headlines_rank','status','dataurl'])
      infolist.sort_by{|feedInfo| feedInfo[:headlines_rank]}
      infolist.each do |feed|
        feeds << feed[:dataurl] if feed[:status]=='Syndicated'
      end
    rescue
    end
    return feeds
  end
  
  def feeds(uri, all=false, querySyndic8=false, _recurs=nil)
    uri = HTMLEntities.decode_entities(uri)
    _recurs = [uri] if _recurs.nil?
    fulluri = makeFullURI(uri)
    
    # Add youtube support
    if fulluri =~ /youtube\.com\/user\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/user/#{$1}/videos.rss"
    end
    if fulluri =~ /youtube\.com\/tag\/(.*[^\/])/
      fulluri = "http://www.youtube.com/rss/tag/#{$1}/videos.rss"
    end
    
    data = open_doc(fulluri)
    return [] if data.nil?

    # is this already a feed?
    if isFeedData?(data)
      feedlist = [fulluri]
      verifyRedirect(feedlist)
      return feedlist
    end
    
    #verify redirection
    newuri = tryBrokenRedirect(data)
    if !newuri.nil? and !newuri.empty?
      unless _recurs.include?(newuri)
        _recurs << newuri
        return feeds(newuri, all=all, querySyndic8=querySyndic8, _recurs=_recurs)
      end
    end
     
    #verify frameset
    frames = getFrameLinks(data, fulluri)
    frames.each {|newuri|
      if !newuri.nil? and !newuri.empty?
        unless _recurs.include?(newuri)
          _recurs << newuri
          return feeds(newuri, all=all, querySyndic8=querySyndic8, _recurs=_recurs)
        end
      end
    }

    # nope, it's a page, try LINK tags first
    outfeeds = getLinks(data, fulluri)
    outfeeds.select {|link| isFeed?(link)}
    
    #_debuglog('found %s feeds through LINK tags' % len(outfeeds))
    if outfeeds.empty?
      # no LINK tags, look for regular <A> links that point to feeds
      begin
        links = getALinks(data, fulluri)
      rescue
        links = []
      end
      
      # Get local links
      links, locallinks = getLocalLinks(links, fulluri)

      # look for obvious feed links on the same server
      selected_feeds = locallinks.select{|link| isFeedLink?(link) and isFeed?(link)}
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "1 #{link}"}
      
      # look harder for feed links on the same server
      selected_feeds = locallinks.select{|link| isXMLRelatedLink?(link) and isFeed?(link)} if outfeeds.empty?
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "2 #{link}"}

      # look for obvious feed links on another server
      selected_feeds = links.select {|link| isFeedLink?(link) and isFeed?(link)} if outfeeds.empty?
      outfeeds << selected_feeds unless selected_feeds.empty?
      # outfeeds.each{|link| puts "3 #{link}"}

      # look harder for feed links on another server
      selected_feeds = links.select {|link| isXMLRelatedLink?(link) and isFeed?(link)} if outfeeds.empty?
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
        outfeeds << uri if isFeed?(uri)
      }
    end
    
    # try with adding ending slash
    if outfeeds.empty? and fulluri !~ /\/$/
      outfeeds = feeds(fulluri + "/", all=all, querySyndic8=querySyndic8, _recurs=_recurs)
    end
    
    # still no luck, search Syndic8 for feeds (requires xmlrpclib)
    #_debuglog('still no luck, searching Syndic8')
    outfeeds << getFeedsFromSyndic8(uri) if querySyndic8 and outfeeds.empty?
    #outfeeds = list(set(outfeeds)) if hasattr(__builtins__, 'set') or __builtins__.has_key('set')
    
    # Verify redirection
    verifyRedirect(outfeeds)
    
    return outfeeds.flatten
  end

  def feed(uri)
    #todo: give preference to certain feed formats
    feedlist = feeds(uri)
    unless feedlist.empty?
      return feedlist[0]
    else
      return nil
    end
  end
  
  def open_doc(link)
    data = nil
    begin
      Timeout::timeout(20) {
        data = Hpricot(open(link,
               "User-Agent" => "Ruby/#{RUBY_VERSION} - Rfeedfinder",
               "From" => "rfeedfinder@googlegroups.com",
               "Referer" => "http://rfeedfinder.rubyforge.org/"), :xml => true)
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
    return data
  end
end