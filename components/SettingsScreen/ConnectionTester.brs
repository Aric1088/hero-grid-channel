sub init()
  m.top.functionName = "testConnection"
end sub

sub testConnection()
  serverUrl = m.top.serverUrl
  if serverUrl = invalid or serverUrl = ""
    m.top.result = "failure"
    return
  end if
  
  testUrl = serverUrl + "/healthz"
  print "ConnectionTester: Testing URL: " + testUrl
  
  port = CreateObject("roMessagePort")
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(testUrl)
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  urlTransfer.SetPort(port)
  
  if urlTransfer.AsyncGetToString()
    event = wait(5000, port) ' 5 second timeout
    if type(event) = "roUrlEvent"
      responseCode = event.GetResponseCode()
      print "ConnectionTester: Response Code: " + responseCode.toStr()
      
      if responseCode = 200
        response = event.GetString()
        json = ParseJson(response)
        if json <> invalid and json.ok <> invalid
          print "ConnectionTester: Successful connection to SpamFilms backend!"
          m.top.result = "success"
          return
        else
          ' Fallback: if it's 200 but not standard JSON (e.g., standard HTTP root or similar), still count it as alive
          m.top.result = "success"
          return
        end if
      end if
    end if
  end if
  
  print "ConnectionTester: Connection failed"
  m.top.result = "failure"
end sub
