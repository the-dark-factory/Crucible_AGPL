--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--
--  pack_tower -- the PACK command: this factory's admitted ledger, packed into one UNRECEIPTED shareable file.
--  Thin driver, seat-written I/O glue (SPARK_Mode Off): it reads no arguments, calls Tower_Pack_Edge.Pack in the
--  directory it is started in, prints the word the edge hands back, and exits. It judges nothing; every judgement
--  is the edge's and the proven packages behind it. Mirrors the lane driver tower_pack_probe_main, for real use.
--
--  RUN IT in the factory's root. It reads state/VERIFIED_CORES.jsonl and the SHARING key at $HOME/.df-tower/df-tower
--  (the operator's df-tower key: the binary reads it at run time, never this text), and writes out/tower.unreceipted.
--  When tower/pack.receipt is present it completes instead: out/tower.bundle from the unreceipted file and the
--  receipt. One row goes to state/tower-pack.jsonl on every run.
--  THE WORD, one line on standard output: packed, packed_unreceipted, refused_no_ledger, refused_no_key,
--  refused_nothing_shareable, refused_too_large, refused_sign_failed, refused_write_failed, refused_no_source,
--  refused_receipt_mismatch, or unmeasured. A refusal is a result: read the word, not the exit status.
--  EXIT STATUS: 0 whenever the edge returned a word (it never raises); 2 for any argument; 3 if this driver itself
--  failed before it could print. Never 1.
--  This is the PACKER's command. The other half of the share side, certify_tower, uses a DIFFERENT key (the
--  admitter's): the two are never the same key and never the same command (the owner's ruling R1).
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Tower_Pack_Edge;

procedure Pack_Tower_Main is
   Word : Ada.Strings.Unbounded.Unbounded_String;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "pack_tower takes no arguments: run it in the factory's root");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Tower_Pack_Edge.Pack (Word);
   Ada.Text_IO.Put_Line (Ada.Strings.Unbounded.To_String (Word));
   Ada.Command_Line.Set_Exit_Status (0);
exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (3);
end Pack_Tower_Main;
