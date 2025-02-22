import tables, streams, strutils, endians, unicode, os
import font
import vmath, print


proc read[T](s: Stream, result: var T) =
  if readData(s, addr(result), sizeof(T)) != sizeof(T):
    quit("cannot read from stream at " & $s.getPosition())

proc readUInt8(stream: Stream): uint8 =
  var val: uint8 = 0
  stream.read(val)
  return val

proc readInt8(stream: Stream): int8 =
  var val: int8 = 0
  stream.read(val)
  return val

proc readUInt16(stream: Stream): uint16 =
  var val: uint16 = 0
  stream.read(val)
  swapEndian16(addr val, addr val)
  return val

proc readUint16Seq(stream: Stream, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0..<len:
    result[i] = stream.readUInt16()

proc readInt16(stream: Stream): int16 =
  var val: int16 = 0
  stream.read(val)
  swapEndian16(addr val, addr val)
  return val

proc readUInt32(stream: Stream): uint32 =
  var val: uint32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return val

proc readInt32(stream: Stream): int32 =
  var val: int32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return val

proc readString(stream: Stream, size: int): string =
  var val = ""
  var i = 0
  while i < size:
    let c = stream.readChar()
    if ord(c) == 0:
      break
    val &= c
    inc i
  while i < size:
    discard stream.readChar()
    inc i
  return val

proc readFixed32(stream: Stream): float =
  var val: int32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return ceil(float(val) / 65536.0 * 100000.0) / 100000.0

proc readLongDateTime(stream: Stream): float64 =
  discard stream.readUInt32()
  return float64(int64(stream.readUInt32()) - 2080198800000)/1000.0 # 1904/1/1


proc readFontTtf*(filename: string): Font =
  ## Reads TTF font
  var font = Font()

  if not existsFile(filename):
    raise newException(IOError, "File name " & filename & " not found")

  var f = newFileStream(filename, fmRead)
  var version = f.readFixed32()
  #assert version == 1.0

  var numTables = f.readUInt16()
  #assert numTables == 21

  var searchRenge = f.readUInt16()
  #assert searchRenge == 256

  var entrySelector = f.readUInt16()
  #assert entrySelector == 4

  var rengeShift = f.readUInt16()
  #assert rengeShift == 80

  type Chunk = object
    tag: string
    checkSum: uint32
    offset: uint32
    length: uint32

  var chunks = initTable[string, Chunk]()

  for i in 0..<int(numTables):
    var chunk: Chunk
    chunk.tag = f.readString(4)
    chunk.checkSum = f.readUInt32()
    chunk.offset = f.readUInt32()
    chunk.length = f.readUInt32()
    chunks[chunk.tag] = chunk

  # head
  f.setPosition(int chunks["head"].offset)
  let headVersion = f.readFixed32()
  let headFontRevision = f.readFixed32()
  let headCheckSumAdjustment = f.readUint32()
  let headMagickNumber = f.readUint32()
  let headFlags = f.readUint16()
  font.unitsPerEm = float f.readUint16()
  let headCreated = f.readLongDateTime()
  let headModified = f.readLongDateTime()
  let headxMin = f.readInt16()
  let headyMin = f.readInt16()
  let headxMax = f.readInt16()
  let headyMax = f.readInt16()
  font.bboxMin = vec2(float headxMin, float headyMin)
  font.bboxMax = vec2(float headxMax, float headyMax)
  let headMacStyle = f.readUint16()
  let headLowestRecPPEM = f.readUint16()
  let headFontDirectionHint = f.readInt16()
  let headIndexToLocFormat = f.readInt16()
  let headGlyphDataFormat = f.readInt16()

  # name
  f.setPosition(int chunks["name"].offset)
  let at = f.getPosition()
  let nameFormat = f.readUint16()
  assert nameFormat == 0
  let nameCount = f.readUint16()
  let nameStringOffset = f.readUint16()
  var baseName, fullName: string
  for i in 0..<(int nameCount):
    let platformID = f.readUint16() #Platform identifier code.
    let platformSpecificID = f.readUint16() #Platform-specific encoding identifier.
    let languageID = f.readUint16() #Language identifier.
    let nameID = f.readUint16() #Name identifiers.
    let length = f.readUint16() #Name string length in bytes.
    let offset = f.readUint16() #Name string offset in bytes from stringOffset.
    let save = f.getPosition()
    f.setPosition(at + int(nameStringOffset + offset))
    if nameID in {1, 4} and platformId in {0, 1, 2}:
      let name = f.readString(int length)
      if name.len > 0:
        font.name = name
    f.setPosition(save)

  # maxp
  f.setPosition(int chunks["maxp"].offset)
  let maxpVersion = f.readFixed32()
  let maxpNumGlyphs = f.readUint16()
  let maxpMaxPoints = f.readUint16()
  let maxpMaxCompositePoints = f.readUint16()
  let maxpMaxCompositeContours = f.readUint16()
  let maxpMaxZones = f.readUint16()
  let maxpMaxTwilightPoints = f.readUint16()
  let maxpMaxStorage = f.readUint16()
  let maxpMaxFunctionDefs = f.readUint16()
  let maxpMaxInstructionDefs = f.readUint16()
  let maxpMaxStackElements = f.readUint16()
  discard f.readUint16()
  let maxpMmaxSizeOfInstructions = f.readUint16()
  let maxpMaxComponentElements = f.readUint16()
  let maxpMaxComponentDepth = f.readUint16()

  # OS/2
  f.setPosition(int chunks["OS/2"].offset)
  let os2_version = f.readUInt16()
  let os2_xAvgCharWidth = f.readInt16()
  let os2_usWeightClass = f.readUInt16()
  let os2_usWidthClass = f.readUInt16()
  let os2_fsType = f.readUInt16()
  let os2_ySubscriptXSize = f.readInt16()
  let os2_ySubscriptYSize = f.readInt16()
  let os2_ySubscriptXOffset = f.readInt16()
  let os2_ySubscriptYOffset = f.readInt16()
  let os2_ySuperscriptXSize = f.readInt16()
  let os2_ySuperscriptYSize = f.readInt16()
  let os2_ySuperscriptXOffset = f.readInt16()
  let os2_ySuperscriptYOffset = f.readInt16()
  let os2_yStrikeoutSize = f.readInt16()
  let os2_yStrikeoutPosition = f.readInt16()
  let os2_sFamilyClass = f.readInt16()

  for i in 0..<10:
      let os2_panose = f.readUInt8()

  let os2_ulUnicodeRange1 = f.readUInt32()
  let os2_ulUnicodeRange2 = f.readUInt32()
  let os2_ulUnicodeRange3 = f.readUInt32()
  let os2_ulUnicodeRange4 = f.readUInt32()
  let os2_achVendID = @[f.readUInt8(), f.readUInt8(), f.readUInt8(), f.readUInt8()]
  let os2_fsSelection = f.readUInt16()
  let os2_usFirstCharIndex = f.readUInt16()
  let os2_usLastCharIndex = f.readUInt16()
  font.ascent = float f.readInt16()
  font.descent = float f.readInt16()
  let os2_sTypoLineGap = f.readInt16()
  let os2_usWinAscent = f.readUInt16()
  let os2_usWinDescent = f.readUInt16()
  if os2_version >= 1.uint16:
      let os2_ulCodePageRange1 = f.readUInt32()
      let os2_ulCodePageRange2 = f.readUInt32()
  if os2_version >= 2.uint16:
      let os2_sxHeight = f.readInt16()
      let os2_sCapHeight = f.readInt16()
      let os2_usDefaultChar = f.readUInt16()
      let os2_usBreakChar = f.readUInt16()
      let os2_usMaxContent = f.readUInt16()

  # loca
  f.setPosition(int chunks["loca"].offset)
  var loca = newSeq[int]()
  var locaOffset = int chunks["loca"].offset
  var locaOffsetSize = newSeq[int]()

  if headIndexToLocFormat == 0:
    # locaType Uint16
    for i in 0..<int(maxpNumGlyphs):
      loca.add int f.readUint16() * 2
      locaOffsetSize.add int locaOffset
      locaOffset += 2
  else:
    # locaType Uint32
    for i in 0..<int(maxpNumGlyphs):
      loca.add int f.readUint32()
      locaOffsetSize.add int locaOffset
      locaOffset += 4

  # glyf
  f.setPosition(int chunks["glyf"].offset)
  var glyphTabe = initTable[int, Glyph]()
  var glyphs = newSeq[Glyph](loca.len)
  let glyphOffset = int chunks["glyf"].offset
  for glyphIndex in 0..<loca.len:
    let locaOffset = loca[glyphIndex]
    let offset = glyphOffset + locaOffset
    f.setPosition(int offset)
    if not glyphTabe.hasKey(offset):

      glyphTabe[offset] = Glyph()
      glyphTabe[offset].ready = false

      var isNull = glyphIndex + 1 < loca.len and loca[glyphIndex] == loca[glyphIndex + 1]
      if isNull:
        glyphTabe[offset].isEmpty = true
        glyphTabe[offset].ready = true

      let numberOfContours = f.readInt16()
      if numberOfContours <= 0:
        glyphTabe[offset].isEmpty = true
        glyphTabe[offset].ready = true

      if not glyphTabe[offset].isEmpty:
        glyphTabe[offset].ttfStream = f
        glyphTabe[offset].ttfOffset = offset
        glyphTabe[offset].numberOfContours = numberOfContours

    glyphs[glyphIndex] = glyphTabe[offset]

  # hhea
  f.setPosition(int chunks["hhea"].offset)
  let hhea_majorVersion = f.readUInt16()
  assert hhea_majorVersion == 1
  let hhea_minorVersion = f.readUInt16()
  assert hhea_minorVersion == 0
  let hhea_ascent = f.readInt16()
  let hhea_descent = f.readInt16()
  let hhea_lineGap = f.readInt16()
  let hhea_advanceWidthMax = f.readUInt16()
  let hhea_minLeftSideBearing = f.readInt16()
  let hhea_minRightSideBearing = f.readInt16()
  let hhea_xMaxExtent = f.readInt16()
  let hhea_caretSlopeRise = f.readInt16()
  let hhea_caretSlopeRun = f.readInt16()
  let hhea_caretOffset = f.readInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  let hhea_metricDataFormat = f.readInt16()
  assert hhea_metricDataFormat == 0
  let hhea_numberOfHMetrics = f.readUInt16()

  # hmtx
  f.setPosition(int chunks["hmtx"].offset)
  var advanceWidth = uint16 0
  var leftSideBearing = int16 0
  for i in 0..<int(glyphs.len):
    if i < int hhea_numberOfHMetrics:
      advanceWidth = f.readUInt16()
      leftSideBearing = f.readInt16()
    glyphs[i].advance = float advanceWidth

  # cmap
  var glyphsIndexToRune = newSeq[string](glyphs.len)
  f.setPosition(int chunks["cmap"].offset)
  let cmapOffset = int chunks["cmap"].offset
  let cmapVersion = f.readUint16()
  let cmapNumberSubtables = f.readUint16()

  for i in 0..<int(cmapNumberSubtables):
    let tablePlatformID = f.readUint16()
    let tablePlatformSpecificID = f.readUint16()
    let tableOffset = f.readUint32()

    if tablePlatformID == 3: # we are only going to use Windows cmap
      f.setPosition(cmapOffset + int tableOffset)
      let tableFormat = f.readUint16()
      if tableFormat == 4:
        # why is this so hard?
        # just a mapping of unicode -> id
        font.glyphs = initTable[string, Glyph]()

        let cmapLength = f.readUint16()
        let cmapLanguage = f.readUint16()
        let segCount = f.readUint16() div 2
        let searchRange = f.readUint16()
        let entrySelector = f.readUint16()
        let rangeShift = f.readUint16()

        let endCountSeq = f.readUint16Seq(int segCount)
        discard f.readUint16()
        let startCountSeq = f.readUint16Seq(int segCount)
        let idDeltaSeq = f.readUint16Seq(int segCount)
        let idRangeAddress =  f.getPosition()
        let idRangeOffsetSeq = f.readUint16Seq(int segCount)
        var glyphIndexAddress = f.getPosition()
        for j in 0..<int(segCount):
          var glyphIndex = 0
          let endCount = endCountSeq[j]
          let startCount = startCountSeq[j]
          let idDelta = idDeltaSeq[j]
          let idRangeOffset = idRangeOffsetSeq[j]

          for c in startCount..endCount:
            if idRangeOffset != 0:
                var glyphIndexOffset = idRangeAddress + j * 2
                glyphIndexOffset += int(idRangeOffset)
                glyphIndexOffset += int(c - startCount) * 2
                f.setPosition(glyphIndexOffset)
                glyphIndex = int f.readUint16()
                if glyphIndex != 0:
                    glyphIndex = int((uint16(glyphIndex) + idDelta) and 0xFFFF)

            else:
              glyphIndex = int((c + idDelta) and 0xFFFF)

            if glyphIndex < glyphs.len:
              let unicode = Rune(int c).toUTF8()
              font.glyphs[unicode] = glyphs[glyphIndex]
              font.glyphs[unicode].code = unicode
              glyphsIndexToRune[glyphIndex] = unicode
            else:
              discard

  font.kerning = initTable[string, float]()
  # kern
  if "kern" in chunks:
    f.setPosition(int chunks["kern"].offset)
    let tableVersion = f.readUint16()
    if tableVersion == 0:
      # Windows format
      let maybe_numTables = f.readUint16()
      let subtableVersion = f.readUint16()
      assert subtableVersion == 0
      let subtableLength = f.readUint16()
      let subtableCoverage = f.readUint16()
      let numPairs = f.readUint16()
      let searchRange = f.readUint16()
      let entrySelector = f.readUint16()
      let rangeShift = f.readUint16()
      for i in 0..<int(numPairs):
        let leftIndex = f.readUint16()
        let rightIndex = f.readUint16()
        let value = f.readInt16()
        let u1 = glyphsIndexToRune[int leftIndex]
        let u2 = glyphsIndexToRune[int rightIndex]
        if u1.len > 0 and u2.len > 0:
          font.kerning[u1 & ":" & u2] = float value

    elif tableVersion == 1:
      # Mac format
      assert false
    else:
      assert false

  return font


proc ttfGlyphToPath*(glyph: var Glyph) =
  var
    f = glyph.ttfStream
    offset = glyph.ttfOffset

  f.setPosition(0)
  f.setPosition(int offset)
  let numberOfContours = f.readInt16()
  assert numberOfContours == glyph.numberOfContours

  type TtfCoridante = object
    x: int
    y: int
    isOnCurve: bool

  let xMin = f.readInt16()
  let yMin = f.readInt16()
  let xMax = f.readInt16()
  let yMax = f.readInt16()

  var endPtsOfContours = newSeq[int]()
  if numberOfContours >= 0:
    for i in 0..<numberOfContours:
      endPtsOfContours.add int f.readUint16()

  if endPtsOfContours.len == 0:
    return

  let instructionLength = f.readUint16()
  for i in 0..<int(instructionLength):
    discard f.readChar()

  let flagsOffset = f.getPosition()
  var flags = newSeq[uint8]()

  if numberOfContours >= 0:
    let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
    var coordinates = newSeq[TtfCoridante](totalOfCoordinates)

    var i = 0
    while i < totalOfCoordinates:
      let flag = f.readUint8()
      flags.add(flag)
      inc i

      if (flag and 0x8) != 0 and i < totalOfCoordinates:
        let repeat = f.readUint8()
        for j in 0..<int(repeat):
          flags.add(flag)
          inc i

    # xCoordinates
    var prevX = 0
    for i, flag in flags:
      var x = 0
      if (flag and 0x2) != 0:
        x = int f.readUint8()
        if (flag and 16) == 0:
          x = -x
      elif (flag and 16) != 0:
        x = 0
      else:
        x = int f.readInt16()
      prevX += x
      coordinates[i].x = prevX
      coordinates[i].isOnCurve = (flag and 1) != 0

    # yCoordinates
    var prevY = 0
    for i, flag in flags:
      var y = 0
      if (flag and 0x4) != 0:
        y = int f.readUint8()
        if (flag and 32) == 0:
          y = -y
      elif (flag and 32) != 0:
        y = 0
      else:
        y = int f.readInt16()
      prevY += y
      coordinates[i].y = prevY

    # make an svg path out of this crazy stuff
    var path = ""
    var
      startPts = 0
      currentPts = 0
      endPts = 0
      prevPoint: TtfCoridante
      currentPoint: TtfCoridante
      nextPoint: TtfCoridante

    for i in 0..<endPtsOfContours.len:
      endPts = endPtsOfContours[i]
      while currentPts < endPts + 1:
        currentPoint = coordinates[currentPts]
        if currentPts != startPts:
          prevPoint = coordinates[currentPts - 1]
        else:
          prevPoint = coordinates[endPts]
        if currentPts != endPts and currentPts + 1 < coordinates.len:
          nextPoint = coordinates[currentPts + 1]
        else:
          nextPoint = coordinates[startPts]

        if currentPts == startPts:
          if currentPoint.isOnCurve:
            path.add "M" & $currentPoint.x & "," & $currentPoint.y & " "
          else:
            path.add "M" & $prevPoint.x & "," & $prevPoint.y & " "
            path.add "Q" & $currentPoint.x & "," & $currentPoint.y & " "
        else:
          if currentPoint.isOnCurve and prevPoint.isOnCurve:
            path.add " L"
          elif not currentPoint.isOnCurve and not prevPoint.isOnCurve:
            var midx = (prevPoint.x + currentPoint.x) div 2
            var midy = (prevPoint.y + currentPoint.y) div 2
            path.add $midx & "," & $midy & " "
          elif not currentPoint.isOnCurve:
            path.add " Q"
          path.add $currentPoint.x & "," & $currentPoint.y & " "

        inc currentPts

      if not currentPoint.isOnCurve:
        if coordinates[startPts].isOnCurve:
          path.add $coordinates[startPts].x & "," & $coordinates[startPts].y & " "
        else:
          var midx = (prevPoint.x + currentPoint.x) div 2
          var midy = (prevPoint.y + currentPoint.y) div 2
          path.add $midx & "," & $midy & " "
      path.add " Z "
      startPts = endPtsOfContours[i] + 1

    glyph.path = path


proc ttfGlyphToCommands*(glyph: var Glyph) =
  var
    f = glyph.ttfStream
    offset = glyph.ttfOffset

  f.setPosition(0)
  f.setPosition(int offset)
  let numberOfContours = f.readInt16()
  assert numberOfContours == glyph.numberOfContours

  type TtfCoridante = object
    x: int
    y: int
    isOnCurve: bool

  let xMin = f.readInt16()
  let yMin = f.readInt16()
  let xMax = f.readInt16()
  let yMax = f.readInt16()

  var endPtsOfContours = newSeq[int]()
  if numberOfContours >= 0:
    for i in 0..<numberOfContours:
      endPtsOfContours.add int f.readUint16()

  if endPtsOfContours.len == 0:
    return

  let instructionLength = f.readUint16()
  for i in 0..<int(instructionLength):
    discard f.readChar()

  let flagsOffset = f.getPosition()
  var flags = newSeq[uint8]()

  if numberOfContours >= 0:
    let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
    var coordinates = newSeq[TtfCoridante](totalOfCoordinates)

    var i = 0
    while i < totalOfCoordinates:
      let flag = f.readUint8()
      flags.add(flag)
      inc i

      if (flag and 0x8) != 0 and i < totalOfCoordinates:
        let repeat = f.readUint8()
        for j in 0..<int(repeat):
          flags.add(flag)
          inc i

    # xCoordinates
    var prevX = 0
    for i, flag in flags:
      var x = 0
      if (flag and 0x2) != 0:
        x = int f.readUint8()
        if (flag and 16) == 0:
          x = -x
      elif (flag and 16) != 0:
        x = 0
      else:
        x = int f.readInt16()
      prevX += x
      coordinates[i].x = prevX
      coordinates[i].isOnCurve = (flag and 1) != 0

    # yCoordinates
    var prevY = 0
    for i, flag in flags:
      var y = 0
      if (flag and 0x4) != 0:
        y = int f.readUint8()
        if (flag and 32) == 0:
          y = -y
      elif (flag and 32) != 0:
        y = 0
      else:
        y = int f.readInt16()
      prevY += y
      coordinates[i].y = prevY

    # make an svg path out of this crazy stuff
    var path = newSeq[PathCommand]()

    proc cmd(kind: PathCommandKind, x, y: int) =
      path.add PathCommand(kind: kind, numbers: @[float x, float y])

    proc cmd(kind: PathCommandKind) =
      path.add PathCommand(kind: kind, numbers: @[])

    proc cmd(x, y: int) =
      path[^1].numbers.add float(x)
      path[^1].numbers.add float(y)

    var
      startPts = 0
      currentPts = 0
      endPts = 0
      prevPoint: TtfCoridante
      currentPoint: TtfCoridante
      nextPoint: TtfCoridante

    for i in 0..<endPtsOfContours.len:
      endPts = endPtsOfContours[i]
      while currentPts < endPts + 1:
        currentPoint = coordinates[currentPts]
        if currentPts != startPts:
          prevPoint = coordinates[currentPts - 1]
        else:
          prevPoint = coordinates[endPts]
        if currentPts != endPts and currentPts + 1 < coordinates.len:
          nextPoint = coordinates[currentPts + 1]
        else:
          nextPoint = coordinates[startPts]

        if currentPts == startPts:
          if currentPoint.isOnCurve:
            cmd(Move, currentPoint.x, currentPoint.y)
          else:
            cmd(Move, prevPoint.x, prevPoint.y)
            cmd(Quad, currentPoint.x, currentPoint.y)
        else:
          if currentPoint.isOnCurve and prevPoint.isOnCurve:
            cmd(Line)
          elif not currentPoint.isOnCurve and not prevPoint.isOnCurve:
            var midx = (prevPoint.x + currentPoint.x) div 2
            var midy = (prevPoint.y + currentPoint.y) div 2
            cmd(midx, midy)
          elif not currentPoint.isOnCurve:
            cmd(Quad)
          cmd(currentPoint.x, currentPoint.y)

        inc currentPts

      if not currentPoint.isOnCurve:
        if coordinates[startPts].isOnCurve:
         cmd(coordinates[startPts].x, coordinates[startPts].y)
        else:
          var midx = (prevPoint.x + currentPoint.x) div 2
          var midy = (prevPoint.y + currentPoint.y) div 2
          cmd(midx, midy)
      cmd(End)
      startPts = endPtsOfContours[i] + 1

    glyph.commands = path

