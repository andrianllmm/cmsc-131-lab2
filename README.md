<!--no-pdf-->
# CMSC 131 Lab 2 Starter

[![lab2-checks](https://github.com/WhiteLicorice/cmsc-131-lab2-starter/actions/workflows/test.yml/badge.svg)](https://github.com/WhiteLicorice/cmsc-131-lab2-starter/actions/workflows/test.yml)

A C-callable library of sort, search, and utility routines in assembly. The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile       platform preamble and build rules
bench.c        provided: file I/O, timing, the C-side comparison, the hostile caller
cdecl.h        provided: the calling-convention macros
LICENSE        provided
sort.asm       yours
search.asm     yours
util.asm       yours
run_tests.sh   provided: the correctness gate
tests/         provided: the test corpus
```

## What to Run

On Windows, run these commands in Git Bash, the shell from Block 1. In that
shell, `make` is your alias for `mingw32-make`. On Linux, use your terminal.

```bash
make
make check
```

`make` builds `bench`. `make check` builds, then runs `./run_tests.sh`,
which reports each check and exits nonzero when any of them fail. Each run
is captured first. Its exit status is read before its text is examined,
so a program that prints the right line and then crashes still fails.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, and 19
of the 36 checks fail. The seventeen that pass prove little. Four are files
that arrive empty, single-element, or already sorted. `gcd(0, 0)` expects 0.
The hostile caller cannot be upset by a stub that touches no register. The
rest are argument and file refusals that the harness performs before any
assembly runs. That red run is the correct starting state for a starter. The
badge stays red until you implement the routines.

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `bench.c`, `Makefile`, `run_tests.sh`, or a `tests/`
file appears as a diff in the open.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

---

## Design Notes

Complete this section before the Week 1 progress report and finish it by
Week 3. The syllabus asks for problem analysis, a solution architecture,
and an estimated timeline. The manual's Deliverables section lists what
this activity adds. Keep each part short. Update it when the plan changes.

### Problem analysis

The four routines `bench.c` expects and what each one returns. Which
registers you preserve and why.

We write four routines for `bench.c`. All are recursive and none call the C
library.

| Routine | Arguments | Returns |
|---|---|---|
| `qsort_asm` | `int *arr, int n` | nothing; sorts `arr` in place, ascending |
| `bsearch_asm` | `int *arr, int n, int key` | index of `key`, or -1 if absent |
| `gcd_asm` | `int a, int b` | gcd of `a` and `b` |
| `sum_range_asm` | `int lo, int hi` | sum of `lo..hi`, or 0 if `lo > hi` |

`gcd_asm` also sets the global `gcd_depth` to the deepest number of gcd
calls on the stack, counting the first as 1. `bench.c` reads it after the
call returns, so we keep the peak, not the current level.

`sum_range_asm` calls `bench_callback` once per call from C, never from its
recursion. `bench` uses it to start a second call mid-flight and checks
that both results come out right.

On cdecl: the caller pushes arguments right to left (first at `[ebp+8]`)
and pops them after the call. Results go in `eax`. `eax`, `ecx`, and `edx`
are caller-saved, so we can clobber them. `ebx`, `esi`, `edi`, and `ebp`
are callee-saved, so we push and pop any we use. The hostile caller checks
this.

### Solution architecture

A stack frame diagram for one recursive call of `qsort_asm`, showing where
the arguments, the return address, saved `ebp`, and the saved registers
sit. Why `sum_range_asm` is reentrant.

The sort and search have to be recursive because the activity tests how we
build stack frames. Each call keeps its own `lo` and `hi` in its frame. A
loop with a manual stack would skip that.

We split the code into `sort.asm`, `search.asm`, and `util.asm`, one per
subsystem. Each of us owns one file, so we don't step on each other and
the history shows who did what.

### Measurements

The ratio `bench` reports on `random1000.txt`, `sorted1000.txt`,
`reverse1000.txt`, `duplicates.txt`, and `identical.txt`. Your worst case
and its cause. One improvement and its estimated effect.

| File | Ratio |
|---|---|
| `random1000.txt` | |
| `sorted1000.txt` | |
| `reverse1000.txt` | |
| `duplicates.txt` | |
| `identical.txt` | |

### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

| Week | Goal | Owner |
|---|---|---|
| 1 | Design Notes, ownership, build runs on the stubs | All of us |
| 2 | Sorting and searching pass their checks | @Romyr05, @andrianllmm |
| 3 | `sum_range_asm`, measurements, quirks and issues | @dejely |
| 4 | Defense | All of us |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists
the three subsystems. Each member owns one. In a group of four, two members
share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---|
| Sorting (`qsort_asm` and its partition) | @Romyr05 |
| Searching (`bsearch_asm`, `gcd_asm`) | @andrianllmm |
| Convention and measurement (`sum_range_asm`, the benchmarks) | @dejely |

## Quirks and Issues

Complete this section before the Week 3 progress report. The syllabus asks
for documentation of quirks and issues with the complete implementation.
One entry per item. State what happens, what causes it, and what the group
did about it.

### Known issues

- 

### Quirks

- 
