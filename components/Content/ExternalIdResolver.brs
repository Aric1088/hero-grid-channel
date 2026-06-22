sub init()
  m.top.functionName = "resolveExternalId"
end sub

sub resolveExternalId()
  if m.top.tmdbId = invalid or m.top.tmdbId = ""
    m.top.hasError = true
    m.top.imdbId = ""
    return
  end if

  mediaType = m.top.mediaType
  if mediaType <> "movie" and mediaType <> "tv"
    m.top.hasError = true
    m.top.imdbId = ""
    return
  end if

  transfer = CreateObject("roUrlTransfer")
  url = "https://api.themoviedb.org/3/" + mediaType + "/" + m.top.tmdbId + "/external_ids"
  transfer.SetUrl(url)
  transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  transfer.InitClientCertificates()
  transfer.AddHeader("Authorization", "Bearer " + getTmdbToken())
  transfer.AddHeader("Content-Type", "application/json")
  transfer.AddHeader("Accept", "application/json")

  print "ExternalIdResolver: resolving " + mediaType + " TMDB " + m.top.tmdbId
  response = transfer.GetToString()
  if response = invalid or response = ""
    m.top.hasError = true
    m.top.imdbId = ""
    return
  end if

  data = ParseJson(response)
  if data = invalid or data.imdb_id = invalid or data.imdb_id = ""
    m.top.hasError = true
    m.top.imdbId = ""
    return
  end if

  print "ExternalIdResolver: resolved IMDb " + data.imdb_id
  m.top.imdbId = data.imdb_id
end sub
