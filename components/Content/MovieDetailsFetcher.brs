sub init()
  m.top.functionName = "fetchDetails"
end sub

sub fetchDetails()
  imdbId = m.top.imdbId
  if imdbId = invalid or imdbId = "" return

  print "MovieDetailsFetcher: Fetching details for " + imdbId
  
  details = getMovieDetails(imdbId)
  
  if details <> invalid
    contentNode = CreateObject("roSGNode", "ContentNode")
    contentNode.addFields({
      details: details
    })
    m.top.content = contentNode
  else
    print "MovieDetailsFetcher: No details found"
  end if
end sub
