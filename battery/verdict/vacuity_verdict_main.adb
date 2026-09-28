--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 06db76c2806d4d96f402c45d39f97afd7cbc1dd3e82f9cc6ecb55212b77d093d
--
with Ada.Command_Line;
with Ada.Text_IO;
with Vacuity_Verdict_Pkg;

procedure Vacuity_Verdict_Main is

   --  VACUITY_VERDICT_MAIN: I/O edge over the proven core Vacuity_Verdict_Pkg.
   --  SCOPE BOUNDARY: this edge DECIDES NOTHING. It reads command-line
   --  arguments, calls Vacuity_Verdict_Pkg, prints one digit, and sets an
   --  exit status. If the arguments are wrong it refuses rather than guessing.
   --  A REFUSAL IS NOT A VERDICT: exit status two means the edge could not
   --  put a proper question to the core; the caller must stop.
   --  USAGE:
   --    vacuity_verdict_main grade T0 RTE TB TC T1 T2 T3 T4
   --      eight outcome digits -> grade digit
   --    vacuity_verdict_main worst A B
   --      two outcome digits -> combined outcome digit
   --    vacuity_verdict_main roll G1 G2
   --      two grade digits -> package grade digit
   --    vacuity_verdict_main claim CLAIMED ESTABLISHED
   --      two grade digits -> "admissible" or "refused"

   function To_Digit (S : String) return Integer is
   begin
      if S = "0" then
         return 0;
      elsif S = "1" then
         return 1;
      elsif S = "2" then
         return 2;
      elsif S = "3" then
         --  Inapplicable (Vacuity_Verdict_Pkg v2, Tony's ruling (b) 2026-09-18):
         --  the test cannot apply to this function. Accepted only as an OUTCOME;
         --  a Grade is still 0 .. 2, so a 3 given where a grade is expected is
         --  refused by the grade checks below rather than silently graded.
         return 3;
      else
         return -1;
      end if;
   end To_Digit;

   procedure Print_Digit (V : Integer) is
   begin
      case V is
         when 0 =>
            Ada.Text_IO.Put_Line ("0");
         when 1 =>
            Ada.Text_IO.Put_Line ("1");
         when 2 =>
            Ada.Text_IO.Put_Line ("2");
         when others =>
            null;
      end case;
   end Print_Digit;

   Count : constant Natural := Ada.Command_Line.Argument_Count;

begin
   if Count = 0 then
      Ada.Text_IO.Put_Line ("usage: vacuity_verdict_main grade|worst|roll|claim <digits>");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
      return;
   end if;

   declare
      Mode : constant String := Ada.Command_Line.Argument (1);
   begin
      if Mode = "grade" then
         if Count /= 9 then
            Ada.Text_IO.Put_Line ("unknown mode or wrong argument count");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
            return;
         end if;

         declare
            T0  : constant Integer := To_Digit (Ada.Command_Line.Argument (2));
            RTE : constant Integer := To_Digit (Ada.Command_Line.Argument (3));
            TB  : constant Integer := To_Digit (Ada.Command_Line.Argument (4));
            TC  : constant Integer := To_Digit (Ada.Command_Line.Argument (5));
            T1  : constant Integer := To_Digit (Ada.Command_Line.Argument (6));
            T2  : constant Integer := To_Digit (Ada.Command_Line.Argument (7));
            T3  : constant Integer := To_Digit (Ada.Command_Line.Argument (8));
            T4  : constant Integer := To_Digit (Ada.Command_Line.Argument (9));
         begin
            if (T0 = -1 or RTE = -1 or TB = -1 or TC = -1 or T1 = -1 or T2 = -1 or T3 = -1 or T4 = -1) then
               Ada.Text_IO.Put_Line ("bad outcome digit");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
               return;
            end if;

            Print_Digit (Vacuity_Verdict_Pkg.Grade_Of (T0, RTE, TB, TC, T1, T2, T3, T4));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         end;

      elsif Mode = "worst" then
         if Count /= 3 then
            Ada.Text_IO.Put_Line ("unknown mode or wrong argument count");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
            return;
         end if;

         declare
            A : constant Integer := To_Digit (Ada.Command_Line.Argument (2));
            B : constant Integer := To_Digit (Ada.Command_Line.Argument (3));
         begin
            if A = -1 or B = -1 then
               Ada.Text_IO.Put_Line ("bad outcome digit");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
               return;
            end if;

            Print_Digit (Vacuity_Verdict_Pkg.Worst (A, B));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         end;

      elsif Mode = "roll" then
         if Count /= 3 then
            Ada.Text_IO.Put_Line ("unknown mode or wrong argument count");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
            return;
         end if;

         declare
            G1 : constant Integer := To_Digit (Ada.Command_Line.Argument (2));
            G2 : constant Integer := To_Digit (Ada.Command_Line.Argument (3));
         begin
            --  A GRADE is 0 .. 2. Outcome 3 (Inapplicable) is an OUTCOME, never a grade:
            --  refuse it here rather than let it reach Roll_Up and raise Constraint_Error.
            --  A refusal is not a verdict; a crash is not either, and it is worse.
            if G1 = -1 or G2 = -1 or G1 > 2 or G2 > 2 then
               Ada.Text_IO.Put_Line ("bad grade digit");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
               return;
            end if;

            Print_Digit (Vacuity_Verdict_Pkg.Roll_Up (G1, G2));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         end;

      elsif Mode = "claim" then
         if Count /= 3 then
            Ada.Text_IO.Put_Line ("unknown mode or wrong argument count");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
            return;
         end if;

         declare
            Claimed   : constant Integer := To_Digit (Ada.Command_Line.Argument (2));
            Established : constant Integer := To_Digit (Ada.Command_Line.Argument (3));
         begin
            --  As above: a Grade is 0 .. 2. Outcome 3 is refused, never graded.
            if Claimed = -1 or Established = -1 or Claimed > 2 or Established > 2 then
               Ada.Text_IO.Put_Line ("bad grade digit");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
               return;
            end if;

            if Vacuity_Verdict_Pkg.Claim_Admissible (Claimed, Established) then
               Ada.Text_IO.Put_Line ("admissible");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
            else
               Ada.Text_IO.Put_Line ("refused");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;
         end;

      else
         Ada.Text_IO.Put_Line ("unknown mode or wrong argument count");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
      end if;
   end;
end Vacuity_Verdict_Main;
