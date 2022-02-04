var registers[16]
var memory[4096]
var index 'Index register
var pc
var stack[16]
var sp;
var keypad[16]
var video_width = 64, video_height = 32
var video[video_width, video_height]
var opcode
var delayTimer
var soundTimer

def fontload
  var font_start_addr = &h50
  var font_size = 80
  var fonts[font_size] = [&hF0, &h90, &h90, &h90, &hF0, &h20, &h60, &h20, &h20, &h70, &hF0, &h10, &hF0, &h80, &hF0, &hF0, &h10, &hF0, &h10, &hF0,	&h90, &h90, &hF0, &h10, &h10,	&hF0, &h80, &hF0, &h10, &hF0,	&hF0, &h80, &hF0, &h90, &hF0,	&hF0, &h10, &h20, &h40, &h40,	&hF0, &h90, &hF0, &h90, &hF0,	&hF0, &h90, &hF0, &h10, &hF0,	&hF0, &h90, &hF0, &h90, &h90,	&hE0, &h90, &hE0, &h90, &hE0,	&hF0, &h80, &h80, &h80, &hF0, &hE0, &h90, &h90, &h90, &hE0, &hF0, &h80, &hF0, &h80, &hF0, &hF0, &h80, &hF0, &h80, &h80]

  for i = 0 to font_size - 1
    memory[font_start_addr + i] = fonts[i]
  next
end

def randnum
  'we want numbers from 0 to 255
end

def init
  pc = &h200

end

def loadrom

end


'Instructions
def op00e0 'cls
  fill video, 0
end

def op00ee 'ret
  sp = sp - 1
  pc = stack[sp]
end

def op1nnn 'JP; jump to mem addr nnn
  'to get the nnn part, we AND the opcode and 0000 1111 1111 1111
  var address = opcode AND &h0fff
  pc = address
end

def op2nn 'CALL; call a subroutine at mem addr nnn
  var address = opcode AND &h0fff
  stack[sp] = pc
  sp = sp + 1
  pc = address
end

def op3xkk 'SE; skip next instruction if register Vx = kk
  'Our PC should already be incremented for the next instruction, so we could just add another 2.
  var Vx = (opcode AND &h0f00) >> 8
  var byte = opcode AND &h00ff

  if registers[Vx] == byte then
    pc = pc + 2
end

def op4xkk 'SNE Vx. byte; skip the next instruction of register Vx != kk
  var Vx = (opcode AND &h0f00) >> 8
  var byte = opcode AND &h00ff

  if registers[Vx] != byte then
    pc = pc + 2
end

def op5xy0 'SE Vx, Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  if registers[Vx] == registers[Vy] then
    pc = pc + 2
end

def op6xkk 'LD Vx, Byte; Set Vx == kk
  var Vx = (opcode AND &h0f00) >> 8
  var byte = opcode AND &h00ff

  registers[Vx] = byte
end

def op7xkk 'ADD Vx, Byte; Set Vx += kk
  var Vx = (opcode AND &h0f00) >> 8
  var byte = opcode AND &h00ff

  registers[Vx] = registers[Vx] + byte
end

def op8xy0 'LD Vx, Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  registers[Vx] = registers[Vy]
end

def op8xy1 'OR Vx, Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  registers[Vx] = registers[Vx] OR registers[Vy]
end

def op8xy2 'AND Vx, Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  registers[Vx] = registers[Vx] AND registers[Vy]
end

def op8xy3 'XOR Vx, Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  registers[Vx] = registers[Vx] XOR registers[Vy]
end

def op8xy4 'ADD Vx, Vy; Add with an overflow. Set VF to 1 if overflow
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  sum = registers[Vx] + registers[Vy]

  if sum > 255 then
    registers[&hf] = 1
  else
    registers[&hf] = 0
  endif

  registers[Vx] = sum & &hff
end

def op8xy5 'SUB Vx, Vy; Sub with a borrow. Set VF to 1 if no borrow?
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  if registers[Vx] > registers[Vy] then
    registers[&hf] = 1
  else
    registers[&hf] = 0
  endif

  registers[Vx] = registers[Vx] - registers[Vy]
end

def op8xy6 'SHR Vx; Store LSB in Vf and then Right shift Vx.
  var Vx = (opcode AND &h0f00) >> 8
  registers[&hf] = (registers[Vx] AND &h1)
  registers[Vx] = registers[Vx] >> 1
end

def op8xy7 'SUBN Vx, Vy; Sub with no borrow? Or at least, set Vf to 1 if borrow needed...
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  if registers[Vy] > registers[Vx] then
    registers[&hf] = 1
  else
    registers[&hf] = 0
  endif

  registers[Vx] = registers[Vy] - registers[Vx]
end

def op8xye 'SHL Vx, {, Vy}; store MSB of Vx in Vf, then left shift Vx.
  var Vx = (opcode AND &h0f00) >> 8
  registers[&hf] = (registers[Vx] AND &h80) >> 7
  registers[Vx] = registers[Vx] << 1
end

def op9xy0 'SNE Vx, Vy; skip next instruction if Vx != Vy
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4

  if registers[Vx] != registers[Vy]
    pc = pc + 2
end

def opannn 'LD I, addr; set index register = nnn
  var address = opcode AND &h0fff
  index = address
end

def opbnnn 'JP V0, addr; Jump to addr nnn + V0
  var address = opcode AND &h0fff
  pc = registers[0] + address
end

def opcxkk 'RND Vx, byte
  var Vx = (opcode AND &h0f00) >> 8
  var byte = opcode AND &h00ff

  registers[Vx] = randnum() & byte
end

'TODO: get this working with smilebasic'
def opDxyn 'DRW Vx, Vy, nibble; Display an n-byte sprite starting at the index register at location(Vx,Vy)
  'Set Vf = collision
  var Vx = (opcode AND &h0f00) >> 8
  var Vy = (opcode AND &h00f0) >> 4
  var height = opcode & &h000f

  var xpos = registers[Vx] MOD video_width
  var ypos = registers[Vy] MOD video_height
  registers[&hf] = 0

  for row = 0 to height - 1
    var spritebyte = memory[index + row]
    for col = 0 to 7
      var spritepixel = spritebyte AND (&h80 >> col)
      var screenpixel = video[(ypos + row) * video_width + (xpos + col))

      if spritepixel then
        if screenpixel == &hffffffff
          registers[&hf] = 1
        endif

        screenpixel = screenpixel XOR &hffffffff
      endif
    next
  next
end

def opex9e 'SKP Vx; skip next instruction if a button with the value in Vx is pressed
  var Vx = (opcode AND &h0f00) >> 8
  var key = registers[Vx]

  if keypad[key] then
    pc = pc + 2
end

def opexa1 'SKNP Vx; skip next instruction if a button with the same value in Vx isn't pressed
  var Vx = (opcode AND &h0f00) >> 8
  var key = registers[Vx]

  if !keypad[key] then
    pc = pc + 2
end

def opfx07 'LD Vx, DT; set Vx = value in delay time
  var Vx = (opcode AND &h0f00) >> 8
  registers[Vx] = delayTimer
end

def opfx0a 'LD Vx, K; Wait for a key press, then store the value of the pressed key in Vx.
  'Wait by just decrementing pc by 2 so that we repeat this instruction.
  if keypad[0] then
    registers[Vx] = 0
  elseif keypad[1] then
    registers[Vx] = 1
  elseif keypad[2] then
    registers[Vx] = 2
  elseif keypad[3] then
    registers[Vx] = 3
  elseif keypad[4] then
    registers[Vx] = 4
  elseif keypad[5] then
    registers[Vx] = 5
  elseif keypad[6] then
    registers[Vx] = 6
  elseif keypad[7] then
    registers[Vx] = 7
  elseif keypad[8] then
    registers[Vx] = 8
  elseif keypad[9] then
    registers[Vx] = 9
  elseif keypad[10] then
    registers[Vx] = 10
  elseif keypad[11] then
    registers[Vx] = 11
  elseif keypad[12] then
    registers[Vx] = 12
  elseif keypad[13] then
    registers[Vx] = 13
  elseif keypad[14] then
    registers[Vx] = 14
  elseif keypad[15] then
    registers[Vx] = 15
  else
    pc = pc - 2
  endif
end

def opfx15 'LD DT, Vx; Set delay timer = Vx
  var Vx = (opcode &h0f00) >> 8
  delayTimer = registers[Vx]
end

def opfx18 'LD ST, Vx; Set sound timer = Vx
  var Vx = (opcode &h0f00) >> 8
  soundTimer = registers[Vx]
end

def opfx1e 'ADD I, Vx; Set index register to += Vx
  var Vx = (opcode &h0f00) >> 8
  index = index + registers[Vx]
end

def opfx29 'LD F, Vx; Set the index register = to start location of a font sprite.
  var Vx = (opcode &h0f00) >> 8
  var digit = registers[Vx]
  'Font sprites are made up of 5 bytes each, one per row.
  index = font_start_addr + (5 * digit)
end

def opfx33 'LD B, Vx; store a BCD representation of the value in Vx in memory locations index,
  'index+1, and index+2.
  var Vx = (opcode &h0f00) >> 8
  var value = registers[Vx]

  memory[index + 2] = value MOD 10
  value = value / 10

  memory[index + 1] = value MOD 10
  value = value / 10

  memory[index] = value MOD 10
end

def opfx55 'LD [index], Vx store the registers from V0 to Vx in memory, starting at mem location stored in Index
  var Vx = (opcode &h0f00) >> 8

  for i = 0 to Vx
    memory[index + i] = registers[i]
  next
end

def opfx65 'LD Vx, [I]; read the registers V0 through Vx from memory starting at mem location in index
  var Vx = (opcode &h0f00) >> 8

  for i = 0 to Vx
    registers[i] = memory[index + i]
  next
end
