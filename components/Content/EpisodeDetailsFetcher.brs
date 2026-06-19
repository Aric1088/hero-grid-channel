sub init()
  m.top.functionName = "fetchDetails"
  print "EpisodeDetailsFetcher: Initialized"
end sub

sub fetchDetails()
  episodeId = m.top.episodeId
  if episodeId = invalid or episodeId = ""
    print "EpisodeDetailsFetcher: Missing episode ID"
    m.top.content = CreateObject("roSGNode", "ContentNode")
    return
  end if

  print "EpisodeDetailsFetcher: Fetching details for " + episodeId
  
  ut = CreateObject("roUrlTransfer")

  ' Parse composite ID format: "imdbId:season:episode"
  parts = episodeId.Split(":")
  if parts.count() >= 3
    imdbId = ut.Escape(parts[0])
    season = ut.Escape(parts[1])
    episode = ut.Escape(parts[2])
    url = resolveBackendPath("/v1/media/streams?imdb_id=" + imdbId + "&type=series&season=" + season + "&episode=" + episode)
  else
    ' Fallback: treat as plain IMDB ID
    url = resolveBackendPath("/v1/media/streams?imdb_id=" + ut.Escape(episodeId) + "&type=series")
  end if

  print "EpisodeDetailsFetcher: Request URL " + url
  
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(url)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()

  port = CreateObject("roMessagePort")
  urlTransfer.SetPort(port)

  if urlTransfer.AsyncGetToString()
    event = wait(30000, port)
    if type(event) = "roUrlEvent"
      responseCode = event.GetResponseCode()
      print "EpisodeDetailsFetcher: Response code " + responseCode.toStr()
      if responseCode = 200
        response = event.GetString()
        if response <> invalid and response <> ""
          json = ParseJson(response)
          if json <> invalid and GetInterface(json, "ifArray") <> invalid
            contentNode = CreateObject("roSGNode", "ContentNode")
            contentNode.addFields({
              torrents: json
            })
            m.top.content = contentNode
            return
          end if
        end if
      end if
    else
      print "EpisodeDetailsFetcher: Request timed out"
    end if
  end if
  
  print "EpisodeDetailsFetcher: No details found"
  m.top.content = CreateObject("roSGNode", "ContentNode")
end sub
