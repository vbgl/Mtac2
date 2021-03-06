Require Import Mtac2.Mtac2.
Import T.

Theorem andb3_exchange :
  forall b c d, andb (andb b c) d = andb (andb b d) c.
MProof.
  intros b c d. destruct b.
  - destruct c.
    { destruct d.
      - reflexivity.
      - reflexivity. }
    { destruct d.
      - reflexivity.
      - reflexivity. }
  - destruct c.
    { destruct d.
      - reflexivity.
      - reflexivity. }
    { destruct d.
      * reflexivity.
      * reflexivity. }
Qed.

Require Import Mtac2.ImportedTactics.
Import Lists.List.ListNotations.

Theorem plus_n_O : forall n:nat, n = n + 0.
MProof.
  intros n. elim n asp [ [] ; [ "n'" ; "IHn'"]].
  - (* n = 0 *) reflexivity.
  - (* n = S n' *) simpl. rewrite <- IHn'.
  reflexivity.
Qed.
