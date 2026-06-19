sub init()
  m.keyboard = m.top.findNode("keyboard")
  m.resultsGrid = m.top.findNode("resultsGrid")
  m.loadingIndicator = m.top.findNode("loadingIndicator")
  m.statusLabel = m.top.findNode("statusLabel")
  m.resultsHeading = m.top.findNode("resultsHeading")
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false

  m.keyboard.textEditBox.hintText = "Search movies & TV shows..."
  
  ' Explicit search button
  m.searchButton = m.top.findNode("searchButton")
  m.searchButton.observeField("buttonSelected", "doSearch")
  
  ' Create fetcher tasks
  m.movieFetcher = CreateObject("roSGNode", "SpamFilmsFetcher")
  m.movieFetcher.observeField("content", "onMoviesReady")
  
  m.seriesFetcher = CreateObject("roSGNode", "SpamFilmsFetcher")
  m.seriesFetcher.observeField("content", "onSeriesReady")
  
  m.resultsGrid.observeField("rowItemSelected", "onItemSelected")
  
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  
  ' Keep track of status
  m.moviesDone = false
  m.seriesDone = false

  ' Observe focus to delegate to children
  m.top.observeField("focusedChild", "onFocusedChildChange")
  
  m.Context = "all"
end sub

sub setSearchContext(context as string)
  print "SearchScreen - Context set to: " + context
  m.Context = context
  ' Update hint text?
  if context = "movies"
     m.keyboard.textEditBox.hintText = "Search Movies..."
  else if context = "series"
     m.keyboard.textEditBox.hintText = "Search TV Shows..."
  else
     m.keyboard.textEditBox.hintText = "Search movies & TV shows..."
  end if
end sub

sub resetState()
  print "SearchScreen - Resetting State"
  m.keyboard.text = ""
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  m.resultsGrid.content = m.searchResults
  m.moviesDone = false
  m.seriesDone = false
  m.loadingIndicator.control = "stop"
  m.loadingIndicator.visible = false
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false
  m.statusLabel.text = "Enter at least 2 characters to search."
  m.statusLabel.color = "0xA9ADB7FF"
end sub

sub onFocusedChildChange()
  ' If SearchScreen itself gets focus (no child has it), force it to keyboard
  if m.top.hasFocus() 
     m.keyboard.setFocus(true)
  end if
end sub

sub doSearch()
  query = m.keyboard.text
  print "SearchScreen - doSearch triggered with query: [" + query + "] Context: " + m.Context
  
  if query.Len() < 2
    print "SearchScreen - Query too short"
    m.statusLabel.text = "Enter at least 2 characters to search."
    m.statusLabel.color = "0xF0B95BFF"
    m.keyboard.setFocus(true)
    return
  end if
  
  m.searchButton.text = "Searching..."
  m.statusLabel.text = "Searching movies and TV shows..."
  m.statusLabel.color = "0xA9ADB7FF"
  m.resultsGrid.visible = false
  m.resultsHeading.visible = false
  m.loadingIndicator.visible = true
  m.loadingIndicator.control = "start"
  
  ' Reset
  m.moviesDone = false
  m.seriesDone = false
  m.searchResults = CreateObject("roSGNode", "ContentNode")
  
  ' Stop before restarting
  m.movieFetcher.control = "STOP"
  m.seriesFetcher.control = "STOP"
  
  if m.Context = "movies"
      ' Search Movies Only
      m.movieFetcher.contentType = "movies"
      m.movieFetcher.keywords = query
      m.movieFetcher.control = "RUN"
      ' Mark series as done (skipped)
      m.seriesDone = true
      
  else if m.Context = "series"
      ' Search Series Only
      m.seriesFetcher.contentType = "series"
      m.seriesFetcher.keywords = query
      m.seriesFetcher.control = "RUN"
      ' Mark movies as done (skipped)
      m.moviesDone = true
      
  else
      ' Search Both (Home/All)
      m.movieFetcher.contentType = "movies"
      m.movieFetcher.keywords = query
      m.movieFetcher.control = "RUN"
      
      m.seriesFetcher.contentType = "series"
      m.seriesFetcher.keywords = query
      m.seriesFetcher.control = "RUN"
  end if
end sub

sub onMoviesReady()
  print "SearchScreen - Movies Ready"
  m.moviesDone = true
  checkAllDone()
end sub

sub onSeriesReady()
  print "SearchScreen - Series Ready"
  m.seriesDone = true
  checkAllDone()
end sub

sub checkAllDone()
  if m.moviesDone and m.seriesDone
    m.loadingIndicator.control = "stop"
    m.loadingIndicator.visible = false
    m.searchButton.text = "Search"

    movieCount = 0
    seriesCount = 0

    if m.Context = "movies" or m.Context = "all" or m.Context = invalid
        if m.movieFetcher.content <> invalid and m.movieFetcher.content.getChildCount() > 0
           movieRow = m.movieFetcher.content.getChild(0)
           movieRow.Title = "Movies"
           movieCount = movieRow.getChildCount()
           m.searchResults.appendChild(movieRow)
        end if
    end if
    
    if m.Context = "series" or m.Context = "all" or m.Context = invalid
        if m.seriesFetcher.content <> invalid and m.seriesFetcher.content.getChildCount() > 0
           seriesRow = m.seriesFetcher.content.getChild(0)
           seriesRow.Title = "TV Shows"
           seriesCount = seriesRow.getChildCount()
           m.searchResults.appendChild(seriesRow)
        end if
    end if
    
    m.resultsGrid.content = m.searchResults
    
    if m.searchResults.getChildCount() > 0
      totalCount = movieCount + seriesCount
      m.resultsHeading.visible = true
      m.resultsGrid.visible = true
      m.statusLabel.text = totalCount.toStr() + " results"
      m.statusLabel.color = "0xA9ADB7FF"
      m.resultsGrid.setFocus(true)
    else
      m.resultsHeading.visible = false
      m.resultsGrid.visible = false
      m.statusLabel.text = "No movies or TV shows found."
      m.statusLabel.color = "0xF0B95BFF"
      m.searchButton.setFocus(true)
    end if
  end if
end sub

sub onItemSelected()
  row = m.resultsGrid.content.getChild(m.resultsGrid.rowItemFocused[0])
  item = row.getChild(m.resultsGrid.rowItemFocused[1])
  
  m.top.contentSelected = item
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if press
    if key = "back"
      if m.ResultsGrid.isInFocusChain()
        m.searchButton.setFocus(true)
        return true
      else if m.searchButton.hasFocus()
        m.keyboard.setFocus(true)
        return true
      end if
    else if key = "down"
      if m.keyboard.isInFocusChain()
        m.searchButton.setFocus(true)
        return true
      else if m.searchButton.hasFocus() and m.resultsGrid.visible and m.resultsGrid.content <> invalid and m.resultsGrid.content.getChildCount() > 0
        m.resultsGrid.setFocus(true)
        return true
      end if
    else if key = "up"
      if m.resultsGrid.isInFocusChain()
        m.searchButton.setFocus(true)
        return true
      else if m.searchButton.hasFocus()
        m.keyboard.setFocus(true)
        return true
      end if
    end if
  end if
  return false
end function
