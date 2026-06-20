sub init()
  m.top.functionName = "fetchDetails"
end sub

sub fetchDetails()
  imdbId = m.top.imdbId
  if imdbId = invalid or imdbId = "" then return

  print "SeriesDetailsFetcher: Fetching details for " + imdbId
  
  details = getSeriesDetails(imdbId)
  
  if details <> invalid
    if type(details) = "roAssociativeArray" and details.episodes <> invalid
      details = details.episodes
    end if
    
    ' Parse into ContentNode hierarchy (Seasons -> Episodes)
    rootContent = CreateObject("roSGNode", "ContentNode")
    
    ' Group by season
    seasons = {}
    
    for each ep in details
      seasonNum = 1
      if ep.season <> invalid then seasonNum = ep.season
      
      sKey = seasonNum.toStr()
      if seasons[sKey] = invalid
        seasons[sKey] = []
      end if
      
      seasons[sKey].Push(ep)
    end for
    
    for s = 1 to 50
      sKey = s.toStr()
      if seasons[sKey] <> invalid
        seasonDeps = seasons[sKey]
        seasonNum = s
        
        row = CreateObject("roSGNode", "ContentNode")
        row.Title = "Season " + sKey
        
        for each ep in seasonDeps
          epNode = CreateObject("roSGNode", "ContentNode")
          epNode.Title = ep.title
          if epNode.Title = invalid or epNode.Title = "" then epNode.Title = "Episode " + ep.episode.toStr()
          
          epNode.Description = ep.overview
          if ep.description <> invalid and ep.Description = invalid then epNode.Description = ep.description
          
          episodeNum = ep.episode
          if episodeNum = invalid then episodeNum = 1

          fields = {
             episodeNum: episodeNum,
             seasonNum: seasonNum,
             id: imdbId + ":" + seasonNum.toStr() + ":" + episodeNum.toStr(),
             episodeId: imdbId + ":" + seasonNum.toStr() + ":" + episodeNum.toStr(),
             imdbId: imdbId
          }
          if ep.runtime <> invalid then fields.runtime = ep.runtime
          if ep.firstAired <> invalid then fields.firstAired = ep.firstAired
          
          epNode.addFields(fields)
          
          if ep.thumbnail <> invalid
             epNode.HDPosterUrl = ep.thumbnail
          else if ep.images <> invalid and ep.images.screenshot <> invalid
             epNode.HDPosterUrl = ep.images.screenshot
          else if ep.images <> invalid and ep.images.poster <> invalid
             epNode.HDPosterUrl = ep.images.poster
          end if
          
          row.appendChild(epNode)
        end for
        
        rootContent.appendChild(row)
      end if
    end for
    
    m.top.content = rootContent
  else
    print "SeriesDetailsFetcher: No details found"
    m.top.content = CreateObject("roSGNode", "ContentNode") ' Ensure it triggers observer
  end if
end sub





