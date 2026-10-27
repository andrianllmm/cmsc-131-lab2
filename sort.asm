;
; sort.asm - qsort_asm, a recursive quicksort callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now it does nothing, which makes
; the benchmark print "NOT SORTED" and "Match: NO". Your job is to replace
; that with the sort described below.
;
; The contract, from bench.c:
;
;       int n                     [ebp+12]
;       int *arr                  [ebp+8]
;
; Sort n 32-bit signed integers in place, ascending. This is the C-facing
; routine. It must obey cdecl (prologue, args at [ebp+8]+, return in eax,
; preserve ebx/esi/edi/ebp, clean arguments after every call it makes). The
; manual lets you use any convention you document for the internal recursive
; routine, but the outer one is fixed.
;
; Requirements from the manual:
;
;   * Recursive. An iterative sort with an explicit stack array does not
;     satisfy the activity.
;   * Lomuto partition with the last element as pivot (the manual's scheme).
;   * No calls into the C standard library.
;   * Clean the arguments off the stack after each call. The next pop
;     otherwise loads an argument into a register you promised to
;     preserve, and the outer call's array base is gone.
;
; The manual's pseudocode:
;
;   qsort(arr, lo, hi):
;       if lo >= hi: return
;       p = partition(arr, lo, hi)
;       qsort(arr, lo, p - 1)
;       qsort(arr, p + 1, hi)
;
;   partition(arr, lo, hi):
;       pivot = arr[hi]
;       i = lo - 1
;       for j = lo to hi - 1:
;           if arr[j] <= pivot:
;               i = i + 1
;               swap arr[i], arr[j]
;       swap arr[i + 1], arr[hi]
;       return i + 1
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _qsort_asm qsort_asm
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _qsort_asm
_qsort_asm:
; starting the sort
        enter   0,0                ; set the pin: ebp = esp
        pusha                      ; save all 8 registers for C

        ; if n<=1 return;
        ; qsort_rec(arr,lo,hi); lo -> 0 and hi -> n-1

        mov     eax, [ebp+12]      ; eax = n
        cmp     eax, 1
        jle     .done              ; n <= 1 → nothing to sort

        dec eax
        push eax                     ; hi = n - 1
        push dword 0                 ; lo = 0, since start with 0
        push dword [ebp+8]           ; arr; d word is needed for 32-bit pointer
        call    qsort_rec            ; qsort_rec(arr, lo, hi)
        add     esp, 12              ; clean the arguments off the stack

.done:
        popa                       ; give C its registers back
        mov     eax, 0             ; no return value (qsort_asm is void)
        leave                      ; undo enter
        ret                        ; back to C

;
; qsort_rec(arr, lo, hi) - the recursive quicksort.
;
; Internal convention: cdecl, the same as the C-facing routine.
;       int hi                    [ebp+16]
;       int lo                    [ebp+12]
;       int *arr                  [ebp+8]
; Returns nothing. Clobbers eax, ecx, edx. Preserves ebx, esi, edi, ebp.
; The caller removes the 3 arguments.
;
qsort_rec:

; void qsort_rec(int *arr, int lo, int hi) {
;     if (lo >= hi) return;              // 0 or 1 card → done
;     int p = partition(arr, lo, hi);    // pivot is now home at index p
;     qsort_rec(arr, lo, p - 1);         // sort the left piece
;     qsort_rec(arr, p + 1, hi);         // sort the right piece
; }


        enter   0,0
        push    ebx                ; ebx will hold p, so save the caller's ebx

;     if (lo >= hi) return;
        mov     eax, [ebp+12]      ; eax = lo
        cmp     eax, [ebp+16]
        jge     .done              ; lo >= hi (signed) → 0 or 1 element, stop

;     int p = partition(arr, lo, hi);
        push    dword [ebp+16]     ; hi
        push    dword [ebp+12]     ; lo
        push    dword [ebp+8]      ; arr
        call    partition          ; eax = p
        add     esp, 12
        mov     ebx, eax           ; ebx = p (ebx survives the calls below)

        ;     qsort_rec(arr, lo, p - 1);
        mov     eax, ebx
        dec     eax                ; eax = p - 1
        push    eax                ; hi = p - 1
        push    dword [ebp+12]     ; lo
        push    dword [ebp+8]      ; arr
        call    qsort_rec          ; qsort_rec(arr, lo, p - 1)
        add     esp, 12

        ;     qsort_rec(arr, p + 1, hi);
        mov     eax, ebx
        inc     eax                ; eax = p + 1
        push    dword [ebp+16]     ; hi
        push    eax                ; lo = p + 1
        push    dword [ebp+8]      ; arr
        call    qsort_rec          ; qsort_rec(arr, p + 1, hi)
        add     esp, 12

.done:
        pop     ebx                ; give the caller its ebx back
        leave
        ret

;
; partition(arr, lo, hi) - Lomuto partition, last element as pivot.
;
; Internal convention: cdecl, the same as qsort_rec.
;       int hi                    [ebp+16]
;       int lo                    [ebp+12]
;       int *arr                  [ebp+8]
; Returns p, the pivot's final index, in eax. Clobbers ecx, edx.
; Preserves ebx, esi, edi, ebp. The caller removes the 3 arguments.
;
; Registers inside the loop:
;       esi = arr      edi = pivot      ebx = i      ecx = j
;       eax, edx = temporaries for the swap
;
partition:
        enter   0,0
        push    ebx                ; save the 3 callee-saved registers we use
        push    esi
        push    edi

        mov     esi, [ebp+8]       ; esi = arr
        mov     ecx, [ebp+12]      ; ecx = j = lo
        mov     edx, [ebp+16]      ; edx = hi
        mov     edi, [esi + edx*4] ; edi = pivot = arr[hi]
        mov     ebx, ecx
        dec     ebx                ; ebx = i = lo - 1

.loop:
        cmp     ecx, [ebp+16]
        jge     .after             ; j >= hi → loop finished
        mov     eax, [esi + ecx*4] ; eax = arr[j]
        cmp     eax, edi
        jg      .next              ; arr[j] > pivot (signed) → skip
        inc     ebx                ; i = i + 1
        mov     edx, [esi + ebx*4] ; swap arr[i], arr[j]
        mov     [esi + ebx*4], eax
        mov     [esi + ecx*4], edx
.next:
        inc     ecx                ; j = j + 1
        jmp     .loop

.after:
        inc     ebx                ; ebx = i + 1
        mov     ecx, [ebp+16]      ; ecx = hi
        mov     eax, [esi + ebx*4] ; swap arr[i + 1], arr[hi]
        mov     edx, [esi + ecx*4]
        mov     [esi + ebx*4], edx
        mov     [esi + ecx*4], eax
        mov     eax, ebx           ; return p = i + 1

        pop     edi                ; restore in reverse order
        pop     esi
        pop     ebx
        leave
        ret
