require File.dirname(__FILE__) + "/spec_helper"

describe Rfeedfinder, "get feeds with option variable set" do
  before(:each) do
    @options_in = {:from => "from", :user_agent => "SpecialAgent", :referer =>"Else"}
    @options = {"From"=>"from", "User-Agent"=>"SpecialAgent", :proxy=>nil, "Referer"=>"Else"}
    @feed_finder = Rfeedfinder.new(@options_in)
  end

  it "should return 1 feed for scripting.com" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpscriptingcom")
    Rfeedfinder.should_receive(:open).once.with("http://www.scripting.com", @options).and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_rss_feed")
    Rfeedfinder.should_receive(:open).once.with("http://www.scripting.com/rss.xml", @options).and_return(data)

    result = @feed_finder.feeds("www.scripting.com")

    result.size.should == 1
    result.should be_a_kind_of(Array)

  end

  it "should return two flicker feeds" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpflickrcomphotosalx")
    Rfeedfinder.should_receive(:open).once.with("http://flickr.com/photos/alx", @options).and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_atom_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom", @options).and_return(data)
    
    data = File.read(File.dirname(__FILE__) + "/fixtures/some_rss_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=rss_200", @options).and_return(data)

    result = @feed_finder.feeds("http://flickr.com/photos/alx")

    result.size.should == 2
    result.should be_a_kind_of(Array)
    result.first.should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom"
    result.last.should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=rss_200"

  end
  
  it "should only return the first feed" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpflickrcomphotosalx")
    Rfeedfinder.should_receive(:open).once.with("http://flickr.com/photos/alx", @options).and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_atom_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom", @options).and_return(data)
    
    result = @feed_finder.feed("http://flickr.com/photos/alx")

    result.should be_a_kind_of(String)
    
    result.should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom"

  end
end

describe Rfeedfinder, "get feeds without options" do
  before(:each) do
    @options = {"From"=>"rfeedfinder@googlegroups.com", "User-Agent"=>"Ruby/#{RUBY_VERSION} - Rfeedfinder #{Rfeedfinder::VERSION::STRING}", "Referer"=>"http://rfeedfinder.rubyforge.org/", :proxy=>nil}
    @feed_finder = Rfeedfinder.new()
  end

  it "should default to default values for the open call" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpscriptingcom")
    Rfeedfinder.should_receive(:open).once.with("http://www.scripting.com", @options).and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_rss_feed")
    Rfeedfinder.should_receive(:open).once.with("http://www.scripting.com/rss.xml", @options).and_return(data)
    
    @feed_finder.feeds("www.scripting.com")
  end
end

describe Rfeedfinder, "should return data if requested" do
  before(:each) do
    @options_in = {:from => "from", :user_agent => "SpecialAgent", :referer =>"Else", :keep_data => true}
    @options = {"From"=>"from", "User-Agent"=>"SpecialAgent", :proxy=>nil, "Referer"=>"Else"}
    @feed_finder = Rfeedfinder.new(@options_in)
  end

  it "should return all feeds and their data" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpflickrcomphotosalx")
    Rfeedfinder.should_receive(:open).once.with("http://flickr.com/photos/alx", @options).and_return(data)

    data1 = File.read(File.dirname(__FILE__) + "/fixtures/some_atom_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom", @options).and_return(data1)
    
    data2 = File.read(File.dirname(__FILE__) + "/fixtures/some_rss_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=rss_200", @options).and_return(data2)

    result = @feed_finder.feeds("http://flickr.com/photos/alx")

    result.size.should == 2
    result.should be_a_kind_of(Array)
    result.first.should be_a_kind_of(Hash)
    
    result.first[:url].should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom"
    result.last[:url].should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=rss_200"

    result.first[:data].should == data1
    result.last[:data].should == data2
  end

  it "should return the first feed and its data" do
    data = File.read(File.dirname(__FILE__) + "/fixtures/httpflickrcomphotosalx")
    Rfeedfinder.should_receive(:open).once.with("http://flickr.com/photos/alx", @options).and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_atom_feed")
    Rfeedfinder.should_receive(:open).once.with("http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom", @options).and_return(data)
    
    result = @feed_finder.feed("http://flickr.com/photos/alx")

    result.should be_a_kind_of(Hash)
    
    result[:url].should == "http://api.flickr.com/services/feeds/photos_public.gne?id=36521964938@N01&lang=es-us&format=atom"
    
    result[:data].should == data
  end
  
end