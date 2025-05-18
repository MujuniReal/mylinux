/*
/*	boot.s
/*
/* boot.s is loaded at 0x7c00 by the bios-startup routines, and moves itself
/* out of the way to address 0x90000, and jumps there.
/*
/* It then loads the system at 0x10000, using BIOS interrupts. Thereafter
/* it disables all interrupts, moves the system down to 0x0000, changes
/* to protected mode, and calls the start of system. System then must
/* RE-initialize the protected mode in it's own tables, and enable
/* interrupts as needed.
/*
/* NOTE! currently system is at most 8*65536 bytes long. This should be no
/* problem, even in the future. I want to keep it simple. This 512 kB
/* kernel size should be enough - in fact more would mean we'd have to move
/* not just these start-up routines, but also do something about the cache-
/* memory (block IO devices). The area left over in the lower 640 kB is meant
/* for these. No other memory is assumed to be "physical", ie all memory
/* over 1Mb is demand-paging. All addresses under 1Mb are guaranteed to match
/* their physical addresses.
/*
/* NOTE1 abouve is no longer valid in it's entirety. cache-memory is allocated
/* above the 1Mb mark as well as below. Otherwise it is mainly correct.
/*
/* NOTE 2! The boot disk type must be set at compile-time, by setting
/* the following equ. Having the boot-up procedure hunt for the right
/* disk type is severe brain-damage.
/* The loader has been made as simple as possible (had to, to get it
/* in 512 bytes with the code to move to protected mode), and continuos
/* read errors will result in a unbreakable loop. Reboot by hand. It
/* loads pretty fast by getting whole sectors at a time whenever possible.

/* 1.44Mb disks: */
sectors = 18
/* 1.2Mb disks:
/* sectors = 15
/* 720kB disks:
/* sectors = 9 */

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

BOOTSEG = 0x07c0
INITSEG = 0x9000
SYSSEG  = 0x1000            /* system loaded at 0x10000 (65536). */
ENDSEG	= SYSSEG + SYSSIZE

start:
    mov $BOOTSEG,%ax
    mov %ax,%ds
    mov $INITSEG,%ax
    mov %ax,%es
    mov $256,%cx
    sub %si,%si
    sub %di,%di
    rep movsw

    ljmp $INITSEG, $go 

go:
    mov %cs,%ax
    mov %ax,%ds
    mov %ax,%es
    mov %ax,%ss
    mov $0x400,%sp

    mov $0x03,%ah       /* Read cursor pos */
    xor %bh,%bh
    int $0x10

    mov $24,%cx
    mov $0x0007,%bx     /*  page 0, attribute 7 (normal) */
    mov $msg1,%bp
    mov $0x1301,%ax     /* write string, move cursor */
    int $0x10

/* ok, we've written the message, now
 we want to load the system (at 0x10000) */

    mov $SYSSEG,%ax
    mov %ax,%es
    call read_it
    call kill_motor

/* if the read went well we get current cursor position ans save it for
 posterity. */

    mov $0x03,%ah       /* read cursor pos */
    xor %bh,%bh
    int $0x10           /* save it in known place, con_init fetches */
    mov %dx,(510)       /* it from 0x90510. */

/* now we want to move to protected mode ... */
    cli

/* first we move the system to it's rightful place */
    mov $0x0000,%ax
    cld                 /* 'direction'=0, movs moves forward */
do_move:
    

.func read_it
sread:	.word 1			/* sectors read of current track */
head:	.word 0			/* current head */
track:	.word 0			/* current track */

read_it:
    mov %es,%ax
    test $0x0fff,%ax
die:
    jne die
    xor %bx,%bx
rp_read:
    mov %es,%ax
    cmp $ENDSEG,%ax
    jb ok1_read
    ret
ok1_read:
    mov $sectors,%ax
    sub (sread),%ax
    mov %ax,%cx
    shl $9,%cx
    add %bx,%cx
    jnc ok2_read
    je ok2_read
    xor %ax,%ax
    sub %bx,%ax
    shr $9,%ax
ok2_read:
    call read_track
    mov %ax,%cx
    add (sread),%ax
    cmp $sectors,%ax
    jne ok3_read
    mov $1,%ax
    sub (head),%ax
    jne ok4_read
    incw (track)
ok4_read:
    mov %ax,(head)
    xor %ax,%ax
ok3_read:
    mov %ax,(sread)
    shl $9,%cx
    add %cx,%bx
    jnc rp_read
    mov %es,%ax
    add $0x1000,%ax
    mov %ax,%es
    xor %bx,%bx
    jmp rp_read

read_track:
    push %ax
    push %bx
    push %cx
    push %dx
    mov (track),%dx
    mov (sread),%cx
    inc %cx
    mov %dl,%ch
    mov (head),%dx
    mov %dl,%dh
    mov $0,%dl
    and $0x0100,%dx
    mov $2,%ah
    int $0x13
    jc bad_rt
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    ret
bad_rt:
    mov $0,%ax
    mov $0,%dx
    int $0x13
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    jmp read_track
.endfunc

.func kill_motor
kill_motor:
    push %dx
    mov $0x3f2,%dx
    mov $0,%al
    outb %al,%dx
    pop %dx
    ret
.endfunc

msg1:
	.byte 13,10
	.ascii "Loading system ..."
	.byte 13,10,13,10
