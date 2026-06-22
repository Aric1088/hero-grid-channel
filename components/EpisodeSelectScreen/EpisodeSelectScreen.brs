sub init()
  m.seriesTitle = m.top.findNode("seriesTitle")
  m.seriesDesc = m.top.findNode("seriesDesc")
  m.episodeList = m.top.findNode("episodeList")
  m.loadingIndicator = m.top.findNode("loadingIndicator")
  m.statusLabel = m.top.findNode("statusLabel")
  m.streamLoading = false

  m.top.observeField("rowItemSelected", "selectFocusedEpisode")
  m.top.observeField("item", "onItemChanged")
end sub

sub onItemChanged()
  if m.top.item = invalid then return

  m.seriesTitle.text = m.top.item.title
  description = m.top.item.description
  if description = invalid or description = "" or LCase(description) = "no description available"
    description = "Browse episodes by season."
  end if
  m.seriesDesc.text = description
  m.currentSeriesImdbId = m.top.item.imdbId

  if m.fetcher <> invalid
    m.fetcher.unobserveField("content")
    m.fetcher.control = "STOP"
  end if

  m.fetcher = CreateObject("roSGNode", "SeriesDetailsFetcher")
  if m.currentSeriesImdbId <> invalid and m.currentSeriesImdbId <> ""
    m.fetcher.imdbId = m.currentSeriesImdbId
  else
    m.currentSeriesImdbId = m.top.item.id
    m.fetcher.imdbId = m.currentSeriesImdbId
  end if

  m.fetcher.observeField("content", "onContentReady")
  m.fetcher.control = "RUN"

  m.loadingIndicator.text = "Loading Seasons..."
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"
  m.statusLabel.visible = false
  m.episodeList.visible = false
end sub

sub onContentReady()
  print "EpisodeSelectScreen.brs - [onContentReady]"
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false

  content = m.fetcher.content
  if content = invalid or content.getChildCount() = 0
    print "No episodes found"
    m.statusLabel.text = "No episodes are available for this series."
    m.statusLabel.visible = true
    return
  end if

  m.statusLabel.visible = false
  m.episodeList.content = content
  m.episodeList.visible = true
  m.episodeList.setFocus(true)
end sub

sub selectFocusedEpisode()
  if m.streamLoading then return

  selected = m.episodeList.rowItemFocused
  if selected = invalid or selected.count() < 2 then return

  row = m.episodeList.content.getChild(selected[0])
  if row = invalid then return

  episode = row.getChild(selected[1])
  if episode = invalid then return
  m.selectedEpisode = episode

  episodeId = episode.getField("episodeId")
  if episodeId = invalid or episodeId = ""
    episodeId = episode.id
  end if
  if episodeId = invalid or episodeId = ""
    seasonNum = episode.getField("seasonNum")
    episodeNum = episode.getField("episodeNum")
    if m.currentSeriesImdbId <> invalid and m.currentSeriesImdbId <> "" and seasonNum <> invalid and episodeNum <> invalid
      episodeId = m.currentSeriesImdbId + ":" + seasonNum.toStr() + ":" + episodeNum.toStr()
    end if
  end if
  if episodeId = invalid or episodeId = ""
    print "EpisodeSelectScreen: Selected episode has no stream identifier"
    showEpisodeStatus("This episode is missing its stream identifier.")
    return
  end if

  m.loadingIndicator.text = "Loading Streams..."
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"
  m.statusLabel.visible = false
  m.streamLoading = true

  if m.streamFetcher <> invalid
    m.streamFetcher.unobserveField("content")
    m.streamFetcher.unobserveField("state")
    m.streamFetcher.control = "STOP"
  end if

  m.streamFetcher = CreateObject("roSGNode", "EpisodeDetailsFetcher")
  if m.streamFetcher = invalid
    print "EpisodeSelectScreen: Failed to create EpisodeDetailsFetcher"
    stopStreamLoading("Unable to load streams")
    return
  end if

  print "EpisodeSelectScreen: Fetching streams for episode " + episodeId
  m.streamFetcher.functionName = "fetchDetails"
  m.streamFetcher.episodeId = episodeId
  m.streamFetcher.observeField("content", "onStreamReady")
  m.streamFetcher.observeField("state", "onStreamFetcherStateChanged")
  m.streamFetcher.control = "RUN"
end sub

sub prepareForDisplay()
  focused = m.episodeList.rowItemFocused
  content = m.episodeList.content

  if content <> invalid
    m.episodeList.content = invalid
    m.episodeList.content = content
  end if

  m.episodeList.visible = true
  if focused <> invalid and focused.count() >= 2
    m.episodeList.jumpToRowItem = focused
  end if
  m.episodeList.setFocus(true)
end sub

sub onStreamFetcherStateChanged()
  if m.streamFetcher = invalid then return

  print "EpisodeSelectScreen: Stream fetcher state = " + m.streamFetcher.state
  if m.streamFetcher.state = "stop" and m.streamFetcher.content = invalid
    stopStreamLoading("No streams available")
    showEpisodeStatus("No playable sources were found for this episode.")
  end if
end sub

sub stopStreamLoading(message as string)
  m.streamLoading = false
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  print "EpisodeSelectScreen: " + message
  m.episodeList.setFocus(true)
end sub

sub onStreamReady()
  stopStreamLoading("Stream fetch completed")

  episode = m.selectedEpisode
  if episode = invalid then return

  if m.streamFetcher.content = invalid or m.streamFetcher.content.torrents = invalid
    print "No valid torrent found for episode"
    showEpisodeStatus("No playable sources were found for this episode.")
    return
  end if

  torrents = m.streamFetcher.content.torrents
  if torrents = invalid or GetInterface(torrents, "ifArray") = invalid or torrents.count() = 0
    print "No valid torrent found for episode"
    showEpisodeStatus("No playable sources were found for this episode.")
    return
  end if

  availableTorrents = {}
  for each t in torrents
    q = getNormalizedQuality(t)

    if q = "720p" or q = "1080p" or q = "2160p"
      existing = availableTorrents[q]
      replaceExisting = existing = invalid
      candidateIsHdr = isHdrTorrent(t)
      candidateLanguageRank = getLanguageRank(t)
      candidateSourceScore = getSourceScore(t)
      if replaceExisting = false
        if candidateSourceScore > existing.sourceScore
          replaceExisting = true
        else if candidateSourceScore = existing.sourceScore
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
        availableTorrents[q] = {
          quality: q,
          hash: t.hash,
          magnet: t.url,
          seeds: t.seeds,
          file: t.fileIdx,
          filename: t.filename,
          title: t.title,
          isHdr: candidateIsHdr,
          languageRank: candidateLanguageRank,
          sourceScore: candidateSourceScore,
          captureType: getCaptureType(t)
        }
      end if
    end if
  end for

  if availableTorrents.count() = 0
    print "No supported torrent qualities found for episode"
    showEpisodeStatus("No supported video qualities were found for this episode.")
    return
  end if

  selectedTorrent = invalid
  if availableTorrents["2160p"] <> invalid
    selectedTorrent = availableTorrents["2160p"]
  else if availableTorrents["1080p"] <> invalid
    selectedTorrent = availableTorrents["1080p"]
  else if availableTorrents["720p"] <> invalid
    selectedTorrent = availableTorrents["720p"]
  end if

  if selectedTorrent = invalid or selectedTorrent.hash = invalid
    print "No valid torrent found for episode"
    showEpisodeStatus("No playable source could be selected for this episode.")
    return
  end if

  print "EpisodeSelectScreen: Selected " + selectedTorrent.quality + " HDR=" + selectedTorrent.isHdr.toStr() + " languageRank=" + selectedTorrent.languageRank.toStr()

  playbackNode = CreateObject("roSGNode", "ContentNode")
  playbackNode.title = m.seriesTitle.text + " - " + episode.title

  hash = selectedTorrent.hash
  playbackNode.url = buildStreamUrl(hash, selectedTorrent.file)
  playbackNode.streamformat = "hls"

  playbackNode.addFields({
    magnetUrl: selectedTorrent.magnet,
    torrentHash: hash,
    file: selectedTorrent.file,
    sourceFile: selectedTorrent.filename,
    mediaType: "series",
    imdbId: m.currentSeriesImdbId,
    seasonNum: episode.getField("seasonNum"),
    episodeNum: episode.getField("episodeNum"),
    hdPosterUrl: episode.hdPosterUrl,
    hdBackgroundImageUrl: episode.hdPosterUrl,
    description: episode.description,
    selectedQuality: selectedTorrent.quality,
    torrents: torrents
  })

  for each q in availableTorrents
    t = availableTorrents[q]
    if q = "720p" and t.hash <> invalid
      playbackNode.addFields({ torrent720pHash: t.hash, torrent720pMagnet: t.magnet, torrent720pSeeds: t.seeds, torrent720pFile: t.file, torrent720pFileName: t.filename })
    else if q = "1080p" and t.hash <> invalid
      playbackNode.addFields({ torrent1080pHash: t.hash, torrent1080pMagnet: t.magnet, torrent1080pSeeds: t.seeds, torrent1080pFile: t.file, torrent1080pFileName: t.filename })
    else if q = "2160p" and t.hash <> invalid
      playbackNode.addFields({ torrent2160pHash: t.hash, torrent2160pMagnet: t.magnet, torrent2160pSeeds: t.seeds, torrent2160pFile: t.file, torrent2160pFileName: t.filename })
    end if
  end for

  m.top.contentSelected = playbackNode
end sub

sub showEpisodeStatus(message as string)
  m.statusLabel.text = message
  m.statusLabel.visible = true
  m.episodeList.setFocus(true)
end sub

function isHdrTorrent(torrent as object) as boolean
  description = ""
  if torrent.title <> invalid then description = description + " " + LCase(torrent.title)
  if torrent.filename <> invalid then description = description + " " + LCase(torrent.filename)

  return InStr(1, description, "dovi") > 0 or InStr(1, description, "dolby vision") > 0 or InStr(1, description, ".dv.") > 0 or InStr(1, description, " hdr") > 0
end function

function getSourceScore(torrent as object) as integer
  score = getLanguageRank(torrent) * 1000
  seeds = 0
  if torrent.seeds <> invalid then seeds = torrent.seeds
  if seeds > 400 then seeds = 400
  score = score + (seeds * 2)

  description = getTorrentDescription(torrent)
  if InStr(1, description, " sample") > 0 or InStr(1, description, "trailer") > 0 then score = score - 10000
  if InStr(1, description, "webrip") > 0 or InStr(1, description, "web-dl") > 0 or InStr(1, description, "bluray") > 0 then score = score + 500
  captureType = getCaptureType(torrent)
  if captureType = "CAM" then score = score - 1800
  if captureType = "HDTS" then score = score - 1400
  if isHdrTorrent(torrent) then score = score - 75
  score = score + getTitleMatchScore(torrent, m.seriesTitle.text)
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
      print "EpisodeSelectScreen: Correcting mislabeled 2160p source to 1080p: " + torrent.hash
    end if
    return "1080p"
  else if InStr(1, description, "720p") > 0
    return "720p"
  end if

  return declaredQuality
end function

function buildStreamUrl(hash as string, fileIdx as dynamic) as string
  if fileIdx <> invalid
    return resolveBackendPath("/v1/stream/" + hash + "/" + fileIdx.toStr() + "/master.m3u8")
  end if

  return resolveBackendPath("/v1/stream/" + hash + "/master.m3u8")
end function
