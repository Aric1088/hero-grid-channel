sub init()
  m.keyboard = m.top.findNode("keyboard")
  m.resultsGrid = m.top.findNode("resultsGrid")
  m.loadingIndicator = m.top.findNode("loadingIndicator")
  m.statusLabel = m.top.findNode("statusLabel")
  m.resultsHeading = m.top.findNode("resultsHeading")
  m.searchSubtitle = m.top.findNode("searchSubtitle")
  m.searchButton = m.top.findNode("searchButton")

  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false
  m.keyboard.textEditBox.hintText = "Search movies & TV shows..."

  m.searchButton.observeField("buttonSelected", "onSearchButtonSelected")
  m.resultsGrid.observeField("rowItemSelected", "onItemSelected")
  m.top.observeField("focusedChild", "onFocusedChildChange")

  m.selectionTimer = CreateObject("roSGNode", "Timer")
  m.selectionTimer.duration = 0.3
  m.selectionTimer.repeat = false
  m.selectionTimer.observeField("fire", "enableResultSelection")

  m.movieFetcher = invalid
  m.seriesFetcher = invalid
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  m.moviesDone = false
  m.seriesDone = false
  m.resultsMode = false
  m.acceptSelections = false
  m.Context = "all"
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
  m.movieFetcher = invalid
  m.seriesFetcher = invalid
  m.keyboard.text = ""
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  m.resultsGrid.content = m.searchResults
  m.moviesDone = false
  m.seriesDone = false
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
  fetcher = CreateObject("roSGNode", "SpamFilmsFetcher")
  fetcher.contentType = contentType
  fetcher.keywords = query
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
  if totalCount > 0
    showResultsMode()
    m.statusLabel.text = totalCount.toStr() + " results"
    m.statusLabel.color = "0xA9ADB7FF"
    m.selectionTimer.control = "stop"
    m.selectionTimer.control = "start"
  else
    m.searchButton.text = "Search"
    m.statusLabel.text = "No movies or TV shows found."
    m.statusLabel.color = "0xF0B95BFF"
    m.searchButton.setFocus(true)
  end if
end sub

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
  m.top.contentSelected = item
end sub

sub showInputMode()
  m.resultsMode = false
  m.acceptSelections = false
  m.keyboard.visible = true
  m.searchSubtitle.visible = true
  m.searchButton.text = "Search"
  m.searchButton.translation = [1580, 500]
  m.statusLabel.translation = [1510, 620]
  m.statusLabel.width = 300
  m.resultsHeading.visible = false
  m.resultsGrid.visible = false
end sub

sub showResultsMode()
  m.resultsMode = true
  m.keyboard.visible = false
  m.searchSubtitle.visible = false
  m.searchButton.text = "Edit Search"
  m.searchButton.translation = [110, 115]
  m.statusLabel.translation = [430, 145]
  m.statusLabel.width = 600
  m.resultsHeading.visible = true
  m.resultsGrid.visible = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if key = "back"
    if m.resultsGrid.isInFocusChain()
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
  end if

  return false
end function
