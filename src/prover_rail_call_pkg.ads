--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f9520680d8a002e72b4cc853b68e6d8b598b94c41892d55d581a5437472acc9d
--
--  Prover_Rail_Call_Pkg -- CRUCIBLE's path to a prover over the PROVER RAIL (step 4b unit 3).
--  Purpose: gather the facts for one proof request and one reply, and let the proven deciders judge them.
--  It decides nothing: the rail line is judged by Rail_Config_Pkg, the endpoint by Sovereign_Gate_Pkg, the
--  request by Prover_Rail_Pkg.May_Send (no socket is opened unless it holds), and the outcome by
--  Prover_Rail_Pkg.Decide. The one socket is Rail_Socket_Edge.Exchange.
--  Configuration: config/rail.conf, one JSON line per rail; the first valid line whose rail is "prover" is used.
--  Usage:
--     Outcome := Prover_Rail_Call_Pkg.Prove (Unit_Name => "Linear_Search", Spec_Text => S, Body_Text => B,
--                                            Level => 2);
--     Prover_Rail_Pkg.Is_Pass (Outcome) is the ONLY way to call the unit proved.
with Prover_Rail_Pkg;

package Prover_Rail_Call_Pkg with SPARK_Mode => Off is

   Conf_Path      : constant String := "config/rail.conf";
   Max_Unit_Bytes : constant := 1_048_576;  --  the same limit as CRUCIBLE's door line

   function Prove
     (Unit_Name : String;
      Spec_Text : String;
      Body_Text : String;
      Level     : Natural) return Prover_Rail_Pkg.Outcome_Kind;

   --  5a-1b: the same call, and beside the outcome the prover's own severity lines, which the service sends
   --  as raw lines after its reply line (bounded on the service side by the proven Prove_Diagnostics_Pkg:
   --  at most 60 lines of at most 512 bytes, in file order). Diagnostics is that text, LF-joined, or empty
   --  when no lines came, the declared count and the lines received disagreed, or the reply was not complete.
   --  It never changes Outcome: Prover_Rail_Pkg.Decide sees the reply line's facts only.
   type Text_Access is access String;

   procedure Prove_With_Diagnostics
     (Unit_Name   : String;
      Spec_Text   : String;
      Body_Text   : String;
      Level       : Natural;
      Outcome     : out Prover_Rail_Pkg.Outcome_Kind;
      Diagnostics : out Text_Access);

   --  5a-2f: the same call, and beside the outcome the Reply_Facts the outcome was decided from (unit_compiled,
   --  checks_generated, checks_unproved, subprograms_skipped, ...), so a caller can derive the gate WORD
   --  (Gate_Word_Pkg) from the very facts Prover_Rail_Pkg.Decide judged. Prove_With_Diagnostics and Prove wrap it.
   procedure Prove_Full
     (Unit_Name   : String;
      Spec_Text   : String;
      Body_Text   : String;
      Level       : Natural;
      Outcome     : out Prover_Rail_Pkg.Outcome_Kind;
      Facts       : out Prover_Rail_Pkg.Reply_Facts;
      Diagnostics : out Text_Access);

end Prover_Rail_Call_Pkg;
