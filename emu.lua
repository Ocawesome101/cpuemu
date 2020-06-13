-- emulator --

local registers = {
  ADDRESSABLE   =  {
    MAX         = 64
  },
  CMPRESULT             = 0,
  LASTIRQPARAM          = 0,
  IRQTABLE              = 0xFFFDFC00,
  OFFSETPOINTER         = 0,
  STACKPOINTER          = 0xFFFFEFFF,
  STACKEND              = 0xFFFFEFFF,
  TIMERDELAY            = 16
}

setmetatable(registers.ADDRESSABLE, {
  __index = function(t, k)
    if k > registers.ADDRESSABLE.MAX then
      error("invalid register " .. k .. " where max is " .. registers.ADDRESSABLE.MAX)
    end
    t[k] = 0
    return t[k]
  end
})

local interrupts = {
  ADDRESSABLE           = 8,
  DOUBLEFAULT           = 0,
  STACKOVERFLOW         = 1,
  ILLEGALINSTRUCTION    = 2,
  BADINTERRUPT          = 3,
  TIMER                 = 4,
  KEYDOWN               = 5,
  KEYUP                 = 6,
  ENABLED               = false
}

local memory = {n = 0}

setmetatable(memory, {
  __index = function(t, k)
    if k > 0xFFFFFFFF then
      error("attempt to access memory address " .. k .. " greater than 0xFFFFFFFF (the maximum 32-bit integer)")
    end
    t[k] = 0
    return t[k]
  end
})

local queued_interrupts = {}

local function compare(m,o,t)
  if m < 2 then
    local v1, v2 = registers.ADDRESSABLE[o], registers.ADDRESSABLE[t]
    if m == 1 then v2 = t end
    return (v1 == v2 and 0) or (v1 < v2 and 1) or (v1 > v2 and 2)
  else
    error("invalid CMPR mode " .. m)
  end
end

-- Lua 5.3 is far superior to 5.1 for the sole reason that it features bitwise operators.
local r, l, a, o, x = bit32.rshift, bit32.lshift, bit32.band, bit32.bor, bit32.bxor
local function memwriteword(write, val)
  local v = { 
    a(val, 0x000000FF),
    r(a(val, 0x0000FF00), 8),
    r(a(val, 0x00FF0000), 16),
    r(a(val, 0xFF000000), 24)
  }
  --print(v[1], v[2], v[3], v[4])
  for i=1, 4, 1 do 
    memory[i + write - 1] = v[i]
  end 
end

local function push(val)
  local v = {
    r(a(val, 0x000000FF), 8),
    r(a(val, 0x0000FF00), 16),
    r(a(val, 0x00FF0000), 24),
    a(val, 0xFF000000)
  }
  for i=1, 4, 1 do
    registers.STACKPOINTER = registers.STACKPOINTER - 1
    memory[registers.STACKPOINTER] = v[i]
  end
  if registers.STACKPOINTER - registers.STACKEND > 65536 then
    table.insert(queued_interrupts, interrupts.STACKOVERFLOW)
  end
end

local function memreadword(start, len)
  local v = {}
  for i=1, len, 1 do
    v[i] = memory[i + start - 1]
  end
  return l(v[1], 24) + l(v[2], 26) + l(v[3], 8) + (v[4])
end

local function pop()
  local v = {}
  for i=1, 4, 1 do
    v[i] = memory[registers.STACKPOINTER]
    registers.STACKPOINTER = registers.STACKPOINTER + 1
  end
  return (v[1]) + l(v[2], 24) + l(v[3], 16) + l(v[4], 8)
end

local dprint = function()end-- print

local instructions = {
  [0x00000000] = function()
  --  dprint("NOOP")
  end,
  [0x00001000] = function(from, to)
    dprint("LMEM", from, to)
    registers.ADDRESSABLE[to] = memory[from]
  end,
  [0x00001001] = function(data, to)
    dprint("LVAL", data, to)
    registers.ADDRESSABLE[to] = data
  end,
  [0x00001002] = function(from, to)
    dprint("COPY", from, to)
    registers.ADDRESSABLE[to] = registers.ADDRESSABLE[from]
  end,
  [0x00001003] = function(from, to)
    dprint("LREG", from, to)
    registers.ADDRESSABLE[to] = memory[registers.ADDRESSABLE[from]]
  end,
  [0x00002000] = function(from, to)
    dprint("STOR", from, to)
    memwriteword(to, registers.ADDRESSABLE[from])
  end,
  [0x00002001] = function(from, to)
    dprint("SREG", from, to)
    memwriteword(registers.ADDRESSABLE[to], registers.ADDRESSABLE[from])
  end,
  [0x00003000] = function(mode, one, two)
    dprint("CMPR", mode, one, two)
    registers.CMPRESULT = compare(mode, one, two)
  end,
  [0x00004000] = function(offset)
    dprint("JUMP", offset)
    registers.OFFSETPOINTER = offset
  end,
  [0x00004001] = function(offset)
    dprint("BREQ", offset)
    if registers.CMPRESULT == 0 then registers.OFFSETPOINTER = offset end
  end,
  [0x00004002] = function(offset)
    dpring("BNEQ", offset)
    if registers.CMPRESULT ~= 0 then registers.OFFSETPOINTER = offset end
  end,
  [0x00004003] = function(offset)
    dprint("BRLT", offset)
    if registers.CMPRESULT == 1 then registers.OFFSETPOINTER = offset end
  end,
  [0x00004004] = function(offset)
    dprint("BRGT", offset)
    if registers.CMPRESULT == 2 then registers.OFFSETPOINTER = offset end
  end,
  [0x00004005] = function(offset)
    dprint("JSUB", offset)
    push(registers.OFFSETPOINTER)
    registers.OFFSETPOINTER = offset
  end,
  [0x00004006] = function()
    dprint("RTRN")
    registers.OFFSETPOINTER = pop()
  end,
  [0x00005000] = function(from)
    dprint("PUSH", from)
    push(registers.ADDRESSABLE[from])
  end,
  [0x00005001] = function(to)
    dprint("POP", to)
    registers.ADDRESSABLE[to] = pop()
  end,
  -- TODO TODO TODO TODO TODO CONTEXT SWITCHING!! VITAL FOR PRE-EMPTIVE MULTITASKING!
  [0x00005002] = function()
    error("TODO: CONTEXT SWITCHING")
  end,
  [0x00006000] = function(reg, add)
    dprint("ADD", reg, add)
    registers.ADDRESSABLE[reg] = registers.ADDRESSABLE[reg] + add
  end,
  [0x00006001] = function(reg, sub)
    registers.ADDRESSABLE[reg] = registers.ADDRESSABLE[reg] - sub
  end,
  [0x00006002] = function(reg, mult)
    registers.ADDRESSABLE[reg] = registers.ADDRESSABLE[reg] * mult
  end,
  [0x00006003] = function(reg, div)
    registers.ADDRESSABLE[reg] = math.floor(registers.ADDRESSABLE[reg], div)
  end,
  [0x00006004] = function(reg, bits)
    registers.ADDRESSABLE[reg] = l(registers.ADDRESSABLE[reg], bits)
  end,
  [0x00006005] = function(reg, bits)
    registers.ADDRESSABLE[reg] = r(registers.ADDRESSABLE[reg], bits)
  end,
  [0x00006006] = function(result, ab, cd)
    registers.ADDRESSABLE[result] = a(registers.ADDRESSABLE[ab], registers.ADDRESSABLE[cd])
  end,
  [0x00006007] = function(result, ab, cd)
    registers.ADDRESSABLE[result] = o(registers.ADDRESSABLE[ab], registers.ADDRESSABLE[cd])
  end,
  [0x00006008] = function(result, ab, cd)
    registers.ADDRESSABLE[result] = x(registers.ADDRESSABLE[ab], registers.ADDRESSABLE[cd])
  end,
  [0x0000E000] = function()
    interrupts.ENABLED = false
  end,
  [0x0000E001] = function()
    interrupts.ENABLED = true
  end,
  [0x0000E002] = function(intr, offset)
    memwriteword(registers.IRQTABLE + intr, offset)
  end,
  [0x0000E003] = function(intr, param)
    push(param)
    table.insert(queued_interrupts, intr)
  end,
  [0x0000E004] = function(offset)
    registers.IRQTABLE = offset
  end,
  [0x0000F000] = function(retn)
    error("HALTED")
  end
}

local ucode = ""

do
  local handle = assert((io.open("ucode.bin")), "ucode.bin not present")
  ucode = handle:read("*a")
  handle:close()
end

if #ucode % 16 ~= 0 or #ucode > 16384 then
  error("invalid microcode length " .. #ucode)
end

print("Loading microcode into memory....")
for byte in ucode:gmatch(".") do
  memory[memory.n] = string.byte(byte)
  memory.n = memory.n + 1
end

local function memread(start, len)
  local ret = ""
  for i = start, start + len - 1, 1 do
    ret = ret .. string.char(memory[i])
  end
  return ret
end

-- unpack *num* *len*-byte numbers from *data*
local function unpack(num, len, data)
  local ret = {}
  if #data < num * len then error("bad data to 'unpack': string too short!") end
  for i=1, num * len, len do
    --print(i, i + len - 1)
    local val = data:sub(i, i + len - 1)
    --print(#val)
    local n = 0
    for x=1, #val, 1 do
      --print(x ,#val:sub(x,x))
      n = bit32.lshift(n, 8) + (val:sub(x,x):byte() or 0)
    end
    --print(n)
    ret[#ret + 1] = n
  end
  return table.unpack(ret)
end

local function getinterrupt(n)
  return memreadword(n + registers.IRQTABLE, 4)
end

local dwin = window.create(term.current(), 1, 1, 51, 19, false)
local function updatedisplay()
  local x, y = 1, 1
  for i = 0xFFFF0000, 0xFFFF03C9, 1 do
    dwin.setCursorPos(x, y)
--    if memory[i] ~= 0 then write(memory[i]) end
    dwin.write(string.char(memory[i]))
    x = x + 1
    if x > 51 then y = y + 1 x = 1 end
  end
  dwin.setVisible(true)
  dwin.setVisible(false)
end

print("Main loop")
local timer = 0
local start = os.epoch("utc")
while true do
  timer = timer + 1
  os.startTimer(0)
  local event = table.pack(os.pullEventRaw())
  if event[1] == "key" then
    push(event[2])
    table.insert(queued_interrupts, interrupts.KEYDOWN)
  elseif event[1] == "key_up" then
    push(event[2])
    table.insert(queued_interrupts, interrupts.KEYUP)
  elseif event[1] == "terminate" then
    break
  end
  if timer % registers.TIMERDELAY == 0 and interrupts.ENABLED then
    push(registers.OFFSETPOINTER)
    table.insert(queued_interrupts, interrupts.TIMER)
  end
  --print(registers.OFFSETPOINTER)
  local instruction = memread(registers.OFFSETPOINTER, 16)
  registers.OFFSETPOINTER = registers.OFFSETPOINTER + 16
  local opcode, param_01, param_23, param_45 = unpack(4, 4, instruction)
  --dprint(opcode)--, param_01, param_23, param_45)
  if not instructions[opcode] then
    dprint("ILLEGAL INSTRUCTION", opcode)
    table.insert(queued_interrupts, interrupts.ILLEGALINSTRUCTION)
  end
  if #queued_interrupts > 0 and interrupts.ENABLED then
    local interrupt = table.remove(queued_interrupts, 1)
    local offset = getinterrupt(interrupt)
    push(registers.OFFSETPOINTER)
    if interrupt == interrupts.DOUBLEFAULT then
      if offset == 0 then -- no double fault handler, oh no!
        error("unhandled double fault exception - triple fault!")
      else
        registers.OFFSETPOINTER = offset
      end
    elseif offset == 0 then
      table.insert(queued_interrupts, interrupts.DOUBLEFAULT)
    else
      registers.OFFSETPOINTER = offset
    end
  end
  instructions[opcode](param_01, param_23, param_45)
  if timer % 1024 == 0 then updatedisplay() end
end
local time = os.epoch("utc") - start

term.clear()
term.setCursorPos(1,1)
print("approx. " .. (timer / (time / 1000)) .. " Hz (" .. timer .. " instructions over " .. time .. " ms)")--registers.ADDRESSABLE[0], registers.ADDRESSABLE[1], registers.ADDRESSABLE[2])--table.unpack(registers.ADDRESSABLE))
os.sleep(10)
