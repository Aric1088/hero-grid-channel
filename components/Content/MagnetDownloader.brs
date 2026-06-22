sub init()
  m.top.functionName = "downloadMagnet"
end sub

sub downloadMagnet()
  magnetUrl = m.top.magnetUrl
  if magnetUrl = invalid or magnetUrl = ""
    print "MagnetDownloader: No magnet URL provided"
    m.top.success = false
    return
  end if
  
  print "MagnetDownloader: Starting download for: " + magnetUrl
  
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(resolveBackendPath("/download-magnet"))
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  urlTransfer.SetRequest("POST")
  urlTransfer.AddHeader("Content-Type", "application/json")
  urlTransfer.AddHeader("Accept", "application/json")
  
  ' Build JSON body
  jsonBody = "{""magnet_uri"":" + FormatJson(magnetUrl)
  if m.top.fileIndex >= 0
    jsonBody = jsonBody + ",""file_index"":" + m.top.fileIndex.toStr()
  end if
  if m.top.fileName <> invalid and m.top.fileName <> ""
    jsonBody = jsonBody + ",""file"":" + FormatJson(m.top.fileName)
  end if
  if m.top.mediaType <> invalid and m.top.mediaType <> ""
    jsonBody = jsonBody + ",""media_type"":" + FormatJson(m.top.mediaType)
  end if
  jsonBody = jsonBody + "}"
  
  ' Use synchronous POST (OK in Task thread)
  responseCode = urlTransfer.PostFromString(jsonBody)
  m.top.responseCode = responseCode
  if responseCode >= 200 and responseCode < 300
    print "MagnetDownloader: Request sent successfully, response code: " + responseCode.toStr()
    if m.top.streamUrl <> invalid and m.top.streamUrl <> ""
      m.top.success = waitForStream(m.top.streamUrl)
    else
      m.top.success = true
    end if
  else
    print "MagnetDownloader: Failed to send request, response code: " + responseCode.toStr()
    m.top.success = false
  end if
end sub

function waitForStream(streamUrl as string) as boolean
  print "MagnetDownloader: Waiting for stream playlist " + streamUrl

  ' Keep the Roku interaction responsive. Stream preparation gets at most
  ' five short readiness checks before returning control to the user.
  for attempt = 1 to 5
    port = CreateObject("roMessagePort")
    streamRequest = CreateObject("roUrlTransfer")
    streamRequest.SetUrl(streamUrl)
    streamRequest.SetCertificatesFile("common:/certs/ca-bundle.crt")
    streamRequest.InitClientCertificates()
    streamRequest.SetPort(port)

    if streamRequest.AsyncGetToString()
      event = wait(700, port)
      if type(event) = "roUrlEvent"
        responseCode = event.GetResponseCode()
        print "MagnetDownloader: Stream readiness response " + responseCode.toStr()
        if responseCode = 200
          playlist = event.GetString()
          if playlist <> invalid and Left(playlist, 7) = "#EXTM3U" and mediaPlaylistReady(streamUrl)
            print "MagnetDownloader: Stream media playlist is ready"
            return true
          end if
        end if
      end if
    end if

    sleep(200)
  end for

  print "MagnetDownloader: Stream playlist did not become ready"
  return false
end function

function mediaPlaylistReady(masterUrl as string) as boolean
  marker = InStr(1, masterUrl, "master.m3u8")
  if marker = 0 then return true

  mediaUrl = Left(masterUrl, marker - 1) + "v0.m3u8"
  port = CreateObject("roMessagePort")
  request = CreateObject("roUrlTransfer")
  request.SetUrl(mediaUrl)
  request.SetCertificatesFile("common:/certs/ca-bundle.crt")
  request.InitClientCertificates()
  request.SetPort(port)
  if not request.AsyncGetToString() then return false

  event = wait(900, port)
  if type(event) <> "roUrlEvent" then return false
  if event.GetResponseCode() <> 200 then return false

  response = event.GetString()
  return response <> invalid and InStr(1, response, "#EXTINF:") > 0
end function
