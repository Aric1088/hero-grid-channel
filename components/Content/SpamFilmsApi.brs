' SpamFilms API - BrightScript port of the React app's API layer
' Fetches movies/series from fusme.link or uxert.link via the Go backend's /proxy endpoint

' Get random base URL (fusme.link or uxert.link)
function getRandomBaseUrl() as string
  baseUrls = ["https://fusme.link", "https://uxert.link"]
  randomIndex = Rnd(baseUrls.count()) - 1
  return baseUrls[randomIndex]
end function

' Fetch movies list from SpamFilms API
' @param options AA with: page, limit, sort, genre, keywords
' @returns Array of movie objects
function getMovies(options = {} as object) as object
  ' Default options
  if options.limit = invalid then options.limit = 20
  if options.page = invalid then options.page = 1
  if options.sort = invalid then options.sort = "trending"
  if options.genre = invalid then options.genre = "All"
  if options.keywords = invalid then options.keywords = ""
  
  ' Pick random backend
  randomBaseUrl = getRandomBaseUrl()
  targetUrl = randomBaseUrl + "/movies/" + options.page.toStr()
  
  ' Build query params
  queryParams = "?limit=" + options.limit.toStr()
  queryParams = queryParams + "&sort=" + options.sort
  queryParams = queryParams + "&local=en&contentLocale=en&showAll=1"
  queryParams = queryParams + "&genre=" + options.genre
  queryParams = queryParams + "&order=-1"
  if options.keywords <> "" then
    queryParams = queryParams + "&keywords=" + options.keywords
  end if
  
  fullUrl = targetUrl + queryParams
  proxiedUrl = withBackendProxy(fullUrl)
  
  print "Fetching movies from: " + proxiedUrl
  
  ' Make HTTP request
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(proxiedUrl)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  
  response = urlTransfer.GetToString()
  if response <> invalid and response <> "" then
    json = ParseJson(response)
    if json <> invalid and GetInterface(json, "ifArray") <> invalid then
      return json
    end if
  end if
  
  return []
end function

' Fetch series list from SpamFilms API
function getSeries(options = {} as object) as object
  ' Default options
  if options.limit = invalid then options.limit = 20
  if options.page = invalid then options.page = 1
  if options.sort = invalid then options.sort = "trending"
  if options.genre = invalid then options.genre = "All"
  if options.keywords = invalid then options.keywords = ""
  
  ' Pick random backend
  randomBaseUrl = getRandomBaseUrl()
  targetUrl = randomBaseUrl + "/shows/" + options.page.toStr()
  
  ' Build query params
  queryParams = "?limit=" + options.limit.toStr()
  queryParams = queryParams + "&sort=" + options.sort
  queryParams = queryParams + "&local=en&contentLocale=en&showAll=0"
  queryParams = queryParams + "&genre=" + options.genre
  queryParams = queryParams + "&order=-1"
  if options.keywords <> "" then
    queryParams = queryParams + "&keywords=" + options.keywords
  end if
  
  fullUrl = targetUrl + queryParams
  proxiedUrl = withBackendProxy(fullUrl)
  
  print "Fetching series from: " + proxiedUrl
  
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(proxiedUrl)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  
  response = urlTransfer.GetToString()
  if response <> invalid and response <> "" then
    json = ParseJson(response)
    if json <> invalid and GetInterface(json, "ifArray") <> invalid then
      return json
    end if
  end if
  
  return []
end function

' Get IMDb rating for a movie/series
function getIMDbRating(imdbId as string) as object
  url = withBackendProxy("https://api.imdbapi.dev/titles/" + imdbId)
  
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(url)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  
  response = urlTransfer.GetToString()
  if response <> invalid and response <> "" then
    json = ParseJson(response)
    if json <> invalid and json.rating <> invalid and json.rating.aggregateRating <> invalid then
      return {
        rating: json.rating.aggregateRating
      }
    end if
  end if
  
  return { rating: invalid }
end function

' Get movie details with torrents from backend streams
function getMovieDetails(imdbId as string) as object
  url = resolveBackendPath("/v1/media/streams?imdb_id=" + imdbId + "&type=movie")
  
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(url)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  
  response = urlTransfer.GetToString()
  if response <> invalid and response <> "" then
    json = ParseJson(response)
    if json <> invalid then
      return { torrents: json }
    end if
  end if
  
  return invalid
end function

' Fetch series details (episodes) from SpamFilms API
' Matches React getSeriesDetails()
function getSeriesDetails(imdbId as string) as object
    allEpisodes = []
    tmdbToken = getTmdbToken()
    tmdbId = ""
    numSeasons = 1
    
    ' Fetch TMDB ID using external ID
    findUrl = withBackendProxy("https://api.themoviedb.org/3/find/" + imdbId + "?external_source=imdb_id")
    reqFind = CreateObject("roUrlTransfer")
    reqFind.SetUrl(findUrl)
    reqFind.SetCertificatesFile("common:/certs/ca-bundle.crt")
    reqFind.InitClientCertificates()
    reqFind.AddHeader("Authorization", "Bearer " + tmdbToken)
    reqFind.AddHeader("Accept", "application/json")
    
    fResp = reqFind.GetToString()
    if fResp <> invalid and fResp <> "" then
        fJson = ParseJson(fResp)
        if fJson <> invalid and fJson.tv_results <> invalid and fJson.tv_results.count() > 0 then
            tmdbId = fJson.tv_results[0].id.toStr()
        end if
    end if
    
    if tmdbId = "" then return invalid
    
    ' Fetch TV details to get number of seasons
    tvUrl = withBackendProxy("https://api.themoviedb.org/3/tv/" + tmdbId)
    reqTv = CreateObject("roUrlTransfer")
    reqTv.SetUrl(tvUrl)
    reqTv.SetCertificatesFile("common:/certs/ca-bundle.crt")
    reqTv.InitClientCertificates()
    reqTv.AddHeader("Authorization", "Bearer " + tmdbToken)
    reqTv.AddHeader("Accept", "application/json")
    
    tvResp = reqTv.GetToString()
    if tvResp <> invalid and tvResp <> "" then
        tvJson = ParseJson(tvResp)
        if tvJson <> invalid and tvJson.number_of_seasons <> invalid then
            numSeasons = tvJson.number_of_seasons
        end if
    end if
    
    ' Fetch each season from TMDB natively
    for s = 1 to numSeasons
      seasonUrl = withBackendProxy("https://api.themoviedb.org/3/tv/" + tmdbId + "/season/" + s.toStr())
      req = CreateObject("roUrlTransfer")
      req.SetUrl(seasonUrl)
      req.SetCertificatesFile("common:/certs/ca-bundle.crt")
      req.InitClientCertificates()
      req.AddHeader("Authorization", "Bearer " + tmdbToken)
      req.AddHeader("Accept", "application/json")
      
      sResp = req.GetToString()
      if sResp <> invalid and sResp <> "" then
        sJson = ParseJson(sResp)
        if sJson <> invalid and sJson.episodes <> invalid then
          for each ep in sJson.episodes
             epMap = {
               title: ep.name,
               season: ep.season_number,
               episode: ep.episode_number,
               overview: ep.overview,
               runtime: ep.runtime,
               id: imdbId + ":" + ep.season_number.toStr() + ":" + ep.episode_number.toStr()
             }
             if ep.still_path <> invalid and ep.still_path <> "" then
               epMap.thumbnail = "https://image.tmdb.org/t/p/w780" + ep.still_path
             end if
             allEpisodes.Push(epMap)
          end for
        end if
      end if
    end for
    
    return allEpisodes
end function







