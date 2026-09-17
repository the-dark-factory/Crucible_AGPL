--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 215c16f10919d9af255df4dbf684d8a82da6be1bdf5de4912812768df18a379f
--
--  Decompose_Activity_Pkg -- the Decompose stage of CRUCIBLE's pipeline, in process (step 4c unit 3).
--  Purpose: ask the model rail for a MASCOT design of the brief, and judge it with the proven MASCOT scanner, measurer
--  and judge. It decides nothing: the model's outcome is judged by Model_Reply_Pkg (inside Model_Rail_Call_Pkg), the
--  design by Mascot_Scan_Pkg / Mascot_Measure_Pkg / Mascot_Judge_Pkg, and the stage outcome by Stage_Outcome_Map_Pkg.
--  A design that does not fit the scanner's bounds (a line over Max_Line, or more than Max_Nodes lines) is REFUSED,
--  never measured on a clipped prefix. Any model outcome other than text is Unmeasured_Here (retry policy is step 5a's).
--  Usage:
--     Decompose_Activity_Pkg.Run (Brief => Sheet_Text, Result => O, Reason => R);
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;

package Decompose_Activity_Pkg with SPARK_Mode => Off is

   --  5a-0: the instruction states every obligation the MASCOT judge measures (Mascot_Judge_Pkg.Fact_Name), in the
   --  order a designer meets them. The first form listed the keys only; the model omitted element/buffer/producer/
   --  consumer, reports and discharge, and the judge refused (measured 2026-09-17, qwen3.8-27b-ada:v0.5).
   Design_Instruction : constant String :=
     "Emit a MASCOT design as JSON lines: exactly one subsystem per line, each line one flat JSON "
     & "object, every value a double-quoted string (no numbers, no lists, no nesting), no prose, no "
     & "fences, no comments. Keys: id, kind, element, buffer, producer, producers, consumer, "
     & "reporting, reads, writes, reports, accessed, discharge, children. A proven judge refuses the "
     & "design unless ALL of these hold: "
     & "(1) every line has id and kind; kind is activity, pool, channel or composite. "
     & "(2) every channel line has element (the type carried), buffer (the depth, e.g. 1), producer "
     & "(one activity id) or producers (activity ids separated by spaces), and consumer naming exactly "
     & "ONE activity id. "
     & "(3) exactly one channel is the events channel: it has reporting set to true, and exactly one "
     & "activity (the sink) consumes it. "
     & "(4) every activity line has reports naming that events channel id, and reads or writes naming "
     & "channel or pool ids (space separated). "
     & "(5) every pool line has element and accessed naming the activity ids that use it. "
     & "(6) every activity and every pool has discharge: the obligation proved there, in words, never "
     & "empty. "
     & "(7) every composite line has children naming ids; every other line is a leaf. "
     & "(8) the data flow between activities has no cycle, and no two channels join the same producer "
     & "to the same consumer. "
     & "Example line: {""id"":""events"",""kind"":""channel"",""element"":""Event"",""buffer"":""8"","
     & """producer"":""searcher"",""consumer"":""reporter"",""reporting"":""true""} "
     & "Brief: ";

   procedure Run
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Ada.Strings.Unbounded.Unbounded_String);

   --  5a-2f: the same run, and beside the outcome the DESIGN TEXT the judge measured (the model's lines after the last
   --  think tag, one subsystem per line, LF-terminated; empty when no design fitted the scanner). Emit_Contract needs the
   --  accepted design's leaves; Run wraps this and discards it.
   procedure Run_Keeping_Design
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Ada.Strings.Unbounded.Unbounded_String;
      Design : out Ada.Strings.Unbounded.Unbounded_String);

end Decompose_Activity_Pkg;
