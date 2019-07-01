open Core_kernel
open Bap.Std
open Bap_primus.Std
open Bap_taint.Std

include Self ()

type value = Primus.value
type machine = Primus.Machine.id

module Machine_id = Monads.Std.Monad.State.Multi.Id
module Machines = Machine_id.Map
module Values = Primus.Value.Set
module Vids = Primus.Value.Id.Set
module Vid = Primus.Value.Id

type func = string * addr

type proof = Used | Unused

type state = {
    functions  : func Primus.Value.Id.Map.t;
    proved     : proof Addr.Map.t;
  }

let state = Primus.Machine.State.declare
    ~name:"unused-results"
    ~uuid:"af66d451-fb62-44c3-9c2a-8969e111ad91"
    (fun _ -> {
         functions  = Map.empty (module Primus.Value.Id);
         proved     = Map.empty (module Addr);
    })

let _, unused =
  Primus.Observation.provide ~inspect:sexp_of_string "unused"

let notify name addr = function
  | Used -> ()
  | Unused ->
     printf "unused result of %s at %a\n%!" name Addr.ppo addr

module Results(Machine : Primus.Machine.S) = struct
  module Value = Primus.Value.Make(Machine)
  module Object = Taint.Object.Make(Machine)
  module Tracker = Taints_tracker.Tracker(Machine)
  open Machine.Syntax

  let create taint name addr =
    Tracker.on_new_taint taint >>= fun  () ->
    let addr = Value.to_word addr in
    let vid = Value.id taint in
    Value.Symbol.of_value name >>= fun name ->
    Machine.current () >>= fun cur ->
    Machine.Global.update state ~f:(fun s ->
        { s with
          functions = Map.set s.functions vid (name,addr)}) >>= fun () ->
    Value.b1

  let mark taint usage =
    let vid = Value.id taint in
    Machine.Global.get state >>= fun s ->
    match Map.find s.functions vid with
    | None -> Value.b0
    | Some (name,addr) ->
       notify name addr usage;
       let s = {s with proved = Map.set s.proved addr usage} in
       Machine.Global.put state s >>= fun () ->
       Value.b1

  let mark_used taint = mark taint Used
  let mark_unused taint = mark taint Unused

  let is_known_usage taint =
    let vid = Value.id taint in
    Machine.Global.get state >>= fun s ->
    match Map.find s.functions vid with
    | None -> Value.b0
    | Some (name,addr) ->
       Value.of_bool (Map.mem s.proved addr)

end

module IsKnownUsage(Machine : Primus.Machine.S) = struct
  module Results = Results(Machine)

  [@@@warning "-P"]
  let run [v] = Results.is_known_usage v
end

module MaybeUnused(Machine : Primus.Machine.S) = struct
  module Results = Results(Machine)

  [@@@warning "-P"]
  let run [taint; name; addr] =
    Results.create taint name addr
end

module MarkUnused(Machine : Primus.Machine.S) = struct
  module Results = Results(Machine)

  [@@@warning "-P"]
  let run [v] = Results.mark_unused v
end

module MarkUsed(Machine : Primus.Machine.S) = struct
  module Results = Results(Machine)

  [@@@warning "-P"]
  let run [v] = Results.mark_used v
end


module HandleUnresolved(Machine : Primus.Machine.S) = struct
  module Value = Primus.Value.Make(Machine)
  module Interpreter = Primus.Interpreter.Make(Machine)
  open Machine.Syntax

  let set_zero v =
    match Var.typ v with
    | Mem _ -> !! ()
    | Imm width ->
       Value.of_int ~width 0 >>= fun x ->
       Interpreter.set v x

  let on_unresolved _ =
    Machine.arch >>= function
    | `x86_64 -> set_zero X86_cpu.AMD64.rax
    | `x86 -> set_zero X86_cpu.IA32.rax
    |  _ -> !! ()

  let init () =  Primus.Linker.unresolved >>> on_unresolved
end

module Return_arg(Machine : Primus.Machine.S) = struct
  module Value = Primus.Value.Make(Machine)
  module Env = Primus.Env.Make(Machine)
  open Machine.Syntax

  let find sub =
    Machine.get () >>= fun proj ->
    Value.Symbol.of_value sub >>= fun name ->
    let subs = Term.to_sequence sub_t (Project.program proj) in
    match Seq.find subs ~f:(fun s -> String.(Sub.name s = name)) with
    | None -> Machine.return None
    | Some sub ->
       Seq.find (Term.to_sequence arg_t sub)
         ~f:(fun a -> Arg.intent a = Some Out) |> function
    | None -> Machine.return None
    | Some out -> Machine.return (Some out)

  [@@@warning "-P"]
  let run [sub] =
    find sub >>= function
    | None -> Value.b0
    | Some a -> Value.Symbol.to_value (Var.name (Arg.lhs a))
end

module Interface(Machine : Primus.Machine.S) = struct
  module Lisp = Primus.Lisp.Make(Machine)
  open Primus.Lisp.Type.Spec

  let init () =
    Machine.sequence [

        Lisp.define "check-if-used" (module MaybeUnused)
          ~types:(tuple [a;b;c] @-> b)
          ~docs:{|(check-if-used T SUB ADDR) marks
                 the return argument of SUB called at ADDR and
                 tainted with T for checking|};

        Lisp.define "is-known-usage" (module IsKnownUsage)
          ~types:(tuple [a] @-> b)
          ~docs:"(is-known-usage T) returns true if a taint T
                 from a return value of a function never was
                 already marked either as a used or as unused";

        Lisp.define "mark-unused" (module MarkUnused)
          ~types:(tuple [a] @-> b)
          ~docs:"(mark-used T) mark a return value of
                 a function tainted by taint T as the unused one";

        Lisp.define "mark-used" (module MarkUsed)
          ~types:(tuple [a] @-> b)
          ~docs:"(mark-used T) mark a return value of
                 a function tainted by taint T as the used one";

        Lisp.define "return-arg" (module Return_arg)
          ~types:(tuple [a] @-> b)
          ~docs:
          ({|(return-arg SUB) returns the name of output argument of the
            subroutine SUB. Returns NIL if the subroutine SUB doesn't
            return anything or subroutine's api is unknown|});
      ]
end

open Config

let enabled = flag "enable" ~doc:"Enables the analysis"

let () = when_ready (fun {get=(!!)} ->
             if !!enabled then
               let () = Taints_tracker.init () in
               List.iter ~f:ident [
                   Primus.Machine.add_component (module Interface);
                   Primus.Machine.add_component (module HandleUnresolved);
           ])
