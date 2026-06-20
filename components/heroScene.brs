' 1st function that runs for the scene on channel startup
sub init()
  print "HeroScene.brs - [init] - Starting scene initialization"

  m.TopMenu = m.top.findNode("TopMenu")
  m.HeroScreen = m.top.findNode("HeroScreen")
  m.DetailsScreen = m.top.findNode("DetailsScreen")
  m.SettingsScreen = m.top.findNode("SettingsScreen")
  m.SearchScreen = m.top.findNode("SearchScreen")
  m.EpisodeSelectScreen = m.top.findNode("EpisodeSelectScreen")
  m.SplashScreen = m.top.findNode("SplashScreen")
  m.ProfileSelectScreen = m.top.findNode("ProfileSelectScreen")

  menuParent = CreateObject("roSGNode", "ContentNode")
  menuRow = menuParent.createChild("ContentNode")

  homeItem = menuRow.createChild("ContentNode")
  homeItem.title = "Home"

  moviesItem = menuRow.createChild("ContentNode")
  moviesItem.title = "Movies"

  tvItem = menuRow.createChild("ContentNode")
  tvItem.title = "TV Shows"

  searchItem = menuRow.createChild("ContentNode")
  searchItem.title = "Search"

  settingsItem = menuRow.createChild("ContentNode")
  settingsItem.title = "Settings"

  m.TopMenu.content = menuParent

  if m.HeroScreen <> invalid
    m.HeroScreen.observeField("rowItemSelected", "OnRowItemSelected")
  end if
  if m.DetailsScreen <> invalid
    m.DetailsScreen.observeField("videoPlayerVisible", "onVideoPlayerVisibleChange")
  end if
  if m.SearchScreen <> invalid
    m.SearchScreen.observeField("contentSelected", "onSearchResultSelected")
  end if
  if m.TopMenu <> invalid
    m.TopMenu.observeField("rowItemSelected", "OnMenuItemSelected")
  end if
  if m.EpisodeSelectScreen <> invalid
    m.EpisodeSelectScreen.observeField("contentSelected", "onEpisodeSelected")
  end if
  if m.SplashScreen <> invalid
    m.SplashScreen.observeField("animationComplete", "onSplashComplete")
  end if
  if m.ProfileSelectScreen <> invalid
    m.ProfileSelectScreen.observeField("profileSelected", "onProfileSelected")
  end if

  m.SplashScreen.setFocus(true)
  m.SplashScreen.ready = true

  print "HeroScene.brs - [init] - Scene initialization complete"
end sub

' Called when a key on the remote is pressed
function onKeyEvent(key as String, press as Boolean) as Boolean
  print ">>> HeroScene >> OnkeyEvent "; key

  if not press then return false

  if m.SplashScreen.visible = true
    return true
  else if m.ProfileSelectScreen.visible = true
    if key = "back" then return false
    return false
  end if

  if key = "down"
    if m.TopMenu.isInFocusChain()
      m.HeroScreen.setFocus(true)
      return true
    end if
  else if key = "up"
    if m.HeroScreen.isInFocusChain()
      focusedInfo = m.HeroScreen.itemFocused
      if focusedInfo = invalid or focusedInfo.count() = 0 or focusedInfo[0] = 0
        m.TopMenu.setFocus(true)
        return true
      end if
    end if
  else if key = "back"
    if m.DetailsScreen.visible = true
      m.DetailsScreen.visible = false
      if m.detailsReturnScreen = "episodes"
        m.EpisodeSelectScreen.visible = true
        m.EpisodeSelectScreen.callFunc("prepareForDisplay")
        m.EpisodeSelectScreen.setFocus(true)
        m.detailsReturnScreen = ""
      else
        showDashboard()
      end if
      return true
    else if m.EpisodeSelectScreen.visible = true
      m.EpisodeSelectScreen.visible = false
      showDashboard()
      return true
    else if m.SearchScreen.visible = true
      toggleSearch()
      return true
    else if m.SettingsScreen.visible = true
      toggleSettings()
      return true
    else if m.HeroScreen.visible = true
      ' Allow Roku OS to show the app exit dialog.
      return false
    end if
  end if

  return false
end function

sub OnMenuItemSelected()
  print "HeroScene.brs - [OnMenuItemSelected]"
  selection = m.TopMenu.rowItemSelected
  if selection = invalid or selection.count() <= 1 then return

  index = selection[1]
  print "Menu Index Selected: "; index

  if index = 3
    toggleSearch()
  else if index = 4
    toggleSettings()
  else
    m.SearchScreen.visible = false
    m.SettingsScreen.visible = false
    m.EpisodeSelectScreen.visible = false
    m.DetailsScreen.visible = false
    showDashboard()

    category = "home"
    if index = 1
      category = "movies"
    else if index = 2
      category = "series"
    end if

    m.HeroScreen.callFunc("loadCategory", category)
    m.HeroScreen.setFocus(true)
  end if
end sub

sub toggleSearch()
  if m.SearchScreen.visible = true
    m.SearchScreen.visible = false
    showDashboard()
  else
    m.HeroScreen.visible = false
    m.SettingsScreen.visible = false
    m.EpisodeSelectScreen.visible = false
    m.DetailsScreen.visible = false
    m.TopMenu.visible = false
    m.SearchScreen.callFunc("setSearchContext", "all")
    m.SearchScreen.callFunc("resetState")
    m.SearchScreen.visible = true
    m.SearchScreen.setFocus(true)
  end if
end sub

sub toggleSettings()
  if m.SettingsScreen.visible = true
    m.SettingsScreen.visible = false
    showDashboard()
  else
    m.HeroScreen.visible = false
    m.SearchScreen.visible = false
    m.EpisodeSelectScreen.visible = false
    m.DetailsScreen.visible = false
    m.TopMenu.visible = false
    m.SettingsScreen.visible = true
    m.SettingsScreen.setFocus(true)
  end if
end sub

sub onSplashComplete()
  print "HeroScene.brs - [onSplashComplete]"
  m.SplashScreen.visible = false
  m.ProfileSelectScreen.visible = true
  m.ProfileSelectScreen.setFocus(true)
end sub

sub onProfileSelected()
  print "HeroScene.brs - [onProfileSelected]"
  m.ProfileSelectScreen.visible = false
  showDashboard()
end sub

sub showDashboard()
  m.SplashScreen.visible = false
  m.ProfileSelectScreen.visible = false
  m.HeroScreen.visible = true
  m.TopMenu.visible = true
  m.HeroScreen.setFocus(true)
end sub

sub OnRowItemSelected()
  print "HeroScene.brs - [OnRowItemSelected] FIRED"
  selection = m.HeroScreen.rowItemSelected
  if selection <> invalid and selection.count() = 2 and m.HeroScreen.content <> invalid
    row = m.HeroScreen.content.getChild(selection[0])
    if row <> invalid
      item = row.getChild(selection[1])
      handleItemSelected(item)
      return
    end if
  end if

  print "HeroScene.brs - Warning: Selection was invalid, falling back to focusedContent"
  handleItemSelected(m.HeroScreen.focusedContent)
end sub

sub onSearchResultSelected()
  print "HeroScene.brs - [onSearchResultSelected]"
  item = m.SearchScreen.contentSelected
  if item <> invalid
    ' Selection is a one-shot event. Clear the node reference before Details
    ' mutates it with stream and torrent fields.
    m.SearchScreen.contentSelected = invalid
    m.SearchScreen.visible = false
    handleItemSelected(item)
  end if
end sub

sub handleItemSelected(item as object)
  if item = invalid then return

  cType = item.getField("cType")
  if cType = invalid then cType = item.contentType

  if cType <> invalid and LCase(cType) = "series"
    showEpisodeSelectScreen(item)
  else
    showDetailsScreen(item)
  end if
end sub

sub showEpisodeSelectScreen(item as object)
  m.HeroScreen.visible = false
  m.SearchScreen.visible = false
  m.SettingsScreen.visible = false
  m.DetailsScreen.visible = false
  m.TopMenu.visible = false
  m.EpisodeSelectScreen.item = item
  m.EpisodeSelectScreen.visible = true
  m.EpisodeSelectScreen.setFocus(true)
end sub

sub onEpisodeSelected()
  episode = m.EpisodeSelectScreen.contentSelected
  if episode <> invalid
    m.detailsReturnScreen = "episodes"
    showDetailsScreen(episode)
  end if
end sub

sub showDetailsScreen(item as object)
  m.SearchScreen.visible = false
  m.SettingsScreen.visible = false

  if m.EpisodeSelectScreen.visible = false then m.detailsReturnScreen = "dashboard"

  m.HeroScreen.visible = false
  m.EpisodeSelectScreen.visible = false
  m.TopMenu.visible = false

  m.DetailsScreen.content = item
  m.DetailsScreen.visible = true
  m.DetailsScreen.setFocus(true)
end sub

sub onVideoPlayerVisibleChange()
  if m.DetailsScreen.videoPlayerVisible = true
    m.TopMenu.visible = false
  else
    if m.SplashScreen.visible = false and m.ProfileSelectScreen.visible = false and m.DetailsScreen.visible = false and m.EpisodeSelectScreen.visible = false
      m.TopMenu.visible = true
    end if
  end if
end sub
