--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a9563ba5e94f2308266d5e483ea859b06abe9c06afc075925b233b4640a8c321
--
with Ada.Command_Line;
with Ada.Text_IO;
with Reciprocity_Pkg;

procedure Reciprocity_Decider is
   use Ada.Command_Line;
   Held, Sent : Natural;
begin
   if Argument_Count /= 3 or else Argument (1) /= "may-pull" then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: reciprocity_decider may-pull <held> <sent>");
      Set_Exit_Status (2);
      return;
   end if;

   Held := Natural'Value (Argument (2));
   Sent := Natural'Value (Argument (3));

   declare
      V : constant Reciprocity_Pkg.Verdict := Reciprocity_Pkg.Reason (Held, Sent);
   begin
      case V is
         when Reciprocity_Pkg.Pulls_Freely    => Ada.Text_IO.Put_Line ("pulls_freely");
         when Reciprocity_Pkg.Reciprocity_Met => Ada.Text_IO.Put_Line ("reciprocity_met");
         when Reciprocity_Pkg.Refused_Owes    => Ada.Text_IO.Put_Line ("refused_owes");
      end case;
      if Reciprocity_Pkg.May_Pull (Held, Sent) then
         Set_Exit_Status (0);
      else
         Set_Exit_Status (1);
      end if;
   end;
exception
   when Constraint_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "reciprocity_decider: held and sent must be non-negative integers");
      Set_Exit_Status (2);
end Reciprocity_Decider;
