;
; search.asm - bsearch_asm, a recursive binary search callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now it always returns 0, which
; makes the benchmark report a match at index 0 for any key. Your job is to
; replace that with the search described below.
;
; The contract, from bench.c:
;
;       int key                    [ebp+16]
;       int n                      [ebp+12]
;       int *arr                   [ebp+8]
;
; Return the index of key in the sorted array, or -1 if it is absent.
; Preserve ebx/esi/edi/ebp, return in eax, and obey cdecl for the outer
; routine (the internal recursive one may use any convention you document).
;
; Requirements from the manual:
;
;   * Recursive.
;   * Compute the midpoint as lo + (hi - lo) / 2, never (lo + hi) / 2.
;     The sum can overflow 32 bits on large arrays. The difference cannot.
;     This exact bug lived in the Java standard library for nine years.
;   * An absent key returns -1.
;   * An empty array and a single-element array must behave.
;   * No calls into the C standard library.
;
; The manual's pseudocode:
;
;   bsearch(arr, lo, hi, key):
;       if lo > hi: return -1
;       mid = lo + (hi - lo) / 2
;       if arr[mid] == key: return mid
;       if arr[mid] < key:  return bsearch(arr, mid + 1, hi, key)
;       else:               return bsearch(arr, lo, mid - 1, key)
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _bsearch_asm bsearch_asm
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _bsearch_asm
_bsearch_asm:
        enter   0,0

        mov     eax, [ebp+12]           ; eax = n
        dec     eax                     ; hi = n - 1

        push    dword [ebp+16]          ; key
        push    eax                     ; hi
        push    dword 0                 ; lo
        push    dword [ebp+8]           ; arr
        call    bsearch_rec
        add     esp, 16                 ; pop 4 args

        leave
        ret

;
; bsearch_rec(arr, lo, hi, key): index of key in arr[lo..hi], or -1.
; Internal, cdecl.
; Uses only eax, ecx, edx.
;
;       int key                     [ebp+20]
;       int hi                      [ebp+16]
;       int lo                      [ebp+12]
;       int *arr                    [ebp+8]
;
bsearch_rec:
        enter   0,0

        mov     ecx, [ebp+12]           ; ecx = lo
        mov     edx, [ebp+16]           ; edx = hi
        cmp     ecx, edx
        jg      .absent                 ; lo > hi: empty range

        ; mid = lo + (hi - lo) / 2
        ; (lo + hi) / 2 can overflow past 2^31 - 1.
        ; hi - lo cannot, and is never negative here.
        mov     eax, edx                ; eax = hi
        sub     eax, ecx                ; eax = hi - lo
        shr     eax, 1                  ; eax = (hi - lo) / 2
        add     eax, ecx                ; eax = mid

        mov     edx, [ebp+8]            ; edx = arr
        mov     edx, [edx+4*eax]        ; edx = arr[mid], 4 bytes per int
        cmp     edx, [ebp+20]           ; arr[mid] vs key
        je      .done                   ; found, eax = mid
        jl      .right                  ; arr[mid] < key: go right

.left:                                  ; arr[mid] > key: go left
        dec     eax                     ; eax = mid - 1
        push    dword [ebp+20]          ; key
        push    eax                     ; hi = mid - 1
        push    dword [ebp+12]          ; lo
        push    dword [ebp+8]           ; arr
        call    bsearch_rec
        add     esp, 16                 ; pop 4 args
        jmp     .done                   ; eax = result

.right:
        inc     eax                     ; eax = mid + 1
        push    dword [ebp+20]          ; key
        push    dword [ebp+16]          ; hi
        push    eax                     ; lo = mid + 1
        push    dword [ebp+8]           ; arr
        call    bsearch_rec
        add     esp, 16                 ; pop 4 args
        jmp     .done                   ; eax = result

.absent:
        mov     eax, -1                 ; not found

.done:
        leave
        ret
