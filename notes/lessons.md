# Troubleshooting log and lessons learned

Problems hit while setting up and running the json-c fuzzing project, in the order they happened.

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | AFL++ build: `fatal error: 'llvm/Support/raw_ostream.h' file not found`, then `no compiler mode available` | LLVM development headers are a separate package from `clang`/`llvm` | `sudo apt install llvm-21-dev libclang-21-dev clang-21 lld-21`, then `make clean && make distrib -j1` |
| 2 | VM froze during `make distrib -j2` | About 1 GB per `clang++` job plus the desktop environment on 4 GB RAM caused heavy swapping | Add swap, use `-j1`, wait it out |
| 3 | `afl-system-config`: `cannot stat .../sched_child_runs_first` | Newer kernels removed that sysctl | Harmless, ignore. Re-run `sudo afl-system-config` after each reboot |
| 4 | Toy target: `corpus count: 1`, no new finds, `last new find: none yet` | The compiler optimized away the dead write (`p[10] = 'x'`), so the bug did not exist in the binary | Make the failure observable: `volatile` pointer, a `printf` of the value, `-O0`, nested `if`s |
| 5 | LAF-intel and CMPLOG did not help on the toy target | Wrong diagnosis: the issue was the missing bug, not the comparison structure | Verify with `echo FUZZ \| ./target` and `afl-showmap` before reaching for fuzzer features |
| 6 | `cmake`: `Unknown argument -j1`, `Ignoring extra path ... CMAKE_INSTALL_PREFIX` | `-j1` belongs to `make`, not `cmake`; it broke the argument list and dropped the install prefix | Put `-j1` on `make`. Re-run `cmake -DCMAKE_INSTALL_PREFIX=... .` in the build dir |
| 7 | `make install`: `Permission denied` on `/usr/local/lib/libjson-c.a` | Prefix was never set (see #6), so it defaulted to `/usr/local` | Install into `$HOME/jsonc-asan`, no sudo |
| 8 | Harness: `call to undeclared function 'read'` | `__AFL_FUZZ_TESTCASE_LEN` expands to `read()`; modern Clang rejects implicit declarations | Add `#include <unistd.h>` |
| 9 | VM display went black after hours | Guest screen blank / power saving | Fuzzer was still running (checked with `top` on a text console, `Ctrl+Alt+F3`). Set Screen Blank to Never and disable suspend |
| 10 | `afl-cmin` crashed with `TypeError: array() argument 1 must be a unicode character, not None` and hung | Bug inside `afl-cmin.py`, apparently with Python 3.14 (root cause not confirmed) | Use `afl-cmin.bash` instead |

## Takeaways

- Before trusting "no crashes", prove the target can crash and that instrumentation sees the paths (`afl-showmap`, manual runs).
- Compilers delete unobservable bugs. Make test bugs visible.
- Judge progress by edge count, not by "last new find". Hit-count changes also count as finds.
- On small VMs, `-j1`, a private install prefix and a leak-free harness are what let a run finish.
- A tool crash that looks like a hang (item 10) is worth checking in the traceback before waiting.
