open Compile_common

type target = [ `Erlang | `Core_erlang | `Native ]

type compilation = { sources : string list; dump_ast : bool; target : target }

exception Unsupported_file_type_for_target of (target * string * string)

let target_to_string = function
  | `Erlang -> "erl"
  | `Core_erlang -> "core"
  | `Native -> "native"

let to_bytecode i lambda =
  lambda
  |> Profile.(record ~accumulate:true generate)
       (fun Lambda.{ code = lambda; required_globals; _ } ->
         let simp_lambda = lambda |> Simplif.simplify_lambda in
         let bytecode =
           simp_lambda |> Bytegen.compile_implementation i.module_name
         in
         (bytecode, required_globals))

let to_lambda i (typedtree, coercion) =
  (typedtree, coercion)
  |> Profile.(record transl) (Translmod.transl_implementation i.module_name)

let emit_bytecode i (bytecode, required_globals) =
  let cmofile = i.output_prefix ^ ".cmo" in
  let oc = open_out_bin cmofile in
  Misc.try_finally
    ~always:(fun () -> close_out oc)
    ~exceptionally:(fun () -> Misc.remove_file cmofile)
    (fun () ->
      bytecode
      |> Profile.(record ~accumulate:true generate)
           (Emitcode.to_file oc i.module_name cmofile ~required_globals))

let read_signature info =
  let module_name = info.module_name in
  let cmi_file = module_name ^ ".cmi" in
  try
    let intf_file = Load_path.find_uncap cmi_file in
    let sign = Env.read_signature module_name intf_file in
    Some sign
  with Not_found -> None

let initialize_compiler () =
  Compmisc.init_path ();
  let _ = Compmisc.initial_env () in
  ()

(** Actual compilation chains *)

let ml_to_core_erlang ~source_file ~output_prefix ~opts =
  let backend info (typed, coercion) =
    let lambda = to_lambda info (typed, coercion) in
    let bytecode = to_bytecode info lambda in
    let _ = emit_bytecode info bytecode in
    let module_name = info.module_name in
    let core_ast = Lambda_to_core_erlang.from_lambda ~module_name lambda.code in
    if opts.dump_ast then (
      Sexplib.Sexp.pp_hum_indent 2 Format.std_formatter
        (Core_erlang.Ast.sexp_of_t core_ast);
      Format.fprintf Format.std_formatter "\n\n%!" );
    Core_erlang.Printer.to_sources [ core_ast ]
  in
  Compile_common.with_info ~native:false ~tool_name:"caramelc" ~source_file
    ~output_prefix ~dump_ext:"cmo"
  @@ fun info -> Compile_common.implementation info ~backend

let ml_to_erlang ~source_file ~output_prefix ~opts:_ =
  let backend info (typed, coercion) =
    let lambda = to_lambda info (typed, coercion) in
    let bytecode = to_bytecode info lambda in
    let _ = emit_bytecode info bytecode in
    let signature = read_signature info in
    let module_name = info.module_name in
    let erl_ast =
      Ocaml_to_erlang.Compile.from_typedtree ~module_name typed signature
    in
    Erlang.Printer.to_sources erl_ast
  in
  Compile_common.with_info ~native:false ~tool_name:"caramelc" ~source_file
    ~output_prefix ~dump_ext:"cmo"
  @@ fun info -> Compile_common.implementation info ~backend

let mli_to_erlang ~source_file ~output_prefix ~opts:_ =
  Compile_common.with_info ~native:false ~tool_name:"caramelc" ~source_file
    ~output_prefix ~dump_ext:"cmi"
  @@ Compile_common.interface

(* Entrypoint to typecheck Erlang *)

let erl_to_cmi ~source_file ~output_prefix ~opts =
  let backend info typed =
    let lambda = to_lambda info typed in
    let bytecode = to_bytecode info lambda in
    emit_bytecode info bytecode
  in
  Compile_common.with_info ~native:false ~tool_name:"caramelc" ~source_file
    ~output_prefix ~dump_ext:"cmo"
  @@ fun i ->
  let erlang_ast =
    match Erlang.Parse.from_file i.source_file with
    | exception exc ->
        Format.fprintf Format.std_formatter "Unhandled parsing error: %s"
          (Printexc.to_string exc);
        exit 1
    | Ok ast -> ast
    | Error `Module_item_list_was_empty ->
        Format.fprintf Format.std_formatter
          "This module was empty: %s, did you remove the file in the meantime?"
          i.source_file;
        exit 1
    | Error `Single_module_item_was_not_a_module_name ->
        Format.fprintf Format.std_formatter
          "This module had a single attribute that was not a -module(name). \
           attribute: %s"
          i.source_file;
        exit 1
    | Error (`Lexer_error (err, _loc)) ->
        Erlang.Lexer.pp_err Format.std_formatter err;
        exit 1
    | Error (`Parser_error msg) ->
        Format.fprintf Format.std_formatter "Parser_error: %s" msg;
        exit 1
  in
  if opts.dump_ast then (
    Sexplib.Sexp.pp_hum_indent 2 Format.std_formatter
      (Erlang.Ast.sexp_of_t erlang_ast);
    Format.fprintf Format.std_formatter "\n\n%!" );
  let parsetree = Erlang_to_ocaml.to_parsetree erlang_ast in
  if opts.dump_ast then (
    Pprintast.structure Format.std_formatter parsetree;
    Format.fprintf Format.std_formatter "\n\n%!" );
  let typedtree =
    parsetree
    |> Profile.(record typing)
         (Typemod.type_implementation i.source_file i.output_prefix
            i.module_name i.env)
  in
  backend i typedtree

let compile_one source ~target ~opts =
  let fn, source_file =
    match source with
    | `Ml file -> (
        match target with
        | `Erlang -> (ml_to_erlang, file)
        | `Core_erlang -> (ml_to_core_erlang, file)
        | _ -> raise (Unsupported_file_type_for_target (target, file, ".ml")) )
    | `Mli file -> (mli_to_erlang, file)
    | `Erl file -> (erl_to_cmi, file)
    | `Unsupported_file_type_for_target (t, file, ext) ->
        raise (Unsupported_file_type_for_target (t, file, ext))
  in
  fn ~source_file ~output_prefix:(Filename.chop_extension source_file) ~opts

let tag_source target filename =
  match target with
  | `Erlang | `Core_erlang -> (
      match Filename.extension filename with
      | ".ml" -> `Ml filename
      | ".mli" -> `Mli filename
      | ext -> `Unsupported_file_type_for_target (target, filename, ext) )
  | `Native -> (
      match Filename.extension filename with
      | ".ml" -> `Ml filename
      | ".mli" -> `Mli filename
      | ".erl" -> `Erl filename
      | ext -> `Unsupported_file_type_for_target (target, filename, ext) )

let compile ({ sources; target; _ } as opts) =
  match
    initialize_compiler ();

    let tagged_sources, errs =
      sources
      |> List.map (tag_source target)
      |> List.partition (function
           | `Unsupported_file_type_for_target (_, _, _) -> false
           | _ -> true)
    in

    errs
    |> List.iter (function
         | `Unsupported_file_type_for_target (tgt, file, ext) ->
             Format.fprintf Format.std_formatter
               "Attempted to compile %s, but %s files are not supported with \
                the target flag: --target=%s%!"
               file ext (target_to_string tgt);
             exit 1
         | _ -> ());

    let ml_sources =
      tagged_sources
      |> List.filter_map (function `Ml f | `Mli f -> Some f | _ -> None)
      |> Dependency_sorter.sorted_files
      |> List.map (tag_source target)
    in

    let erlang_sources =
      tagged_sources
      |> List.filter_map (function `Erl f -> Some (`Erl f) | _ -> None)
    in

    List.iter (compile_one ~target ~opts) (ml_sources @ erlang_sources);

    Warnings.check_fatal ()
  with
  | exception Env.Error err -> Env.report_error Format.std_formatter err
  | exception exc -> (
      match Location.error_of_exn exc with
      | Some (`Ok error) -> Location.print_report Format.std_formatter error
      | _ ->
          Format.fprintf Format.std_formatter "ERROR: %s"
            (Printexc.to_string exc) )
  | _ -> ()
