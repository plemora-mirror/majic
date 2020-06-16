# Majic

**Majic** provides a robust integration of [libmagic](http://man7.org/linux/man-pages/man3/libmagic.3.html) for Elixir.

With this library, you can start an one-off process to run a single check, or run the process as a daemon if you expect to run
many checks.

It is a friendly fork of [gen_magic](https://github.com/evadne/gen_magic) featuring a (arguably) more robust C-code
using erl_interface, built in pooling, unified/clean API, and an optional Plug.

This package is regulary tested on multiple platforms (Debian, macOS, Fedora, Alpine, FreeBSD) to ensure it'll work fine
in any environment.

## Installation

The package can be installed by adding `majic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:majic, "~> 1.0"}
  ]
end
```

You must also have [libmagic](http://man7.org/linux/man-pages/man3/libmagic.3.html) installed locally with headers, alongside common compilation tools (i.e. build-essential). These can be acquired by apt-get, yum, brew, etc.

Compilation of the underlying C program is automatic and handled by [elixir_make](https://github.com/elixir-lang/elixir_make).

## Usage

Depending on the use case, you may utilise a single (one-off) Majic process without reusing it as a daemon, or utilise a connection pool (such as Poolboy) in your application to run multiple persistent Majic processes.

To use Majic directly, you can use `Majic.Once.perform/1`:

```elixir
iex(1)> Majic.perform(".", once: true)
{:ok,
 %Majic.Result{
   content: "directory",
   encoding: "binary",
   mime_type: "inode/directory"
 }}
```

To use the Majic server as a daemon, you can start it first, keep a reference, then feed messages to it as you require:

```elixir
{:ok, pid} = Majic.Server.start_link([])
{:ok, result} = Majic.perform(path, server: pid)
```

See `Majic.Server.start_link/1` and `t:Majic.Server.option/0` for more information on startup parameters.

See `Majic.Result` for details on the result provided.

## Configuration

When using `Majic.Server.start_link/1` to start a persistent server, or `Majic.Helpers.perform_once/2` to run an ad-hoc request, you can override specific options to suit your use case.

| Name | Default | Description |
| - | - | - |
| `:startup_timeout` | 1000 | Number of milliseconds to wait for client startup |
| `:process_timeout` | 30000 | Number of milliseconds to process each request |
| `:recycle_threshold` | 10 | Number of cycles before the C process is replaced |
| `:database_patterns` | `[:default]` | Databases to load |

See `t:Majic.Server.option/0` for details.

__Note__ `:recycle_thresold` is only useful if you are using a libmagic `<5.29`, where it was susceptible to memleaks
([details](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=840754)]). In future versions of `majic` this option could
be ignored.

### Reloading / Altering databases

If you want `majic` to reload its database(s), run `Majic.Server.reload(ref)`.

If you want to add or remove databases to a running server, you would have to run `Majic.Server.reload(ref, databases)`
where databases being the same argument as `database_patterns` on start. `Majic` does not support adding/removing
databases at runtime without a port reload.

### Use Cases

#### Ad-Hoc Requests

For ad-hoc requests, you can use the helper method `Majic.Once.perform_once/2`:

```elixir
iex(1)> Majic.perform(Path.join(File.cwd!(), "Makefile"), once: true)
{:ok,
 %Majic.Result{
   content: "makefile script, ASCII text",
   encoding: "us-ascii",
   mime_type: "text/x-makefile"
}}
```

#### Supervised Requests

The Server should be run under a supervisor which provides resiliency.

Here we run it under a supervisor in an application:

```elixir
children =
  [
    # ...
    {Majic.Server, [name: YourApp.Majic]}
  ]

opts = [strategy: :one_for_one, name: YourApp.Supervisor]
Supervisor.start_link(children, opts)
```

Now we can ask it to inspect a file:

```elixir
iex(2)> Majic.perform(Path.expand("~/.bash_history"), server: YourApp.Majic)
{:ok, %Majic.Result{mime_type: "text/plain", encoding: "us-ascii", content: "ASCII text"}}
```

Note that in this case we have opted to use a named process.

#### Pool

For concurrency *and* resiliency, you may start the `Majic.Pool`. By default, it will start a `Majic.Server`
worker per online scheduler:

You can add a pool in your application supervisor by adding it as a child:

```elixir
children =
  [
    # ...
    {Majic.Pool, [name: YourApp.MajicPool, pool_size: 2]}
  ]

opts = [strategy: :one_for_one, name: YourApp.Supervisor]
Supervisor.start_link(children, opts)
```

And then you can use it with `Majic.perform/2` with `pool: YourApp.MajicPool` option:

```elixir
iex(1)> Majic.perform(Path.expand("~/.bash_history"), pool: YourApp.MajicPool)
{:ok, %Majic.Result{mime_type: "text/plain", encoding: "us-ascii", content: "ASCII text"}}
```

#### Use with Plug.Upload

If you use Plug or Phoenix, you may want to automatically verify the content type of every `Plug.Upload`. The
`Majic.Plug` is there for this.

Enable it by using `plug Majic.Plug, pool: YourApp.MajicPool` in your pipeline or controller. Then, every `Plug.Upload`
in `conn.params` is now verified. The filename is also altered with an extension matching its content-type.

## Notes

### Soak Test

Run an endless cycle to prove that the program is resilient:

```bash
find /usr/share/ -name *png | xargs mix run test/soak.exs
find . -name *ex | xargs mix run test/soak.exs
```

## Acknowledgements

During design and prototype development of this library, the Author has drawn inspiration from the following individuals, and therefore
thanks all contributors for their generosity:

- [Evadne Wu](https://github.com/evadne)
  - Original [gen_magic](https://github.com/evadne/gen_magic) author.
- [James Every](https://github.com/devstopfix)
  - Enhanced Elixir Wrapper (based on GenServer)
  - Initial Hex packaging (v.0.22)
  - Soak Testing
- Matthias and Ced for helping the author with C oddities
- [Hecate](https://github.com/Kleidukos) for laughing at aforementionned oddities
- majic for giving inspiration for the lib name (magic, majic, get it? hahaha..)
