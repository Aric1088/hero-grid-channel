sub init()
  m.seriesTitle = m.top.findNode("seriesTitle")
  m.seriesDesc = m.top.findNode("seriesDesc")
  m.episodeList = m.top.findNode("episodeList")
  m.loadingIndicator = m.top.findNode("loadingIndicator")

  m.top.observeField("rowItemSelected", "selectFocusedEpisode")
  m.top.observeField("item", "onItemChanged")
end sub

sub onItemChanged()
  if m.top.item = invalid then return

  m.seriesTitle.text = m.top.item.title
  m.seriesDesc.text = m.top.item.description
  m.currentSeriesImdbId = m.top.item.imdbId

  if m.fetcher <> invalid then m.fetcher.control = "STOP"

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
  m.episodeList.visible = false
end sub

sub onContentReady()
  print "EpisodeSelectScreen.brs - [onContentReady]"
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false

  content = m.fetcher.content
  if content = invalid or content.getChildCount() = 0
    print "No episodes found"
    return
  end if

  m.episodeList.content = content
  m.episodeList.visible = true
  m.episodeList.setFocus(true)
end sub

sub selectFocusedEpisode()
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
    return
  end if

  m.loadingIndicator.text = "Loading Streams..."
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"

  if m.streamFetcher <> invalid then m.streamFetcher.control = "STOP"

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
  end if
end sub

sub stopStreamLoading(message as string)
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
    return
  end if

  torrents = m.streamFetcher.content.torrents
  if torrents = invalid or GetInterface(torrents, "ifArray") = invalid or torrents.count() = 0
    print "No valid torrent found for episode"
    return
  end if

  availableTorrents = {}
  for each t in torrents
    q = "unknown"
    if t.quality <> invalid then q = LCase(t.quality)
    if q = "4k" then q = "2160p"

    if q = "720p" or q = "1080p" or q = "2160p"
      existing = availableTorrents[q]
      replaceExisting = existing = invalid
      candidateIsHdr = isHdrTorrent(t)
      candidateLanguageRank = getLanguageRank(t)
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
        availableTorrents[q] = {
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

  if availableTorrents.count() = 0
    print "No supported torrent qualities found for episode"
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
    hdPosterUrl: episode.hdPosterUrl,
    hdBackgroundImageUrl: episode.hdPosterUrl,
    description: episode.description,
    selectedQuality: selectedTorrent.quality
  })

  for each q in availableTorrents
    t = availableTorrents[q]
    if q = "720p" and t.hash <> invalid
      playbackNode.addFields({ torrent720pHash: t.hash, torrent720pMagnet: t.magnet, torrent720pSeeds: t.seeds, torrent720pFile: t.file })
    else if q = "1080p" and t.hash <> invalid
      playbackNode.addFields({ torrent1080pHash: t.hash, torrent1080pMagnet: t.magnet, torrent1080pSeeds: t.seeds, torrent1080pFile: t.file })
    else if q = "2160p" and t.hash <> invalid
      playbackNode.addFields({ torrent2160pHash: t.hash, torrent2160pMagnet: t.magnet, torrent2160pSeeds: t.seeds, torrent2160pFile: t.file })
    end if
  end for

  m.top.contentSelected = playbackNode
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

function buildStreamUrl(hash as string, fileIdx as dynamic) as string
  if fileIdx <> invalid
    return resolveBackendPath("/v1/stream/" + hash + "/" + fileIdx.toStr() + "/master.m3u8")
  end if

  return resolveBackendPath("/v1/stream/" + hash + "/master.m3u8")
end function
