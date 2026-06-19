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
  jsonBody = "{""magnet_uri"":""" + magnetUrl + """}"
  
  ' Use synchronous POST (OK in Task thread)
  responseCode = urlTransfer.PostFromString(jsonBody)
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
          if playlist <> invalid and Left(playlist, 7) = "#EXTM3U"
            print "MagnetDownloader: Stream playlist is ready"
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
