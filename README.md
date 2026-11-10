# json-c-fuzzing

Coverage-guided fuzzing of [json-c](https://github.com/json-c/json-c) with AFL++ and AddressSanitizer, using a persistent-mode harness on a resource-constrained VM (4 GB RAM).

This is a methodology project, not a vulnerability report. The run found **no crashes or hangs**. json-c is a mature library that is already continuously fuzzed, so a null result was the expected outcome. The goal was to build a correct, fast, reproducible fuzzing pipeline and to understand where it plateaus and why.

A full narrative, including the mistakes along the way, is in [`WRITEUP LINK`](https://medium.com/@lastknowngood/fuzzing-json-c-with-afl-and-asan-on-a-4-gb-vm-setup-mistakes-and-a-null-result-1383ec452c42). 

## Results

| Metric | Value |
|---|---|
| Run time | 29,279 s (about 8 h 8 min), single core |
| Total executions | 272,018,758 |
| Average speed | about 9,300 exec/s (peaked around 18,000 exec/s early in the run) |
| Corpus (raw) | 1,261 inputs, grown from 5 seeds |
| Edges found | 590 |
| Stability | 98.64% |
| Crashes / hangs | 0 / 0 |

Coverage had effectively plateaued early. Between the 16-minute mark and the 8-hour mark, new edges only went from 148 to 151, so the extra hours added very little.

## Environment

| Component | Version |
|---|---|
| OS | Ubuntu 26.04 LTS (VirtualBox VM, 4 GB RAM, 4 vCPUs) |
| AFL++ | 4.33c (`afl-clang-fast`, LLVM-PCGUARD mode) |
| Clang / LLVM | 21.1.8 |
| Sanitizer | AddressSanitizer (`AFL_USE_ASAN=1`) |
| json-c | `json-c 0.19` |

## Repository layout

```
harness/jc_harness.c   persistent-mode AFL++ harness
build.sh
results/
  fuzzer_stats         final AFL++ statistics
  plot_data            raw plot data
```

## What the harness does

`harness/jc_harness.c` uses AFL++ persistent mode (`__AFL_LOOP(10000)`) and shared-memory input (`__AFL_FUZZ_TESTCASE_BUF`), so there is no process spawn or file I/O per input. Each iteration:

1. Parses the input with `json_tokener_parse_ex` and an explicit length (the buffer is not NUL-terminated).
2. If parsing succeeds, serializes the object with `json_object_to_json_string_ext(..., JSON_C_TO_STRING_PRETTY)`, so the serializer is exercised and not just the parser.
3. Frees everything (`json_object_put`, `json_tokener_free`) so memory does not grow across iterations.

## Reproducing the run

**1. Install dependencies and build AFL++**

```bash
sudo apt install -y build-essential git python3-dev automake cmake flex bison \
  libglib2.0-dev libpixman-1-dev python3-setuptools cpio libtool-bin ninja-build \
  clang llvm lld llvm-21-dev libclang-21-dev clang-21 lld-21

git clone https://github.com/AFLplusplus/AFLplusplus
cd AFLplusplus
make distrib -j1        # -j1 on 4 GB RAM; higher values caused heavy swapping
sudo make install
```

**2. Build json-c with ASan into a private prefix**

```bash
cd ~ && git clone https://github.com/json-c/json-c && cd json-c
mkdir build && cd build
AFL_USE_ASAN=1 CC=afl-clang-fast cmake .. \
  -DCMAKE_BUILD_TYPE=Debug -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX=$HOME/jsonc-asan -DCMAKE_INSTALL_LIBDIR=lib
AFL_USE_ASAN=1 make -j1
make install
```

**3. Compile the harness**

```bash
AFL_USE_ASAN=1 afl-clang-fast -O1 -g harness/jc_harness.c \
  -I$HOME/jsonc-asan/include -o jc_harness $HOME/jsonc-asan/lib/libjson-c.a
echo '{"a":[1,2]}' | ./jc_harness; echo $?    # expect 0
```

**4. Fuzz**

```bash
sudo afl-system-config          # re-run after every reboot
afl-fuzz -m none -x ~/AFLplusplus/dictionaries/json.dict \
  -i seeds -o out_jc -- ./jc_harness
```

`-m none` is needed because ASan reserves a very large virtual address space. The dictionary ships with AFL++.

**5. Minimize the corpus**

```bash
afl-cmin.bash -m none -i out_jc/default/queue -o results/corpus_min -- ./jc_harness
```

I used `afl-cmin.bash` because the Python `afl-cmin` crashed on this system (see the write-up).

## Limitations

- **Single harness, single entry point.** Only the tokener and the pretty-print serializer are exercised. Other APIs (JSON pointer, JSON patch, `json_object_from_file`, strict-mode tokener flags) are not covered.
- **No coverage report yet.** I judged the plateau from AFL++ statistics, not from line-level coverage. An `llvm-cov` report would show exactly which code the harness never reaches.
- **One run, one core, about 8 hours.** No parallel instances, no CMPLOG or structure-aware mutation.
- **Zero findings** means this harness did not trigger a memory error in this time. It is not a statement about json-c's security.

## Next steps

- Generate an `llvm-cov` report and identify unreached code.
- Write a second harness for `json_pointer_*` and `json_patch_apply`.
- Fuzz with different `json_tokener` flags (strict mode, trailing characters).
- Try parallel instances and CMPLOG.

## License

Harness and notes: MIT. json-c and AFL++ are covered by their own licenses.
