sub init()
  print "SplashScreen: Initializing"
  m.background = m.top.findNode("background")
  m.title = m.top.findNode("title")
  m.subtitle = m.top.findNode("subtitle")
  m.fadeOut = m.top.findNode("fadeOut")
  
  if m.fadeOut <> invalid
    m.fadeOut.observeField("state", "onAnimationComplete")
    print "SplashScreen: Animation observer set"
  else
    print "SplashScreen: ERROR - fadeOut animation not found"
  end if
end sub

sub onAnimationComplete()
  print "SplashScreen: onAnimationComplete state = " ; m.fadeOut.state
  if m.fadeOut <> invalid and m.fadeOut.state = "stopped"
    print "SplashScreen: Animation finished, hiding"
    m.top.visible = false
    ' Signal parent to show HeroScreen
    m.top.animationComplete = true
  end if
end sub

sub onReady()
  print "SplashScreen: Ready signal received"
  if m.top.ready = true and m.fadeOut <> invalid
    print "SplashScreen: Starting fade out animation"
    m.fadeOut.control = "start"
  end if
end sub


