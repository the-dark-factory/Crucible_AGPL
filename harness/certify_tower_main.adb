--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--
--  certify_tower -- the CERTIFY command: an unreceipted shareable file, completed with its provenance record.
--  Thin driver, seat-written I/O glue (SPARK_Mode Off): it reads no arguments, calls Tower_Receipt_Edge.Issue in
--  the directory it is started in, prints the word the edge hands back, and exits. It judges nothing; every
--  judgement is the edge's and the proven packages behind it. Mirrors the lane driver tower_receipt_probe_main,
--  for real use.
--
--  RUN IT on the build host, as the ADMITTER, in the issuer's root. It reads in/tower.unreceipted, the
--  allowed_signers file BESIDE THIS BINARY (the packers it knows), and the admitter's key at
--  $HOME/keys/interim-2026-08.key (the same identity admit-core.sh signs core admissions with; the binary reads
--  it at run time, never this text). It writes out/tower.bundle (the completed file) and out/tower.receipt (the
--  record and its seal, so the packer can complete its own copy). One row goes to state/tower-receipt.jsonl on
--  every measured run.
--  THE WORD, one line on standard output: issued, refused_no_source, refused_no_key, refused_not_sealed,
--  refused_not_a_payload, refused_seal_unknown, refused_seal_invalid, refused_self_sealed, refused_sign_failed,
--  refused_write_failed, or unmeasured. A refusal is a result: read the word, not the exit status.
--  EXIT STATUS: 0 whenever the edge returned a word (it never raises); 2 for any argument; 3 if this driver itself
--  failed before it could print. Never 1.
--  Start it by a PATH WITH A SLASH (bin/certify_tower, or the absolute path): started through PATH by a bare name
--  the edge names no signers, on purpose, and refuses every seal as unknown.
--  This is the ADMITTER's command. The other half of the share side, pack_tower, uses a DIFFERENT key (the
--  packer's): a file sealed with this admitter's own key is refused as self-sealed (the owner's ruling R1).
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Tower_Receipt_Edge;

procedure Certify_Tower_Main is
   Word : Ada.Strings.Unbounded.Unbounded_String;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "certify_tower takes no arguments: run it in the issuer's root, as the admitter");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Tower_Receipt_Edge.Issue (Word);
   Ada.Text_IO.Put_Line (Ada.Strings.Unbounded.To_String (Word));
   Ada.Command_Line.Set_Exit_Status (0);
exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (3);
end Certify_Tower_Main;
