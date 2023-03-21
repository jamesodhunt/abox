# Tests

## To run an individual CLI test 

```bash
$ bats_test='rm.bats'
$ cd "$build_dir/bats/test"
$ BUILD_DIR=.. "../../../bats/$bats_test"
```

## To debug a utility test

Set the `CK_FORK=no` variable to stop the `libcheck` library from
forking as that will confound debugging failing tests.

```bash
$ make utils-test
$ arch=$(uname -m)
$ CK_FORK=no gdb "builddir/arch/${arch}/src/utils/test-utils"
```
