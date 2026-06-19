' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

 'setting top interfaces
Sub Init()
  print "Description.brs - [Init]"
  m.Title             = m.top.findNode("Title")
  m.DescriptionLabel  = m.top.findNode("Description")
  
End Sub

' Content change handler
' All fields population
Sub OnContentChanged()
  print "Description.brs - [OnContentChanged]"
  item = m.top.content

  title = item.title.toStr()
  if title <> invalid then
    m.Title.text = title.toStr()
  end if

  value = item.description
  if value <> invalid then
    if value.toStr() <> "" then
      m.DescriptionLabel.text = value.toStr()
    else
      m.DescriptionLabel.text = "No description"
    end if
  end if

  
End Sub
