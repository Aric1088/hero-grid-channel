' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' inits details screen
' sets all observers
' configures buttons for Details screen
function Init()
  print "DetailsScreen.brs - [init] STARTING"
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")

  m.buttons = m.top.findNode("Buttons")
  m.detailsChrome = m.top.findNode("DetailsChrome")
  m.resolutionList = m.top.findNode("ResolutionList")
  m.videoPlayer = m.top.findNode("VideoPlayer")
  m.poster = m.top.findNode("Poster")
  m.description = m.top.findNode("Description")
  m.background = m.top.findNode("Background")
  m.loadingIndicator = m.top.findNode("LoadingIndicator")
  m.playbackStatus = m.top.findNode("PlaybackStatus")
  m.preparationOverlay = m.top.findNode("PreparationOverlay")
  m.preparationSpinner = m.top.findNode("PreparationSpinner")
  m.preparationTitle = m.top.findNode("PreparationTitle")
  m.preparationMessage = m.top.findNode("PreparationMessage")
  m.preparationSource = m.top.findNode("PreparationSource")
  m.preparationProgress = m.top.findNode("PreparationProgress")
  m.titleLabel = m.top.findNode("TitleLabel")
  m.fadeIn = m.top.findNode("fadeinAnimation")
  m.fadeOut = m.top.findNode("fadeoutAnimation")

  print "DetailsScreen - Buttons node valid: " + Box(m.buttons <> invalid).toStr()

  ' set up button observer

  print "DetailsScreen - Buttons node valid: " + Box(m.buttons <> invalid).toStr()

  ' set up button observer
  m.buttons.observeField("itemSelected", "onItemSelected")
  m.resolutionList.observeField("itemSelected", "onResolutionSelected")
  m.videoPlayer.observeField("visible", "onVideoVisibleChange")
  m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
  m.videoPlayer.observeField("availableAudioTracks", "onAvailableAudioTracksChanged")
  m.videoPlayer.observeField("availableSubtitleTracks", "onAvailableSubtitleTracksChanged")
  m.videoPlayer.observeField("currentAudioTrack", "onCurrentAudioTrackChanged")
  m.videoPlayer.observeField("currentSubtitleTrack", "onCurrentSubtitleTrackChanged")
  m.videoPlayer.seamlessAudioTrackSelection = true
  print "DetailsScreen - Button observer set"

  ' initialize selected resolution and torrents
  m.selectedResolution = invalid
  m.availableTorrents = { "720p": [], "1080p": [], "2160p": [] }
  m.currentTorrentIndex = 0
  m.torrentFetcher = invalid
  m.magnetTask = invalid
  m.pendingVideoContent = invalid
  m.pendingDirectRetry = invalid
  m.activeVideoContent = invalid
  m.directVariantRetry = false
  m.playbackQuality = invalid
  m.playbackInProgress = false
  m.activeContentKey = ""
  m.detailsReady = false

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
  hidePreparationOverlay()
end function

' set proper focus to buttons if Details opened and stops Video if Details closed
sub onVisibleChange()
  print "DetailsScreen.brs - [onVisibleChange]"
  if m.top.visible
    m.fadeIn.control = "start"
    m.buttons.jumpToItem = 0
    m.buttons.setFocus(true)
  else
    if m.magnetTask <> invalid
      m.magnetTask.unobserveField("success")
      m.magnetTask.control = "STOP"
      m.magnetTask = invalid
    end if
    if m.torrentFetcher <> invalid
      m.torrentFetcher.unobserveField("content")
      m.torrentFetcher.control = "STOP"
      m.torrentFetcher = invalid
    end if
    m.pendingVideoContent = invalid
    m.pendingDirectRetry = invalid
    if m.top.findNode("ResolutionBackdrop") <> invalid then m.top.findNode("ResolutionBackdrop").visible = false
    if m.top.findNode("ResolutionPanel") <> invalid then m.top.findNode("ResolutionPanel").visible = false
    if m.top.findNode("ResolutionTitle") <> invalid then m.top.findNode("ResolutionTitle").visible = false
    if m.resolutionList <> invalid then m.resolutionList.visible = false
    if m.loadingIndicator <> invalid
      m.loadingIndicator.control = "stop"
      m.loadingIndicator.visible = false
    end if
    hidePreparationOverlay()
    if m.playbackStatus <> invalid then m.playbackStatus.visible = false
    m.playbackInProgress = false
    m.playbackQuality = invalid
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
  if m.detailsChrome <> invalid then m.detailsChrome.visible = not m.videoPlayer.visible
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

    if retryDirectMediaPlaylist()
      return
    end if

    if tryNextPlaybackSource()
      return
    end if

    m.videoPlayer.visible = false
    m.playbackStatus.text = "Playback stopped because this source could not be decoded. Choose Play to try another source."
    m.playbackStatus.visible = true
    m.buttons.setFocus(true)
  else if m.videoPlayer.state = "playing"
    print "SUCCESS: Video is now playing!"
  else if m.videoPlayer.state = "buffering"
    print "Video is buffering..."
  else if m.videoPlayer.state = "paused"
    print "Video is paused"
  else if m.videoPlayer.state = "stopped"
    if startPendingDirectRetry() then return
    print "Video is stopped"
  else if m.videoPlayer.state = "finished"
    if startPendingDirectRetry() then return
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
      ' Count available resolutions
      availableCount = 0
      lastQuality = ""
      for each quality in m.availableTorrents
        if m.availableTorrents[quality] <> invalid and m.availableTorrents[quality].count() > 0
          availableCount = availableCount + 1
          lastQuality = quality
        end if
      end for

      if availableCount > 1
        showResolutionSelector()
        m.buttons.setFocus(false)
      else if availableCount = 1
        switchToQuality(lastQuality)
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
      updateActionButtons()
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
    m.playbackStatus.text = "No playable source is available for this title."
    m.playbackStatus.visible = true
    m.buttons.setFocus(true)
    return
  end if

  ' Set video content with the stream URL
  videoContent = CreateObject("roSGNode", "ContentNode")
  videoContent.url = content.url ' This is the HLS stream URL
  videoContent.streamFormat = "hls" ' Specify HLS format
  if content.title <> invalid then videoContent.title = content.title
  configureSubtitleTracks(videoContent, content)
  m.pendingDirectRetry = invalid
  m.directVariantRetry = false

  print "Video URL set: " + content.url
  print "Stream format: hls"
  print "Torrent hash: " + Box(content.torrentHash).toStr()

  if content.magnetUrl <> invalid and content.magnetUrl <> ""
    print "Preparing magnet stream before playback..."
    m.playbackInProgress = true
    if m.playbackQuality = invalid then m.playbackQuality = m.selectedResolution
    m.pendingVideoContent = videoContent
    updatePreparationStatus()
    showPreparationOverlay()
    startMagnetTask()
    return
  end if

  startVideoPlayback(videoContent)
end sub

sub onMagnetPrepared()
  if m.magnetTask = invalid then return

  if m.magnetTask.success = true and m.pendingVideoContent <> invalid
    print "DetailsScreen: Stream preparation complete"
    hidePreparationOverlay()
    startVideoPlayback(m.pendingVideoContent)
    m.pendingVideoContent = invalid
    m.playbackInProgress = false
    m.playbackStatus.visible = false
  else
    print "WARNING: Stream preparation failed for torrent index " + m.currentTorrentIndex.toStr()

    m.currentTorrentIndex = m.currentTorrentIndex + 1
    quality = m.playbackQuality
    torrents = invalid
    if quality <> invalid and m.availableTorrents <> invalid
      torrents = m.availableTorrents[quality]
    end if
    if torrents <> invalid and m.currentTorrentIndex < torrents.count()
      print "DetailsScreen: Trying next torrent index " + m.currentTorrentIndex.toStr() + " of " + torrents.count().toStr()
      prepareSelectedTorrent()
      m.pendingVideoContent.url = m.top.content.url
      updatePreparationStatus()
      startMagnetTask()
    else
      print "ERROR: No more torrents available for this quality!"
      hidePreparationOverlay()
      m.playbackInProgress = false
      m.playbackStatus.text = "No working " + Box(quality).toStr() + " source was found. Choose Play to try another quality."
      m.playbackStatus.visible = true
      m.buttons.setFocus(true)
      m.pendingVideoContent = invalid
    end if
  end if
end sub

sub startMagnetTask()
  if m.magnetTask <> invalid
    m.magnetTask.unobserveField("success")
    m.magnetTask.control = "STOP"
  end if

  content = m.top.content
  if content = invalid then return
  m.magnetTask = CreateObject("roSGNode", "MagnetDownloader")
  m.magnetTask.magnetUrl = content.magnetUrl
  m.magnetTask.streamUrl = content.url
  fileIndex = content.getField("file")
  if fileIndex <> invalid then m.magnetTask.fileIndex = fileIndex
  sourceFile = content.getField("sourceFile")
  if sourceFile <> invalid then m.magnetTask.fileName = sourceFile
  mediaType = content.getField("mediaType")
  if mediaType = invalid or mediaType = ""
    mediaType = "movie"
    cType = content.getField("cType")
    if cType <> invalid and LCase(cType) = "series" then mediaType = "series"
    if content.getField("seasonNum") <> invalid then mediaType = "series"
  end if
  m.magnetTask.mediaType = mediaType
  m.magnetTask.observeField("success", "onMagnetPrepared")
  m.magnetTask.control = "RUN"
end sub

sub updatePreparationStatus()
  quality = m.playbackQuality
  total = 1
  if quality <> invalid and m.availableTorrents[quality] <> invalid
    total = m.availableTorrents[quality].count()
  end if
  attempt = m.currentTorrentIndex + 1
  qualityLabel = Box(quality).toStr()
  if quality = invalid or qualityLabel = "<invalid>" then qualityLabel = ""

  if qualityLabel = ""
    m.preparationTitle.text = "Preparing stream"
  else
    m.preparationTitle.text = "Preparing " + qualityLabel
  end if

  if attempt = 1
    m.preparationMessage.text = "Connecting to the selected source"
  else
    m.preparationMessage.text = "That source did not respond. Trying another"
  end if

  m.preparationSource.text = "Source " + attempt.toStr() + " of " + total.toStr()
  progressWidth = Int((attempt / total) * 640)
  if progressWidth < 24 then progressWidth = 24
  if progressWidth > 640 then progressWidth = 640
  m.preparationProgress.width = progressWidth
  m.playbackStatus.visible = false
end sub

sub showPreparationOverlay()
  if m.preparationOverlay <> invalid then m.preparationOverlay.visible = true
  if m.preparationSpinner <> invalid
    m.preparationSpinner.visible = true
    m.preparationSpinner.control = "start"
  end if
end sub

sub hidePreparationOverlay()
  if m.preparationSpinner <> invalid
    m.preparationSpinner.control = "stop"
    m.preparationSpinner.visible = false
  end if
  if m.preparationOverlay <> invalid then m.preparationOverlay.visible = false
end sub

sub startVideoPlayback(videoContent as object)
  m.activeVideoContent = videoContent
  m.videoPlayer.audioSelectionPreferences = {
    values: [
      { language: ["en-US", "en-GB", "en", "en-*", "eng"] },
      { descriptive: "false" }
    ],
    overrideSystem: true
  }
  m.videoPlayer.subtitleSelectionPreferences = {
    values: [
      { language: ["en-US", "en-GB", "en", "en-*", "eng"] },
      { descriptive: "false" }
    ],
    overrideSystem: false
  }
  m.videoPlayer.content = videoContent
  print "Setting video player visible and playing..."
  m.videoPlayer.visible = true
  m.videoPlayer.setFocus(true)
  m.videoPlayer.control = "play"
  print "============================"
end sub

sub configureSubtitleTracks(videoContent as object, sourceContent as object)
  if videoContent = invalid or sourceContent = invalid then return

  imdbId = sourceContent.getField("imdbId")
  if imdbId = invalid or imdbId = "" then return

  subtitleUrl = resolveBackendPath("/subtitles?imdb_id=" + imdbId)
  seasonNum = sourceContent.getField("seasonNum")
  episodeNum = sourceContent.getField("episodeNum")
  if seasonNum <> invalid and episodeNum <> invalid
    subtitleUrl = subtitleUrl + "&season=" + seasonNum.toStr() + "&episode=" + episodeNum.toStr()
  end if

  videoContent.closedCaptions = true
  videoContent.subtitleTracks = [{
    Language: "eng",
    Description: "English",
    TrackName: subtitleUrl
  }]
  print "DetailsScreen: Added English subtitle track " + subtitleUrl
end sub

sub onAvailableAudioTracksChanged()
  tracks = m.videoPlayer.availableAudioTracks
  count = 0
  if tracks <> invalid then count = tracks.count()
  print "DetailsScreen: Available audio tracks = " + count.toStr()
  if tracks <> invalid
    for each track in tracks
      print "  audio: " + FormatJson(track)
    end for
  end if
end sub

sub onAvailableSubtitleTracksChanged()
  tracks = m.videoPlayer.availableSubtitleTracks
  count = 0
  if tracks <> invalid then count = tracks.count()
  print "DetailsScreen: Available subtitle tracks = " + count.toStr()
  if tracks <> invalid
    for each track in tracks
      print "  subtitle: " + FormatJson(track)
    end for
  end if
end sub

sub onCurrentAudioTrackChanged()
  print "DetailsScreen: Current audio track = " + Box(m.videoPlayer.currentAudioTrack).toStr()
end sub

sub onCurrentSubtitleTrackChanged()
  print "DetailsScreen: Current subtitle track = " + Box(m.videoPlayer.currentSubtitleTrack).toStr()
end sub

function retryDirectMediaPlaylist() as boolean
  if m.directVariantRetry then return false
  if m.videoPlayer.errorCode <> -3 then return false
  if m.activeVideoContent = invalid or m.activeVideoContent.url = invalid then return false

  sourceUrl = m.activeVideoContent.url
  suffixPosition = InStr(1, sourceUrl, "master.m3u8")
  if suffixPosition = 0 then return false

  directContent = CreateObject("roSGNode", "ContentNode")
  directContent.url = Left(sourceUrl, suffixPosition - 1) + "v0.m3u8"
  directContent.streamFormat = "hls"
  if m.activeVideoContent.title <> invalid then directContent.title = m.activeVideoContent.title
  if m.activeVideoContent.subtitleTracks <> invalid
    directContent.closedCaptions = true
    directContent.subtitleTracks = m.activeVideoContent.subtitleTracks
  end if

  m.directVariantRetry = true
  m.pendingDirectRetry = directContent
  print "DetailsScreen: Retrying direct media playlist: " + directContent.url
  m.videoPlayer.control = "stop"
  return true
end function

function startPendingDirectRetry() as boolean
  if m.pendingDirectRetry = invalid then return false

  directContent = m.pendingDirectRetry
  m.pendingDirectRetry = invalid
  m.activeVideoContent = directContent
  m.videoPlayer.content = directContent
  m.videoPlayer.visible = true
  m.videoPlayer.setFocus(true)
  m.videoPlayer.control = "play"
  print "DetailsScreen: Direct media playlist playback started"
  return true
end function

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

  contentKey = ""
  if content.id <> invalid then contentKey = content.id
  if contentKey = "" and content.getField("imdbId") <> invalid then contentKey = content.getField("imdbId")
  if contentKey = "" and content.title <> invalid then contentKey = content.title
  if contentKey <> "" and contentKey = m.activeContentKey
    if m.playbackInProgress or m.torrentFetcher <> invalid or m.detailsReady
      print "DetailsScreen: Ignoring duplicate content notification for " + contentKey
      return
    end if
  end if
  m.activeContentKey = contentKey
  m.detailsReady = false
  if m.torrentFetcher <> invalid
    m.torrentFetcher.unobserveField("content")
    m.torrentFetcher.control = "STOP"
    m.torrentFetcher = invalid
  end if

  ' Set description
  m.description.content = content

  ' Set poster and background
  if content.hdPosterUrl <> invalid
    m.poster.uri = content.hdPosterUrl
    m.background.uri = content.hdPosterUrl
    m.poster.visible = true
    m.description.translation = [425, 625]
    descriptionLabel = m.description.findNode("DescriptionText")
    if descriptionLabel <> invalid then descriptionLabel.width = 880
  end if
  if content.hdBackgroundImageUrl <> invalid
    m.background.uri = content.hdBackgroundImageUrl
    if content.hdPosterUrl = content.hdBackgroundImageUrl
      m.poster.visible = false
      m.description.translation = [96, 625]
      descriptionLabel = m.description.findNode("DescriptionText")
      if descriptionLabel <> invalid then descriptionLabel.width = 1210
    end if
  end if

  ' Set title
  if content.title <> invalid then m.titleLabel.text = content.title

  ' Reset torrents and resolution
  m.availableTorrents = { "720p": [], "1080p": [], "2160p": [] }
  m.selectedResolution = invalid
  m.playbackQuality = invalid
  m.playbackInProgress = false
  m.currentTorrentIndex = 0
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  hidePreparationOverlay()
  m.playbackStatus.visible = false

  ' Button references
  m.playButton = m.top.findNode("playButton")
  m.resumeButton = m.top.findNode("resumeButton")
  m.resolutionList = m.top.findNode("ResolutionList")

  updateActionButtons()

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
  if content.getField("torrents") <> invalid and content.getField("torrents").count() > 0
    print "Found torrents list in content object directly (e.g., from TV show episode)"
    for each t in content.torrents
      q = getNormalizedQuality(t)
      
      if q = "720p" or q = "1080p" or q = "2160p"
        candidateIsHdr = isHdrTorrent(t)
        candidateLanguageRank = getLanguageRank(t)
        
        m.availableTorrents[q].push({
          quality: q,
          hash: t.hash,
          magnet: t.url,
          seeds: t.seeds,
          file: t.fileIdx,
          filename: t.filename,
          title: t.title,
          isHdr: candidateIsHdr,
          languageRank: candidateLanguageRank,
          sourceScore: getSourceScore(t),
          captureType: getCaptureType(t)
        })
      end if
    end for
    
    for each q in m.availableTorrents
      sortTorrents(m.availableTorrents[q])
    end for

    print "Parsed TV show torrents from content.torrents"
  else if has720p or has1080p or has2160p
    if has720p
      m.availableTorrents["720p"].push({
        quality: "720p",
        hash: content.getField("torrent720pHash"),
        magnet: content.getField("torrent720pMagnet"),
        seeds: content.getField("torrent720pSeeds"),
        file: content.getField("torrent720pFile"),
        filename: content.getField("torrent720pFileName"),
        isHdr: false,
        languageRank: 0,
        sourceScore: 0,
        captureType: ""
      })
    end if
    if has1080p
      m.availableTorrents["1080p"].push({
        quality: "1080p",
        hash: content.getField("torrent1080pHash"),
        magnet: content.getField("torrent1080pMagnet"),
        seeds: content.getField("torrent1080pSeeds"),
        file: content.getField("torrent1080pFile"),
        filename: content.getField("torrent1080pFileName"),
        isHdr: false,
        languageRank: 0,
        sourceScore: 0,
        captureType: ""
      })
    end if
    if has2160p
      m.availableTorrents["2160p"].push({
        quality: "2160p",
        hash: content.getField("torrent2160pHash"),
        magnet: content.getField("torrent2160pMagnet"),
        seeds: content.getField("torrent2160pSeeds"),
        file: content.getField("torrent2160pFile"),
        filename: content.getField("torrent2160pFileName"),
        isHdr: false,
        languageRank: 0,
        sourceScore: 0,
        captureType: ""
      })
    end if

    print "Found resolution options"
    m.detailsReady = true

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
  qualityOrder = ["2160p", "1080p", "720p"]
  for each quality in qualityOrder
    if m.availableTorrents[quality] <> invalid and m.availableTorrents[quality].count() > 0
      print "Adding quality option: " + quality
      m.resolutionQualities.push(quality)
      label = quality
      topTorrent = m.availableTorrents[quality][0]
      if topTorrent.captureType <> invalid and topTorrent.captureType <> ""
        label = label + " " + topTorrent.captureType
      end if
      resolutions.push({ title: label })
    end if
  end for

  ' Display resolution list with backdrop
  m.resolutionList.content = ContentList2SimpleNode(resolutions)
  m.top.findNode("ResolutionBackdrop").visible = true
  m.top.findNode("ResolutionPanel").visible = true
  m.top.findNode("ResolutionTitle").visible = true
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
  
  hideResolutionSelector()
  m.buttons.setFocus(true)
    m.buttons.jumpToItem = 0
    
  playContent()
end sub

sub hideResolutionSelector()
  m.top.findNode("ResolutionBackdrop").visible = false
  m.top.findNode("ResolutionPanel").visible = false
  m.top.findNode("ResolutionTitle").visible = false
  m.resolutionList.visible = false
end sub

sub cancelPlaybackPreparation()
  print "DetailsScreen: Playback preparation canceled"
  if m.magnetTask <> invalid
    m.magnetTask.unobserveField("success")
    m.magnetTask.control = "STOP"
    m.magnetTask = invalid
  end if
  m.pendingVideoContent = invalid
  m.pendingDirectRetry = invalid
  m.playbackInProgress = false
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  hidePreparationOverlay()
  m.playbackStatus.text = "Playback preparation canceled."
  m.playbackStatus.visible = true
  m.buttons.setFocus(true)
end sub

' Switch to a different quality
sub switchToQuality(quality as string)
  print "DetailsScreen.brs - [switchToQuality] Switching to: " + quality
  m.selectedResolution = quality
  m.playbackQuality = quality
  m.currentTorrentIndex = 0
  prepareSelectedTorrent()
end sub

sub prepareSelectedTorrent()
  content = m.top.content
  quality = m.playbackQuality
  if quality = invalid then quality = m.selectedResolution
  if content = invalid or quality = invalid then return

  torrents = m.availableTorrents[quality]
  if torrents = invalid or torrents.count() = 0 or m.currentTorrentIndex >= torrents.count()
    print "ERROR: No more torrents available for quality " + quality
    return
  end if

  torrent = torrents[m.currentTorrentIndex]
  print "Preparing torrent index " + m.currentTorrentIndex.toStr() + " of " + torrents.count().toStr() + " (hash: " + torrent.hash + ")"

  updatedFields = {
    magnetUrl: torrent.magnet,
    torrentHash: torrent.hash,
    selectedQuality: quality,
    sourceFile: torrent.filename
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
end sub

sub onTorrentFetched()
  print "DetailsScreen.brs - [onTorrentFetched]"
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.buttons.visible = true
  m.buttons.setFocus(true)
  
  if m.torrentFetcher = invalid then return
  detailsNode = m.torrentFetcher.content
  m.torrentFetcher.unobserveField("content")
  m.torrentFetcher = invalid
  if detailsNode <> invalid and detailsNode.details <> invalid
    movie = detailsNode.details
    if movie.torrents <> invalid and movie.torrents.count() > 0
      for each t in movie.torrents
        q = getNormalizedQuality(t)
        
        if q = "720p" or q = "1080p" or q = "2160p"
          candidateIsHdr = isHdrTorrent(t)
          candidateLanguageRank = getLanguageRank(t)
          
          m.availableTorrents[q].push({
            quality: q,
            hash: t.hash,
            magnet: t.url,
            seeds: t.seeds,
            file: t.fileIdx,
            filename: t.filename,
            title: t.title,
            isHdr: candidateIsHdr,
            languageRank: candidateLanguageRank,
            sourceScore: getSourceScore(t),
            captureType: getCaptureType(t)
          })
        end if
      end for
      
      for each q in m.availableTorrents
        sortTorrents(m.availableTorrents[q])
      end for
      
      availableCount = 0
      lastQuality = ""
      for each q in m.availableTorrents
        if m.availableTorrents[q].count() > 0
          availableCount = availableCount + 1
          lastQuality = q
        end if
      end for

      print "Dynamically fetched " + availableCount.toStr() + " resolutions"
      m.detailsReady = true
      
      if availableCount = 1
        switchToQuality(lastQuality)
      end if
    end if
  end if
end sub

sub updateActionButtons()
  content = m.top.content
  if content = invalid then return
  result = [{ title: "Play" }]
  if isInWatchlist(content.id)
    result.push({ title: "Remove from Watchlist" })
  else
    result.push({ title: "Add to Watchlist" })
  end if
  m.buttons.content = ContentList2SimpleNode(result)
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
  wordDescription = CreateObject("roRegex", "[^a-z]+", "i").ReplaceAll(description, " ")
  wordDescription = " " + wordDescription + " "

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

  if InStr(1, wordDescription, " english ") > 0 or InStr(1, wordDescription, " eng ") > 0 then hasEnglish = true
  if InStr(1, wordDescription, " multi ") > 0 or InStr(1, description, "dual audio") > 0 then hasMulti = true
  foreignWords = [" spanish ", " spa ", " latino ", " castellano ", " italian ", " ita ", " french ", " fre ", " german ", " ger ", " russian ", " rus ", " polish ", " pol ", " portuguese ", " por ", " japanese ", " jap ", " hindi ", " hin ", " tamil ", " telugu ", " tagalog ", " dubbed ", " dub "]
  for each indicator in foreignWords
    if InStr(1, wordDescription, indicator) > 0 then hasForeign = true
  end for
  if InStr(1, description, "rick y morty") > 0 then hasForeign = true

  if hasEnglish then return 4
  if hasMulti then return 3
  if hasForeign then return 0
  return 2
end function

function getNormalizedQuality(torrent as object) as string
  declaredQuality = "unknown"
  if torrent.quality <> invalid then declaredQuality = LCase(torrent.quality)
  if declaredQuality = "4k" then declaredQuality = "2160p"

  description = ""
  if torrent.title <> invalid then description = description + " " + LCase(torrent.title)
  if torrent.filename <> invalid then description = description + " " + LCase(torrent.filename)

  if InStr(1, description, "2160p") > 0 or InStr(1, description, " 4k") > 0
    return "2160p"
  else if InStr(1, description, "1080p") > 0
    if declaredQuality = "2160p"
      print "DetailsScreen: Correcting mislabeled 2160p source to 1080p: " + torrent.hash
    end if
    return "1080p"
  else if InStr(1, description, "720p") > 0
    return "720p"
  end if

  return declaredQuality
end function

function isBetterTorrent(t1 as object, t2 as object) as boolean
  score1 = 0
  score2 = 0
  if t1.sourceScore <> invalid then score1 = t1.sourceScore
  if t2.sourceScore <> invalid then score2 = t2.sourceScore
  if score2 > score1 return true
  if score2 < score1 return false

  if t2.languageRank > t1.languageRank return true
  if t2.languageRank < t1.languageRank return false
  
  if t1.isHdr = true and t2.isHdr = false return true
  if t1.isHdr = false and t2.isHdr = true return false
  
  if t2.seeds <> invalid and (t1.seeds = invalid or t2.seeds > t1.seeds) return true
  return false
end function

function getSourceScore(torrent as object) as integer
  score = getLanguageRank(torrent) * 1000
  seeds = 0
  if torrent.seeds <> invalid then seeds = torrent.seeds
  if seeds > 700 then seeds = 700
  score = score + seeds

  description = getTorrentDescription(torrent)
  if InStr(1, description, " sample") > 0 or InStr(1, description, "trailer") > 0
    score = score - 10000
  end if
  captureType = getCaptureType(torrent)
  if captureType = "CAM"
    score = score - 1800
  else if captureType = "HDTS"
    score = score - 1400
  end if
  if InStr(1, description, "webrip") > 0 or InStr(1, description, "web-dl") > 0 or InStr(1, description, "bluray") > 0
    score = score + 500
  end if
  if isHdrTorrent(torrent) then score = score - 75
  requestedTitle = ""
  if m.top.content <> invalid and m.top.content.title <> invalid then requestedTitle = m.top.content.title
  score = score + getTitleMatchScore(torrent, requestedTitle)
  return score
end function

function getCaptureType(torrent as object) as string
  description = getTorrentDescription(torrent)
  if InStr(1, description, "hdts") > 0 or InStr(1, description, "telesync") > 0 then return "HDTS"
  if InStr(1, description, "camrip") > 0 or InStr(1, description, ".cam.") > 0 or InStr(1, description, "-cam-") > 0 or InStr(1, description, " cam ") > 0 or Right(description, 4) = " cam" then return "CAM"
  return ""
end function

function getTorrentDescription(torrent as object) as string
  description = ""
  if torrent.title <> invalid then description = description + " " + LCase(torrent.title)
  if torrent.filename <> invalid then description = description + " " + LCase(torrent.filename)
  return description
end function

function getTitleMatchScore(torrent as object, requestedTitle as string) as integer
  if requestedTitle = invalid or requestedTitle = "" then return 0
  normalizer = CreateObject("roRegex", "[^a-z0-9]+", "i")
  requested = normalizer.ReplaceAll(LCase(requestedTitle), " ")
  description = normalizer.ReplaceAll(getTorrentDescription(torrent), " ")
  words = CreateObject("roRegex", " +", "").Split(requested)
  significantWords = 0
  for each word in words
    if Len(word) >= 4 and word <> "the" and word <> "with" and word <> "from"
      significantWords = significantWords + 1
      if InStr(1, description, word) > 0 then return 300
    end if
  end for
  if significantWords > 0 then return -1800
  return 0
end function

function tryNextPlaybackSource() as boolean
  quality = m.playbackQuality
  if quality = invalid or m.availableTorrents = invalid then return false
  torrents = m.availableTorrents[quality]
  if torrents = invalid or m.currentTorrentIndex + 1 >= torrents.count() then return false

  m.currentTorrentIndex = m.currentTorrentIndex + 1
  print "DetailsScreen: Playback failed; trying source " + (m.currentTorrentIndex + 1).toStr()
  m.videoPlayer.visible = false
  m.videoPlayer.control = "stop"
  prepareSelectedTorrent()
  playContent()
  return true
end function

sub sortTorrents(torrents as object)
  n = torrents.count()
  for i = 0 to n - 2
    for j = 0 to n - i - 2
      if isBetterTorrent(torrents[j], torrents[j+1])
        temp = torrents[j]
        torrents[j] = torrents[j+1]
        torrents[j+1] = temp
      end if
    end for
  end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "back"
    if m.videoPlayer <> invalid and m.videoPlayer.visible = true
      print "DetailsScreen: Dismissing video player on back key"
      m.videoPlayer.visible = false
      m.videoPlayer.control = "stop"
      m.buttons.setFocus(true)
      return true
    else if m.resolutionList <> invalid and m.resolutionList.visible = true
      hideResolutionSelector()
      m.buttons.setFocus(true)
      return true
    else if m.playbackInProgress
      cancelPlaybackPreparation()
      return true
    end if
  end if

  return false
end function








