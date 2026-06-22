sub init()
  m.keyboard = m.top.findNode("keyboard")
  m.resultsGrid = m.top.findNode("resultsGrid")
  m.loadingIndicator = m.top.findNode("loadingIndicator")
  m.statusLabel = m.top.findNode("statusLabel")
  m.resultsHeading = m.top.findNode("resultsHeading")
  m.searchSubtitle = m.top.findNode("searchSubtitle")
  m.searchButton = m.top.findNode("searchButton")
  m.searchActionPanel = m.top.findNode("searchActionPanel")

  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false
  m.keyboard.textEditBox.hintText = "Search movies & TV shows..."

  m.searchButton.observeField("buttonSelected", "onSearchButtonSelected")
  m.keyboard.observeField("text", "onQueryChanged")
  m.resultsGrid.observeField("rowItemSelected", "onItemSelected")
  m.top.observeField("focusedChild", "onFocusedChildChange")

  m.queryTimer = CreateObject("roSGNode", "Timer")
  m.queryTimer.duration = 0.65
  m.queryTimer.repeat = false
  m.queryTimer.observeField("fire", "onQueryTimerFired")

  m.selectionTimer = CreateObject("roSGNode", "Timer")
  m.selectionTimer.duration = 0.3
  m.selectionTimer.repeat = false
  m.selectionTimer.observeField("fire", "enableResultSelection")

  m.movieFetcher = invalid
  m.seriesFetcher = invalid
  m.idResolver = invalid
  m.pendingSelection = invalid
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  m.moviesDone = false
  m.seriesDone = false
  m.resultsMode = false
  m.acceptSelections = false
  m.lastResultCount = 0
  m.Context = "all"
end sub

sub onQueryChanged()
  if m.resultsMode then return

  m.queryTimer.control = "stop"
  if m.keyboard.text.Len() >= 2
    m.statusLabel.text = "Searching..."
    m.statusLabel.color = "0xA9ADB7FF"
    m.queryTimer.control = "start"
  else
    m.statusLabel.text = "Enter at least 2 characters to search."
    m.statusLabel.color = "0xA9ADB7FF"
  end if
end sub

sub onQueryTimerFired()
  if not m.resultsMode and m.keyboard.text.Len() >= 2 then doSearch()
end sub

sub setSearchContext(context as string)
  m.Context = context
  if context = "movies"
    m.keyboard.textEditBox.hintText = "Search movies..."
  else if context = "series"
    m.keyboard.textEditBox.hintText = "Search TV shows..."
  else
    m.keyboard.textEditBox.hintText = "Search movies & TV shows..."
  end if
end sub

sub resetState()
  print "SearchScreen - Resetting State"
  stopFetcher(m.movieFetcher)
  stopFetcher(m.seriesFetcher)
  stopResolver()
  m.movieFetcher = invalid
  m.seriesFetcher = invalid
  m.pendingSelection = invalid
  m.keyboard.text = ""
  m.queryTimer.control = "stop"
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  m.resultsGrid.content = m.searchResults
  m.moviesDone = false
  m.seriesDone = false
  m.lastResultCount = 0
  m.acceptSelections = false
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.statusLabel.text = "Enter at least 2 characters to search."
  m.statusLabel.color = "0xA9ADB7FF"
  showInputMode()
end sub

sub onFocusedChildChange()
  if m.top.hasFocus() then m.keyboard.setFocus(true)
end sub

sub onSearchButtonSelected()
  if m.resultsMode
    showInputMode()
    m.keyboard.setFocus(true)
  else
    doSearch()
  end if
end sub

sub doSearch()
  query = m.keyboard.text
  print "SearchScreen - doSearch triggered with query: [" + query + "] Context: " + m.Context

  if query.Len() < 2
    m.statusLabel.text = "Enter at least 2 characters to search."
    m.statusLabel.color = "0xF0B95BFF"
    m.keyboard.setFocus(true)
    return
  end if

  stopFetcher(m.movieFetcher)
  stopFetcher(m.seriesFetcher)
  m.movieFetcher = invalid
  m.seriesFetcher = invalid

  m.searchButton.text = "Searching..."
  m.statusLabel.text = "Searching movies and TV shows..."
  m.statusLabel.color = "0xA9ADB7FF"
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"
  m.acceptSelections = false
  m.moviesDone = false
  m.seriesDone = false
  m.searchResults = CreateObject("roSGNode", "ContentNode")

  if m.Context = "movies"
    m.movieFetcher = createFetcher("movies", query, "onMoviesReady")
    m.seriesDone = true
  else if m.Context = "series"
    m.seriesFetcher = createFetcher("series", query, "onSeriesReady")
    m.moviesDone = true
  else
    m.movieFetcher = createFetcher("movies", query, "onMoviesReady")
    m.seriesFetcher = createFetcher("series", query, "onSeriesReady")
  end if
end sub

function createFetcher(contentType as string, query as string, callbackName as string) as object
  fetcher = CreateObject("roSGNode", "MetadataSearchFetcher")
  fetcher.contentType = contentType
  fetcher.query = query
  fetcher.observeField("content", callbackName)
  fetcher.control = "RUN"
  return fetcher
end function

sub stopFetcher(fetcher as object)
  if fetcher <> invalid
    fetcher.unobserveField("content")
    fetcher.control = "STOP"
  end if
end sub

sub onMoviesReady()
  if m.movieFetcher = invalid or m.moviesDone then return
  print "SearchScreen - Movies Ready"
  m.moviesDone = true
  checkAllDone()
end sub

sub onSeriesReady()
  if m.seriesFetcher = invalid or m.seriesDone then return
  print "SearchScreen - Series Ready"
  m.seriesDone = true
  checkAllDone()
end sub

sub checkAllDone()
  if not (m.moviesDone and m.seriesDone) then return

  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  movieCount = 0
  seriesCount = 0

  if m.movieFetcher <> invalid and m.movieFetcher.content <> invalid and m.movieFetcher.content.getChildCount() > 0
    movieRow = m.movieFetcher.content.getChild(0)
    movieRow.title = "Movies"
    movieCount = movieRow.getChildCount()
    m.searchResults.appendChild(movieRow)
  end if

  if m.seriesFetcher <> invalid and m.seriesFetcher.content <> invalid and m.seriesFetcher.content.getChildCount() > 0
    seriesRow = m.seriesFetcher.content.getChild(0)
    seriesRow.title = "TV Shows"
    seriesCount = seriesRow.getChildCount()
    m.searchResults.appendChild(seriesRow)
  end if

  m.resultsGrid.content = m.searchResults
  totalCount = movieCount + seriesCount
  m.lastResultCount = totalCount
  if totalCount > 0
    showResultsMode()
    m.statusLabel.text = totalCount.toStr() + " results"
    m.statusLabel.color = "0xA9ADB7FF"
    m.selectionTimer.control = "stop"
    m.selectionTimer.control = "start"
  else
    m.searchButton.text = "Search"
    if fetchersFailed()
      m.statusLabel.text = "Search is temporarily unavailable."
    else
      m.statusLabel.text = "No movies or TV shows found."
    end if
    m.statusLabel.color = "0xF0B95BFF"
    m.searchButton.setFocus(true)
  end if
end sub

function fetchersFailed() as boolean
  movieFailed = m.movieFetcher <> invalid and m.movieFetcher.hasError
  seriesFailed = m.seriesFetcher <> invalid and m.seriesFetcher.hasError
  return movieFailed or seriesFailed
end function

sub enableResultSelection()
  if m.resultsMode and m.resultsGrid.visible
    m.acceptSelections = true
    m.resultsGrid.setFocus(true)
  end if
end sub

sub onItemSelected()
  if not m.acceptSelections or not m.resultsGrid.isInFocusChain() then return
  focused = m.resultsGrid.rowItemFocused
  if focused = invalid or focused.count() <> 2 then return

  row = m.resultsGrid.content.getChild(focused[0])
  if row = invalid then return
  item = row.getChild(focused[1])
  if item = invalid then return

  m.acceptSelections = false
  imdbId = item.getField("imdbId")
  if imdbId <> invalid and imdbId <> ""
    m.top.contentSelected = item
    return
  end if

  tmdbId = item.getField("tmdbId")
  tmdbType = item.getField("tmdbType")
  if tmdbId = invalid or tmdbId = "" or tmdbType = invalid
    showSelectionError("This title is missing required metadata.")
    return
  end if

  stopResolver()
  m.pendingSelection = item
  m.loadingIndicator.text = "Loading title details..."
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"
  m.statusLabel.text = "Resolving title availability..."
  m.idResolver = CreateObject("roSGNode", "ExternalIdResolver")
  m.idResolver.tmdbId = tmdbId
  m.idResolver.mediaType = tmdbType
  m.idResolver.observeField("imdbId", "onExternalIdResolved")
  m.idResolver.control = "RUN"
end sub

sub onExternalIdResolved()
  if m.idResolver = invalid then return

  resolvedId = m.idResolver.imdbId
  selectedItem = m.pendingSelection
  stopResolver()
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false

  if selectedItem = invalid or resolvedId = invalid or resolvedId = ""
    showSelectionError("This title is listed by TMDB but has no IMDb mapping for playback.")
    return
  end if

  selectedItem.setFields({
    imdbId: resolvedId,
    needsEnrichment: true
  })
  print "SearchScreen: selected TMDB title resolved to " + resolvedId
  m.statusLabel.text = m.lastResultCount.toStr() + " results"
  m.statusLabel.color = "0xA9ADB7FF"
  m.pendingSelection = invalid
  m.top.contentSelected = selectedItem
end sub

sub stopResolver()
  if m.idResolver <> invalid
    m.idResolver.unobserveField("imdbId")
    m.idResolver.control = "STOP"
    m.idResolver = invalid
  end if
end sub

sub showSelectionError(message as string)
  m.pendingSelection = invalid
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.statusLabel.text = message
  m.statusLabel.color = "0xF0B95BFF"
  m.acceptSelections = true
  m.resultsGrid.setFocus(true)
end sub

sub showInputMode()
  m.resultsMode = false
  m.acceptSelections = false
  m.keyboard.visible = true
  m.searchSubtitle.visible = true
  m.searchButton.text = "Search"
  m.searchButton.translation = [1540, 510]
  m.statusLabel.translation = [1540, 630]
  m.statusLabel.width = 250
  m.searchActionPanel.visible = true
  m.resultsHeading.visible = false
  m.resultsGrid.visible = false
end sub

sub showResultsMode()
  m.resultsMode = true
  m.keyboard.visible = false
  m.searchSubtitle.visible = false
  m.searchButton.text = "Edit Search"
  m.searchButton.translation = [96, 115]
  m.statusLabel.translation = [410, 145]
  m.statusLabel.width = 600
  m.searchActionPanel.visible = false
  m.resultsHeading.visible = true
  m.resultsGrid.visible = true
end sub

sub restoreResultsFocus()
  if m.resultsMode and m.resultsGrid.content <> invalid
    m.statusLabel.text = m.lastResultCount.toStr() + " results"
    m.statusLabel.color = "0xA9ADB7FF"
    m.acceptSelections = true
    m.resultsGrid.visible = true
    m.resultsGrid.setFocus(true)
  else
    m.keyboard.setFocus(true)
  end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "back"
    if m.idResolver <> invalid
      stopResolver()
      m.pendingSelection = invalid
      m.loadingIndicator.control = "stop"
      m.loadingIndicator.visible = false
      m.statusLabel.text = "Selection canceled."
      m.acceptSelections = true
      m.resultsGrid.setFocus(true)
      return true
    else if m.resultsGrid.isInFocusChain()
      showInputMode()
      m.keyboard.setFocus(true)
      return true
    else if m.searchButton.hasFocus()
      m.keyboard.setFocus(true)
      return true
    end if
  else if key = "down"
    if m.keyboard.isInFocusChain()
      m.searchButton.setFocus(true)
      return true
    else if m.searchButton.hasFocus() and m.resultsMode
      m.resultsGrid.setFocus(true)
      return true
    end if
  else if key = "up"
    if m.resultsGrid.isInFocusChain()
      m.searchButton.setFocus(true)
      return true
    else if m.searchButton.hasFocus() and not m.resultsMode
      m.keyboard.setFocus(true)
      return true
    end if
  else if key = "right"
    if m.keyboard.isInFocusChain()
      m.searchButton.setFocus(true)
      return true
    end if
  else if key = "left"
    if m.searchButton.hasFocus() and not m.resultsMode
      m.keyboard.setFocus(true)
      return true
    end if
  end if

  return false
end function
