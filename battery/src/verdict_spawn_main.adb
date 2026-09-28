--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 91a97b66311956bb4463f5f815aa00df81da911551a37db0d4cb33dccf9e02db
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Verdict_Reply_Pkg;

procedure Verdict_Spawn_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   use type Lovelace_Verdict_Reply_Pkg.Exit_Kind;
   use type Lovelace_Verdict_Reply_Pkg.Reply_Kind;

   --  SLOT BEGIN (scan)
   function Usage_Ok return Boolean is
   begin
      if Ada.Command_Line.Argument_Count < 2 then return False; end if;
      declare M : constant String := Ada.Command_Line.Argument (2); begin
         if M /= "worst" and then M /= "roll" and then M /= "grade" then return False; end if;
      end;
      for K in 3 .. Ada.Command_Line.Argument_Count loop
         declare D : constant String := Ada.Command_Line.Argument (K); begin
            if D /= "0" and then D /= "1" and then D /= "2" then return False; end if;
         end;
      end loop;
      return True;
   end Usage_Ok;
   function Decimal (N : Long_Long_Integer) return String is
      S : constant String := Long_Long_Integer'Image (N);
   begin
      if S (S'First) = ' ' then return S (S'First + 1 .. S'Last); else return S; end if;
   end Decimal;
   function Errno_Text (E : Integer) return String is
     (case E is when 2 => "no such file or directory", when 13 => "permission denied",
        when 20 => "not a directory", when 62 => "too many levels of symbolic links",
        when 63 => "file name too long", when others => "errno " & Decimal (Long_Long_Integer (E)));
   function Has_Slash (S : String) return Boolean is
   begin
      for C of S loop if C = '/' then return True; end if; end loop; return False;
   end Has_Slash;
   function Path_Hit (Edge : String) return String is
   begin
      if not Ada.Environment_Variables.Exists ("PATH") then return ""; end if;
      declare P : constant String := Ada.Environment_Variables.Value ("PATH"); F : Positive := P'First; begin
         for I in P'First .. P'Last + 1 loop
            if I > P'Last or else P (I) = ':' then
               declare D : constant String := P (F .. I - 1); begin
                  if D'Length > 0 and then D (D'First) = '/' and then GNAT.OS_Lib.Is_Executable_File (D & "/" & Edge)
                    and then not GNAT.OS_Lib.Is_Directory (D & "/" & Edge) then return D & "/" & Edge; end if;
               end;
               F := I + 1;
            end if;
         end loop;
      end;
      return "";
   end Path_Hit;
   function Start_Error (Edge : String) return String is
   begin
      if not Has_Slash (Edge) then
         if Path_Hit (Edge) = "" then return "exec: """ & Edge & """: executable file not found in $PATH"; end if;
         return "";
      end if;
      declare FD : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Edge, GNAT.OS_Lib.Binary); E : constant Integer := GNAT.OS_Lib.Errno; begin
         if FD = GNAT.OS_Lib.Invalid_FD then return "fork/exec " & Edge & ": " & Errno_Text (E); end if;
         GNAT.OS_Lib.Close (FD);
      end;
      if GNAT.OS_Lib.Is_Directory (Edge) or else not GNAT.OS_Lib.Is_Executable_File (Edge) then
         return "fork/exec " & Edge & ": permission denied"; end if;
      return "";
   end Start_Error;
   function Program_Path (Edge : String) return String is (if Has_Slash (Edge) then Edge else Path_Hit (Edge));
   procedure Report (Mode : String; Status : Lovelace_Verdict_Reply_Pkg.Exit_Kind; Code : Integer;
                     Start : String; Output : String) is
      Text : constant String (1 .. Output'Length) := Output;
      R : constant Lovelace_Verdict_Reply_Pkg.Reply := Lovelace_Verdict_Reply_Pkg.Reply_Of (Status, Text);
      A : constant Lovelace_Verdict_Reply_Pkg.Answer := Lovelace_Verdict_Reply_Pkg.Answer_Of (R);
      Word : constant String := Text (Lovelace_Verdict_Reply_Pkg.Word_First (Text) .. Lovelace_Verdict_Reply_Pkg.Word_Last (Text));
   begin
      Ada.Text_IO.Put_Line ("kind " & (case R.Kind is when Lovelace_Verdict_Reply_Pkg.Refused => "refused",
         when Lovelace_Verdict_Reply_Pkg.Errored => "errored", when Lovelace_Verdict_Reply_Pkg.Unreadable => "unreadable",
         when Lovelace_Verdict_Reply_Pkg.Number => "number"));
      Ada.Text_IO.Put_Line ("value " & Decimal (R.Value));
      Ada.Text_IO.Put_Line ("answer " & (if A.Answered then Decimal (Long_Long_Integer (A.Digit)) else "none"));
      Ada.Text_IO.Put_Line ("word " & (if R.Kind = Lovelace_Verdict_Reply_Pkg.Unreadable or else R.Kind = Lovelace_Verdict_Reply_Pkg.Number then Word else ""));
      Ada.Text_IO.Put_Line ("error " & (case R.Kind is
         when Lovelace_Verdict_Reply_Pkg.Refused => "edge refused: " & Word,
         when Lovelace_Verdict_Reply_Pkg.Errored => (if Status = Lovelace_Verdict_Reply_Pkg.Not_Started then "edge " & Mode & ": " & Start & " ()"
             else "edge " & Mode & ": exit status " & Decimal (Long_Long_Integer (Code)) & " (" & Word & ")"),
         when others => ""));
   end Report;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if not Usage_Ok then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "verdict-spawn: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Edge  : constant String := Ada.Command_Line.Argument (1);
      Mode  : constant String := Ada.Command_Line.Argument (2);
      Start : constant String := Start_Error (Edge);
      Args  : GNAT.OS_Lib.Argument_List (1 .. Ada.Command_Line.Argument_Count - 1);
      Code  : aliased Integer := 0;
   begin
      for K in Args'Range loop
         Args (K) := new String'(Ada.Command_Line.Argument (K + 1));
      end loop;
      if Start /= "" then
         Report (Mode, Lovelace_Verdict_Reply_Pkg.Not_Started, 0, Start, "");
      else
         declare
            Output : constant String := GNAT.Expect.Get_Command_Output
              (Command    => Program_Path (Edge),
               Arguments  => Args,
               Input      => "",
               Status     => Code'Access,
               Err_To_Out => False);
         begin
            if Output'Length > Lovelace_Verdict_Reply_Pkg.Max_Reply then
               Ada.Text_IO.Put_Line ("kind errored");
               Ada.Text_IO.Put_Line ("value 0");
               Ada.Text_IO.Put_Line ("answer none");
               Ada.Text_IO.Put_Line ("word ");
               Ada.Text_IO.Put_Line ("error edge " & Mode & ": reply over 4096 bytes");
            elsif Code = 0 then
               Report (Mode, Lovelace_Verdict_Reply_Pkg.Exit_Ok, Code, "", Output);
            elsif Code = 2 then
               Report (Mode, Lovelace_Verdict_Reply_Pkg.Exit_Two, Code, "", Output);
            else
               Report (Mode, Lovelace_Verdict_Reply_Pkg.Exit_Other, Code, "", Output);
            end if;
         end;
      end if;
      for K in Args'Range loop
         GNAT.OS_Lib.Free (Args (K));
      end loop;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
   --  SLOT END (main)
end Verdict_Spawn_Main;
