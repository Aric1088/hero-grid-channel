sub init()
  m.top.functionName = "fetchMetadata"
end sub

sub fetchMetadata()
  resultRoot = CreateObject("roSGNode", "ContentNode")
  resultRow = resultRoot.createChild("ContentNode")

  query = m.top.query
  contentType = m.top.contentType
  if query = invalid or query = ""
    m.top.content = resultRoot
    return
  end if

  endpointType = "movie"
  rowTitle = "Movies"
  rokuType = "movies"
  if contentType = "series"
    endpointType = "tv"
    rowTitle = "TV Shows"
    rokuType = "series"
  end if
  resultRow.title = rowTitle

  transfer = CreateObject("roUrlTransfer")
  url = "https://api.themoviedb.org/3/search/" + endpointType
  url = url + "?query=" + transfer.Escape(query) + "&page=1"
  transfer.SetUrl(url)
  transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  transfer.InitClientCertificates()
  transfer.AddHeader("Authorization", "Bearer " + getTmdbToken())
  transfer.AddHeader("Content-Type", "application/json")
  transfer.AddHeader("Accept", "application/json")

  print "MetadataSearchFetcher: " + endpointType + " query [" + query + "]"
  response = transfer.GetToString()
  if response = invalid or response = ""
    m.top.hasError = true
    m.top.errorMessage = "Metadata search returned no response."
    m.top.content = resultRoot
    return
  end if

  data = ParseJson(response)
  if data = invalid or data.results = invalid or GetInterface(data.results, "ifArray") = invalid
    m.top.hasError = true
    m.top.errorMessage = "Metadata search returned an invalid response."
    m.top.content = resultRoot
    return
  end if

  resultLimit = data.results.count()
  if resultLimit > 15 then resultLimit = 15

  if resultLimit > 0
    for index = 0 to resultLimit - 1
      item = data.results[index]
      node = resultRow.createChild("ContentNode")

      title = item.title
      if contentType = "series" then title = item.name
      if title = invalid or title = "" then title = "Untitled"

      node.id = item.id.toStr()
      node.title = title
      if item.overview <> invalid and item.overview <> ""
        node.description = item.overview
      else
        node.description = "No description available"
      end if

      poster = ""
      if item.poster_path <> invalid and item.poster_path <> ""
        poster = "https://image.tmdb.org/t/p/w342" + item.poster_path
      end if
      backdrop = poster
      if item.backdrop_path <> invalid and item.backdrop_path <> ""
        backdrop = "https://image.tmdb.org/t/p/w1280" + item.backdrop_path
      end if
      if poster <> "" then node.hdPosterUrl = poster
      if backdrop <> "" then node.hdBackgroundImageUrl = backdrop

      year = 0
      dateValue = item.release_date
      if contentType = "series" then dateValue = item.first_air_date
      if dateValue <> invalid and Len(dateValue) >= 4
        year = Val(Left(dateValue, 4))
      end if

      node.addFields({
        cType: rokuType,
        tmdbId: item.id.toStr(),
        tmdbType: endpointType,
        imdbId: "",
        year: year,
        needsEnrichment: true,
        hasTorrents: "false",
        selectedQuality: ""
      })
      node.url = ""
      node.streamFormat = "hls"
      print "MetadataSearchFetcher: result " + index.toStr() + " id=" + item.id.toStr() + " title=" + title
    end for
  end if

  print "MetadataSearchFetcher: returned " + resultRow.getChildCount().toStr() + " " + endpointType + " results"
  m.top.content = resultRoot
end sub
