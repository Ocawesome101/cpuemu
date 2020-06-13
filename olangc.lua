-- OLang compiler --

local args = {...}

local file = assert(args[1], "usage: olangc <file> [outfile]")

local handle = assert(io.open(file))
local data = handle:read("*a")
handle:close()

local out = ""

-- trim to something more easily parseable
data = data:gsub("//(.-)\n", ""):gsub("\n", " ")
while data:find("  ") do
  data = data:gsub("  ", " ")
end
print(data)

local reg = 0
local declared = {}
while data:find("def (.-)::(.-) (.-);") do
  if reg > 64 then
    error("too many variables declared - max 64")
  end
  local t, n, v = data:match("def (.-)::(.-) (.-);")
  print("DECLARE", t, n, "as", v)
  declared[n] = {
    type = t,
    reg  = reg
  }
  reg = reg + 1
end
