# Tests

Tests are written using
[Bats-core](https://github.com/bats-core/bats-core#readme) testing framework.
A docker container is used to setup the testing environment to run these. The
`test.sh` script should be used to run the tests.

```sh
./test.sh
```

Or only a specific test.

```sh
./test.sh site-init.bats
```

Or interactively from within the container.

```sh
DEBUG=y ./test.sh
```
