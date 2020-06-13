-- assemble things! --

local args = {...}

local file = args[1]
local out = args[2] or "out.bin"

local handle = assert(io.open(file))

local replace = {
  noop = 0x00000000,
  lmem = 0x00001000,
  lval = 0x00001001,
  lreg = 0x00001003,
  copy = 0x00001002,
  stor = 0x00002000,
  sreg = 0x00002001,
  cmpr = 0x00003000,
  jump = 0x00004000,
  breq = 0x00004001,
  bneq = 0x00004002,
  brlt = 0x00004003,
  brgt = 0x00004004,
  jsub = 0x00004005,
  rtrn = 0x00004006,
  push = 0x00005000,
  pop  = 0x00005001,
  cntx = 0x00005002,
  add  = 0x00006000,
  sub  = 0x00006001,
  mult = 0x00006002,
  div  = 0x00006003,
  bls  = 0x00006004,
  brs  = 0x00006005,
  band = 0x00006006,
  bor  = 0x00006007,
  bxor = 0x00006008,
  dint = 0x0000E000,
  eint = 0x0000E001,
  sint = 0x0000E002,
  intr = 0x0000E003,
  intb = 0x0000E004,
  tint = 0x0000E005,
  halt = 0x0000F000
}

local function jump(p1)
  return p1 * 16
end

local func = {
  [0x00004000] = jump,
  [0x00004001] = jump,
  [0x00004002] = jump,
  [0x00004003] = jump,
  [0x00004004] = jump,
  [0x00004005] = jump
}

local data = ""

--[[local sc = string.char
function string.char(n)
  print(n)
  return sc(n)
end]]

local r, a = bit32.rshift, bit32.band
local function uint32(op)
  op = op or "0"
  local op = assert(tonumber(op), "illegal argument " .. op)
--  print(op)
  return string.char(r(a(op, 0xFF000000), 24)) .. string.char(r(a(op, 0x00FF0000), 16)) .. string.char(r(a(op, 0x0000FF00), 8)) .. string.char(r(a(op, 0x000000FF), 0))
end

local function packline(op, p1, p2, p3)
  if func[op] then p1, p2, p3 = func[op](p1, p2, p3) end
  return uint32(op) .. uint32(p1) .. uint32(p2) .. uint32(p3)
end

--[[
local sm = string.match
function string.match(s, p)
  print(s, p, sm(s, p))
  return sm(s, p)
end
--]]


for line in handle:lines() do
  line = line:gsub(";(.+)", "")
  line = line:gsub("( +)", " ")
  local op, p1, p2, p3 = line:match("(%g+) (%g+) (%g+) (%g+)")
  if not op then op, p1, p2 = line:match("(%g+) (%g+) (%g+)") end
  if not op then op, p1 = line:match("(%g+) (%g+)") end
  if not op then op = line:match("(%g+)") end
  if op then
    print(op, p1, p2, p3)
    if not replace[op] then
      error("illegal instruction: " .. op)
    end
    op = replace[op]
    data = data .. packline(op, p1, p2, p3)
  else
    print(line)
  end
end

local ohandle = assert(io.open(out, "w"))

ohandle:write(data)
ohandle:close()
