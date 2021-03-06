# Roadmap

This is a list of all the research and work I'd like to do within the context
of Caramel.

Past milestones marked with :heavy_check_mark:, current milestone is marked
with :hammer:, future milestones have a name but no date. The future work
section contains less defined ideas.

#### Milestones

* [2020 Q4 - Milestone 1: OCaml on the BEAM](#2020-q4---milestone-1-ocaml-on-the-beam-heavy_check_mark) :heavy_check_mark:
* [2020 Q4 - Milestone 2: Sound Compilation](#2020-q1---milestone-2-sound-compilation-hammer) :hammer:
* [Milestone 3: Typechecker for Erlang](#milestone-3-typechecker-for-erlang)
* [Future Work](#future-work) :crystal_ball:

## 2020 Q4 - Milestone 1: [OCaml on the BEAM](https://github.com/AbstractMachinesLab/caramel/milestone/1) :heavy_check_mark:

The initial goal, to type-check Erlang, led me to the thesis that a subset of a
well-typed language like OCaml could be used to discover a well-typed subset of
Erlang, and that subset could then be successfully type-checked.

This yielded an OCaml to Erlang compiler as a byproduct, that is the focus of
the current milestone.

Caramel doesn't at the moment intend to support all of the existing OCaml
software, and not even all of the OCaml language. Only some of it, as it would
have to be a good citizen of the BEAM, allowing for interop with existing BEAM
languages. And it would have to be a subset of OCaml expressive enough to solve
meaningful, real-life problems, in a type-safe way.

This is why **milestone 1 is focused on getting the compilation from
OCaml to Erlang to a good place**, where we can write type-safe application
cores in OCaml, and surround these with good old Erlang seamlessly.

To achieve this we will need to work primarily on:

* the translation from the OCaml Typedtree to the Erlang AST (see [issue
  #6](https://github.com/AbstractMachinesLab/caramel/issues/6)),
* the checking of certain invariants of both ASTs (see [issue
  #6](https://github.com/AbstractMachinesLab/caramel/issues/6)),
* the printing of the Erlang AST (see [issue
  #7](https://github.com/AbstractMachinesLab/caramel/issues/7)), and on
* the runtime support required to execute the generated source code (see [issue
  #8](https://github.com/AbstractMachinesLab/caramel/issues/8)).

The __next milestone__, will likely focus on parsing the generated Erlang
source code to verify that it is still type-safe. This would help us really
define the subset of Erlang that is well-typed.

**Outcomes**:
- `caramelc compile --target=erlang`

## 2020 Q4 - Milestone 2: [Verified Compilation](https://github.com/AbstractMachinesLab/caramel/milestone/2) :hammer:

While Milestone 1 gave us the `caramelc compile` command to compile OCaml
programs to Erlang, its focus was to output idiomatic Erlang sources.

The immediate work, Milestone 2, is about **verifying that this compilation is
sound**.

In other words, we want to verify that the compiled Erlang sources are every
bit as type-safe as the OCaml sources they came from.

The general approach we will take will be to prove that compilation of programs
is structure preserving, _a proper isomorphism_, by doing the reverse work:
grab a generated Erlang program, turn it into an OCaml one, check if its the
exact same as the original OCaml program.

This will guarantee that every Erlang program generated by Caramel is as sound
as the original OCaml program.

To achieve this we will need to work on:

* the translation from the Erlang AST to the OCaml Parsetree
* the verification that two OCaml Typedtrees are indeed equivalent
* a mechanism to verify this isomorphism on a very large space of programs

The __next milestone__, will build on this foundation knowing that the
compilation artifacts of Caramel are as sound as any other OCaml compilation
artifact.

**Outcomes**:
- `caramelc verify`

## Milestone 3: [Typechecker for Erlang]()

Milestone 2 left us a proof that the compilation is sound, and we can rely on
it. As a by-product, it also includes a sound translation pipeline from Erlang
to OCaml.

This milestone will package this pipeline into a usable type-checker for a
restricted subset of Standard Erlang: `caramelc check`.

Because the inputs may be hand-written Erlang sources, we can no longer make
the same assumptions we made before when reading generated Erlang sources known
to be syntactically and semantically valid.

To make this command actually usable we will need to work on:

* the Standard Erlang parser, in particular parsing errors
* a number of static analyses to guarantee some AST invariants
* type-checking errors, in particular translating them into Erlang syntax

The __next milestone__ will count with a sound compilation pipeline from OCaml
to Erlang, and from Erlang to OCaml. A convenient by-product of this work is
the rather low-hanging fruit of compiling Erlang programs to native binaries by
reusing the rest of the mainline OCaml compiler.

**Outcomes**:
- `caramelc check`

## Future Work

I'd like to build a foundation in the OCaml ecosystem to engage and benefit
from the BEAM, and I think this can be done by providing good libraries to work
with Erlang sources in OCaml programs.

This roughly means support for both Standard Erlang and Core Erlang:

* being able to read and parse sources with good error reports,

* providing AST definitions and helpers to construct, manipulate, and check
  different properties in them

* and printers to generate sources in a readable fashion

The work has already been started, as Caramel currently supports parsing a
subset of Erlang, and can produce Core Erlang sources for a very very small
subset of the lower level OCaml Lambda language.

On the other hand, having both an Erlang frontend _and_ backend to the OCaml
compiler means the BEAM can leverage from the broader OCaml ecosystem as well:

* Reason code (and other alternative OCaml syntaxes) could be transparently
  compiled to Erlang

* Erlang code could be compiled to Javascript with the Js_of_ocaml backend

* Erlang code that uses the OCaml standard library could be compiled to small
  native binaries running on the OCaml Runtime

* Erlang code could be compiled to Core Erlang ensuring type-safety

* Core Erlang code from any BEAM language could be type-checked as OCaml

* Type-driven tools for refactoring and verification could be used on Erlang
  sources

* Lower level languages like the OCaml Bytecode could run on an interpreter on
  the BEAM, allowing the bulk of OCaml programs to run on the BEAM

And many other ideas that have come up on discussions about this project so far.

The art is long but the life is short, so we'll do one thing at a time and
we'll see how far along we get.

/ Leandro
