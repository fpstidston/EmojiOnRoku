' Copyright Kasper Gammeltoft and other contributors. Licensed under MIT
' https://github.com/KasperGam/EmojiOnRoku/blob/main/LICENSE
sub init()
    m.components = m.top.findNode("layout")
    m.top.observeField("text", "setText")

    m.top.observeField("color", "updateComponents")
    m.top.observeField("lineSpacing", "updateComponents")

    ' If the emoji size is not set initiliase to a sample of the font height
    if m.top.emojiSize = 0
        label = createLabel("Sample")
        m.top.emojiSize = label.boundingRect().height
    end if
end sub

' Updates only fields that have no effect on layout
function updateComponents()
    ' Only update components if we are actually rendering text
    if m.top.text <> ""
        ' Set default line spacing to something reasonable
        if m.top.lineSpacing = 0
            m.components.itemSpacings = [ m.top.emojiSize / 4 ]
        end if

        comps = getAllComponents()
        for each comp in comps
            if comp.subtype() = "Label"
                comp.color = m.top.color
            end if
        end for
    end if
end function

' Updates the entire label components with new text. 
function setText()
    labelText = m.top.text

    ' This tracks the horizontal and vertical progress of the function
    cursor = {
        currWidth: 0
        currRow: Invalid
    }

    resetComponents()

    if labelText <> ""
        cursor.currRow = createRow(cursor.currRow)
        ' Check for emojis in this text
        emojiRegex = createObject("roRegex", regex(), "m")
        matches = emojiRegex.matchAll(labelText)

        for each match in matches
            matchText = match[0]
            ' Create the label representing all text before this match, 
            ' if there is any
            loc = labelText.instr(matchText)
            if loc > 0
                leftText = labelText.left(loc)
                cursor = distributeWords(leftText, cursor)
                if cursor = Invalid
                    return void
                end if
            end if

            ' Get the URI for this emoji and create the poster
            pointURI = emojiPointName(matchText)
            posterNode = createPoster(pointURI)

            cursor = updateCursor(cursor, posterNode)
            if cursor = Invalid
                return void
            end if

            ' Update the remaining text. Set to be text after this emoji.
            labelText = labelText.mid(loc + matchText.len())
        end for

        ' If we have text at the end after the last emoji match, create 
        ' a label for that text. 
        if labelText <> ""
            cursor = distributeWords(labelText, cursor)
            if cursor = Invalid
                return void
            end if
        end if
    end if

    ' Update the fields that do not affect layout
    updateComponents()
end function

' Create a new label to display non-emoji text in the label.
function createLabel(withText as String)
    label = createObject("roSGNode", "Label")
    label.text = withText
    label.color = m.top.color
    if m.top.font <> Invalid
        label.font = m.top.font
    end if

    return label
end function

' Create a new poster to show an emoji with.
function createPoster(uri as String)
    poster = CreateObject("roSGNode", "Poster")
    poster.uri = uri

    ' Use emoji size first if set
    if m.top.emojiSize > 0
        poster.width = m.top.emojiSize
        poster.height = m.top.emojiSize
    end if

    return poster
end function

' Create a new line in the multi-line label
function createRow(currRow)
    numLines = m.components.getChildCount()

    ' If a maximum number of lines set and is reached
    if m.top.maxLines <> 0  and numLines = m.top.maxLines
        ' Replace last node with an ellipsis
        ellipsis = createLabel("…")
        lastNodeIndex = currRow.getChildCount() - 1
        lastNode = currRow.getChild(lastNodeIndex)
        currRow.removeChild(lastNode)
        currRow.appendChild(ellipsis)

        return Invalid
    end if

    ' Create the new row
    row = CreateObject("roSGNode", "LayoutGroup")
    row.layoutDirection="horiz"
    row.vertAlignment="center"
    m.components.AppendChild(row)

    return row
end function

' Arrange the words horizontally with breaks to new line
function distributeWords(text, cursor)
    labelTextArr = text.split(" ")
    for each leftWord in labelTextArr
        labelNode = createLabel(leftWord + " ")
        cursor = updateCursor(cursor, labelNode)
        if cursor = Invalid
            return Invalid
        end if
    end for

    return cursor
end function

' Incremenet the current width and create a new line if necessary
function updateCursor(cursor, node)
    width = node.boundingRect().width
    cursor.currWidth += width
    if cursor.currWidth > m.top.width and m.top.width > 0
        cursor.currWidth = width
        cursor.currRow = createRow(cursor.currRow)
        if cursor.currRow = Invalid
            return Invalid
        end if
    end if

    cursor.currRow.appendChild(node)
    return cursor
end function

' Returns all components for the current emoji label.
function getAllComponents()
    components = []
    for i = 0 to m.components.getChildCount() - 1
        line = m.components.getChild(i)
        for j = 0 to line.getChildCount() - 1
            components.push(line.getChild(j))
        end for
    end for

    return components
end function

' Removes all lines to reset the layout group.
function resetComponents()
    while m.components.getChildCount() > 0
        m.components.removeChildIndex(0)
    end while
end function