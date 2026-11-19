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
        enter   0,0                     ; push ebp; mov ebp, esp
                                        ; uses only eax, so nothing else to save

        ; n = 0 gives hi = -1, so bsearch_rec returns -1 without reading arr
        mov     eax, [ebp+12]           ; eax = n
        dec     eax                     ; eax = n - 1

        ; initialize the recursive search 
        ; lo = 0, hi = n - 1, key = [ebp+16], arr = [ebp+8]
        push    dword [ebp+16]          ; key
        push    eax                     ; hi
        push    dword 0                 ; lo
        push    dword [ebp+8]           ; arr

        ; Going to here 
        call    bsearch_rec             ; eax = bsearch_rec(arr, 0, n - 1, key)

        ; Cleaning up the stack after the call
        add     esp, 16                 ; remove 4 arguments

        leave
        ret

;
; bsearch_rec(arr, lo, hi, key) - the recursive binary search.
;
; Internal convention: cdecl, the same as the C-facing routine.
;       int key                     [ebp+20]
;       int hi                      [ebp+16]
;       int lo                      [ebp+12]
;       int *arr                    [ebp+8]
; Returns the index of key in arr[lo..hi], or -1, in eax. Clobbers eax,
; ecx, edx. Preserves ebx, esi, edi, ebp. The caller removes the 4 arguments.
;
bsearch_rec:
        enter   0,0

        ; The first thing to do is check if the range is empty. 
        ;If lo > hi, then the key is absent and we return -1.
        ;Otherwise, we compute the midpoint and compare the value at that index with the key. 

        ; Initialize arguments
        mov     ecx, [ebp+12]           ; ecx = lo
        mov     edx, [ebp+16]           ; edx = hi

        ; Checking if the range is empty
        cmp     ecx, edx
        jg      .absent                 ; lo > hi: empty range

        ; mid = lo + (hi - lo) / 2
        ; (lo + hi) / 2 can overflow past 2^31 - 1 for large indices.
        ; hi - lo cannot, since it is at most the array length. It is also
        ; never negative here (lo <= hi), so shr halves it correctly.
        mov     eax, edx                ; eax = hi
        sub     eax, ecx                ; eax = hi - lo
        shr     eax, 1                  ; eax = (hi - lo) / 2
        add     eax, ecx                ; eax = mid

        ; At the midpoint, we can compare the value at that index with the key.
        mov     edx, [ebp+8]            ; edx = arr  (address of the array)
        mov     edx, [edx + eax*4]      ; edx = arr[mid]

        ; one compare sets the flags for all three outcomes
        cmp     edx, [ebp+20]           ; Key we are searching for
        je      .done                   ; arr[mid] == key: found, eax = mid
        jl      .right                  ; arr[mid] < key: go right

;lo to mid - 1
.left:                                  ; arr[mid] > key: fall through, go left
        dec     eax                     ; eax = mid - 1
        push    dword [ebp+20]          ; key
        push    eax                     ; hi = mid - 1
        push    dword [ebp+12]          ; lo
        push    dword [ebp+8]           ; arr
        call    bsearch_rec             ; eax = bsearch_rec(arr, lo, mid - 1, key)
        add     esp, 16                 ; remove 4 arguments
        jmp     .done                   ; return eax

; mid + 1 to hi
.right:
        inc     eax                     ; eax = mid + 1
        push    dword [ebp+20]          ; key
        push    dword [ebp+16]          ; hi
        push    eax                     ; lo = mid + 1
        push    dword [ebp+8]           ; arr
        call    bsearch_rec             ; eax = bsearch_rec(arr, mid + 1, hi, key)
        add     esp, 16                 ; remove 4 arguments
        jmp     .done                   ; return eax

.absent:
        mov     eax, -1                 ; not found

.done:
        leave
        ret
