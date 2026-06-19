' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' Called when the HeroScreen component is initialized
sub Init()
  'Uncomment the print statements to see where and when the functions are called
  print "HeroScreen.brs - [init]"

  'Get references to child nodes
  m.RowList = m.top.findNode("RowList")
  m.background = m.top.findNode("Background")
  m.currentBackgroundUri = ""

  ' Initialize Fetchers
  m.movieFetcher = CreateObject("roSGNode", "SpamFilmsFetcher")
  m.movieFetcher.observeField("content", "onMoviesLoaded")
  
  m.seriesFetcher = CreateObject("roSGNode", "SpamFilmsFetcher")
  m.seriesFetcher.observeField("content", "onSeriesLoaded")
  
  ' State
  m.MoviesContent = invalid
  m.SeriesContent = invalid
  m.CurrentCategory = "home" ' Default
  
  ' Start fetching
  m.movieFetcher.contentType = "movies"
  m.movieFetcher.page = 1
  m.movieFetcher.sort = "trending"
  m.movieFetcher.genre = "All"
  m.movieFetcher.control = "RUN"
  
  m.seriesFetcher.contentType = "series"
  m.seriesFetcher.page = 1
  m.seriesFetcher.sort = "trending"
  m.seriesFetcher.genre = "All"
  m.seriesFetcher.control = "RUN"

  'Create observer events for when content is loaded
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")
end sub

sub onMoviesLoaded()
  print "HeroScreen.brs - [onMoviesLoaded]"
  m.MoviesContent = m.movieFetcher.content
  if m.CurrentCategory = "home"
     combineAndShowHome()
  else if m.CurrentCategory = "movies"
     updateDisplay(m.MoviesContent)
  end if
end sub

sub onSeriesLoaded()
  print "HeroScreen.brs - [onSeriesLoaded]"
  m.SeriesContent = m.seriesFetcher.content
  if m.CurrentCategory = "home"
     combineAndShowHome()
  else if m.CurrentCategory = "series"
     updateDisplay(m.SeriesContent)
  end if
end sub

sub loadCategory(category as string)
  print "HeroScreen.brs - loadCategory: " + category
  m.CurrentCategory = category
  
  if category = "movies"
     if m.MoviesContent <> invalid
        updateDisplay(m.MoviesContent)
     end if
  else if category = "series"
     if m.SeriesContent <> invalid
        updateDisplay(m.SeriesContent)
     end if
  else if category = "home"
     combineAndShowHome()
  else if category = "watchlist"
     showWatchlistOnly()
  end if
end sub

sub combineAndShowHome()
    ' Combine Movies and Series rows into one list
    print "HeroScreen - Combining Home Content"
    combined = CreateObject("roSGNode", "ContentNode")
    
    ' ADD WATCHLIST ROW FIRST
    watchlistArr = getWatchlist()
    if watchlistArr <> invalid and watchlistArr.Count() > 0
        watchlistRow = combined.createChild("ContentNode")
        watchlistRow.Title = "Your Watchlist"
        for each wItem in watchlistArr
            itemNode = watchlistRow.createChild("ContentNode")
            if wItem.id <> invalid then itemNode.id = wItem.id
            if wItem.title <> invalid then itemNode.title = wItem.title
            if wItem.type <> invalid then itemNode.contentType = wItem.type
            if wItem.poster <> invalid then itemNode.HDPosterUrl = wItem.poster
            if wItem.background <> invalid then itemNode.hdBackgroundImageUrl = wItem.background
            if wItem.description <> invalid then itemNode.description = wItem.description
            itemNode.Categories = "watchlist"
        end for
    end if
    
    if m.MoviesContent <> invalid
       for i = 0 to m.MoviesContent.getChildCount() - 1
           row = m.MoviesContent.getChild(i)
           ' Clone row? or just append reference?
           ' RowList content structure ensures rows are children.
           ' We can append the SAME row node to multiple parents?
           ' SceneGraph nodes can only have ONE parent.
           ' So we must CLONE the row node if we want to show it in multiple lists without stripping it from the old one.
           
           ' Actually, cloning is expensive.
           ' Since we only show ONE screen at a time, maybe we can re-parent?
           ' But m.MoviesContent IS the content of m.movieFetcher.
           ' If we steal its children, m.movieFetcher.content becomes empty.
           
           ' Better approach:
           ' Just clone the ROW node (lightweight container), pointing to same items?
           ' Yes, creating a new Row Node and adding the same child items (Items can be shared? No, strict hierarchy).
           
           ' If we can't share nodes, we have to clone.
           ' SpamFilmsFetcher creates NEW content every time we run it.
           
           ' Let's just clone logic:
           rowCopy = row.clone(true)
           rowCopy.Title = "Trending Movies"
           combined.appendChild(rowCopy)
       end for
    end if
    
    if m.SeriesContent <> invalid
       for i = 0 to m.SeriesContent.getChildCount() - 1
           row = m.SeriesContent.getChild(i)
           rowCopy = row.clone(true)
           rowCopy.Title = "Trending Series"
           combined.appendChild(rowCopy)
       end for
    end if
    
    updateDisplay(combined)
end sub

sub updateDisplay(content as object)
  if content <> invalid
     m.top.content = content
     m.top.numBadRequests = 0
     m.rowList.setFocus(true) 
  end if
end sub

' handler of focused item in RowList
sub OnItemFocused()
  itemFocused = m.top.itemFocused
  if itemFocused.Count() = 2 then
    if m.top.content <> invalid
        row = m.top.content.getChild(itemFocused[0])
        if row <> invalid
            focusedContent = row.getChild(itemFocused[1])
            if focusedContent <> invalid then
              m.top.focusedContent = focusedContent
              newUri = focusedContent.hdBackgroundImageUrl
              ' Only update the background when the art actually changes to avoid flicker
              if m.currentBackgroundUri <> newUri and newUri <> invalid then
                m.currentBackgroundUri = newUri
                m.background.uri = newUri
              end if
            end if
        end if
    end if
  end if
end sub

' sets proper focus to RowList in case channel returns from Details Screen
sub onVisibleChange()
  'print "HeroScreen.brs - [onVisibleChange]"
  if m.top.visible then m.rowList.setFocus(true)
end sub

' set proper focus to RowList in case if return from Details Screen
sub onFocusedChildChange()
  if m.top.isInFocusChain() and not m.rowList.hasFocus() then m.rowList.setFocus(true)
end sub

sub showWatchlistOnly()
    combined = CreateObject("roSGNode", "ContentNode")
    watchlistArr = getWatchlist()
    if watchlistArr <> invalid and watchlistArr.Count() > 0
        watchlistRow = combined.createChild("ContentNode")
        watchlistRow.Title = "Your Watchlist"
        for each wItem in watchlistArr
            itemNode = watchlistRow.createChild("ContentNode")
            if wItem.id <> invalid then itemNode.id = wItem.id
            if wItem.title <> invalid then itemNode.title = wItem.title
            if wItem.type <> invalid then itemNode.contentType = wItem.type
            if wItem.poster <> invalid then itemNode.HDPosterUrl = wItem.poster
            if wItem.background <> invalid then itemNode.hdBackgroundImageUrl = wItem.background
            if wItem.description <> invalid then itemNode.description = wItem.description
            itemNode.Categories = "watchlist"
        end for
    end if
    updateDisplay(combined)
end sub
