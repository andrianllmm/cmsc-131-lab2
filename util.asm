;
; util.asm - gcd_asm and sum_range_asm, both recursive, callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now gcd_asm returns 0 and
; sum_range_asm returns 0, so the benchmark's --gcd and --reentrancy demos
; fail. Your job is to replace both.
;
; The contracts, from bench.c:
;
;       int b                       [ebp+12]
;       int a                       [ebp+8]
;       int gcd_asm(int a, int b)   returns the greatest common divisor
;
;       int hi                      [ebp+12]
;       int lo                      [ebp+8]
;       int sum_range_asm(lo, hi)   returns the sum of lo..hi inclusive
;
; Both are C-facing and must obey cdecl: prologue, args at [ebp+8]+, return
; in eax, preserve ebx/esi/edi/ebp, clean arguments after every call.
;
; gcd_asm also sets the global `gcd_depth` to the recursion depth of its
; most recent call. The depth is the number of gcd calls on the stack at
; the deepest point, the first call counted as 1. gcd(1071, 462) makes
; four calls, so it reaches 4. bench.c declares the global extern and
; prints it after --gcd:
;
;       int gcd_depth               (in .bss, exported, one int)
;
; The manual's requirements:
;
;   * Both recursive (Euclid's algorithm for gcd).
;   * sum_range_asm must be reentrant. It has to stay correct when a second
;     call begins before the first has finished. That means no .data or
;     .bss storage that changes during execution. Everything lives on the
;     stack and in registers. The static gcd_depth global is gcd's, not
;     sum_range's, and it is diagnostic rather than part of a result.
;   * sum_range_asm calls the C function bench_callback(void) once each
;     time C calls it, which is how bench makes one call overlap another.
;     The recursive calls must not call it again. bench counts the calls.
;     Declare it extern and call it with cdecl. It is not in the manual's
;     pseudocode, but it is what the reentrancy demo runs on.
;   * No calls into the C standard library.
;
; Euclid:
;
;   gcd(a, b):
;       if b == 0: return a
;       return gcd(b, a % b)
;
; sum_range, written so that nothing lives outside the stack:
;
;   sum_range(lo, hi):
;       if lo > hi: return 0
;       return lo + sum_range(lo + 1, hi)
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _gcd_asm gcd_asm
  %define _sum_range_asm sum_range_asm
  %define _gcd_depth gcd_depth
  %define _bench_callback bench_callback
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .bss
        global  _gcd_depth
_gcd_depth      resd    1

segment .text
        global  _gcd_asm

; Euclids algorithm for gcd, recursive
_gcd_asm:
        enter   0,0                     ; push ebp; mov ebp, esp
                                        ; uses only eax, so nothing else to save

        mov     dword [_gcd_depth], 0   ; reset the depth for this call

        ; PUshing the arguments for the recursive gcd function
        push    dword 1                 ; level = 1, the first call
        push    dword [ebp+12]          ; b
        push    dword [ebp+8]           ; a

        ; Calling the recursive gcd function
        ; computing gcd(a, b) and passing the level as 1
        call    gcd_rec                 ; eax = gcd_rec(a, b, 1)

        ; Cleaning up the stack after the call
        add     esp, 12                 ; remove 3 arguments

        leave
        ret

;
; gcd_rec(a, b, level) - Euclid's algorithm, recursive.
;
; Internal convention: cdecl, the same as the C-facing routine.
;       int level                   [ebp+16]
;       int b                       [ebp+12]
;       int a                       [ebp+8]
; Returns gcd(a, b) in eax. Clobbers eax, ecx, edx. Preserves ebx, esi,
; edi, ebp. The caller removes the 3 arguments.
; Raises gcd_depth to level, so the peak stays after the calls return.
;


; Records how deep the recursion went
gcd_rec:
        enter   0,0

        ; gcd_depth = max(gcd_depth, level)
        mov     ecx, [ebp+16]           ; the level of this call

        ; For safety checking only (works only on the first iteration)
        cmp     ecx, [_gcd_depth]       ; Compres level with current peak stored in global
        jle     .depth_recorded         ; level <= gcd_depth: keep the peak
        
        mov     [_gcd_depth], ecx       ; new peak

; Actual GCD calculation
.depth_recorded:

        ; Checking if b == 0, if so return a
        mov     eax, [ebp+8]            ; eax = a
        mov     ecx, [ebp+12]           ; ecx = b
        cmp     ecx, 0
        je      .done                   ; b == 0: return a, already in eax

        ; Signed division
        cdq                             ; sign-extend eax into edx:eax for idiv
        idiv    ecx                     ; edx = a % b

        ; return gcd_rec(b, a % b, level + 1)

        ; Initializing the level for the next recursive call
        mov     eax, [ebp+16]           ; eax = level
        inc     eax                     ; eax = level + 1

        ; Pushing the next arguments for the recursive call
        push    eax                     ; level + 1
        push    edx                     ; a % b
        push    ecx                     ; b

        ; Calling the recursive gcd function
        call    gcd_rec                 ; eax = gcd_rec(b, a % b, level + 1)

        ; Cleaning up
        add     esp, 12                 ; remove 3 arguments

.done:
        leave
        ret

        global  _sum_range_asm
        extern  _bench_callback


; utility function for another recursive function
; This practices reentrancy
 
_sum_range_asm:
        enter   0,0                     ; push ebp; mov ebp, esp
                                        ; uses only eax, so nothing else to save

        ; Once per call from C, including empty ranges. bench uses this
        ; callback to start a second sum_range_asm before this one returns.
        ; Checking if correct yung sum_range_asm and is re entrant 
        call    _bench_callback         ; bench_callback()

        ; Initializes argument 
        push    dword [ebp+12]          ; hi
        push    dword [ebp+8]           ; lo

        ; Calls the sum_range_rc
        call    sum_range_rec           ; eax = sum_range_rec(lo, hi)

        add     esp, 8                  ; remove 2 arguments

        leave
        ret

;
; sum_range_rec(lo, hi) - the recursive sum of lo..hi inclusive.
;
; Internal convention: cdecl, the same as the C-facing routine.
;       int hi                      [ebp+12]
;       int lo                      [ebp+8]
; Returns the sum in eax, or 0 if lo > hi. Clobbers eax. Preserves ebx,
; esi, edi, ebp. The caller removes the 2 arguments.
; Each frame keeps its own lo until the recursive result returns, and
; nothing is stored outside the stack. Only the C-facing entry calls back.
;
sum_range_rec:
        enter   0,0

        ; Initializes arguments for the recursive call
        mov     eax, [ebp+8]            ; eax = lo

        ; Comparing hi vs lo
        cmp     eax, [ebp+12]

        ; Checking if the range is empty or done
        jg      .empty                  ; lo > hi: return 0
        je      .done                   ; lo == hi: return lo (avoids lo + 1 overflow)

        ; return lo + sum_range_rec(lo + 1, hi)
        inc     eax                     ; eax = lo + 1

        ; lo + 1 (first argument for the next recursive call)
        push    dword [ebp+12]          ; hi
        push    eax                     ; lo + 1

        ; Next recursive call to sum_range_rec
        call    sum_range_rec           ; eax = sum_range_rec(lo + 1, hi)

        ; Removing 2 arguments
        add     esp, 8                  ; remove 2 arguments

        ; add the current lo to the result of the recursive call
        add     eax, [ebp+8]            ; eax += this frame's lo
        jmp     .done

.empty:
        xor     eax, eax                ; eax = 0
.done:
        leave
        ret
