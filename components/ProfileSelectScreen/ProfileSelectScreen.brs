sub init()
  m.grid = m.top.findNode("profileMarkupGrid")
  m.grid.observeField("itemSelected", "onItemSelected")
  
  m.top.observeField("visible", "onVisibleChange")
  
  buildProfiles()
end sub

sub onVisibleChange()
  if m.top.visible = true
    m.grid.setFocus(true)
  end if
end sub

sub buildProfiles()
  profiles = [
    { title: "Admin", description: "AD", id: "admin" }
    { title: "Guest", description: "GU", id: "guest" }
    { title: "Kids", description: "KI", id: "kids" }
    { title: "Retro", description: "RE", id: "retro" }
  ]
  
  parent = CreateObject("roSGNode", "ContentNode")
  for each p in profiles
    item = parent.createChild("ContentNode")
    item.title = p.title
    item.description = p.description
    item.addFields({ id: p.id })
  end for
  
  m.grid.content = parent
end sub

sub onItemSelected()
  selectedIndex = m.grid.itemSelected
  if selectedIndex >= 0 and m.grid.content <> invalid
    selectedNode = m.grid.content.getChild(selectedIndex)
    if selectedNode <> invalid
      m.top.profileSelected = {
        id: selectedNode.getField("id"),
        name: selectedNode.title,
        avatar: selectedNode.description
      }
      print "ProfileSelectScreen: Profile Selected: " + selectedNode.title
    end if
  end if
end sub
