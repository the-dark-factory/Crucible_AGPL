--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Edge glue, written outside the lane and NOT proved. Vendored into Crucible 2026-09-28 from ada-factory
--  expand-lovelace-check-cores/multicall (df928190). This comment block is the only difference from it.
--  Unstamped source sha256: d3a88bd9d2a89cc2f3abe0e50efc5eb8fee06074b9d7868b9d8c7c6386cb165c
--
pragma SPARK_Mode (Off);

--  Vacuity_Battery: the multi-call LINK UNIT of the lovelace vacuity battery (sheets-assembly.txt
--  section 1, "OPTION: a mechanical multi-call link unit"). Edge glue, built outside the lane.
--
--  Every lane-verified unit of the kit is linked here AS-IS as a library procedure; this file adds
--  only the dispatch. The procedure run is chosen by the simple name of argv[0] (busybox style):
--  the kit's executable names are links to this one image, so `wire_main` still finds its kit
--  beside itself and still spawns `wire_strip_main` etc. as child processes -- same names, same
--  argv, same exit status (each unit sets it with Ada.Command_Line.Set_Exit_Status and returns).
--
--  Started under its own name `vacuity-battery`, it is the battery's front door and runs Wire_Main
--  with argv unchanged:  vacuity-battery wire <spec.ads> [<deps-dir>]  (the links must sit beside it).
--  There is no first-argument subcommand form: that would shift Argument (1 ..) under the verified
--  units, which read their arguments by position.
--
--  An unknown name prints one line on standard error and exits 2.

with Ada.Command_Line;
with Ada.Text_IO;
with Argv_Reader_Main;
with Aspect_Counter_Main;
with Byte_Measure_Main;
with Claim_Former_Main;
with Deps_Lister_Main;
with Event_Sink_Main;
with Expr_Tokenizer_Main;
with Function_Scanner_Main;
with Go_Quote_Wide_Main;
with Header_Finder_Main;
with Lemma_Builder_Main;
with Poly_Parser_Main;
with Prover_Main;
with Spec_File_Reader_Main;
with Splice_Render_Main;
with T0_Stage_Main;
with T1_Stage_Main;
with T2_Stage_Main;
with T3_Callee_Stage_Main;
with T3_Mutant_Conjuncts_Main;
with T3_Mutant_Edits_Main;
with T3_Mutant_Render_Main;
with T6_Pre_Main;
with T6_Sub_Main;
with Tb_Stage_Main;
with Tc_Stage_Main;
with Verdict_Spawn_Main;
with Wire_Claim_Main;
with Wire_Close_Main;
with Wire_Domain_Main;
with Wire_Gate_Main;
with Wire_Grade_Main;
with Wire_Main;
with Wire_Mutants_Main;
with Wire_Norm_Main;
with Wire_Norm_Poly_Main;
with Wire_Parse_Main;
with Wire_Strip_Main;

procedure Vacuity_Battery is

   type Entry_Point is access procedure;
   type Name_Text is access constant String;

   type Row is record
      Name : Name_Text;
      Run  : Entry_Point;
   end record;

   type Table is array (Positive range <>) of Row;

   function R (Name : String; Run : Entry_Point) return Row is ((new String'(Name), Run));

   Entries : constant Table :=
     (R ("vacuity-battery",          Wire_Main'Access),
      R ("wire_main",                Wire_Main'Access),
      R ("argv_reader_main",         Argv_Reader_Main'Access),
      R ("aspect_counter_main",      Aspect_Counter_Main'Access),
      R ("byte_measure_main",        Byte_Measure_Main'Access),
      R ("claim_former_main",        Claim_Former_Main'Access),
      R ("deps_lister_main",         Deps_Lister_Main'Access),
      R ("event_sink_main",          Event_Sink_Main'Access),
      R ("expr_tokenizer_main",      Expr_Tokenizer_Main'Access),
      R ("function_scanner_main",    Function_Scanner_Main'Access),
      R ("go_quote_wide_main",       Go_Quote_Wide_Main'Access),
      R ("header_finder_main",       Header_Finder_Main'Access),
      R ("lemma_builder_main",       Lemma_Builder_Main'Access),
      R ("poly_parser_main",         Poly_Parser_Main'Access),
      R ("prover_main",              Prover_Main'Access),
      R ("spec_file_reader_main",    Spec_File_Reader_Main'Access),
      R ("splice_render_main",       Splice_Render_Main'Access),
      R ("t0_stage_main",            T0_Stage_Main'Access),
      R ("t1_stage_main",            T1_Stage_Main'Access),
      R ("t2_stage_main",            T2_Stage_Main'Access),
      R ("t3_callee_stage_main",     T3_Callee_Stage_Main'Access),
      R ("t3_mutant_conjuncts_main", T3_Mutant_Conjuncts_Main'Access),
      R ("t3_mutant_edits_main",     T3_Mutant_Edits_Main'Access),
      R ("t3_mutant_render_main",    T3_Mutant_Render_Main'Access),
      R ("t6_pre_main",              T6_Pre_Main'Access),
      R ("t6_sub_main",              T6_Sub_Main'Access),
      R ("tb_stage_main",            Tb_Stage_Main'Access),
      R ("tc_stage_main",            Tc_Stage_Main'Access),
      R ("verdict_spawn_main",       Verdict_Spawn_Main'Access),
      R ("wire_claim_main",          Wire_Claim_Main'Access),
      R ("wire_close_main",          Wire_Close_Main'Access),
      R ("wire_domain_main",         Wire_Domain_Main'Access),
      R ("wire_gate_main",           Wire_Gate_Main'Access),
      R ("wire_grade_main",          Wire_Grade_Main'Access),
      R ("wire_mutants_main",        Wire_Mutants_Main'Access),
      R ("wire_norm_main",           Wire_Norm_Main'Access),
      R ("wire_norm_poly_main",      Wire_Norm_Poly_Main'Access),
      R ("wire_parse_main",          Wire_Parse_Main'Access),
      R ("wire_strip_main",          Wire_Strip_Main'Access));

   --  The simple name: everything after the last '/'.
   function Simple_Name (Path : String) return String is
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            return Path (I + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Simple_Name;

   Called : constant String := Simple_Name (Ada.Command_Line.Command_Name);

begin
   for E of Entries loop
      if E.Name.all = Called then
         E.Run.all;
         return;
      end if;
   end loop;
   Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "vacuity-battery: no unit named """ & Called & """");
   Ada.Command_Line.Set_Exit_Status (2);
end Vacuity_Battery;
