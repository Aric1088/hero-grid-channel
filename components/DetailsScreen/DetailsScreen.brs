' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' inits details screen
' sets all observers
' configures buttons for Details screen
function Init()
  print "DetailsScreen.brs - [init] STARTING"
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")

  m.buttons = m.top.findNode("Buttons")
  m.resolutionList = m.top.findNode("ResolutionList")
  m.videoPlayer = m.top.findNode("VideoPlayer")
  m.poster = m.top.findNode("Poster")
  m.description = m.top.findNode("Description")
  m.background = m.top.findNode("Background")
  m.loadingIndicator = m.top.findNode("LoadingIndicator")
  m.fadeIn = m.top.findNode("fadeinAnimation")
  m.fadeOut = m.top.findNode("fadeoutAnimation")

  print "DetailsScreen - Buttons node valid: " + Box(m.buttons <> invalid).toStr()

  ' set up button observer
  m.buttons.observeField("itemSelected", "onItemSelected")
  m.resolutionList.observeField("itemSelected", "onResolutionSelected")
  m.videoPlayer.observeField("visible", "onVideoVisibleChange")
  m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
  print "DetailsScreen - Button observer set"

  ' initialize selected resolution and torrents
  m.selectedResolution = invalid
  m.availableTorrents = {}
  m.torrentFetcher = invalid
  m.magnetTask = invalid
  m.pendingVideoContent = invalid

  ' create buttons (will be updated dynamically in OnContentChange)
  result = []
  for each button in ["Play"]
    result.push({ title: button })
  end for
  m.buttons.content = ContentList2SimpleNode(result)


  ' initially hide resolution list
  m.resolutionList.visible = false
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
end function

' set proper focus to buttons if Details opened and stops Video if Details closed
sub onVisibleChange()
  print "DetailsScreen.brs - [onVisibleChange]"
  if m.top.visible
    m.fadeIn.control = "start"
    m.buttons.jumpToItem = 0
    m.buttons.setFocus(true)
  else
    if m.top.findNode("ResolutionBackdrop") <> invalid then m.top.findNode("ResolutionBackdrop").visible = false
    if m.resolutionList <> invalid then m.resolutionList.visible = false
    if m.loadingIndicator <> invalid
      m.loadingIndicator.control = "stop"
      m.loadingIndicator.visible = false
    end if
    m.fadeOut.control = "start"
    m.videoPlayer.visible = false
    m.videoPlayer.control = "stop"
    m.poster.uri = ""
    m.background.uri = ""
  end if
end sub

' set proper focus to Buttons in case if return from Video PLayer
sub OnFocusedChildChange()
  print "DetailsScreen.brs - [OnFocusedChildChange]"
  if m.top.isInFocusChain() and not m.buttons.hasFocus() and not m.videoPlayer.hasFocus() and not m.resolutionList.hasFocus() then
    m.buttons.setFocus(true)
  end if
end sub

' set proper focus on buttons and stops video if return from Playback to details
sub onVideoVisibleChange()
  print "DetailsScreen.brs - [onVideoVisibleChange]"
  if m.videoPlayer.visible = false and m.top.visible = true
    m.buttons.setFocus(true)
    m.videoPlayer.control = "stop"
  end if
end sub

' event handler of Video player msg
sub OnVideoPlayerStateChange()
  print "===== VIDEO PLAYER STATE CHANGE ====="
  print "DetailsScreen.brs - [OnVideoPlayerStateChange]"
  print "New state: " + m.videoPlayer.state

  if m.videoPlayer.state = "error"
    print "ERROR: Video player encountered an error!"
    if m.videoPlayer.errorMsg <> invalid then print "Error message: " + m.videoPlayer.errorMsg
    if m.videoPlayer.errorCode <> invalid then print "Error code: " + m.videoPlayer.errorCode.toStr()
    if m.videoPlayer.errorStr <> invalid then print "Error string: " + m.videoPlayer.errorStr
    m.videoPlayer.visible = false
  else if m.videoPlayer.state = "playing"
    print "SUCCESS: Video is now playing!"
  else if m.videoPlayer.state = "buffering"
    print "Video is buffering..."
  else if m.videoPlayer.state = "finished"
    print "Video playback finished"
    m.videoPlayer.visible = false
  else
    print "Unknown state: " + m.videoPlayer.state
  end if
  print "============================"
end sub
  ' on Button press handler - just play the content with selected resolution
  sub onItemSelected()
    selectedIndex = m.buttons.itemSelected
    content = m.top.content
    if content = invalid then return

    if selectedIndex = 0
      print "DetailsScreen - [onItemSelected] Play button pressed"
      ' If multiple resolutions exist, show selector
      if m.availableTorrents <> invalid and m.availableTorrents.count() > 1
        showResolutionSelector()
        m.buttons.setFocus(false)
        else if m.availableTorrents <> invalid and m.availableTorrents.count() = 1
          ' Just play the single available resolution
          keys = m.availableTorrents.keys()
          switchToQuality(keys[0])
          playContent()
        else
          ' Use default URL
          playContent()
        end if
    else if selectedIndex = 1
      print "DetailsScreen - [onItemSelected] Watchlist button pressed"
      if isInWatchlist(content.id)
        removeFromWatchlist(content.id)
      else
        itemData = {
          id: content.id,
          title: content.title,
          hdPosterUrl: content.hdPosterUrl,
          cType: content.cType
        }
        addToWatchlist(itemData)
      end if
      ' Re-trigger content change to update button labels
      OnContentChange()
    end if
  end sub

' Play the selected content
sub playContent()
  print "DetailsScreen.brs - [playContent]"
  content = m.top.content
  if content = invalid
    print "ERROR: Content is invalid!"
    return
  end if

  ' Check if we have a valid URL
  if content.url = invalid or content.url = ""
    print "ERROR: No valid URL available!"
    return
  end if

  ' Set video content with the stream URL
  videoContent = CreateObject("roSGNode", "ContentNode")
  videoContent.url = content.url ' This is the HLS stream URL
  videoContent.streamFormat = "hls" ' Specify HLS format
  if content.title <> invalid then videoContent.title = content.title

  print "Video URL set: " + content.url
  print "Stream format: hls"
  print "Torrent hash: " + Box(content.torrentHash).toStr()

  if content.magnetUrl <> invalid and content.magnetUrl <> ""
    print "Preparing magnet stream before playback..."
    m.pendingVideoContent = videoContent
    m.loadingIndicator.text = "Preparing Stream..."
    m.loadingIndicator.visible = true
    m.loadingIndicator.control = "start"

    m.magnetTask = CreateObject("roSGNode", "MagnetDownloader")
    m.magnetTask.magnetUrl = content.magnetUrl
    m.magnetTask.streamUrl = content.url
    m.magnetTask.observeField("success", "onMagnetPrepared")
    m.magnetTask.control = "RUN"
    return
  end if

  startVideoPlayback(videoContent)
end sub

sub onMagnetPrepared()
  if m.magnetTask = invalid then return

  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false

  if m.magnetTask.success = true and m.pendingVideoContent <> invalid
    print "DetailsScreen: Stream preparation complete"
    startVideoPlayback(m.pendingVideoContent)
  else
    print "ERROR: Stream preparation failed"
    m.buttons.setFocus(true)
  end if

  m.pendingVideoContent = invalid
end sub

sub startVideoPlayback(videoContent as object)
  m.videoPlayer.audioSelectionPreferences = {
    values: [
      { language: ["en-US", "en-GB", "en", "en-*", "eng"] },
      { descriptive: "false" }
    ],
    overrideSystem: true
  }
  m.videoPlayer.content = videoContent
  print "Setting video player visible and playing..."
  m.videoPlayer.visible = true
  m.videoPlayer.setFocus(true)
  m.videoPlayer.control = "play"
  print "============================"
end sub

' Trigger backend to start downloading magnet (fire and forget - non-blocking)
sub triggerMagnetDownload(magnetUrl as string)
  urlTransfer = CreateObject("roUrlTransfer")
  urlTransfer.SetUrl(resolveBackendPath("/download-magnet"))
  urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
  urlTransfer.InitClientCertificates()
  urlTransfer.SetRequest("POST")
  urlTransfer.AddHeader("Content-Type", "application/json")
  urlTransfer.AddHeader("Accept", "application/json")

  ' Build JSON body
  jsonBody = "{""magnet_uri"":""" + magnetUrl + """}"

  print "Sending POST to download-magnet endpoint (fire and forget)"
  print "Body: " + jsonBody

  ' Fire and forget - don't wait for response to avoid blocking
  if urlTransfer.PostFromString(jsonBody)
    print "Magnet download request sent"
  else
    print "Failed to send POST request"
  end if
end sub

' Content change handler
sub OnContentChange()
  print "DetailsScreen.brs - [OnContentChange]"
  content = m.top.content
  if content = invalid then return

  ' Set description
  m.description.content = content

  ' Set poster and background
  if content.hdPosterUrl <> invalid
    m.poster.uri = content.hdPosterUrl
    m.background.uri = content.hdPosterUrl
  end if
  if content.hdBackgroundImageUrl <> invalid
    m.background.uri = content.hdBackgroundImageUrl
  end if

  ' Set title
  if content.title <> invalid
    m.top.findNode("Overhang").title = content.title
  end if

  ' Reset torrents and resolution
  m.availableTorrents = {}
  m.selectedResolution = invalid
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false

  ' Button references
  m.playButton = m.top.findNode("playButton")
  m.resumeButton = m.top.findNode("resumeButton")
  m.resolutionList = m.top.findNode("ResolutionList")

  ' Build buttons dynamically
  result = []
  result.push({ title: "Play" })
  if isInWatchlist(content.id)
      result.push({ title: "Remove from Watchlist" })
  else
      result.push({ title: "Add to Watchlist" })
  end if
  m.buttons.content = ContentList2SimpleNode(result)

  print "Loading details for: " + Box(content.title).toStr()

  ' Check for available quality options - stored as simple strings
  ' torrent1080pHash, torrent2160pHash fields contain the hash strings
  ' Check for available quality options - stored as simple strings
  ' torrent1080pHash, torrent2160pHash fields contain the hash strings
  has720p = content.getField("torrent720pHash") <> invalid and content.getField("torrent720pHash") <> ""
  has1080p = content.getField("torrent1080pHash") <> invalid and content.getField("torrent1080pHash") <> ""
  has2160p = content.getField("torrent2160pHash") <> invalid and content.getField("torrent2160pHash") <> ""

  print "Available qualities: 720p=" + has720p.toStr() + ", 1080p=" + has1080p.toStr() + ", 2160p=" + has2160p.toStr()

  ' Build list of available torrents
  if has720p or has1080p or has2160p
    if has720p
      m.availableTorrents["720p"] = {
        quality: "720p",
        hash: content.getField("torrent720pHash"),
        magnet: content.getField("torrent720pMagnet"),
        seeds: content.getField("torrent720pSeeds"),
        file: content.getField("torrent720pFile")
      }
    end if
    if has1080p
      m.availableTorrents["1080p"] = {
        quality: "1080p",
        hash: content.getField("torrent1080pHash"),
        magnet: content.getField("torrent1080pMagnet"),
        seeds: content.getField("torrent1080pSeeds"),
        file: content.getField("torrent1080pFile")
      }
    end if
    if has2160p
      m.availableTorrents["2160p"] = {
        quality: "2160p",
        hash: content.getField("torrent2160pHash"),
        magnet: content.getField("torrent2160pMagnet"),
        seeds: content.getField("torrent2160pSeeds"),
        file: content.getField("torrent2160pFile")
      }
    end if

    print "Found " + m.availableTorrents.count().toStr() + " resolution options"

    ' We only parse here. Resolution selector will be shown when Play is clicked.
  else
    ' Try to fetch details dynamically
    imdbId = content.getField("imdbId")
    print "No initial torrents, fetching details for " + Box(imdbId).toStr()
    if imdbId <> invalid
      m.loadingIndicator.text = "Loading Streams..."
      m.loadingIndicator.visible = true
      m.loadingIndicator.control = "start"
      m.torrentFetcher = CreateObject("roSGNode", "MovieDetailsFetcher")
      m.torrentFetcher.imdbId = imdbId
      m.torrentFetcher.observeField("content", "onTorrentFetched")
      m.torrentFetcher.control = "RUN"
    end if
  end if

  ' Ensure focus is on buttons after content loads
  if m.top.visible and m.top.isInFocusChain()
    m.buttons.setFocus(true)
    print "Focus on buttons"
  end if
end sub

'///////////////////////////////////////////'
' Helper function convert AA to Node
function ContentList2SimpleNode(contentList as object, nodeType = "ContentNode" as string) as object
  print "DetailsScreen.brs - [ContentList2SimpleNode]"
  result = createObject("roSGNode", nodeType)
  if result <> invalid
    for each itemAA in contentList
      item = createObject("roSGNode", nodeType)
      item.setFields(itemAA)
      result.appendChild(item)
    end for
  end if
  return result
end function

' Select best resolution from available torrents (prefer 2160p, then 1080p)
function selectBestResolution(torrents as object) as object
  if torrents = invalid or torrents.count() = 0 then return invalid

  ' Look for 2160p first
  for each t in torrents
    if t.quality = "2160p" then return t
  end for

  ' Fall back to 1080p
  for each t in torrents
    if t.quality = "1080p" then return t
  end for

  ' Return first available
  return torrents[0]
end function

' Show resolution selection dialog
sub showResolutionSelector()
  print "DetailsScreen.brs - [showResolutionSelector]"

  if m.availableTorrents = invalid or m.availableTorrents.count() = 0
    print "No torrents available for resolution selection"
    return
  end if

  ' Build resolution list content - list the keys from the map
  resolutions = []
  m.resolutionQualities = []
  for each quality in m.availableTorrents
    print "Adding quality option: " + quality
    m.resolutionQualities.push(quality)
    resolutions.push({
      title: quality
    })
  end for

  ' Display resolution list with backdrop
  m.resolutionList.content = ContentList2SimpleNode(resolutions)
  m.top.findNode("ResolutionBackdrop").visible = true
  m.resolutionList.visible = true
  m.resolutionList.jumpToItem = 0
  m.resolutionList.setFocus(true)
  print "Resolution selector displayed with " + resolutions.count().toStr() + " options"
end sub

' Handle resolution selection
  sub onResolutionSelected()
    print "DetailsScreen.brs - [onResolutionSelected]"
    selectedIndex = m.resolutionList.itemSelected
    print "Selected index: " + selectedIndex.toStr()
  
    if selectedIndex >= 0
      if m.resolutionQualities <> invalid and selectedIndex < m.resolutionQualities.count()
        quality = m.resolutionQualities[selectedIndex]
        print "Selected quality: " + quality
        switchToQuality(quality)
      end if
    end if
  
    m.top.findNode("ResolutionBackdrop").visible = false
    m.resolutionList.visible = false
    m.buttons.setFocus(true)
    m.buttons.jumpToItem = 0
    
    playContent()
  end sub

' Switch to a different quality
sub switchToQuality(quality as string)
  print "DetailsScreen.brs - [switchToQuality] Switching to: " + quality

  content = m.top.content
  if content = invalid
    print "ERROR: Content is invalid!"
    return
  end if

  ' Get torrent info from the map
  torrent = m.availableTorrents[quality]
  if torrent = invalid
    print "ERROR: Quality not found: " + quality
    return
  end if

  if torrent.hash <> invalid and torrent.hash <> ""
    updatedFields = {
      magnetUrl: torrent.magnet,
      torrentHash: torrent.hash,
      selectedQuality: quality
    }

    if torrent.file <> invalid
      streamUrl = resolveBackendPath("/v1/stream/" + torrent.hash + "/" + torrent.file.toStr() + "/master.m3u8")
      updatedFields.file = torrent.file
    else
      streamUrl = resolveBackendPath("/v1/stream/" + torrent.hash + "/master.m3u8")
    end if
    updatedFields.url = streamUrl
    content.setFields(updatedFields)

    print "Stream URL updated: " + streamUrl
    print "Torrent hash updated: " + torrent.hash
  else
    print "ERROR: No hash for quality " + quality
  end if
end sub

sub onTorrentFetched()
  print "DetailsScreen.brs - [onTorrentFetched]"
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.buttons.visible = true
  m.buttons.setFocus(true)
  
  detailsNode = m.torrentFetcher.content
  if detailsNode <> invalid and detailsNode.details <> invalid
    movie = detailsNode.details
    if movie.torrents <> invalid and movie.torrents.count() > 0
      for each t in movie.torrents
        q = "unknown"
        if t.quality <> invalid then q = LCase(t.quality)
        if q = "4k" then q = "2160p"
        
        if q = "720p" or q = "1080p" or q = "2160p"
          existing = m.availableTorrents[q]
          candidateIsHdr = isHdrTorrent(t)
          candidateLanguageRank = getLanguageRank(t)
          replaceExisting = existing = invalid
          if replaceExisting = false
            if candidateLanguageRank > existing.languageRank
              replaceExisting = true
            else if candidateLanguageRank = existing.languageRank
              if existing.isHdr = true and candidateIsHdr = false
                replaceExisting = true
              else if existing.isHdr = candidateIsHdr and t.seeds <> invalid
                if existing.seeds = invalid or t.seeds > existing.seeds
                  replaceExisting = true
                end if
              end if
            end if
          end if

          if replaceExisting
            m.availableTorrents[q] = {
              quality: q,
              hash: t.hash,
              magnet: t.url,
              seeds: t.seeds,
              file: t.fileIdx,
              isHdr: candidateIsHdr,
              languageRank: candidateLanguageRank
            }
          end if
        end if
      end for
      
      print "Dynamically fetched " + m.availableTorrents.count().toStr() + " resolutions"
      
      ' We only parse here. Resolution selector will be shown when Play is clicked.
      if m.availableTorrents.count() = 1
        keys = m.availableTorrents.keys()
        switchToQuality(keys[0])
      end if
    end if
  end if
end sub

function isHdrTorrent(torrent as object) as boolean
  description = ""
  if torrent.title <> invalid then description = description + " " + LCase(torrent.title)
  if torrent.filename <> invalid then description = description + " " + LCase(torrent.filename)

  return InStr(1, description, "dovi") > 0 or InStr(1, description, "dolby vision") > 0 or InStr(1, description, ".dv.") > 0 or InStr(1, description, " hdr") > 0
end function

function getLanguageRank(torrent as object) as integer
  description = ""
  if torrent.title <> invalid then description = description + " " + LCase(torrent.title)
  if torrent.filename <> invalid then description = description + " " + LCase(torrent.filename)

  hasEnglish = false
  hasMulti = false
  hasForeign = false

  if torrent.languages <> invalid and GetInterface(torrent.languages, "ifArray") <> invalid
    for each language in torrent.languages
      normalized = LCase(language)
      if normalized = "english" or normalized = "eng"
        hasEnglish = true
      else if normalized = "multi"
        hasMulti = true
      else if normalized = "spanish" or normalized = "spa" or normalized = "es"
        hasForeign = true
      end if
    end for
  end if

  if InStr(1, description, "english") > 0 or InStr(1, description, " eng ") > 0 then hasEnglish = true
  if InStr(1, description, "multi") > 0 then hasMulti = true
  if InStr(1, description, "spanish") > 0 or InStr(1, description, "latino") > 0 or InStr(1, description, "castellano") > 0 or InStr(1, description, "rick y morty") > 0 then hasForeign = true

  if hasEnglish then return 4
  if hasMulti then return 3
  if hasForeign then return 0
  return 2
end function








