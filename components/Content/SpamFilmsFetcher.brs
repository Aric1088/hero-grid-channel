' SpamFilms Content Fetcher Task
' Runs on separate thread to fetch and parse content from SpamFilms API

sub init()
  m.top.functionName = "fetchContent"
end sub

' Extract torrent hash from magnet URL
function extractTorrentHash(magnetUrl as string) as string
  ' Extract hash from magnet URL pattern: xt=urn:btih:{hash}
  regex = CreateObject("roRegex", "xt=urn:btih:([A-Fa-f0-9]{40}|[A-Za-z2-7]{32})", "i")
  match = regex.Match(magnetUrl)
  if match.count() > 1
    return match[1]
  end if
  return ""
end function

' Main task function - fetches content from SpamFilms API
sub fetchContent()
  print "===== SpamFilmsFetcher: Starting fetch for " + m.top.contentType + " ====="
  print "Page: " + m.top.page.toStr() + ", Sort: " + m.top.sort + ", Genre: " + m.top.genre

  ' Build options
  options = {
    page: m.top.page,
    sort: m.top.sort,
    genre: m.top.genre,
    keywords: m.top.keywords,
    limit: 20
  }

  ' Fetch data based on content type
  items = []
  if m.top.contentType = "movies"
    items = getMovies(options)
  else if m.top.contentType = "series"
    items = getSeries(options)
  end if

  if items = invalid or GetInterface(items, "ifArray") = invalid
    print "SpamFilmsFetcher: API returned invalid content; treating as empty."
    items = []
  end if

  print "===== SpamFilmsFetcher: Received " + items.count().toStr() + " items ====="

  if items.count() = 0 then
    print "SpamFilmsFetcher: No items received (or search empty)."
    ' Return empty node to signal completion so observers fire
    emptyNode = createObject("roSGNode", "ContentNode")
    m.top.content = emptyNode
    return
  end if

  ' Parse items into ContentNode structure
  parent = createObject("roSGNode", "ContentNode")
  row = createObject("roSGNode", "ContentNode")

  if m.top.contentType = "movies"
    row.Title = "SpamFilms Movies"
  else
    row.Title = "SpamFilms Series"
  end if

  for each item in items
    contentNode = createObject("roSGNode", "ContentNode")
    
          if item._id <> invalid then contentNode.id = item._id
      if item.title <> invalid then 
        contentNode.title = item.title
      else if item.name <> invalid then 
        contentNode.title = item.name
      end if
      if m.top.contentType <> invalid then contentNode.addFields({ cType: m.top.contentType })

    if item.synopsis <> invalid then
      contentNode.description = item.synopsis
    else if item.description <> invalid then
      contentNode.description = item.description
    else
      contentNode.description = "No description available"
    end if

    if item.images <> invalid
      if item.images.poster <> invalid
        posterUrl = item.images.poster
        if Left(posterUrl, 7) = "http://"
          posterUrl = "https://" + Mid(posterUrl, 8)
        end if
        contentNode.hdPosterUrl = posterUrl
        contentNode.hdBackgroundImageUrl = posterUrl
      end if
      if item.images.fanart <> invalid
        fanartUrl = item.images.fanart
        if Left(fanartUrl, 7) = "http://"
          fanartUrl = "https://" + Mid(fanartUrl, 8)
        end if
        contentNode.hdBackgroundImageUrl = fanartUrl
      end if
    end if

    ' Parse embedded torrents from backend
    customFields = {}
    if item.imdb_id <> invalid then customFields.imdbId = item.imdb_id
    if item.year <> invalid then customFields.year = item.year
    
    hasTorrents = false
    if item.torrents <> invalid and item.torrents.en <> invalid
      qualities = ["1080p", "2160p", "720p"]
      for each quality in qualities
        if item.torrents.en[quality] <> invalid
          t = item.torrents.en[quality]
          hash = extractTorrentHash(t.url)
          if hash <> ""
            customFields["torrent" + quality + "Hash"] = hash
            customFields["torrent" + quality + "Magnet"] = t.url
            if t.seed <> invalid then customFields["torrent" + quality + "Seeds"] = t.seed.toStr()
            hasTorrents = true
            
            if customFields.magnetUrl = invalid or customFields.magnetUrl = "" or quality = "2160p"
              customFields.magnetUrl = t.url
              customFields.torrentHash = hash
              customFields.selectedQuality = quality
            end if
          end if
        end if
      end for
    end if
    
    if hasTorrents
      customFields.needsEnrichment = false
      customFields.hasTorrents = "true"
    else
      customFields.magnetUrl = ""
      customFields.torrentHash = ""
      customFields.needsEnrichment = true
      customFields.hasTorrents = "false"
      customFields.selectedQuality = ""
    end if
    
    contentNode.addFields(customFields)
    
    ' Built-ins
    if customFields.torrentHash <> invalid and customFields.torrentHash <> ""
      contentNode.url = resolveBackendPath("/v1/stream/" + customFields.torrentHash + "/master.m3u8")
    else
      contentNode.url = ""
    end if
    contentNode.streamformat = "hls"

    row.appendChild(contentNode)
  end for
  
  print "SpamFilmsFetcher: Finished populating " + row.getChildCount().toStr() + " items."
  parent.appendChild(row)
  m.top.content = parent
  print "SpamFilmsFetcher: Requesting " + items.count().toStr() + " items - showing grid immediately"
end sub

function getApiBaseUrl() as string
  return getBackendUrl() + "/v1/catalog"
end function

function getMovies(options as object) as object
  apiBaseUrl = getApiBaseUrl()
  targetUrl = apiBaseUrl + "/movies/" + options.page.toStr()

  queryParams = "?limit=" + options.limit.toStr()
  queryParams = queryParams + "&sort=" + options.sort
  queryParams = queryParams + "&local=en&contentLocale=en&showAll=1"
  queryParams = queryParams + "&genre=" + options.genre
  queryParams = queryParams + "&order=-1"
  if options.keywords <> ""
    ut = CreateObject("roUrlTransfer")
    queryParams = queryParams + "&keywords=" + ut.Escape(options.keywords)
  end if

  fullUrl = targetUrl + queryParams
  proxiedUrl = fullUrl

  print "Fetching movies from: " + proxiedUrl

  port = CreateObject("roMessagePort")
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(proxiedUrl)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  urlTransfer.SetPort(port)

  if urlTransfer.AsyncGetToString()
    event = wait(30000, port)
    if type(event) = "roUrlEvent"
      responseCode = event.GetResponseCode()
      print "Movie fetch response code: " + responseCode.toStr()
      if responseCode = 200
        response = event.GetString()
        if response <> invalid and response <> ""
          json = ParseJson(response)
          if json <> invalid and GetInterface(json, "ifArray") <> invalid
            print "Successfully parsed " + json.count().toStr() + " movies"
            return json
          else
            print "Failed to parse JSON or not an array"
          end if
        else
          print "Empty response"
        end if
      else
        print "HTTP error: " + responseCode.toStr()
      end if
    else
      print "Timeout or invalid event"
    end if
  end if
  return invalid
end function

function getSeries(options as object) as object
  apiBaseUrl = getApiBaseUrl()
  targetUrl = apiBaseUrl + "/shows/" + options.page.toStr()

  queryParams = "?limit=" + options.limit.toStr()
  queryParams = queryParams + "&sort=" + options.sort
  queryParams = queryParams + "&local=en&contentLocale=en&showAll=0"
  queryParams = queryParams + "&genre=" + options.genre
  queryParams = queryParams + "&order=-1"
  if options.keywords <> ""
    ut = CreateObject("roUrlTransfer")
    queryParams = queryParams + "&keywords=" + ut.Escape(options.keywords)
  end if

  fullUrl = targetUrl + queryParams
  proxiedUrl = fullUrl

  print "Fetching series from: " + proxiedUrl

  port = CreateObject("roMessagePort")
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(proxiedUrl)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  urlTransfer.SetPort(port)

  if urlTransfer.AsyncGetToString()
    event = wait(30000, port)
    if type(event) = "roUrlEvent"
      responseCode = event.GetResponseCode()
      print "Series fetch response code: " + responseCode.toStr()
      if responseCode = 200
        response = event.GetString()
        if response <> invalid and response <> ""
          json = ParseJson(response)
          if json <> invalid and GetInterface(json, "ifArray") <> invalid
            print "Successfully parsed " + json.count().toStr() + " series"
            return json
          else
            print "Failed to parse JSON or not an array"
          end if
        else
          print "Empty response"
        end if
      else
        print "HTTP error: " + responseCode.toStr()
      end if
    else
      print "Timeout or invalid event"
    end if
  end if
  return invalid
end function




