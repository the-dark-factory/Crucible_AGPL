--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 823745ce033006eaf55391c9ac5a017bcce09be6f51dba296e94c4fa6e43c0c1
--
package Shelf_Case_Pkg with SPARK_Mode is

   type Shelf_State is
     (Admitted, Claimed, Proving, Proved, Delivered, Closed, Withdrawn, Refused);

   type Actor_Kind is
     (Actor_Solver, Actor_Palais, Actor_Sender);

   type Move_Facts is record
      from_state           : Shelf_State := Closed;
      to_state             : Shelf_State := Refused;
      actor                : Actor_Kind  := Actor_Solver;
      lease_held           : Boolean     := False;
      palais_proof_receipt : Boolean     := False;
      in_situ_receipt      : Boolean     := False;
   end record;

   function Is_Terminal (S : Shelf_State) return Boolean is
     ((S = Closed) or (S = Withdrawn) or (S = Refused))
     with Post =>
       (Is_Terminal'Result = ((S = Closed) or (S = Withdrawn) or (S = Refused))) and then
       (if S = Admitted then not Is_Terminal'Result) and then
       (if S = Proved then not Is_Terminal'Result);

   function Receipt_Entered (S : Shelf_State) return Boolean is
     ((S = Proved) or (S = Delivered) or (S = Closed) or (S = Refused))
     with Post =>
       (Receipt_Entered'Result = ((S = Proved) or (S = Delivered) or (S = Closed) or (S = Refused))) and then
       (if S = Claimed then not Receipt_Entered'Result) and then
       (if S = Proving then not Receipt_Entered'Result);

   function Receipts_Complete (F : Move_Facts) return Boolean is
     ((F.palais_proof_receipt and then F.in_situ_receipt))
     with Post =>
       (Receipts_Complete'Result = (F.palais_proof_receipt and then F.in_situ_receipt)) and then
       (if not F.palais_proof_receipt then not Receipts_Complete'Result) and then
       (if not F.in_situ_receipt then not Receipts_Complete'Result);

   function Ordering_Lawful (F : Move_Facts) return Boolean is
     (((F.from_state = Admitted) and then (F.to_state = Claimed)) or
      ((F.from_state = Admitted) and then (F.to_state = Refused)) or
      ((F.from_state = Claimed) and then (F.to_state = Proving)) or
      ((F.from_state = Claimed) and then (F.to_state = Admitted)) or
      ((F.from_state = Claimed) and then (F.to_state = Withdrawn)) or
      ((F.from_state = Proving) and then (F.to_state = Proved)) or
      ((F.from_state = Proving) and then (F.to_state = Claimed)) or
      ((F.from_state = Proved) and then (F.to_state = Delivered)) or
      ((F.from_state = Delivered) and then (F.to_state = Closed)))
     with Post =>
       (Ordering_Lawful'Result = (((F.from_state = Admitted) and then (F.to_state = Claimed)) or
                                  ((F.from_state = Admitted) and then (F.to_state = Refused)) or
                                  ((F.from_state = Claimed) and then (F.to_state = Proving)) or
                                  ((F.from_state = Claimed) and then (F.to_state = Admitted)) or
                                  ((F.from_state = Claimed) and then (F.to_state = Withdrawn)) or
                                  ((F.from_state = Proving) and then (F.to_state = Proved)) or
                                  ((F.from_state = Proving) and then (F.to_state = Claimed)) or
                                  ((F.from_state = Proved) and then (F.to_state = Delivered)) or
                                  ((F.from_state = Delivered) and then (F.to_state = Closed)))) and then
       (if Is_Terminal (F.from_state) then not Ordering_Lawful'Result) and then
       (if Ordering_Lawful'Result and then F.from_state = Proved then F.to_state = Delivered) and then
       (if F.to_state = Closed and then Ordering_Lawful'Result then F.from_state = Delivered);

   function May_Move (F : Move_Facts) return Boolean is
     ((Ordering_Lawful (F)) and then
      (not ((F.actor = Actor_Solver) and then Receipt_Entered (F.to_state))) and then
      (if F.to_state = Proved then F.palais_proof_receipt) and then
      (if F.to_state = Closed then Receipts_Complete (F)) and then
      (if (F.to_state = Proving or F.to_state = Withdrawn) then F.lease_held))
     with Post =>
       (May_Move'Result = ((Ordering_Lawful (F)) and then
                          (not ((F.actor = Actor_Solver) and then Receipt_Entered (F.to_state))) and then
                          (if F.to_state = Proved then F.palais_proof_receipt) and then
                          (if F.to_state = Closed then Receipts_Complete (F)) and then
                          (if (F.to_state = Proving or F.to_state = Withdrawn) then F.lease_held))) and then
       (if F.to_state = Closed then (if May_Move'Result then Receipts_Complete (F))) and then
       (if (F.actor = Actor_Solver) and then Receipt_Entered (F.to_state) then not May_Move'Result) and then
       (if Is_Terminal (F.from_state) then not May_Move'Result) and then
       (if May_Move'Result and then F.to_state = Proved then F.palais_proof_receipt) and then
       (if May_Move'Result and then F.to_state = Closed then (F.palais_proof_receipt and then F.in_situ_receipt));

end Shelf_Case_Pkg;
