sub init()
  m.cardFrame = m.top.findNode("cardFrame")
  m.focusBorder = m.top.findNode("focusBorder")
  m.avatarLabel = m.top.findNode("avatarLabel")
  m.nameLabel = m.top.findNode("nameLabel")
end sub

sub onContentChange()
  content = m.top.itemContent
  if content <> invalid
    m.nameLabel.text = content.title
    ' We use the Description field to store the giant emoji avatar
    if content.description <> invalid and content.description <> ""
      m.avatarLabel.text = content.description
    end if
    if content.title = "Admin"
      m.cardFrame.color = "0x24506BFF"
    else if content.title = "Guest"
      m.cardFrame.color = "0x3B4252FF"
    else if content.title = "Kids"
      m.cardFrame.color = "0x57436BFF"
    else
      m.cardFrame.color = "0x5B4639FF"
    end if
  end if
end sub

sub onFocusChange()
  ' MarkupGrid sets focusPercent between 0.0 and 1.0 as focus transitions
  if m.top.focusPercent > 0.5
    m.focusBorder.visible = true
    m.nameLabel.color = "0xFFFFFFFF"
    m.top.scale = [1.05, 1.05]
  else
    m.focusBorder.visible = false
    m.nameLabel.color = "0xAAAAAAFF"
    m.top.scale = [1.0, 1.0]
  end if
end sub
