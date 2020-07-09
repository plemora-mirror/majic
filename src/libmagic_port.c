//
// libmagic_port: The Sorcerer’s Apprentice
//
// To use this program, compile it with dynamically linked libmagic, as mirrored
// at https://github.com/file/file. You may install it with apt-get,
// yum or brew. Refer to the Makefile for further reference.
//
// This program is designed to run interactively as a backend daemon to the
// GenMagic library.
//
// Communication is done over STDIN/STDOUT as binary packets of 2 bytes length
// plus X bytes payload, where the payload is an erlang term encoded with
// :erlang.term_to_binary/1 and decoded with :erlang.binary_to_term/1.
//
// Once the program is ready, it sends the `:ready` atom.
//
// It is then up to the Erlang side to load databases, by sending messages:
// - `{:add_database, :default | path}`
//
// If the requested database have been loaded, an `{:ok, :loaded}` message will
// follow. Otherwise, the process will exit (exit code 1).
//
// Commands are sent to the program STDIN as an erlang term of `{Operation,
// Argument}`, and response of `{:ok | :error, Response}`.
//
// The program may exit with the following exit codes:
//  - 1 if libmagic handles could not be opened,
//  - 2 if something went wrong with ei_*,
//  - 3 if you sent invalid term format,
//  - 255 if the loop exited unexpectedly.
//
// Invalid packets will cause the program to exit (exit code 3). This will
// happen if your Erlang Term format doesn't match the version the program has
// been compiled with.
//
// Commands:
// {:reload, _} :: :ready
// {:add_database, :default | String.t()} :: {:ok, _} | {:error, _}
// {:file, path :: String.t()} :: {:ok, {type, encoding, name}} | {:error,
// :badarg} | {:error, {errno :: integer(), String.t()}}
// {:bytes, binary()} :: same as :file
// {:stop, reason :: atom()} :: exit 0

#include <arpa/inet.h>
#include <ei.h>
#ifdef EI_INCOMPLETE
#include <erl_interface.h>
#endif
#include <errno.h>
#include <getopt.h>
#include <libgen.h>
#include <magic.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define ERROR_OK 0
#define ERROR_MAGIC 1
#define ERROR_EI 2
#define ERROR_BAD_TERM 3

// We use a bigger than possible valid command length (around 4111 bytes) to
// allow more precise errors when using too long paths.
#define COMMAND_LEN 8000
#define COMMAND_BUFFER_SIZE COMMAND_LEN + 1

#define MAGIC_FLAGS_COMMON (MAGIC_CHECK | MAGIC_ERROR)
magic_t magic_setup(int flags);

#define EI_ENSURE(result)                                                      \
  do {                                                                         \
    if (result != 0) {                                                         \
      fprintf(stderr, "EI ERROR, line: %d", __LINE__);                         \
      exit(ERROR_EI);                                                          \
    }                                                                          \
  } while (0);

typedef char byte;

void setup_environment();
void magic_close_all();
void magic_open_all();
int magic_load_all(char *path);
void process_command(uint16_t len, byte *buf);
void process_command_file(byte *buf, int index, ei_x_buff *result);
void process_command_bytes(byte *buf, int index, ei_x_buff *result);
void process_command_load(byte *buf, int index, ei_x_buff *result);
void process_file(char *path, ei_x_buff *result);
void process_bytes(char *bytes, int size, ei_x_buff *result);
void process_load(ei_x_buff *result, char *path);
void send_and_free(ei_x_buff *result);
size_t read_cmd(byte *buf);
size_t write_cmd(byte *buf, size_t len);
void error(ei_x_buff *result, const char *error);
void handle_magic_error(magic_t handle, int errn, ei_x_buff *result);
void fdseek(uint16_t count);

static magic_t magic_mime_type;     // MAGIC_MIME_TYPE
static magic_t magic_mime_encoding; // MAGIC_MIME_ENCODING
static magic_t magic_type_name;     // MAGIC_NONE

bool magic_loaded = false;

int main(int argc, char **argv) {
#ifdef EI_INCOMPLETE
  erl_init(NULL, -1);
#else
  EI_ENSURE(ei_init());
#endif
  setup_environment();
  magic_open_all();

  byte buf[COMMAND_BUFFER_SIZE];
  uint16_t len;
  while ((len = read_cmd(buf)) > 0) {
    process_command(len, buf);
  }

  return 255;
}

void process_command(uint16_t len, byte *buf) {
  ei_x_buff result;
  char atom[128];
  int index, version, arity;
  index = 0;

  // Initialize result
  EI_ENSURE(ei_x_new_with_version(&result));
  EI_ENSURE(ei_x_encode_tuple_header(&result, 2));

  if (len >= COMMAND_LEN)
    return error(&result, "badarg");

  if (ei_decode_version(buf, &index, &version) != 0)
    exit(ERROR_BAD_TERM);

  if (ei_decode_tuple_header(buf, &index, &arity) != 0)
    return error(&result, "badarg");

  if (arity != 2)
    return error(&result, "badarg");

  if (ei_decode_atom(buf, &index, atom) != 0)
    return error(&result, "badarg");

  // {:file, path}
  if (strlen(atom) == 4 && strcmp(atom, "file") == 0)
    return process_command_file(buf, index, &result);

  // {:bytes, bytes}
  if (strlen(atom) == 5 && strcmp(atom, "bytes") == 0)
    return process_command_bytes(buf, index, &result);

  // {:add_database, path}
  if (strlen(atom) == 12 && strcmp(atom, "add_database") == 0)
    return process_command_load(buf, index, &result);

  // {:reload, _}
  if (strlen(atom) == 6 && strcmp(atom, "reload") == 0)
    return magic_open_all();

  // {:stop, _}
  if (strlen(atom) == 4 && strcmp(atom, "stop") == 0)
    exit(ERROR_OK);

  error(&result, "badarg");
}

void process_command_file(byte *buf, int index, ei_x_buff *result) {
  int termtype, termsize;
  char path[4097];
  long bin_length;

  if (!magic_loaded)
    return error(result, "magic_database_not_loaded");

  ei_get_type(buf, &index, &termtype, &termsize);

  if (termtype != ERL_BINARY_EXT)
    return error(result, "badarg");

  if (termsize > 4096)
    return error(result, "enametoolong");

  EI_ENSURE(ei_decode_binary(buf, &index, path, &bin_length));
  path[termsize] = '\0';
  process_file(path, result);
}

void process_command_bytes(byte *buf, int index, ei_x_buff *result) {
  if (!magic_loaded)
    return error(result, "magic_database_not_loaded");

  int termtype, termsize;
  long bin_length;
  char bytes[51];
  EI_ENSURE(ei_get_type(buf, &index, &termtype, &termsize));

  if (termtype != ERL_BINARY_EXT)
    return error(result, "badarg");

  if (termsize > 50)
    return error(result, "toolong");

  EI_ENSURE(ei_decode_binary(buf, &index, bytes, &bin_length));
  bytes[termsize] = '\0';
  process_bytes(bytes, termsize, result);
}

void process_command_load(byte *buf, int index, ei_x_buff *result) {
  char path[4097];
  int termtype, termsize;
  ei_get_type(buf, &index, &termtype, &termsize);

  if (termtype == ERL_BINARY_EXT) {
    if (termsize > 4096)
      return error(result, "enametoolong");

    long bin_length;
    EI_ENSURE(ei_decode_binary(buf, &index, path, &bin_length));
    path[termsize] = '\0';
    return process_load(result, path);
  }

  if (termtype == ERL_ATOM_EXT) {
    EI_ENSURE(ei_decode_atom(buf, &index, path));
    if (strlen(path) == 7 && strcmp(path, "default") == 0)
      return process_load(result, NULL);
  }

  error(result, "badarg");
}

void process_load(ei_x_buff *result, char *path) {
  if (magic_load_all(path) == 0) {
    EI_ENSURE(ei_x_encode_atom(result, "ok"));
    EI_ENSURE(ei_x_encode_atom(result, "loaded"));
  } else {
    EI_ENSURE(ei_x_encode_atom(result, "error"));
    EI_ENSURE(ei_x_encode_atom(result, "not_loaded"));
  }
  send_and_free(result);
}

void setup_environment() { opterr = 0; }

void magic_close_all() {
  magic_loaded = false;
  if (magic_mime_encoding) {
    magic_close(magic_mime_encoding);
    magic_mime_encoding = NULL;
  }
  if (magic_mime_type) {
    magic_close(magic_mime_type);
    magic_mime_type = NULL;
  }
  if (magic_type_name) {
    magic_close(magic_type_name);
    magic_type_name = NULL;
  }
}

void magic_open_all() {
  magic_close_all();
  magic_mime_encoding = magic_open(MAGIC_FLAGS_COMMON | MAGIC_MIME_ENCODING);
  magic_mime_type = magic_open(MAGIC_FLAGS_COMMON | MAGIC_MIME_TYPE);
  magic_type_name = magic_open(MAGIC_FLAGS_COMMON | MAGIC_NONE);

  if (magic_mime_encoding && magic_mime_type && magic_type_name) {
    ei_x_buff ok_buf;
    EI_ENSURE(ei_x_new_with_version(&ok_buf));
    EI_ENSURE(ei_x_encode_atom(&ok_buf, "ready"));
    return send_and_free(&ok_buf);
  }

  exit(ERROR_MAGIC);
}

int magic_load_all(char *path) {
  int res;

  if ((res = magic_load(magic_mime_encoding, path)) != 0)
    return res;
  if ((res = magic_load(magic_mime_type, path)) != 0)
    return res;
  if ((res = magic_load(magic_type_name, path)) != 0)
    return res;

  magic_loaded = true;
  return 0;
}

void process_bytes(char *path, int size, ei_x_buff *result) {
  const char *mime_type_result = magic_buffer(magic_mime_type, path, size);
  const int mime_type_errno = magic_errno(magic_mime_type);

  if (mime_type_errno > 0)
    return handle_magic_error(magic_mime_type, mime_type_errno, result);

  const char *mime_encoding_result =
      magic_buffer(magic_mime_encoding, path, size);
  int mime_encoding_errno = magic_errno(magic_mime_encoding);

  if (mime_encoding_errno > 0)
    return handle_magic_error(magic_mime_encoding, mime_encoding_errno, result);

  const char *type_name_result = magic_buffer(magic_type_name, path, size);
  int type_name_errno = magic_errno(magic_type_name);

  if (type_name_errno > 0)
    return handle_magic_error(magic_type_name, type_name_errno, result);

  EI_ENSURE(ei_x_encode_atom(result, "ok"));
  EI_ENSURE(ei_x_encode_tuple_header(result, 3));
  EI_ENSURE(
      ei_x_encode_binary(result, mime_type_result, strlen(mime_type_result)));
  EI_ENSURE(ei_x_encode_binary(result, mime_encoding_result,
                               strlen(mime_encoding_result)));
  EI_ENSURE(
      ei_x_encode_binary(result, type_name_result, strlen(type_name_result)));
  send_and_free(result);
}

void handle_magic_error(magic_t handle, int errn, ei_x_buff *result) {
  const char *error = magic_error(handle);
  EI_ENSURE(ei_x_encode_atom(result, "error"));
  EI_ENSURE(ei_x_encode_tuple_header(result, 2));
  long errlon = (long)errn;
  EI_ENSURE(ei_x_encode_long(result, errlon));
  EI_ENSURE(ei_x_encode_binary(result, error, strlen(error)));
  send_and_free(result);
}

void process_file(char *path, ei_x_buff *result) {
  const char *mime_type_result = magic_file(magic_mime_type, path);
  const int mime_type_errno = magic_errno(magic_mime_type);

  if (mime_type_errno > 0)
    return handle_magic_error(magic_mime_type, mime_type_errno, result);

  const char *mime_encoding_result = magic_file(magic_mime_encoding, path);
  int mime_encoding_errno = magic_errno(magic_mime_encoding);

  if (mime_encoding_errno > 0)
    return handle_magic_error(magic_mime_encoding, mime_encoding_errno, result);

  const char *type_name_result = magic_file(magic_type_name, path);
  int type_name_errno = magic_errno(magic_type_name);

  if (type_name_errno > 0)
    return handle_magic_error(magic_type_name, type_name_errno, result);

  EI_ENSURE(ei_x_encode_atom(result, "ok"));
  EI_ENSURE(ei_x_encode_tuple_header(result, 3));
  EI_ENSURE(
      ei_x_encode_binary(result, mime_type_result, strlen(mime_type_result)));
  EI_ENSURE(ei_x_encode_binary(result, mime_encoding_result,
                               strlen(mime_encoding_result)));
  EI_ENSURE(
      ei_x_encode_binary(result, type_name_result, strlen(type_name_result)));
  send_and_free(result);
}

// Adapted from https://erlang.org/doc/tutorial/erl_interface.html
// Changed `read_cmd`, the original one was buggy given some length (due to
// endinaness).
// TODO: Check if `write_cmd` exhibits the same issue.
size_t read_exact(byte *buf, size_t len) {
  int i, got = 0;

  do {
    if ((i = read(0, buf + got, len - got)) <= 0) {
      return (i);
    }
    got += i;
  } while (got < len);

  return (len);
}

size_t write_exact(byte *buf, size_t len) {
  int i, wrote = 0;

  do {
    if ((i = write(1, buf + wrote, len - wrote)) <= 0)
      return (i);
    wrote += i;
  } while (wrote < len);

  return (len);
}

size_t read_cmd(byte *buf) {
  int i;
  if ((i = read(0, buf, sizeof(uint16_t))) <= 0) {
    return (i);
  }
  uint16_t len16 = *(uint16_t *)buf;
  len16 = ntohs(len16);

  // Buffer isn't large enough: just return possible len, without reading.
  // Up to the caller of verifying the size again and return an error.
  // buf left unchanged, stdin emptied of X bytes.
  if (len16 > COMMAND_LEN) {
    fdseek(len16);
    return len16;
  }

  return read_exact(buf, len16);
}

size_t write_cmd(byte *buf, size_t len) {
  byte li;

  li = (len >> 8) & 0xff;
  write_exact(&li, 1);

  li = len & 0xff;
  write_exact(&li, 1);

  return write_exact(buf, len);
}

void send_and_free(ei_x_buff *result) {
  write_cmd(result->buff, result->index);
  EI_ENSURE(ei_x_free(result));
}

void error(ei_x_buff *result, const char *error) {
  EI_ENSURE(ei_x_encode_atom(result, "error"));
  EI_ENSURE(ei_x_encode_atom(result, error));
  send_and_free(result);
}

void fdseek(uint16_t count) {
  int i = 0;
  while (i < count) {
    getchar();
    i += 1;
  }
}
