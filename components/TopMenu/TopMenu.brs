sub Init()
  m.RowList = m.top.findNode("MenuRowList")
  m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
  if m.top.isInFocusChain() and not m.RowList.hasFocus()
    m.RowList.setFocus(true)
  end if
end sub
