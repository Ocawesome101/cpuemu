local c, x, y = 0, 1, 1
while true do
  os.sleep(0)
  if c == 256 then c = 0 end
  term.setCursorPos(x, y)
  term.write(string.char(c))
  c = c + 1
  x = x + 1
  if x == 51 then x = 1 y = y + 1 end
  if y == 19 then y = 1 end
end
