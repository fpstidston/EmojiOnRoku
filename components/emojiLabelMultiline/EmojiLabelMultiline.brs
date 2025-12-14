' Copyright Kasper Gammeltoft and other contributors. Licensed under MIT
' https://github.com/KasperGam/EmojiOnRoku/blob/main/LICENSE
sub init()
    m.components = m.top.findNode("layout")
    m.top.observeField("text", "setText")
    m.top.observeField("width", "setText")
    m.top.observeField("font", "setText")
    m.top.observeField("maxLines", "setText")
    m.top.observeField("emojiSize", "setText")
    m.top.observeField("lineSpacing", "setText")
    m.top.observeField("height", "setText")

    m.top.observeField("color", "updateComponents")

    ' Set default line spacing
    label = createLabel("Sample")
    m.lineHeight = label.boundingRect().height
    lineSpacing = m.top.lineSpacing
    if lineSpacing = 0
        lineSpacing =  m.lineHeight / 4
        m.components.itemSpacings = [ lineSpacing ]
    else
        m.components.itemSpacings = lineSpacing
    end if

    ' Set default emoji size
    if m.top.emojiSize = 0
        m.top.emojiSize = m.lineHeight
    end if
end sub

' Updates only fields that have no effect on line breaks
function updateComponents()
    height = m.top.height
    if height > 0
        if m.top.vertAlign = "center"
            m.components.vertAlignment = "center"
            midPointY = height / 2
            m.components.translation = [0, midPointY]
        else if m.top.vertAlign = "bottom"
            m.components.vertAlignment = "bottom"
            m.components.translation = [0, height]
        end if
    end if

    ' Only update color if we are actually rendering text
    if m.top.text <> ""
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
        curWidth: 0
        curLine: Invalid
    }

    resetComponents()

    if labelText <> ""
        cursor.curLine = createLine(cursor.curLine, Invalid)
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

    if m.top.emojiSize = 0
        m.top.emojiSize = label.boundingRect().height
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
function createLine(curLine, comp)
    height = m.top.height
    numLines = m.components.getChildCount()
    maxLines = m.top.maxLines
    
    curHeight = m.components.boundingRect().height
    curHeight += m.lineHeight + m.top.lineSpacing
    newlineExceedsHeight = height > 0 and curHeight > height
    newlineExceedsMaxLines = maxLines > 0 and numLines = maxLines

    ' If a height is set and new line would exceed it or a maximum number of lines is set and is reached
    if newlineExceedsHeight or newlineExceedsMaxLines
        ' Ensure the last component ends with an ellipsis
        if comp <> invalid
            truncateNode(curLine, comp)
        else
            ' If there is a new line character rendered as an empty line
            ellipsis = createLabel("…")
            curLine.appendChild(ellipsis)
        end if

        ' Tell calling function to stop drawing new lines
        return Invalid
    end if

    ' Create the new line
    line = CreateObject("roSGNode", "LayoutGroup")
    line.layoutDirection="horiz"
    line.vertAlignment="center"
    m.components.AppendChild(line)

    return line
end function

function truncateNode(curLine, comp)
    ' See if the next component to be added extends beyond the available width
    width = m.top.width
    compWidth = comp.boundingRect().width
    curWidth = curLine.boundingRect().width + compWidth

    if curWidth > width and width > 0
        diff = curWidth - width

        ellipsis = createLabel("…")
        minWidth = ellipsis.boundingRect().width
        ' For labels, we might be able to have the label use proper ellipsis by itself
        if comp.subType() = "Label"
            compNewWidth = compWidth - diff
            ' If the label is too short to have an ellipsis itself, insert one here
            if compNewWidth <= minWidth
                ' Remove the last added component
                lastCompIndex = curLine.getChildCount() - 1
                lastComp = curLine.getChild(lastCompIndex)
                curLine.removeChild(lastComp)
                if lastComp.subType() = "Label"
                    ' Extend the last label that fits so that it does not fit and add it using truncate
                    lastComp.text += "…"
                    truncateNode(curLine, lastComp)
                else
                    ' Replace emoji with ellipsis
                    curLine.appendChild(ellipsis)
                end if
            else
                ' Label will use ellipsis with explicit width set
                comp.width = compNewWidth
                curLine.appendChild(comp)
            end if
        else
            ' Replace emoji with ellipsis
            curLine.appendChild(ellipsis)          
        end if
    end if
end function

' Arrange the words horizontally with breaks to new line
function distributeWords(text, cursor)
    regex = CreateObject("roRegex", "\n", "gm")
    replacedNewlines = regex.replaceAll(text ," __NEW_LINE__ ")

    wordsArr = replacedNewlines.split(" ")
    for each word in wordsArr
        if word = "__NEW_LINE__"
            cursor.curLine = createLine(cursor.curLine, Invalid)
            cursor.curWidth = 0
            if cursor.curLine = Invalid
                return Invalid
            end if
        else
            labelNode = createLabel(word + " ")
            cursor = updateCursor(cursor, labelNode)
            if cursor = Invalid
                return Invalid
            end if
        end if

    end for 

    return cursor
end function

' Incremenet the current width and create a new line if necessary
function updateCursor(cursor, comp)
    width = comp.boundingRect().width
    cursor.curWidth += width

    if cursor.curWidth > m.top.width and m.top.width > 0
        cursor.curLine = createLine(cursor.curLine, comp)
        cursor.curWidth = width
        if cursor.curLine = Invalid
            return Invalid
        end if
    end if
    cursor.curLine.appendChild(comp)

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