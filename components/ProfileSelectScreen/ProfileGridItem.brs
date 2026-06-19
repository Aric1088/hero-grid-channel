sub init()
  m.cardFrame = m.top.findNode("cardFrame")
  m.cardInner = m.top.findNode("cardInner")
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
  end if
end sub

sub onFocusChange()
  ' MarkupGrid sets focusPercent between 0.0 and 1.0 as focus transitions
  if m.top.focusPercent > 0.5
    m.focusBorder.visible = true
    m.nameLabel.color = "0xFFFFFFFF" ' High contrast White
  else
    m.focusBorder.visible = false
    m.nameLabel.color = "0xAAAAAAFF" ' Soft Grey
  end if
end sub
