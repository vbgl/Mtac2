Require Import Mtac2.Mtac2.

Goal True.
MProof.
  M.bind (M.ret I) (fun r => M.ret r).
Qed.

Goal True.
MProof.
  (r <- M.ret I; M.ret r)%MC.
Qed.
