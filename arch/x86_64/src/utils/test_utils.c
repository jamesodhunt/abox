/*--------------------------------------------------------------------
 * vim:set noexpandtab:
 *--------------------------------------------------------------------
 * Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 *--------------------------------------------------------------------
 * Description: See DESIGN.md.
 *--------------------------------------------------------------------
 */

#define _GNU_SOURCE /* for asprintf */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h> /* PIPE_BUF */
#include <fcntl.h> /* O_* flags */
#include <time.h>
#include <libgen.h> /* basename(3) */

#include <check.h>

/* Number of argv elements to use for testing */
#define TEST_ARGV_ELEMS             4

/* We need more to test getopt */
#define TEST_GETOPT_ARGV_ELEMS      6

/* If this variable is set to any value, show test debug output */
#define DEBUG_VAR "DEBUG"

#define show_debug() \
    getenv(DEBUG_VAR)

#define check_test_func(t) \
{ \
    assert((t)->name); \
    assert((t)->fp); \
}

#define mk_test_func_entry(test_func, test_type) \
{ #test_func, test_type, test_func }

#define run_test_funcs(test_array, test_type, test_handler) \
{ \
    size_t count = sizeof((test_array)) / sizeof((test_array)[0]); \
    \
    for (size_t i = 0; i < count; i++) { \
        test_type *t = &(test_array)[i]; \
        \
        if (show_debug()) { \
            fprintf(stderr, \
                    "DEBUG: %s:%d testing function '%s' " \
                    "(type '%s', fp %p)\n", \
                    __func__, __LINE__, \
                    t->name, \
                    func_type_to_str(t->func_type), \
                    t->fp); \
        } \
        \
        (test_handler)(t); \
        \
        if (show_debug()) { \
            fprintf(stderr, \
                    "DEBUG: %s:%d tested function '%s' " \
                    "(type '%s', fp %p)\n", \
                    __func__, __LINE__, \
                    t->name, \
                    func_type_to_str(t->func_type), \
                    t->fp); \
        } \
    } \
}

/*------------------------------------------------------------------*/
/* C prototypes for assembly language routines under test */

extern char *asm_basename(char *path);
extern char *asm_strchr(const char *s, int c);
extern int asm_getopt(int argc, char *const argv[], const char *optstring);
extern size_t asm_strlen(const char *msg);

extern int get_errno(void);
extern int libc_strtol(const char *str, int base, long *result);
extern int num_to_timespec(const char *num, struct timespec *ts);
extern size_t argv_bytes(int argc, const char *argv[]);
extern ssize_t read_block(int fd, void *buffer, size_t bytes);
extern ssize_t write_block(int fd, const void *buffer, size_t bytes);
extern void *alloc_args_buffer(int argc, const char *argv[], size_t *bytes);
extern void set_errno(int value);

/*------------------------------------------------------------------*/
/* utilities */

typedef ssize_t Reader(int fd, void *buffer, size_t count);
typedef ssize_t Writer(int fd, const void *buffer, size_t count);

ssize_t safe_write(int fd, const void *buffer, size_t count);
ssize_t safe_read(int fd, void *buffer, size_t count);

void test_read_and_write(const char *description, Reader *reader, Writer *writer);

/*------------------------------------------------------------------*/

/* To ensure the validity of the tests, if a function has a system
 * equivalent, we run the test using the system function first as a
 * control (as we expect all tests to pass with the official
 * implemenation. We then run the test again for the local assembly
 * implementation.
 *
 * This enum allows us to discrimine between the function types.
 */
enum FuncType {
    SYSTEM_FUNC,
    ASM_FUNC,
};

const char *
func_type_to_str(enum FuncType ft)
{
    switch (ft)
    {
        case SYSTEM_FUNC: return "system";
        case ASM_FUNC: return "ASM";
        default: return "unknown";
    }
}

/*------------------------------------------------------------------*/

typedef struct basename_test_func {
    const char *name;
    enum FuncType func_type;
    char *(*fp)(char *path);
} BasenameTestFunc;

typedef struct getopt_test_func {
    const char *name;
    enum FuncType func_type;
    int (*fp)(int argc, char *const argv[], const char *optstring);
} GetoptTestFunc;

typedef struct strlen_test_func {
    const char *name;
    enum FuncType func_type;
    size_t (*fp)(const char *s);
} StrlenTestFunc;

typedef struct strchr_test_func {
    const char *name;
    enum FuncType func_type;
    char *(*fp)(const char *s, int c);
} StrchrTestFunc;

/*------------------------------------------------------------------*/

START_TEST(test_asm_utils_errno)
{
    /* test get errno */
    int actual_errno = errno;
    int test_errno = get_errno();

    ck_assert_int_eq(actual_errno, test_errno);

    /* test get errno */
    int value = 7;
    set_errno(value);

    /* re-test get errno */
    actual_errno = errno;
    test_errno = get_errno();

    ck_assert_int_eq(actual_errno, value);
    ck_assert_int_eq(actual_errno, test_errno);
}
END_TEST

void
handle_test_strlen(StrlenTestFunc *tf)
{
    check_test_func(tf);

    typedef struct test_data {
        const char *str;
        size_t len;
    } TestData;

    TestData tests[] = {
        { NULL, 0},
        { "", 0 },
        { "\0", 0 },

        { "a", 1 },
        { "a\0b", 1 },
        { ".", 1 },
        { " ", 1 },
        { "\t", 1 },
        { "\n", 1 },

        { "  ", 2 },
        { "   ", 3 },
        { "\t\t\t", 3 },
        { "\t\n\n", 3 },
        { "\n\n\n", 3 },
        { "foo", 3 },
        { "a b", 3 },
        { "a\tb", 3 },
        { "a\nb", 3 },

        { "hello, world", 12 },
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        if (!t->str && tf->func_type == SYSTEM_FUNC) {
            fprintf(stderr,
                    "WARNING: skipping '%s(NULL)' test for %s "
                    "implementation (not tolerated)\n",
                    tf->name,
                    func_type_to_str(tf->func_type));
            continue;
        }

        size_t len = tf->fp(t->str);

        ck_assert_int_eq(len, t->len);
    }
}

START_TEST(test_asm_utils_asm_strlen)
{
    StrlenTestFunc test_funcs[] = {
        mk_test_func_entry(strlen, SYSTEM_FUNC),
        mk_test_func_entry(asm_strlen, ASM_FUNC),
    };

    run_test_funcs(test_funcs, StrlenTestFunc, handle_test_strlen);
}
END_TEST

/* For getopt behaviour, see:
 *
 * https://pubs.opengroup.org/onlinepubs/9699919799.2018edition/functions/getopt.html
 */
void
handle_test_getopt(GetoptTestFunc *tf)
{
    check_test_func(tf);

    /* The set of variables that we need to check after a call.
     *
     * Note that we test optind automatically below.
     */
    typedef struct test_arg_result {
        int ret;
        const char *optarg;
        int optind;
        int optopt;
    } ArgResult;

    typedef struct test_data {
        /* A brief description of the test */
        const char *name;

        int argc;
        const char **argv;

        const char *optstring;
        /* We provide a set of results since for each test we will call
         * asm_getopt TEST_GETOPT_ARGV_ELEMS times, once for each CLI
         * argument.
         */
        ArgResult *results[TEST_GETOPT_ARGV_ELEMS];
    } TestData;

    /* Note that we force POSIXLY_CORRECT mode by prefixing optstring
     * with "+" in some of the tests below, as documented in getopt(3).
     *
     * The ASM implementation doesn't recognise "+" but since it only
     * handles POSIX behaviour anyway, it's benign.
     */
    TestData tests[] = {
        {  .name = "boolean option",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-a", NULL, NULL, NULL},
            .optstring = "a",
            .results = { &(ArgResult){'a', NULL, 2, 0}, NULL, NULL, NULL, NULL },
        },

        {  .name = "non-bundled option",
            .argc = 3,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-c", "command", NULL, NULL},
            .optstring = "c:",
            .results = { &(ArgResult){'c', "command", 3, 0}, NULL, NULL, NULL, NULL },
        },

        {  .name = "bundled option",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-bbundled", NULL, NULL, NULL},
            .optstring = "ab:z",
            .results = { &(ArgResult){'b', "bundled", 2, 0}, NULL, NULL, NULL, NULL },
        },

        {  .name = "return on 1st non option (POSIX)",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "ignored", NULL, NULL, NULL},
            .optstring = "+a",
            .results = { &(ArgResult){-1, NULL, 1, 0}, NULL, NULL, NULL, NULL },
        },

        {  .name = "two bool options",
            .argc = 3,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-a", "-b", NULL, NULL},
            .optstring = "ab",
            .results = { &(ArgResult){'a', NULL, 2, 0}, &(ArgResult){'b', NULL, 3, 0}, NULL, NULL, NULL },
        },

        {  .name = "two options needing args",
            .argc = 5,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-c", "command", "-d", "foo", NULL},
            .optstring = "c:d:",
            .results = { &(ArgResult){'c', "command", 3, 0}, &(ArgResult){'d', "foo", 5, 0}, NULL, NULL, NULL },
        },

        {  .name = "two bundled options",
            .argc = 5,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-ccommand", "-dfoo", NULL},
            .optstring = "c:d:",
            .results = { &(ArgResult){'c', "command", 2, 0}, &(ArgResult){'d', "foo", 3, 0}, NULL, NULL, NULL },
        },

        {  .name = "bool option before option needing arg",
            .argc = 4,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-a", "-c", "command", NULL},
            .optstring = "ac:",
            .results = { &(ArgResult){'a', NULL, 2, 0}, &(ArgResult){'c', "command", 4, 0}, NULL, NULL, NULL },
        },

        {  .name = "option needing arg before bool option",
            .argc = 4,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-c", "command", "-a", NULL},
            .optstring = "ac:",
            .results = { &(ArgResult){'c', "command", 3, 0}, &(ArgResult){'a', NULL, 4, 0}, NULL, NULL, NULL },
        },

        /* FIXME: can't handle this yet. */
#if 0
        {  .name = "boolean option with unexpected bundled value",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-datoz", NULL, NULL, NULL},
            .optstring = "c:d",

            .results = { &(ArgResult){'d', NULL, 1, 0}, NULL, NULL, NULL, NULL },
        },
#endif
        {  .name = "Options ignored after single dash arg",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-", "-a", NULL, NULL},
            .optstring = "+a",
            .results = { &(ArgResult){-1, NULL, 1, 0}, NULL, NULL, NULL, NULL },
        },

        {  .name = "Options ignored after double dash arg",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "--", "-a", NULL, NULL},
            .optstring = "+a",
            .results = { &(ArgResult){-1, NULL, 2, 0}, NULL, NULL, NULL, NULL },
        },

        /* Error scenarios */
        {  .name = "non-bundled option with missing arg",
            .argc = 2,
            .argv = (const char *[TEST_GETOPT_ARGV_ELEMS]){"prog", "-c", NULL, NULL, NULL},
            .optstring = "c:",
            .results = { &(ArgResult){'?', NULL, 2, 'c'}, NULL, NULL, NULL, NULL },
        },


    };

    int ret;

    /* The system implementation cannot cope with invalid args */
    if (tf->func_type != SYSTEM_FUNC) {
        /* Perform some basic initial tests */
        ret = tf->fp(0, NULL, "");
        ck_assert_int_eq(ret, -1);

        ret = tf->fp(1, NULL, "");
        ck_assert_int_eq(ret, -1);

        ret = tf->fp(3, NULL, "");
        ck_assert_int_eq(ret, -1);

        ret = tf->fp(3, NULL, "abc:");
        ck_assert_int_eq(ret, -1);

        ret = tf->fp(0, NULL, "abc:");
        ck_assert_int_eq(ret, -1);
    }

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        /* Reset global state to POSIX prescribed values.
         *
         * Note: We'd like to check these values initially, but we can't
         * as GNU getopt (which may have been called previously)
         * maintains internal state with no way to reset it correctly.
         */
        optarg = NULL;
        opterr = 1;
        optopt = '?';
        optind = 1;

        if (show_debug()) {
            fprintf(stderr, "FIXME: "
                    "Test[%d] ('%s'): "
                    "argc: %d, "
                    "argv: (0: '%s', 1: '%s', 2: '%s', 3: '%s', 4: '%s'), "
                    "optstring: '%s'\n",
                    i,
                    t->name ? t->name : "",
                    t->argc,
                    t->argv[0] ? t->argv[0] : "",
                    t->argv[1] ? t->argv[1] : "",
                    t->argv[2] ? t->argv[2] : "",
                    t->argv[3] ? t->argv[3] : "",
                    t->argv[4] ? t->argv[4] : "",
                    t->optstring ? t->optstring : "");
        }

        for (int arg = 0; arg < TEST_GETOPT_ARGV_ELEMS; arg++) {
            const ArgResult *result = t->results[arg];

            if (! result) {
                /* Test has indicated no more results expected */
                break;
            }

            if (show_debug()) {
                fprintf(stderr, "FIXME: "
                        "    arg[%d]: expected result : ret: %d ('%c'),"
                        " optarg: '%s', optind: %d, optopt: %d ('%c')\n",
                        arg,
                        result->ret,
                        result->ret,
                        result->optarg ? result->optarg : "",

                        result->optind,

                        result->optopt,
                        result->optopt);
            }

            int ret = tf->fp(t->argc, (char ** const)t->argv, t->optstring);

            if (show_debug()) {
                fprintf(stderr, "FIXME: "
                        "    arg[%d]: actual result   : ret: %d ('%c'),"
                        " optarg: '%s', optind: %d, optopt: %d ('%c')\n",
                        arg,
                        ret,
                        ret,
                        optarg ? optarg : "",
                        optind,
                        optopt,
                        optopt);
            }

            ck_assert_int_eq(ret, result->ret);
            ck_assert_int_eq(optind, result->optind);
            ck_assert_int_eq(optopt, result->optopt);

            if (! result->optarg) {
                ck_assert_ptr_eq(optarg, result->optarg);
            } else {
                ck_assert_str_eq(optarg, result->optarg);
            }
        }

        if (show_debug()) {
            fprintf(stderr, "FIXME: Test[%d]: SUCCESS\n", i);
        }
    }
}

START_TEST(test_asm_utils_asm_getopt)
{
    GetoptTestFunc test_funcs[] = {
        mk_test_func_entry(getopt, SYSTEM_FUNC),
        mk_test_func_entry(asm_getopt, ASM_FUNC),
    };

    run_test_funcs(test_funcs, GetoptTestFunc, handle_test_getopt);
}
END_TEST

void
handle_test_basename(BasenameTestFunc *tf)
{
    check_test_func(tf);

    /* Note that basename(3) doesn't return a meaningful
     * error value to check for.
     */
    typedef struct test_data {
        const char *path;
        const char *result;
    } TestData;

    TestData tests[] = {
        { NULL, "." },
        { "", "." },
        { "/", "/" },
        { "/ ", " " },
        { "/ /", " " },
        { "/// /////", " " },
        { "///foo/////", "foo" },

        /* From basename(3) */
        { "/usr/lib", "lib" },
        { "/usr/", "usr" },
        { "usr", "usr" },
        { "/", "/" },
        { ".", "." },
        { "..", ".." },

        /* Good website! ;) */
        { "/.", "." },

        { "../", ".." },
        { "/../", ".." },
        { "/..", ".." },
        { "../", ".." },
        { "./../", ".." },
        { "./.", "." },
        { "./..", ".." },
        { "...", "..." },
        { ".....", "....." },

        /* If the path doesn't contain a slash, it is returned
         * verbatim.
         */
        { "a", "a" },
        { "az", "az" },
        { "foo", "foo" },
        { " ", " " },
        { "  ", "  " },
        { "   ", "   " },
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        char buffer[BUFSIZ];

        /* basename modifies its arg, so give it a writable copy */
        if (t->path) {
            strcpy(buffer, t->path);
        }

        const char *result = tf->fp(t->path ? buffer : NULL);

        if (show_debug()) {
            fprintf(stderr, "FIXME: "
                    "    test[%d]: path: '%s', expected result: '%s', "
                    "actual result: '%s'\n",
                    i,
                    t->path ? buffer : "",
                    t->result ? t->result: "",
                    result ? result : "");
        }
        fflush(NULL);

        ck_assert_ptr_nonnull(result);

        ck_assert_str_eq(result, t->result);
    }
}

START_TEST(test_asm_utils_asm_basename)
{
    BasenameTestFunc test_funcs[] = {
        mk_test_func_entry(basename, SYSTEM_FUNC),
        mk_test_func_entry(asm_basename, ASM_FUNC),
    };

    run_test_funcs(test_funcs, BasenameTestFunc, handle_test_basename);
}
END_TEST

void
handle_test_strchr(StrchrTestFunc *tf)
{
    check_test_func(tf);

    typedef struct test_data {
        const char *s;
        int c;
        const char *result;
    } TestData;

    const char *b = "b";
    const char *foo = "foo";

    TestData tests[] = {
        { NULL, 0, NULL },
        { NULL, 'a', NULL },

        /* Search for trailing '\0' */
        { b, 0, b+strlen(b) },
        { foo, 0, foo+strlen(foo) },

        { "wibble", 'z', NULL },
        { "wibble", UCHAR_MAX, NULL },
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        if (!t->s && tf->func_type == SYSTEM_FUNC) {
            fprintf(stderr,
                    "WARNING: skipping '%s(NULL)' test for %s "
                    "implementation (not tolerated)\n",
                    tf->name,
                    func_type_to_str(tf->func_type));
            continue;
        }
        char *result = tf->fp(t->s, t->c);

        if (show_debug()) {
            fprintf(stderr, "FIXME: "
                    "    test[%d]: s: '%s', c: %d, expected result: '%s' (%p), "
                    "actual result: '%s' (%p)\n",
                    i,
                    t->s ? t->s : "",
                    t->c,
                    t->result ? t->result: "",
                    t->result,
                    result ? result : "",
                    result);
        }

        if (t->result) {
            ck_assert_ptr_nonnull(result);

            /* Search byte was '\0' */
            if (!*t->result) {
                ck_assert(!*result);
            } else {
                /* Search byte was not the delimiter */
                ck_assert_str_eq(result, t->result);
            }
        } else {
            ck_assert_ptr_null(result);
        }
    }
}

START_TEST(test_asm_utils_asm_strchr)
{
    StrchrTestFunc test_funcs[] = {
        mk_test_func_entry(strchr, SYSTEM_FUNC),
        mk_test_func_entry(asm_strchr, ASM_FUNC),
    };

    run_test_funcs(test_funcs, StrchrTestFunc, handle_test_strchr);
}
END_TEST

START_TEST(test_asm_utils_argv_bytes)
{
    typedef struct test_data {
        int argc;
        const char *argv[TEST_ARGV_ELEMS];
        size_t len;
    } TestData;

    const char *empty = "";
    const char *single_byte = "x";
    const char *foo = "foo";
    const char *hello_world = "hello_world";

    TestData tests[] = {
        { 0, {NULL, NULL, NULL, NULL}, 0 },
        { 1, {empty, NULL, NULL, NULL}, 0 },
        { 2, {empty, empty, NULL, NULL}, 0 },
        { 3, {empty, empty, empty, NULL}, 0 },
        { 4, {empty, empty, empty, empty}, 0 },

        { 1, {single_byte, NULL, NULL, NULL}, 1 },
        { 2, {single_byte, single_byte, NULL, NULL}, (1+1) },
        { 3, {single_byte, single_byte, single_byte, NULL}, (1+1+1) },
        { 4, {single_byte, single_byte, single_byte, single_byte}, (1+1+1+1) },

        { 1, {foo, NULL, NULL, NULL}, 3 },
        { 2, {foo, foo, NULL, NULL}, (3+3) },
        { 3, {foo, foo, foo, NULL}, (3+3+3) },
        { 4, {foo, foo, foo, foo}, (3+3+3+3) },

        { 3, {foo, hello_world, single_byte, NULL}, (3+11+1) },
        { 3, {hello_world, hello_world, hello_world, NULL}, (11+11+11) },
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        size_t len = argv_bytes(t->argc, (const char **)t->argv);

        ck_assert_int_eq(len, t->len);
    }
}
END_TEST

START_TEST(test_asm_utils_libc_strtol)
{
    long result;

    typedef struct test_data {
        const char *str;
        int base;
        long *num;
        int expected_return;
        long expected_result;
    } TestData;

    TestData tests[] = {
        {NULL, 0, NULL, -1, -1},
        {"foo", 10, &result, -1, -1},
        {"0", 10, &result, 0, 0},
        {"3abc", 10, &result, -1, -1},
        {"abc3", 10, &result, -1, -1},
        {"-1", 10, &result, 0, -1},
        {"-17", 10, &result, 0, -17},
        {"17", 10, &result, 0, 17},
        {"0X7FFFFFFFFFFFFFFF", 16, &result, 0, LONG_MAX},
        {"0X8000000000000000", 16, &result, -1, -1},
        {"-9223372036854775808", 10, &result, 0, LONG_MIN},
        {"-9223372036854775809", 10, &result, -1, -1},
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        if (show_debug()) {
            fprintf(stderr,
                    "DEBUG: %s:%d: PRE: test[%d]: str: '%s', "
                    "base: %d, *num: %p, "
                    "expected_ret: %d, expected_result: %ld\n",
                    __func__,
                    __LINE__,
                    i,
                    t->str ? t->str : "",
                    t->base,
                    t->num,
                    t->expected_return,
                    t->expected_result);
        }

        int ret = libc_strtol(t->str,
                t->base,
                t->num);

        bool expect_failure = t->expected_return == -1;

        if (show_debug()) {
            fprintf(stderr,
                    "DEBUG: %s:%d: POST: test[%d]: str: '%s', "
                    "base: %d, *num: %p, "
                    "expected_ret: %d, expected_result: %ld, "
                    "expect_failure: %s, "
                    "ret: %d\n",
                    __func__,
                    __LINE__,
                    i,
                    t->str ? t->str : "",
                    t->base,
                    t->num,
                    t->expected_return,
                    t->expected_result,
                    expect_failure ? "yes" : "no",
                    ret);
        }

        if (expect_failure) {
            ck_assert_int_eq(ret, -1);
            continue;
        }

        ck_assert_int_eq(ret, 0);
        ck_assert(*t->num == t->expected_result);
    }
}
END_TEST

START_TEST(test_asm_utils_alloc_args_buffer)
{
    typedef struct test_data {
        int argc;
        const char *argv[TEST_ARGV_ELEMS];
        /* Total length of all bytes in all argv elements */
        size_t args_len;

        /* Length of returned string including space separators
         * newline and nul terminator.
         */
        size_t total_len;
    } TestData;

    const char *empty = "";
    const char *single_byte = "x";
    const char *foo = "foo";
    const char *hello_world = "hello_world";

    /* These symbolic names are simply used to make the TestData array
     * more understandable.
     */
#define NL_BYTE 1
#define SPC_BYTE 1

    TestData tests[] = {
        { 0, {NULL, NULL, NULL, NULL}, 0, 0 },
        { 1, {empty, NULL, NULL, NULL}, 0, 0 },
        { 2, {empty, empty, NULL, NULL}, 0, 0 },
        { 3, {empty, empty, empty, NULL}, 0, 0 },
        { 4, {empty, empty, empty, empty}, 0, 0 },

        { 1, {single_byte, NULL, NULL, NULL}, 1, (1+NL_BYTE) },
        { 2, {single_byte, single_byte, NULL, NULL}, (2*1), ((2*1)+SPC_BYTE+NL_BYTE) },
        { 3, {single_byte, single_byte, single_byte, NULL}, (3*1), ((3*1)+(2*SPC_BYTE)+NL_BYTE) },
        { 4, {single_byte, single_byte, single_byte, single_byte}, (4*1), ((4*1)+(3*SPC_BYTE)+NL_BYTE) },

        { 1, {foo, NULL, NULL, NULL}, 3, (3+NL_BYTE) },
        { 2, {foo, foo, NULL, NULL}, (2*3), ((2*3)+SPC_BYTE+NL_BYTE) },
        { 3, {foo, foo, foo, NULL}, (3*3), ((3*3)+(2*SPC_BYTE)+NL_BYTE) },
        { 4, {foo, foo, foo, foo}, (4*3), ((4*3)+(3*SPC_BYTE)+NL_BYTE) },

        { 3, {foo, hello_world, single_byte, NULL}, (3+11+1), ((3+11+1)+(2*SPC_BYTE)+NL_BYTE) },
        { 4, {foo, hello_world, single_byte, hello_world}, (3+11+1+11), ((3+11+1+11)+(3*SPC_BYTE)+NL_BYTE) },
        { 4, {hello_world, hello_world, hello_world, hello_world}, (4*11), ((4*11)+(3*SPC_BYTE)+NL_BYTE) },
    };

#undef NL_BYTE
#undef SPC_BYTE

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        const TestData *t = &tests[i];

        char *str = NULL;

        size_t bytes = t->args_len;

        bool expect_failure = !t->args_len;

        if (show_debug()) {
            fprintf(stderr,
                    "FIXME: PRE  : test[%d]: "
                    "argc: %d, argv: (0: '%s', 1: '%s', 2: '%s', 3: '%s'), "
                    "args_len: %lu, total_len: %lu, bytes: %lu, "
                    "expect_failure: %s\n",
                    i,
                    t->argc,
                    t->argv[0] ? t->argv[0] : "",
                    t->argv[1] ? t->argv[1] : "",
                    t->argv[2] ? t->argv[2] : "",
                    t->argv[3] ? t->argv[3] : "",
                    t->args_len,
                    t->total_len,
                    bytes,
                    expect_failure ? "yes" : "no");
        }

        str = alloc_args_buffer(t->argc, (const char **)t->argv, &bytes);

        if (show_debug()) {
            fprintf(stderr,
                    "FIXME: POST : test[%d]: "
                    "argc: %d, argv: (0: '%s', 1: '%s', 2: '%s', 3: '%s'), "
                    "args_len: %lu, total_len: %lu, bytes: %lu, "
                    "expect_failure: %s, returned value: '%s'\n",
                    i,
                    t->argc,
                    t->argv[0] ? t->argv[0] : "",
                    t->argv[1] ? t->argv[1] : "",
                    t->argv[2] ? t->argv[2] : "",
                    t->argv[3] ? t->argv[3] : "",
                    t->args_len,
                    t->total_len,
                    bytes,
                    expect_failure ? "yes" : "no",
                    str ? str : "");
        }

        if (expect_failure) {
            ck_assert_ptr_null(str);
            continue;
        }

        ck_assert_int_eq(bytes, t->total_len);

        /* paranoia check */
        size_t len = strlen(str);
        ck_assert_int_eq(bytes, len);

        free(str);
    }
}
END_TEST

START_TEST(test_asm_utils_read_block)
{
    test_read_and_write("test read_block with safe_write",
            read_block,
            safe_write);
}
END_TEST

START_TEST(internal_test_read_and_write)
{
    test_read_and_write("test write_block with safe_read",
            safe_read,
            safe_write);
}
END_TEST

START_TEST(test_asm_utils_write_block)
{
    test_read_and_write("test write_block with safe_read",
            safe_read,
            write_block);
}
END_TEST

/*------------------------------------------------------------------*/
/* Utilities */

/* Write the specified number of bytes from the specified block of
 * data to stdout.
 *
 * Simple wrapper around write(2).
 *
 * @fd: file descriptor to write to.
 * @buffer: Buffer to read from.
 * @count: Number of bytes to read from @buffer and write to @fd.
 *
 * aka/keywords: write_block, write_safe, write_buffer.
 */
ssize_t
safe_write(int fd, const void *buffer, size_t count)
{
    ssize_t result;
    size_t bytes_written = 0;

    const char *p = (const char *)buffer;

    size_t remaining = count;

    if (fd < 0) {
        return -1;
    }

    if (! buffer) {
        return -1;
    }

    if (! count) {
        return 0;
    }

    while (remaining) {
again:
        result = write(fd, p, remaining);

        if (! result) {
            /* EOF */
            break;
        }

        if (result < 0) {
            int saved = errno;

            if (saved == EINTR || saved == EAGAIN) {
                goto again;
            }

            perror("safe_write::write");
            return -1;
        }

        p += result;
        bytes_written += result;
        remaining -= result;
    }

    return bytes_written;
}

/* Read the specified number of bytes from the specified file
 * descriptor into the specified buffer.
 *
 * Simple wrapper around read(2).
 *
 * @fd: file descriptor to read from.
 * @buffer: Buffer to write into.
 * @count: Number of bytes to read from @fd and write to @buffer.
 *
 * aka/keywords: read_block, read_safe, read_buffer.
 */
ssize_t
safe_read(int fd, void *buffer, size_t count)
{
    ssize_t result;
    size_t bytes_read = 0;

    char *p = (char *)buffer;

    size_t remaining = count;

    if (fd < 0) {
        return -1;
    }

    if (! buffer) {
        return -1;
    }

    if (! count) {
        return 0;
    }

    while (remaining) {
again:
        result = read(fd, p, remaining);

        if (! result) {
            /* EOF */
            break;
        }

        if (result < 0) {
            int saved = errno;

            if (saved == EINTR || saved == EAGAIN) {
                goto again;
            }

            perror("safe_read::read");
            return -1;
        }

        p += result;
        bytes_read += result;
        remaining -= result;
    }

    return bytes_read;
}


/*------------------------------------------------------------------*/

void
test_read_and_write(const char *description, Reader *reader, Writer *writer)
{
    assert (description);
    assert (reader);
    assert (writer);

#define PIPEBUF2_BUFFER_SIZE ((PIPE_BUF*2)+1)

#define BUFFER_SIZE (PIPEBUF2_BUFFER_SIZE)

    typedef struct test_data {
        int fd;
        char *buffer;
        size_t count;
        ssize_t expected_result;
        char *expected_data;
    } TestData;

    int empty_pipe[2] = { -1 };
    int one_byte_pipe[2] = { -1 };
    int three_byte_pipe[2] = { -1 };
    int hundred_byte_pipe[2] = { -1 };
    int pipebuf_bytes_pipe [2] = { -1 };

    int pipebuf2_bytes_pipe [2] = { -1 };

    char buffer[BUFFER_SIZE];

    char pipebuf_buffer[PIPE_BUF+1];

    char pipebuf2_buffer[PIPEBUF2_BUFFER_SIZE];

    char hundred_bytes[100];

    size_t buffer_size = sizeof(buffer_size);

    ck_assert(! pipe2(empty_pipe, O_CLOEXEC));
    ck_assert(! pipe2(one_byte_pipe, O_CLOEXEC));
    ck_assert(! pipe2(three_byte_pipe, O_CLOEXEC));
    ck_assert(! pipe2(hundred_byte_pipe, O_CLOEXEC));
    ck_assert(! pipe2(pipebuf_bytes_pipe, O_CLOEXEC));

    /* This pipe will contain >PIPE_BUF bytes, forcing multiple reads
     * to obtain all the data.
     */
    ck_assert(! pipe2(pipebuf2_bytes_pipe, O_CLOEXEC | O_DIRECT));

    close(empty_pipe[1]);

    ck_assert_int_eq(1, writer(one_byte_pipe[1], "x", 1));
    ck_assert_int_eq(3, writer(three_byte_pipe[1], "abc", 3));

    /* Setup the 100 byte pipe */
    char *p = (char *)&hundred_bytes;

    for (int i = 0; i < 10; i++) {
        strcpy(p, "1234567890");
        p += 10;
    }

    memset(pipebuf_buffer, 'x', PIPE_BUF);
    pipebuf_buffer[PIPE_BUF] = '\0';

    memset(pipebuf2_buffer, 'y', PIPEBUF2_BUFFER_SIZE-1);
    pipebuf2_buffer[PIPEBUF2_BUFFER_SIZE-1] = '\0';

    ck_assert_int_eq(100, writer(hundred_byte_pipe[1], hundred_bytes, sizeof(hundred_bytes)));

    ck_assert_int_eq(PIPE_BUF, writer(pipebuf_bytes_pipe[1], pipebuf_buffer, sizeof(pipebuf_buffer)-1));

    /* This pipe contains >PIPE_BUF bytes, requiring multiple calls to
     * read(2) to read all the data.
     */
    ck_assert_int_eq(PIPEBUF2_BUFFER_SIZE-1,
            writer(pipebuf2_bytes_pipe[1],
                pipebuf2_buffer,
                sizeof(pipebuf2_buffer)-1));

    TestData tests[] = {
        { -1, NULL, 0, -1, NULL },
        { -1, buffer, 0, -1, NULL },
        { -1, buffer, buffer_size, -1, NULL },
        { -1, NULL, buffer_size, -1, NULL },

        { empty_pipe[0], buffer, 0, 0, NULL },
        { empty_pipe[0], buffer, 1, 0, NULL },

        { one_byte_pipe[0], (char *)&buffer, 1, 1, "x"},
        { three_byte_pipe[0], buffer, 3, 3, "abc"},
        { hundred_byte_pipe[0], buffer, 100, 100, hundred_bytes},

        { pipebuf_bytes_pipe[0], buffer, PIPE_BUF, PIPE_BUF, pipebuf_buffer},

        { pipebuf2_bytes_pipe[0], buffer, PIPEBUF2_BUFFER_SIZE-1, PIPEBUF2_BUFFER_SIZE-1, pipebuf2_buffer},
    };

    for (int i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        memset(buffer, '\0', sizeof (buffer));

        const TestData *t = &tests[i];

        ssize_t result;

        result = reader(t->fd, t->buffer, t->count);

        if (show_debug()) {
#define MAX_BYTES_TO_SHOW 32

            fprintf(stderr,
                    "DEBUG: %s (reader: %p, writer: %p): test[%d]: fd: %d, "
                    "buffer: %p ('%.*s%s', only displaying first %d bytes), "
                    "count: %lu, "
                    "expected_result: %ld, "
                    "expected_data: '%.*s%s' (only displaying first %d bytes), "
                    "result: %ld\n",
                    description,
                    reader,
                    writer,

                    i,
                    t->fd,

                    t->buffer,

                    result > 0
                    ? result <= MAX_BYTES_TO_SHOW
                    ? (int)result
                    : MAX_BYTES_TO_SHOW
                    : 0,
                    t->buffer,

                    result > MAX_BYTES_TO_SHOW ? "…" : "",
                    MAX_BYTES_TO_SHOW,

                    t->count,

                    t->expected_result,

                    (int)t->expected_result <= MAX_BYTES_TO_SHOW
                        ? (int)t->expected_result
                        : MAX_BYTES_TO_SHOW,
                    t->expected_data ? t->expected_data : "",

                    result > MAX_BYTES_TO_SHOW ? "…" : "",
                    MAX_BYTES_TO_SHOW,

                    result);
#undef MAX_BYTES_TO_SHOW

        }

        ck_assert_int_eq(result, t->expected_result);

        if (t->expected_result <= 0 || !t->buffer || !t->count) {
            continue;
        }

        /* ck_assert_str_eq() cannot handle long strings,
         * so handle it ourselves.
         *
         * Note: we need to take care with this check to avoid reading
         * invalid data.
         */
        size_t bytes_to_copy = t->expected_result > result ?
            t->expected_result : result;

        int str_result = memcmp(t->expected_data,
                buffer,
                bytes_to_copy);

        ck_assert_int_eq(str_result, 0);
    }

    for (int i = 0; i < 2; i++) {
        (void)close(empty_pipe[i]);
        (void)close(one_byte_pipe[i]);
        (void)close(three_byte_pipe[i]);
        (void)close(hundred_byte_pipe[i]);
        (void)close(pipebuf_bytes_pipe[i]);
        (void)close(pipebuf2_bytes_pipe[i]);
    }

#undef BUFFER_SIZE
#undef PIPEBUF2_BUFFER_SIZE
}

/*------------------------------------------------------------------*/

Suite *
asm_utils_suite(void)
{
    Suite *s;
    TCase *tc_core;

    s = suite_create("abox asm utils");
    assert(s);

    tc_core = tcase_create("core");

    /* Add each test */

    tcase_add_test(tc_core, internal_test_read_and_write);

    tcase_add_test(tc_core, test_asm_utils_alloc_args_buffer);
    tcase_add_test(tc_core, test_asm_utils_argv_bytes);
    tcase_add_test(tc_core, test_asm_utils_asm_basename);
    tcase_add_test(tc_core, test_asm_utils_asm_getopt);
    tcase_add_test(tc_core, test_asm_utils_asm_strchr);
    tcase_add_test(tc_core, test_asm_utils_asm_strlen);
    tcase_add_test(tc_core, test_asm_utils_errno);
    tcase_add_test(tc_core, test_asm_utils_libc_strtol);
    tcase_add_test(tc_core, test_asm_utils_read_block);
    tcase_add_test(tc_core, test_asm_utils_write_block);

    /*------------------------------*/

    suite_add_tcase(s, tc_core);

    /*------------------------------*/

    suite_add_tcase(s, tc_core);

    return s;
}

/*------------------------------------------------------------------*/

int
main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    Suite *s;
    SRunner *sr;
    int number_failed;

    s = asm_utils_suite();
    sr = srunner_create(s);

    srunner_run_all(sr, CK_NORMAL);
    number_failed = srunner_ntests_failed(sr);
    srunner_free(sr);

    return (! number_failed) ? EXIT_SUCCESS : EXIT_FAILURE;
}
