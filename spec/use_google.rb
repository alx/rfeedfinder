require File.dirname(__FILE__) + "/spec_helper"

describe Rfeedfinder, ":use_google => true" do
  before(:each) do
    @options = {"From"=>"rfeedfinder@googlegroups.com", "User-Agent"=>"Ruby/#{RUBY_VERSION} - Rfeedfinder #{Rfeedfinder::VERSION::STRING}", "Referer"=>"http://rfeedfinder.rubyforge.org/", :proxy=>nil}
  end

  it "should raise an ArgumentError if you don't use a valid URL and don't use google" do
    lambda { Rfeedfinder.feeds("ThisIsWrong") }.should raise_error(ArgumentError)
    lambda { Rfeedfinder.feeds("This is also wrong") }.should raise_error(ArgumentError)
    lambda { Rfeedfinder.feeds("This.is.wrong") }.should raise_error(ArgumentError)
    lambda { Rfeedfinder.feeds("Sebastian Probst Eides blog") }.should raise_error(ArgumentError)
  end

  it "should get the site from google if that is spesified" do
    response = GoogleResponseClass.new("http://www.scripting.com")
    Net::HTTP.should_receive(:get_response).
      with(URI.parse("http://www.google.com/search?q=HAHA&btnI=I'm+Feeling+Lucky")).
      and_return(response)

    data = File.read(File.dirname(__FILE__) + "/fixtures/httpscriptingcom")
    Rfeedfinder.should_receive(:open).once.
      with("http://www.scripting.com", @options).
      and_return(data)

    data = File.read(File.dirname(__FILE__) + "/fixtures/some_rss_feed")
    Rfeedfinder.should_receive(:open).once.with("http://www.scripting.com/rss.xml", @options).and_return(data)

    result = Rfeedfinder.feed("HAHA", {:use_google => true})
    # result.should == "http://www.scripting.com/rss.xml"
  end

end

class GoogleResponseClass
  def initialize(val)
    @val = val
  end
  def to_hash
    {'location' => [@val]}
  end
end