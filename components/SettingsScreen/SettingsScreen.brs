sub init()
  m.keyboard = m.top.findNode("keyboard")
  m.saveButton = m.top.findNode("saveButton")
  m.resetButton = m.top.findNode("resetButton")
  m.currentUrlLabel = m.top.findNode("currentUrlLabel")
  m.statusLabel = m.top.findNode("statusLabel")

  m.saveButton.observeField("buttonSelected", "onSave")
  m.resetButton.observeField("buttonSelected", "onReset")

  resetDisplay()
  m.saveButton.setFocus(true)
end sub

sub resetDisplay()
  activeUrl = getBackendUrl()
  m.currentUrlLabel.text = activeUrl
  m.keyboard.text = activeUrl
  m.statusLabel.text = ""
  m.statusLabel.color = "0xA9AFBAFF"
end sub

sub onSave()
  newUrl = m.keyboard.text
  if Right(newUrl, 1) = "/" then newUrl = Left(newUrl, Len(newUrl) - 1)
  if Left(newUrl, 7) <> "http://" and Left(newUrl, 8) <> "https://"
    newUrl = "http://" + newUrl
  end if

  m.statusLabel.text = "Testing " + newUrl + "..."
  m.statusLabel.color = "0xF0B95BFF"
  saveBackendUrl(newUrl)
  m.currentUrlLabel.text = newUrl

  m.tester = CreateObject("roSGNode", "ConnectionTester")
  m.tester.serverUrl = newUrl
  m.tester.observeField("result", "onTestFinished")
  m.tester.control = "RUN"
end sub

sub onReset()
  defaultUrl = "https://spamfilms.ddns.net:8080"
  saveBackendUrl(defaultUrl)
  resetDisplay()
  m.statusLabel.text = "Default restored. Testing connection..."

  m.tester = CreateObject("roSGNode", "ConnectionTester")
  m.tester.serverUrl = defaultUrl
  m.tester.observeField("result", "onTestFinished")
  m.tester.control = "RUN"
end sub

sub onTestFinished()
  if m.tester = invalid then return
  if m.tester.result = "success"
    m.statusLabel.text = "Connection successful. The server is available."
    m.statusLabel.color = "0x53D18CFF"
  else
    m.statusLabel.text = "Connection failed. Check the address, port, and network."
    m.statusLabel.color = "0xFF6B6BFF"
  end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "down" and m.keyboard.hasFocus()
    m.saveButton.setFocus(true)
    return true
  else if key = "up" and (m.saveButton.hasFocus() or m.resetButton.hasFocus())
    m.keyboard.setFocus(true)
    return true
  else if key = "left" and m.resetButton.hasFocus()
    m.saveButton.setFocus(true)
    return true
  else if key = "right" and m.saveButton.hasFocus()
    m.resetButton.setFocus(true)
    return true
  end if

  return false
end function
