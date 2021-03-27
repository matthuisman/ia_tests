import sys

import xbmcplugin, xbmcgui

handle = int(sys.argv[1])

url = 'https://raw.githubusercontent.com/matthuisman/ia_tests/master/mpd_renewal_url/token2/'

li = xbmcgui.ListItem()
li.setPath(url)

xbmcplugin.addDirectoryItem(handle, url, li, False)
xbmcplugin.endOfDirectory(handle, succeeded=True)