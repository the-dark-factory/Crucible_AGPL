--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fe5f301e937a4b7c64f7ea4c67b74726bd3d0657588e31ea86bc85bb9199e6c8
--
--  Tower_Base_Check_Edge body -- template with ONE slot (base-facts), filled by a Wu edge round.
--  PROVENANCE OF THE FIXED TEXT, said so that nobody has to guess:
--    LIFTED from the FORGED and lane-probed stamp tool (harness/stamp_tower_main.adb, wu-crucible-tower-stamp-edge
--    round E, probe 25/25, unstamped sha256 04b0f218...3b620): function Strip and the reading block (Open / two
--    Get_Line / the third End_Of_File look / the handler) UNCHANGED but for indentation; the expression of
--    Non_Blank, the Line_1 length test and GNAT.SHA256.Digest of line 1 with these differences and no others:
--    the two stripped lines are named Text_1 and Text_2 (Line_1 is this procedure's parameter), Non_Blank is
--    declared at package level instead of in a block, the path is the constant Bundle_Path and the bound the
--    constant Max_Line_1 (same values), and where the tool called Fail and returned this body records a fact.
--    That is what makes this THE SAME acceptance test the pin was made with: the same lines, not a second
--    description of them. If the stamp tool's reading ever changes, this must change with it.
--    SEAT-WRITTEN plumbing: the package and procedure frame, the three measured Booleans and their defaults,
--    the call of Tower_Base_Verdict_Pkg.Decide, handing Line_1 back only on Base_Holds, the last handler.
--  The slot only RECORDS the three facts. The verdict is Tower_Base_Verdict_Pkg.Decide's, and nothing else's.
with Ada.Text_IO;
with GNAT.SHA256;
with Crucible_Tower;

package body Tower_Base_Check_Edge with SPARK_Mode => Off is

   use type Tower_Base_Verdict_Pkg.Verdict_Kind;

   function Strip (S : String) return String is
      Last : Integer := S'Last;
   begin
      while Last >= S'First and then S (Last) in ASCII.CR | ASCII.LF loop
         Last := Last - 1;
      end loop;
      if Last < S'First then
         return "";
      else
         declare
            R : constant String (1 .. Last - S'First + 1) := S (S'First .. Last);
         begin
            return R;
         end;
      end if;
   end Strip;

   function Non_Blank (S : String) return Boolean is
      (for some I in S'Range => S (I) /= ' ' and then S (I) /= ASCII.HT);

   procedure Check
     (Verdict : out Tower_Base_Verdict_Pkg.Verdict_Kind;
      Facts   : out Tower_Base_Verdict_Pkg.Base_Facts;
      Line_1  : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Read_Ok : Boolean := False;
      L1 : Ada.Strings.Unbounded.Unbounded_String;
      L2 : Ada.Strings.Unbounded.Unbounded_String;

      --  What was measured. Every one starts False: a fact nobody measured refuses.
      Pin_Was_Measured : Boolean := False;   --  the binary carries a pin at all
      File_Was_Read    : Boolean := False;   --  the file passed the stamp tool's acceptance test
      Digest_Did_Match : Boolean := False;   --  SHA-256 of line 1 equals the compiled-in pin
      Kept_Line_1      : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      Facts   := (pin_measured => False, file_read => False, digest_matches => False);
      Verdict := Tower_Base_Verdict_Pkg.Decide (Facts);
      Line_1  := Ada.Strings.Unbounded.Null_Unbounded_String;

      Pin_Was_Measured := Crucible_Tower.Base_Measured;

      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Bundle_Path);
         if Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Close (F);
         else
            L1 := Ada.Strings.Unbounded.To_Unbounded_String (Ada.Text_IO.Get_Line (F));
            if Ada.Text_IO.End_Of_File (F) then
               Ada.Text_IO.Close (F);
            else
               L2 := Ada.Strings.Unbounded.To_Unbounded_String (Ada.Text_IO.Get_Line (F));
               Read_Ok := Ada.Text_IO.End_Of_File (F);
               Ada.Text_IO.Close (F);
            end if;
         end if;
      exception
         when others =>
            Read_Ok := False;
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;

      if Read_Ok then
         declare
            Text_1 : constant String := Strip (Ada.Strings.Unbounded.To_String (L1));
            Text_2 : constant String := Strip (Ada.Strings.Unbounded.To_String (L2));
         begin
            if Text_1'Length = 0 or else Text_1'Length > Max_Line_1 then
               File_Was_Read := False;
            elsif not Non_Blank (Text_2) then
               File_Was_Read := False;
            else
               File_Was_Read := True;
               declare
                  Digest_Raw : constant String := GNAT.SHA256.Digest (Text_1);
               begin
                  Digest_Did_Match := Digest_Raw = Crucible_Tower.Base_Digest;
                  Kept_Line_1 := Ada.Strings.Unbounded.To_Unbounded_String (Text_1);
               end;
            end if;
         end;
      end if;

      --  SLOT BEGIN (base-facts)
      Facts.pin_measured := Pin_Was_Measured;
      Facts.file_read := File_Was_Read;
      Facts.digest_matches := Digest_Did_Match;
      --  SLOT END (base-facts)

      Verdict := Tower_Base_Verdict_Pkg.Decide (Facts);
      if Verdict = Tower_Base_Verdict_Pkg.Base_Holds then
         Line_1 := Kept_Line_1;
      else
         Line_1 := Ada.Strings.Unbounded.Null_Unbounded_String;
      end if;
   exception
      when others =>
         --  No exception may turn into a permission: whatever went wrong, the file facts are False. The pin
         --  fact is a compiled-in constant and cannot raise, so the word said is about the FILE, not the pin.
         Facts   := (pin_measured => Crucible_Tower.Base_Measured, file_read => False, digest_matches => False);
         Verdict := Tower_Base_Verdict_Pkg.Decide (Facts);
         Line_1  := Ada.Strings.Unbounded.Null_Unbounded_String;
   end Check;

end Tower_Base_Check_Edge;
