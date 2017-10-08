From Mtac2 Require Import Mtac2 Datatypes List.

Import ListNotations.
Open Scope M_scope.

(** MTele: a telescope which represents functions of the type
      `X -> ... -> Z -> M R`
    where R may depend on the value given for X and Y

   This will be used to represent legal types of patterns and fixpoints.
 *)
Inductive MTele : Type :=
| mBase (R : Type) : MTele
| mTele {X : Type} (F : X -> MTele) : MTele
.

Notation "'[tele' x .. y , b ]" := (mTele (fun x => .. (mTele (fun y => mBase b)) .. )) (at level 100, x binder, y binder).

(** MTele_ty: calculate `X -> ... -> Z -> M R` from a given MTele

   To be able to use this in the definition of M.t itself, we paramatrize by M.
*)
Fixpoint MTele_ty M (m : MTele) : Prop :=
  match m with
  | mBase R => M R
  | @mTele X F => forall (x : X), MTele_ty M (F x)
  end.

(** Constant MTele_ty *)
Fixpoint MTele_C (M : Type -> Prop) (b : forall R, M R) m : MTele_ty M m :=
  match m with
  | mBase R => b R
  | mTele F => fun x => MTele_C M b (F x)
  end.


Fixpoint MTele_map' (M : Type -> Prop) {X : forall R :Type, Prop} (m : MTele) : forall (f : MTele_ty (fun R => M R -> X R) m), MTele_ty M m -> MTele_ty (fun R => X R) m :=
  match m as m' return _ m' -> MTele_ty M m' -> MTele_ty _ m' with
  | mBase R => fun (f : M R -> X R) (t : M R) => f t
  | mTele F => fun (f : forall x : _, MTele_ty _ (F x)) (t : forall x : _, MTele_ty M (F x)) =>
                 fun x : _ => MTele_map' M (F x) (f x) (t x)
  end.

Fixpoint MTele_mkfunc (M : Type -> Prop) {X : Type -> Prop} (b : forall R, M R -> X R) (m : MTele) : MTele_ty (fun R => M R -> X R) m :=
  match m as m' return MTele_ty (fun R => M R -> X R) m' with
  | mBase R => fun t => b _ t
  | mTele F => fun x => MTele_mkfunc M b (F x)
  end.

Notation MT_Acc R m := (forall (M' : Type -> Prop), MTele_ty M' m -> M' R).

Fixpoint MTele_open (M : Type -> Prop) {X : Type -> Prop} m :
  (forall R, MT_Acc R m -> X R) -> MTele_ty X m  :=
  match m as m' return (forall R, MT_Acc R m' -> X R) -> MTele_ty X m' with
  | mBase R => fun b => b R (fun M' x => x)
  | mTele F => fun b x => MTele_open M (F x) (fun R f => b R (fun M' mR => f M' (mR x)))
  end.

Definition MTele_map (M : Type -> Prop) {X : Type -> Prop}  (b : forall R, M R -> X R) (m : MTele) : MTele_ty M m -> MTele_ty (fun R => X R) m :=
  MTele_map' M _ (MTele_mkfunc _ b m).

(** mt_pattern: Alternative pattern definition which uses MTele. *)
Inductive mtpattern' (M : Type -> Prop) (A : Type) (m : A -> Prop) (y : A) : Prop :=
| mtpbase' : forall x : A, (m x) -> Unification -> mtpattern' M A m y
| mtptele' : forall {C}, (forall x : C, mtpattern' M A m y) -> mtpattern' M A m y.

Arguments mtpbase' {M A m y} _ _ _.
Arguments mtptele' {M A m y C} _.

Section Test.

Variables (A : Type) (m : A -> Prop).

Inductive mtpattern  : Prop :=
| mtpbase : forall x : A, (m x) -> Unification -> mtpattern
| mtptele : forall {C}, (forall x : C, mtpattern) -> mtpattern.

End Test.

Arguments mtpbase {A m} _ _ _.
Arguments mtptele {A m C} _.

Definition mtmmatch' A m (y : A) (ps : list (mtpattern A (fun x => MTele_ty M (m x)))) : MTele_ty M.t (m y) :=
  MTele_open
    M.t (m y)
    (fun R acc =>
       (fix mmatch' ps : M.t R :=
          match ps with
          | [m:] => M.raise NoPatternMatches
          | [m: p & ps'] =>
            (* M.print "dbg2";; *)
                    let g := (fix go p :=
                                (* M.print "inner";; *)
                                (* M.print_term p;; *)
                        match p return M.t _ with
                        | mtpbase x f u =>
                          (* M.print "mtpbase";; *)
                          oeq <- M.unify x y u;
                          match oeq return M.t R with
                          | Some eq =>
                            (* eq has type x = t, but for the pattern we need t = x.
         we still want to provide eq_refl though, so we reduce it *)
                            let h := reduce (RedStrong [rl:RedBeta;RedDelta;RedMatch]) (eq_sym eq) in
                            let 'eq_refl := eq in
                            (* For some reason, we need to return the beta-reduction of the pattern, or some tactic fails *)

                            (* M.print "dbg1";; *)
                            let f' := (match h in _ = z return MTele_ty M.t (m z) -> MTele_ty M.t (m y)
                                       with
                                       | eq_refl => fun f => f
                                       end f)
                            in
                            let a := acc _ f' in
                            let b := reduce (RedStrong [rl:RedBeta]) (a) in
                            (* b *)
                            b
                          | None =>
                            M.raise DoesNotMatch
                        end

                        | mtptele f =>
                          (* M.print "dbg3";; *)
                          c <- M.evar _;
                          go (f c)
                        end
                     ) in
            (* M.print_term p;; *)
            let t := g p in
            M.mtry' t
                  (fun e =>
                     mif M.unify e DoesNotMatch UniMatchNoRed then mmatch' ps' else M.raise e)
            (* mtry' (open_mtpattern _ (fun _ => _)) *)
            (*       (fun e => *)
            (*          mif unify e DoesNotMatch UniMatchNoRed then mmatch' ps' else raise e) *)
          end) ps
    ).

Module TestFin.
Require Fin.
Definition mt : nat -> MTele := fun n => mTele (fun _ : Fin.t n => mBase (True)).
Definition pO u : mtpattern nat _ := @mtpbase _ (fun x => MTele_ty M (mt x)) O (fun x => Fin.case0 (fun _ => M True) x) u.
Definition p1 u : mtpattern nat _ := @mtpbase _ (fun x => MTele_ty M (mt x)) 1 (fun n => M.ret I) u.
Definition pi u : mtpattern nat (fun x => MTele_ty M (mt x)) :=
  mtptele (fun i : nat =>
             @mtpbase _ _ i (fun n => M.ret I) u
          ).

Program Example pbeta : mtpattern nat (fun x => MTele_ty M (mt x)) :=
  mtptele (fun i : nat =>
            @mtpbase _ (* (fun x => MTele_ty M (mt x)) *) _ (i + 1) (fun n : Fin.t (i + 1) => M.ret I) UniCoq
         ).
End TestFin.

Definition MTele_of {A} (T : A -> Prop) :=
  b <- M.fresh_binder_name T;
  M.nu b None (fun a =>
  (mfix1 f (T : Prop) : M (MTele) :=
                    mmatch T as t' return M MTele with
                                        | [?X : Type] M X =u> M.ret (mBase X)
                                        | [?(X : Type) (F : forall x:X, Prop)] (forall x:X, F x)
                                          =u>
                                           b <- M.fresh_binder_name F;
                                          f <- M.nu b None (fun x =>
                                                 g <- f (F x);
                                                 M.abs_fun x g);
                                          M.ret (mTele f)
   end
  ) (T a) >>= (M.abs_fun a)).


(* Bind Scope Unification_scope with Unification. *)
(* Delimit Scope Unification_scope with Unification. *)
(* Notation "'=u>'" := (UniCoq) : Unification_scope. *)
(* Notation "'=e>'" := (UniEvarconv) : Unification_scope. *)
(* Notation "'=n>'" := (UniMatchNoRed) : Unification_scope. *)
(* Notation "'=m>'" := (UniMatch) : Unification_scope. *)
(* Close Scope Unification_scope. *)

Bind Scope mtpattern_scope with mtpattern.
Delimit Scope mtpattern_scope with mtpattern.

Notation "[? x .. y ] ps" := (mtptele (fun x => .. (mtptele (fun y => ps)).. ))
  (at level 202, x binder, y binder, ps at next level) : mtpattern_scope.

Notation "d '=u>' t" := (mtpbase d t UniCoq)
    (at level 201) : mtpattern_scope.
Notation "d '=c>' t" := (mtpbase d t UniEvarconv)
    (at level 201) : mtpattern_scope.
Notation "d '=n>' t" := (mtpbase d t UniMatchNoRed)
    (at level 201) : mtpattern_scope.
Notation "d '=m>' t" := (mtpbase d t UniMatch)
    (at level 201) : mtpattern_scope.

Notation "'_' => b " := (mtptele (fun x=> mtpbase x (fun _ => b%core) UniMatch))
  (at level 201, b at next level) : mtpattern_scope.

Notation "'with' | p1 | .. | pn 'end'" :=
  ((@cons (mtpattern _ _) p1%mtpattern (.. (@cons (mtpattern _ _) pn%mtpattern nil) ..)))
  (at level 91, p1 at level 210, pn at level 210) : with_mtpattern_scope.
Notation "'with' p1 | .. | pn 'end'" :=
  ((@cons (mtpattern _ _) p1%mtpattern (.. (@cons (mtpattern _ _) pn%mtpattern nil) ..)))
  (at level 91, p1 at level 210, pn at level 210) : with_mtpattern_scope.

Delimit Scope with_mtpattern_scope with with_mtpattern.

Class TC_UNIFY {T : Type} (A B : T) := tc_unify : (A = B).
Arguments tc_unify {_} _ _ {_}.
Hint Extern 0 (TC_UNIFY ?A ?B) => mrun (o <- M.unify A B UniCoq; match o with | Some eq => M.ret eq | None => M.failwith "cannot (tc_)unify." end) : typeclass_instances.

Class MT_OF {A} (T : A -> Prop) := mt_of : A -> MTele.
Arguments mt_of {_} _ {_}.
Hint Extern 0 (MT_OF ?t) => mrun (MTele_of t) : typeclass_instances.

Notation "'mtmmatch' x 'as' y 'return' T p" :=
  (
    let m := mt_of (fun y => T) in
    match tc_unify (fun _z => MTele_ty M (m _z))((fun y => T))
          in _ = R return list (mtpattern _ R) -> R x with
    | eq_refl => fun ps => mtmmatch' _ (m) x ps
    end
    (p%with_mtpattern)
  ) (at level 90, p at level 91).

(* Goal nat -> True. *)
(*   MProof. *)
(*   intros x. *)
(*   ((( *)
(*        let x := S x in *)
(*         m <- MTele_of (fun y => Fin.t y -> M True); *)
(*         oeq <- M.unify  (fun y => MTele_ty M (m y)) (fun y => Fin.t y -> M True) UniCoq; *)
(*         mat <- (match oeq in option _ return list (mtpattern _ (fun y => Fin.t y -> M True)) -> M ((fun y => Fin.t y -> M True) x) with *)
(*         | Some eq => *)
(*           match eq in _ = R return list (mtpattern _ R) -> M (R x) with *)
(*           | eq_refl => fun ps => *)
(*                          M.ret (mtmmatch' _ m x ps ) *)
(*           end *)
(*         | None => fun _ => M.failwith "Impossible Case" *)
(*         end) *)

(*           [m: *)
(*              (mtptele (fun i :nat => (mtpbase (S i) (fun t : Fin.t (S i) => M.ret I) UniCoq))) *)
(*           ]; *)
(*         mat (@Fin.F1 _)))). *)
(* Qed. *)

Local
Program Definition test_mtmmatch x (F : Fin.t (S x)) : M True :=
                   (((mtmmatch (S x) as y return (Fin.t y -> M True)
                                              with
                                              | [? (i : nat)] (i + 1) =u> (fun f : Fin.t (i+1) => M.ret I)
                   end

                 )  F))%MC.