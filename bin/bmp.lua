local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local term = require("term")
local gpu = term.gpu()

-- useful function for later
function decodeBytes(bytes,length)
  length = length or bytes:len()
  local out = 0
  for i=0,length-1 do
    out = out + bytes:byte(i+1) * math.pow(2,i*8)
  end
  return math.floor(out)
end

-- get args
args = {...}

-- print help if no args
if #args == 0 then
  print("Displays a bitmap (.bmp) file\nUsage: bmp file.bmp\n")
  return nil
end

-- open file
local filePath = shell.resolve(args[1])
local file, err = fs.open(filePath,"rb")

-- check whether file opened
if file == nil then
  print(err)
  return nil
end

-- check whether is is windows bitmap
if file:read(2) ~= "BM" then
  print("Unsupported file type.")
  file:close()
  return nil
end

-- table for storing properties
local bmp = {}

-- get size according to header
bmp.size = decodeBytes(file:read(4),4)
print(bmp.size)

-- find where pixel data starts
file:seek("cur",4)
bmp.dataStart = decodeBytes(file:read(4),4)
print(bmp.dataStart)

-- get this header size
bmp.headerSize = decodeBytes(file:read(4),4)
print(bmp.headerSize)

-- close if unsupported header
if bmp.headerSize ~= 12 and bmp.headerSize ~= 40 then
  print("Only BITMAPCOREHEADER and BITMAPINFOHEADER bitmap types are supported currently.")
  file:close()
  return nil
end

-- get image dimesions
if bmp.headerSize == 12 then
  bmp.width = decodeBytes(file:read(2),2)
  bmp.height = decodeBytes(file:read(2),2)
else
  bmp.width = decodeBytes(file:read(4),4)
  bmp.height = decodeBytes(file:read(4),4)
end
print(bmp.width,bmp.height)

-- close if invalid resolution
err = gpu.setResolution(bmp.width,math.ceil(bmp.height/2))
if err == nil then
  print("Invalid resolution")
  file:close()
  return nil
end

-- get bits per pixel
file:seek("cur",2)
bmp.bpp = decodeBytes(file:read(2),2)
print(bmp.bpp)

-- close if unsupported bpp
if bmp.bpp ~= 24 then
  print("Only 24 BPP bitmaps supported currently.")
  file:close()
  return nil
end

-- close if compressed
bmp.compressionMethod = decodeBytes(file:read(4),4)
print(bmp.compressionMethod)
if bmp.compressionMethod > 0 then
  print("Compressed bitmaps are not supported.")
  file:close()
  return nil
end

-- now to display actual image data
file:seek("set",bmp.dataStart)
term.clear()
for y=1,bmp.height do
  if math.floor(y % 2) == 1 then
    colours = {}
    for x=1,bmp.width do
      colours[x] = decodeBytes(file:read(3),3)
    end
  else
    term.setCursor(1,0)
    for x=1,bmp.width do
      gpu.setForeground(colours[x])
      gpu.setBackground(decodeBytes(file:read(3),3))
      term.write("▄")
    end
  end
  file:seek("cur",bmp.width % 4)
end
term.setCursor(1,bmp.height/2)

-- close file to prevent memory leak
file:close()
