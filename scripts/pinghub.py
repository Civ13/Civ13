import urllib2
import time
import threading

while True:
	urllib2.urlopen("http://mechahitler.co.nf/servers.php").read()
	time.sleep(10) # We may take up to this long to recreate the page, don't try to recreate it twice at once!

