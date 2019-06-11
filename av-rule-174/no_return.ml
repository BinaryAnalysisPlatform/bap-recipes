open Core_kernel
open Bap.Std

class mapper no_rets = object
  inherit Term.mapper

  method! map_jmp j =
    match Jmp.kind j with
    | Goto _ | Ret _ | Int _ -> j
    | Call c ->
       match Call.target c with
       | Indirect _ -> j
       | Direct tid ->
          if List.mem no_rets tid ~equal:Tid.equal then
            Jmp.with_kind j (Call (Call.with_noreturn c))
          else j
end

(* Subroutine is noreturn when:
     - all the calls from subroutine are non return
       and the list of calls is not empty
     - id doesn't contain interupt or return jumps *)
let is_no_return sub =
  let is_goto j =
    Jmp.kind j |> function | Goto _ -> true | _ -> false in
  let jumps =
    Seq.fold (Term.to_sequence blk_t sub) ~init:[]
      ~f:(fun acc b ->
        let jumps = Term.to_sequence jmp_t b in
        let jumps = Seq.filter jumps ~f:(Fn.non is_goto) in
        Seq.to_list jumps @ acc) in
  match jumps with
  | [] -> false
  | jumps ->
     List.for_all jumps ~f:(fun j ->
         match Jmp.kind j with
         | Call c -> Option.is_none (Call.return c)
         | _ -> false)

let no_rets subs =
  Seq.filter subs ~f:is_no_return |> Seq.to_list

let main proj =
  let prog = Project.program proj in
  let names = ["abort"; "exit"; "__stack_chk_fail"] in
  let subs = Term.to_sequence sub_t prog in
  let no_rets = no_rets subs in
  let no_rets = no_rets @
                  (Seq.filter_map subs ~f:(fun s ->
                       if List.mem names (Sub.name s) ~equal:String.equal then
                         Some s
                       else None) |> Seq.to_list) in
  let no_rets = List.map ~f:Term.tid no_rets in
  Project.with_program proj ((new mapper no_rets)#run prog)

let init () = Project.register_pass ~autorun:true main
