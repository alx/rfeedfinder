require 'test/unit'
require File.dirname(__FILE__) + '/../lib/rfeedfinder'

def feed_finder(host_url, feed_url = "")
  feed = Rfeedfinder.feed(host_url)
  puts "feed_finder: #{feed}"
  assert_not_nil feed
  assert_not_equal "", feed
  assert_equal(feed_url, feed) if feed_url != "" # test only if feed_url
  return feed
end