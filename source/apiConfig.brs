' SpamFilms API Configuration Utility

function getBackendUrl() as string
  defaultUrl = "https://spamfilms.ddns.net:8080"
  sec = CreateObject("roRegistrySection", "SpamFilmsConfig")
  savedUrl = sec.Read("BackendUrl")
  if savedUrl <> invalid and savedUrl <> ""
    return savedUrl
  end if

  return defaultUrl
end function

function getTmdbToken() as string
  return "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MDJlZjU1M2VhMTY3NTAxOWUwOWZiNzA2OWM3MWJlZiIsIm5iZiI6MTcxOTY5NDY1NS41MjQsInN1YiI6IjY2ODA3NTNmMGY1MDdlYTYzZWYxN2FlYSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.s5v3eMTFg2nTeBWGkthAhbh9gdu9xTv1zmWQxQ6_AkQ"
end function

sub saveBackendUrl(url as string)
  sec = CreateObject("roRegistrySection", "SpamFilmsConfig")
  sec.Write("BackendUrl", url)
  sec.Flush()
  print "Saved new Backend URL to registry: " + url
end sub

function resolveBackendPath(path as string) as string
  baseUrl = getBackendUrl()
  if Right(baseUrl, 1) = "/" and Left(path, 1) = "/"
    return baseUrl + Mid(path, 2)
  else if Right(baseUrl, 1) <> "/" and Left(path, 1) <> "/"
    return baseUrl + "/" + path
  end if
  return baseUrl + path
end function

function withBackendProxy(targetUrl as string) as string
  ut = CreateObject("roUrlTransfer")
  escapedUrl = ut.Escape(targetUrl)
  return resolveBackendPath("/proxy?url=" + escapedUrl)
end function
