--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8e0bcdd48d0b4ec9d63533733cf01fecfd31bd5703d7fedb04814255e97ca7a2
--
--  Diagnosis_Activity_Pkg body -- template (seat-written plumbing) with ONE slot (source-word), filled by a Wu edge round.
--  Brief BRIEF_crucible_step5a3_diagnosis_layer_2026-09-17 (5a-3d/e).
with Ada.Characters.Handling;
with Model_Rail_Call_Pkg;
with Model_Reply_Pkg;
with Reasoner_Check_Pkg;

package body Diagnosis_Activity_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Diagnosis_Class_Pkg.Hint_Class;
   use type Diagnosis_Class_Pkg.Catalogue_Class;
   use type Diagnosis_Select_Pkg.Source_Kind;
   use type Reasoner_Check_Pkg.Check_Kind;

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   type Which is (Prover, Spec, Body_Kind);

   --  Fold every line of Text through the proven evidence rules (lines longer than the core's bound are skipped).
   procedure Fold (Text : String; W : Which; E : in out Diagnosis_Class_Pkg.Evidence) is
      Start : Positive := Text'First;
   begin
      for P in Text'First .. Text'Last + 1 loop
         if P = Text'Last + 1 or else Text (P) = LF then
            if P > Start then
               declare
                  L1 : constant String (1 .. P - Start) := Text (Start .. P - 1);
               begin
                  if L1'Length <= Diagnosis_Class_Pkg.Max_Line then
                     case W is
                        when Prover    => E := Diagnosis_Class_Pkg.Add_Prover_Line (E, L1);
                        when Spec      => E := Diagnosis_Class_Pkg.Add_Spec_Line (E, L1);
                        when Body_Kind => E := Diagnosis_Class_Pkg.Add_Body_Line (E, L1);
                     end case;
                  end if;
               end;
            end if;
            Start := P + 1;
         end if;
      end loop;
   end Fold;

   --  The reasoner's first line "CLASS: <word>" → a catalogue class (Unclassified when absent or not one of the five).
   function Claimed_Class (Reply : String) return Diagnosis_Class_Pkg.Catalogue_Class is
      R     : constant String := Lower (Reply);
      Start : Positive := R'First;
   begin
      for P in R'First .. R'Last + 1 loop
         if P = R'Last + 1 or else R (P) = LF then
            if P > Start then
               declare
                  L : constant String := R (Start .. P - 1);
                  K : Natural := 0;
               begin
                  for I in L'Range loop
                     if I + 5 <= L'Last and then L (I .. I + 5) = "class:" then
                        K := I + 6;
                        exit;
                     end if;
                  end loop;
                  if K > 0 then
                     declare
                        Rest : constant String := L (K .. L'Last);
                        function Has (W : String) return Boolean is
                          (for some I in Rest'First .. Rest'Last - W'Length + 1 => Rest (I .. I + W'Length - 1) = W);
                     begin
                        if Has ("inductive_strength") then return Diagnosis_Class_Pkg.Inductive_Strength;
                        elsif Has ("hard_frame") then return Diagnosis_Class_Pkg.Hard_Frame;
                        elsif Has ("omission") then return Diagnosis_Class_Pkg.Omission;
                        elsif Has ("idiom") then return Diagnosis_Class_Pkg.Idiom;
                        elsif Has ("logic") then return Diagnosis_Class_Pkg.Logic;
                        else return Diagnosis_Class_Pkg.Unclassified;
                        end if;
                     end;
                  end if;
               end;
            end if;
            Start := P + 1;
         end if;
      end loop;
      return Diagnosis_Class_Pkg.Unclassified;
   end Claimed_Class;

   procedure Diagnose
     (Lines          : String;
      Spec_Text      : String;
      Body_Text      : String;
      State          : in out Diagnosis_Select_Pkg.Select_State;
      Text           : out Unbounded_String;
      Class_Word     : out Unbounded_String;
      Catalogue_Word : out Unbounded_String;
      Source_Word    : out Unbounded_String)
   is
      E  : Diagnosis_Class_Pkg.Evidence;
      Ch : Diagnosis_Select_Pkg.Choice;
   begin
      Text := Null_Unbounded_String;
      Class_Word := To_Unbounded_String ("no_hint");
      Catalogue_Word := To_Unbounded_String ("unclassified");
      Source_Word := To_Unbounded_String ("none");

      Fold (Lines, Prover, E);
      Fold (Spec_Text, Spec, E);
      Fold (Body_Text, Body_Kind, E);
      Ch := Diagnosis_Select_Pkg.Choose (E, State);

      if Ch.source = Diagnosis_Select_Pkg.Deterministic then
         Text := To_Unbounded_String (Hint_Text (Ch.class));
         Class_Word := To_Unbounded_String (Lower (Diagnosis_Class_Pkg.Hint_Class'Image (Ch.class)));
         Catalogue_Word := To_Unbounded_String (Lower (Diagnosis_Class_Pkg.Catalogue_Class'Image (Diagnosis_Class_Pkg.Catalogue_Of (Ch.class))));
      elsif Ch.source = Diagnosis_Select_Pkg.Reasoner then
         declare
            L1     : constant String := (if Lines'Length <= Max_Lines_Chars then Lines else Lines (Lines'First .. Lines'First + Max_Lines_Chars - 1));
            Prompt : constant String :=
              "/no_think" & LF & Reasoner_Instruction & LF & "THE PROVER'S LINES:" & LF & L1 & LF & LF &
              "THE SPECIFICATION:" & LF & Spec_Text & LF & LF & "THE BODY:" & LF & Body_Text & LF;
            Reply  : Model_Rail_Call_Pkg.Text_Access;
            MO     : Model_Reply_Pkg.Outcome_Kind;
         begin
            Model_Rail_Call_Pkg.Complete (Prompt, Reply, MO);
            if Model_Reply_Pkg.Is_Text (MO) then
               declare
                  Claimed  : constant Diagnosis_Class_Pkg.Catalogue_Class := Claimed_Class (Reply.all);
                  Set      : constant Reasoner_Check_Pkg.Class_Set := Reasoner_Check_Pkg.Evidence_Set (E);
                  Believed : constant Diagnosis_Class_Pkg.Catalogue_Class := Reasoner_Check_Pkg.Believed_Class (Claimed, Set);
               begin
                  Class_Word := To_Unbounded_String (Lower (Diagnosis_Class_Pkg.Catalogue_Class'Image (Claimed)));
                  Catalogue_Word := To_Unbounded_String (Lower (Diagnosis_Class_Pkg.Catalogue_Class'Image (Believed)));
                  if Believed /= Diagnosis_Class_Pkg.Unclassified then
                     Text := To_Unbounded_String ("REASONER (class " & Lower (Diagnosis_Class_Pkg.Catalogue_Class'Image (Believed)) & ", checked):" & LF & Reply.all);
                  end if;
               end;
            end if;
         end;
      end if;

      --  SLOT BEGIN (source-word)
      Source_Word := To_Unbounded_String
        (if Ch.source = Diagnosis_Select_Pkg.Deterministic then "deterministic"
         elsif Ch.source = Diagnosis_Select_Pkg.Reasoner then
           (if To_String (Catalogue_Word) = "unclassified" then "reasoner-unclassified" else "reasoner-agreed")
         else "none");
      --  SLOT END (source-word)

      State := Diagnosis_Select_Pkg.Record_Sent (State, Ch);
   exception
      when others =>
         Text := Null_Unbounded_String;
         Source_Word := To_Unbounded_String ("none");
   end Diagnose;

end Diagnosis_Activity_Pkg;
