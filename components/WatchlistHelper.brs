' WatchlistHelper.brs

function getWatchlist() as Object
  sec = CreateObject("roRegistrySection", "SpamFilmsConfig")
  if sec.Exists("Watchlist")
    val = sec.Read("Watchlist")
    if val <> "" then
      json = ParseJson(val)
      if json <> invalid then return json
    end if
  end if
  return []
end function

sub saveWatchlist(list as Object)
  sec = CreateObject("roRegistrySection", "SpamFilmsConfig")
  jsonStr = FormatJson(list)
  sec.Write("Watchlist", jsonStr)
  sec.Flush()
end sub

function isInWatchlist(id as String) as Boolean
  list = getWatchlist()
  for each item in list
    if item.id = id then return true
  end for
  return false
end function

sub addToWatchlist(item as Object)
  list = getWatchlist()
  if not isInWatchlist(item.id)
    list.Push(item)
    saveWatchlist(list)
  end if
end sub

sub removeFromWatchlist(id as String)
  list = getWatchlist()
  newList = []
  for each item in list
    if item.id <> id then newList.Push(item)
  end for
  saveWatchlist(newList)
end sub
