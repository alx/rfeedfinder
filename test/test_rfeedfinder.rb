require File.dirname(__FILE__) + '/test_helper.rb'

class TestRfeedfinder < Test::Unit::TestCase

  def setup
  end
  
  def test_feed
    feed_finder "http://scripting.com",
               "http://www.scripting.com/rss.xml"
  end
  
  def test_feeds
    feeds = Rfeedfinder.feeds("http://flickr.com/photos/alx")
    assert_equal 2, feeds.size 
  end
  
  def test_could_be_feed
    feed_finder "http://blog.alexgirard.com/feed/",
               "http://blog.alexgirard.com/feed/"
  end
  
  def test_jumpcut_alias
    feed_finder "http://www.jumpcut.com/cursonsongvideo",
                "http://rss.jumpcut.com/rss/user?u_id=17C65AB8A6EF11DBBE093EF340157CF2"
  end
  
  def test_jumpcut_home
    feed_finder "http://www.jumpcut.com/myhome/?u_id=DB9EC418FDAF11DB8198000423CEF5F6",
               "http://rss.jumpcut.com/rss/user?u_id=db9ec418fdaf11db8198000423cef5f6"
  end
  
  def test_jumpcut_rss
    feed_finder "http://rss.jumpcut.com/rss/user?u_id=db9ec418fdaf11db8198000423cef5f6",
               "http://rss.jumpcut.com/rss/user?u_id=db9ec418fdaf11db8198000423cef5f6"
  end
  
  def test_random_blogspot
    feed_finder "http://organizandolaesperanza.blogspot.com"
    feed_finder "http://skblackburn.blogspot.com/"
    feed_finder "http://nadapersonal.blogspot.com"
    feed_finder "http://diariodeunadislexica.blogspot.com/"
    feed_finder "http://diputadodelosverdes.blogspot.com/"
    feed_finder "http://cinclin.blogspot.com/"
    feed_finder "http://claudiaramos.blogspot.com/"
  end
  
  def test_el_pais
    feed_finder "http://lacomunidad.elpais.com/krismontesinos/"
    feed_finder "http://lacomunidad.elpais.com/krismontesinos/posts"
    feed_finder "http://lacomunidad.elpais.com/krismontesinos"
  end
  
  def test_from_feevy
    feed_finder "http://www.becker-posner-blog.com/index.rdf"
    feed_finder "http://www.slashdot.com", "http://rss.slashdot.org/Slashdot/slashdot"
    feed_finder "http://planeta.lamatriz.org", "http://planeta.lamatriz.org/feed/"
    feed_finder "http://edubloggers.blogspot.com/"
    feed_finder "http://www.deugarte.com/", "http://www.deugarte.com/feed/"
    feed_finder "http://www.twitter.com/alx/"
    feed_finder "http://alemama.blogspot.com"
    feed_finder "http://seedmagazine.com/news/atom-focus.xml"
    feed_finder "http://bitacora.feevy.com"
    feed_finder "http://www.enriquemeneses.com/"
    feed_finder "http://ianasagasti.blogs.com/"
    feed_finder "http://www.ecoperiodico.com/"
    feed_finder "http://bloc.balearweb.net/rss.php?summary=1"
    feed_finder "http://www.antoniobezanilla.com/"
    feed_finder "http://www.joselopezorozco.com/"
    feed_finder "http://minijoan.vox.com/"
    feed_finder "http://www.dosdedosdefrente.com/blog/"
    feed_finder "http://www.deugarte.com/blog/fabbing/feed"
    feed_finder "http://www.papelenblanco.com/autor/sergio-fernandez/rss2.xml"
    feed_finder "http://sombra.lamatriz.org/"
    feed_finder "http://tristezza0.spaces.live.com/", "http://tristezza0.spaces.live.com/feed.rss"
    feed_finder "http://lacoctelera.com/macadamia"
    feed_finder "http://www.liberation.fr"
    feed_finder "http://juxtaprose.com/posts/good-web-20-critique/feed/"
    feed_finder "http://www.gara.net/rss/kultura"
    feed_finder "http://davicius.wordpress.com/feed/"
    feed_finder "http://www.cato-at-liberty.org/wp-rss.php" 
    feed_finder "http://creando.bligoo.com/"
    feed_finder "http://svn.37signals.com/", "http://feeds.feedburner.com/37signals/beMH"
    feed_finder "http://www.takingitglobal.org/connections/tigblogs/feed.rss?UserID=251"
    feed_finder "http://www.rubendomfer.com/blog/"
    feed_finder "http://www.arfues.net/weblog/"
    feed_finder "http://www.lkstro.com/"
    feed_finder "http://www.lorenabetta.info"
    feed_finder "http://www.adesalambrar.info/"
    feed_finder "http://www.bufetalmeida.com/rss.xml"
    feed_finder "http://dreams.draxus.org/"
    feed_finder "http://mephisto.sobrerailes.com/"
  end
  
  def test_fotolog
    feed_finder "http://www.fotolog.com/darth_fonsu/"
    feed_finder "http://www0.fotolog.com/darth_fonsu/feed/main/rss20"
    feed_finder "http://www1.fotolog.com/mad_lux", "http://www0.fotolog.com/mad_lux/feed/main/rss20"
    feed_finder "http://www1.fotolog.com/kel_06/"
  end
  
  def test_google_video
    feed_finder "http://video.google.com/videosearch?hl=en&safe=off&q=the+office"
  end
  
  def test_blogsome
    feed_finder "http://voxd.blogsome.com/"
  end
  
  def test_youtube
    feed_finder "http://www.youtube.com/user/nocommenttv"
  end
  
  def test_google_news
    feed_finder "http://news.google.com/news?hl=en&ned=us&q=olpc&btnG=Search+News"
  end
  
  def test_not_fulluri_link
    # Meta link is only giving /feed/atom.xml
    feed_finder "http://blog.zvents.com/", "http://blog.zvents.com/feed/atom.xml"
  end
  
  def test_412_error
    feed_finder "http://www.arteleku.net/4.1/blog/laburrak/?feed=rss2", "http://www.arteleku.net/4.1/blog/laburrak/?feed=rss2"
  end
  
  def test_unrecognized_feed
    feed_finder "http://www.gobmenorca.com/noticies/RSS"
  end
  
  def test_maria
    #feed_finder "http://www.carmenfernandez.net"
    #feed_finder "http://getxogorria.blogcindario.com"
    #feed_finder "http://jeanpaulmarat.blogspot.com"
    #feed_finder "http://resistiendocavernablogcindario.com"
    # feed = feed_finder "http://enredadera.bbvablogs.com/"
    # feed = feed_finder "http://arfues.net/weblog"
    feed = feed_finder "http://elsantacrucenio.com/index.php?option=com_rss&amp;feed=RSS0.91&amp;no_html=1"
  end
  
  def test_bbva
    feed_finder "http://prueba.bbvablogs.com/feed/"
  end
  
  def test_nytimes
    feed_finder "http://www.nytimes.com/services/xml/rss/nyt/HomePage.xml"
  end
end
