sub init()
  m.keyboard = m.top.findNode("keyboard")
  m.saveButton = m.top.findNode("saveButton")
  m.resetButton = m.top.findNode("resetButton")
  m.currentUrlLabel = m.top.findNode("currentUrlLabel")
  m.statusLabel = m.top.findNode("statusLabel")
  
  m.saveButton.observeField("buttonSelected", "onSave")
  m.resetButton.observeField("buttonSelected", "onReset")
  
  ' Set initial values
  resetDisplay()
  
  ' Focus on Save button first
  m.saveButton.setFocus(true)
end sub

sub resetDisplay()
  activeUrl = getBackendUrl()
  m.currentUrlLabel.text = "Active Server: " + activeUrl
  m.keyboard.text = activeUrl
  m.statusLabel.text = ""
  m.statusLabel.color = "0xAAAAAAFF"
end sub

sub onSave()
  newUrl = m.keyboard.text
  
  ' Clean input (remove trailing slash)
  if Right(newUrl, 1) = "/" then newUrl = Left(newUrl, Len(newUrl) - 1)
  
  ' Clean input (prepend http:// if missing)
  if Left(newUrl, 7) <> "http://" and Left(newUrl, 8) <> "https://"
    newUrl = "http://" + newUrl
  end if
  
  m.statusLabel.text = "Testing connection to " + newUrl + "..."
  m.statusLabel.color = "0xFFFF00FF" ' Yellow
  
  ' Save value immediately
  saveBackendUrl(newUrl)
  m.currentUrlLabel.text = "Active Server: " + newUrl
  
  ' Run dynamic async test task
  m.tester = CreateObject("roSGNode", "ConnectionTester")
  m.tester.serverUrl = newUrl
  m.tester.observeField("result", "onTestFinished")
  m.tester.control = "RUN"
end sub

sub onReset()
  defaultUrl = "https://spamfilms.ddns.net:8080"
  saveBackendUrl(defaultUrl)
  resetDisplay()
  m.statusLabel.text = "Reset to default. Testing..."
  
  m.tester = CreateObject("roSGNode", "ConnectionTester")
  m.tester.serverUrl = defaultUrl
  m.tester.observeField("result", "onTestFinished")
  m.tester.control = "RUN"
end sub

sub onTestFinished()
  if m.tester <> invalid
    if m.tester.result = "success"
      m.statusLabel.text = "✓ Connection Successful! Backend server is active."
      m.statusLabel.color = "0x00FF00FF" ' Green
    else
      m.statusLabel.text = "✗ Connection Failed! Please check the address, port, and network configuration."
      m.statusLabel.color = "0xFF0000FF" ' Red
    end if
  end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  handled = false
  if press
    if key = "down"
      if m.keyboard.hasFocus()
        m.saveButton.setFocus(true)
        handled = true
      end if
    else if key = "up"
      if m.saveButton.hasFocus() or m.resetButton.hasFocus()
        m.keyboard.setFocus(true)
        handled = true
      end if
    else if key = "left"
      if m.resetButton.hasFocus()
        m.saveButton.setFocus(true)
        handled = true
      end if
    else if key = "right"
      if m.saveButton.hasFocus()
        m.resetButton.setFocus(true)
        handled = true
      end if
    end if
  end if
  return handled
end function
