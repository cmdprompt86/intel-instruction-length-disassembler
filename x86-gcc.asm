.intel_syntax noprefix
.altmacro

.macro hex bytes:req
prevchr=-1
.irpc byte, \bytes
.if prevchr==-1
prevchr=0x\byte
.else
.byte prevchr*16+0x\byte
prevchr=-1
.endif
.endr
.endm

.data
fmt: .string "len=%d"
.text
.global main

tstinstr:
PADDD xmm1, main[ecx]
main:

mov edx, offset tstinstr
call getlen
push eax
push offset fmt
call printf
add esp, 8
xor eax, eax
ret


PR_ADDR16=1
PR_VEX=1
PR_EVEX=1
getlen:
pusha
call eot
tbl:
hex 4444129944441209
hex FE99C40000
hex 26159999
hex F5115655F344
hex F299A09999
hex 8888999912F099
hex F111F122
hex 44B9CF5639B99199
hex 44441199F144F111
hex 22A19999090099DEF09944
ex:
hex 4444F399
hex F14449F099
hex F544F199C9D9F744FD44
hex 55554449F144F522F544
hex 99945499999454
hex F34454F044545554
hex F199F944F944
eot:
pop esi
 
push -128
pop ebp
lea edi, [esp+ebp*2]
mov ebx, edi
lodsd
stosd
stosd
stosd
stosd
lodsd
stosd
stosd
stosd
stosd
 
unpack:
lodsb
cmp al, 0xF0
jb one+1
add al, 19
movzx ecx, al
lodsb
one:
rep stosb
cmp edi, esp
jb unpack

mov esi, edx
.if PR_ADDR16
mov cl, 2
mov edx, ecx
.else
cdq
mov dl, 2
.endif
next:
lodsb
cmp al, 0x66
jnz data32
cdq
 
data32:
.if PR_ADDR16
cmp al, 0x67
jnz addr32
xor ecx, ecx
addr32:
.endif
 
cmp al, 0x0F
jne Lxlat
 
L0F:
sub ebx, ebp
dec ebp
lodsb
 
Lxlat:
shr al, 1
xlat
jc odd
shr al, 4
odd:
and al, 0x0F
jz next
 
calcsize:
aam 4
cmp al, 2
jne noimm16
add al, dl
noimm16:
mov dl, al
 
shrah1:
shr ah, 1
jc vextest
sahf
jnc addsize
 
dec edx
jz addsize
cmp al, 3
je addsize
inc edx
jz displ32
inc edx
inc edx
 
addsize:
add edx, esi
sub edx, [edi+20] ;# edx
mov [edi+28], edx ;# eax
popa
ret
 
vextest:
lodsb
sahf
jnc modrm
dec ebp
jp shrah1 ;# 38|3A
inc ebp
.if PR_VEX
test dl, dl
jnp Ltest ;#1|2 == test /r, imm8|32

cmp al, 0xC0
jb notvex
test edx, edx
jnz L0F
inc esi
.if PR_EVEX
cmp al, 0xF0
jb noevex
inc esi
noevex:
.endif
test al, 2
jz L0F
vex3:
inc esi
sub al, 0xDE
jmp calcsize
.endif
Ltest:
test al, 0b110000
jz modrm
notvex:
cdq
 
modrm:
cmp al, 0xC0
jae addsize
and al, 0xC7
shl al, 1
lahf
.if PR_ADDR16
add al, cl
sahf
.endif
jc displ32
js displ8
cmp al, (5+PR_ADDR16)<<1
jne nodispl
displ32:
inc edx
.if PR_ADDR16
add dl, cl
.else
inc edx
inc edx
.endif
displ8:
inc edx
nodispl:
.if PR_ADDR16
jecxz addsize
.endif
 
shl al, 1
cmp al, (4+PR_ADDR16)<<2
jne addsize
lodsb
sahf
js addsize
and al, 7
cmp al, 5
je displ32
jmp addsize
end:
