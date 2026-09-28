--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 192fa8160943b6f5f130bfcae8787ed75f9f7e6c516d4bef91b5b13997e97b27
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Indefinite_Ordered_Maps;
with GNAT.OS_Lib;
with Lovelace_Message_Rules_Pkg;
with Lovelace_Run_Config_Pkg;

procedure Prover_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   use type GNAT.OS_Lib.String_Access;
   use type Lovelace_Message_Rules_Pkg.Fault_Kind;
   use type Lovelace_Message_Rules_Pkg.Level_Kind;

   --  CLI contract:
   --    prover_main <variant-file> <package> <tag> [<deps-dir> [<carried-name>...]]
   --  prints, exit 0:
   --    reached true|false
   --    fault <text, or nothing after the space>
   --    msg <line> <level> <text>   (each kept message, in output order)
   --    eg <line> <text>            (each stored example, by ascending line)
   --  usage or an unreadable variant: one line on standard error, exit 2.

   package U renames Ada.Strings.Unbounded;
   package M renames Lovelace_Message_Rules_Pkg;

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);
   package Example_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => Positive, Element_Type => String);

   Max_Variant : constant := 1_048_576;
   Max_Output  : constant := 4_194_304;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   FF : constant Character := Character'Val (12);
   CR : constant Character := Character'Val (13);

   function Decimal (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Decimal;

   function Is_Re_Space (C : Character) return Boolean is
     (C = ' ' or else C = HT or else C = LF or else C = FF or else C = CR);

   function Lower (S : String) return String is
      R : String (1 .. S'Length) := S;
   begin
      for I in R'Range loop
         if R (I) in 'A' .. 'Z' then
            R (I) := Character'Val (Character'Pos (R (I)) + 32);
         end if;
      end loop;
      return R;
   end Lower;

   function Errno_Text (E : Integer) return String is
   begin
      case E is
         when 2 => return "no such file or directory";
         when 13 => return "permission denied";
         when 20 => return "not a directory";
         when others => return "errno " & Decimal (E);
      end case;
   end Errno_Text;

   --  Read a whole file. Ok is False when it cannot be opened or read, or holds more than Max bytes.
   procedure Read_File (Path : String; Max : Natural; Data : out U.Unbounded_String;
                        Ok : out Boolean; Err : out Integer) is
      FD : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Data := U.Null_Unbounded_String;
      Ok := False;
      Err := 0;
      if FD = GNAT.OS_Lib.Invalid_FD then
         Err := GNAT.OS_Lib.Errno;
         return;
      end if;
      if GNAT.OS_Lib.File_Length (FD) > Long_Integer (Max) then
         GNAT.OS_Lib.Close (FD);
         return;
      end if;
      declare
         Buf : String (1 .. Natural (GNAT.OS_Lib.File_Length (FD)));
         N   : Integer := 0;
      begin
         if Buf'Length > 0 then
            N := GNAT.OS_Lib.Read (FD, Buf (1)'Address, Buf'Length);
         end if;
         GNAT.OS_Lib.Close (FD);
         if N = Buf'Length then
            Data := U.To_Unbounded_String (Buf);
            Ok := True;
         end if;
      end;
   end Read_File;

   --  Write Data to Path (created, or truncated). Ok is False on any failure.
   procedure Write_File (Path : String; Data : String; Ok : out Boolean) is
      FD : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
      N  : Integer := 0;
   begin
      Ok := False;
      if FD = GNAT.OS_Lib.Invalid_FD then
         return;
      end if;
      if Data'Length > 0 then
         N := GNAT.OS_Lib.Write (FD, Data (Data'First)'Address, Data'Length);
      end if;
      GNAT.OS_Lib.Close (FD);
      Ok := N = Data'Length;
   end Write_File;

   --  VACUITY_DUMP: <dump>/<nnn>-<tag>.ads, nnn the number of *.ads already there (at least 3 digits).
   procedure Dump_Variant (Tag : String; Text : String) is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Count  : Natural := 0;
      Ok     : Boolean;
   begin
      if not Ada.Environment_Variables.Exists ("VACUITY_DUMP") then
         return;
      end if;
      declare
         Dump : constant String := Ada.Environment_Variables.Value ("VACUITY_DUMP");
      begin
         if Dump = "" then
            return;
         end if;
         if not GNAT.OS_Lib.Is_Directory (Dump) then
            Ada.Directories.Create_Path (Dump);
         end if;
         Ada.Directories.Start_Search (Search, Dump, "");
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
            begin
               if Name'Length >= 4 and then Name (Name'Last - 3 .. Name'Last) = ".ads" then
                  Count := Count + 1;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         declare
            D   : constant String := Decimal (Count);
            Pad : constant String := (if D'Length = 1 then "00" elsif D'Length = 2 then "0" else "");
         begin
            Write_File (Dump & "/" & Pad & D & "-" & Tag & ".ads", Text, Ok);
         end;
      end;
   end Dump_Variant;

   --  One output line, as Go's reMsg sees it. Is_Msg is False when it does not match.
   procedure Parse_Message (L : String; Is_Msg : out Boolean; File_Last : out Natural;
                            Line_First : out Positive; Line_Last : out Natural;
                            Level : out M.Level_Kind; Text_First : out Positive) is
      I : Natural := 0;
      J : Natural;
   begin
      Is_Msg := False;
      File_Last := 0;
      Line_First := 1;
      Line_Last := 0;
      Level := M.Info_Level;
      Text_First := 1;
      for K in L'Range loop
         if L (K) = ':' then
            I := K;
            exit;
         end if;
      end loop;
      if I = 0 or else I - L'First < 5 then
         return;
      end if;
      if L (I - 4 .. I - 1) /= ".ads" and then L (I - 4 .. I - 1) /= ".adb" then
         return;
      end if;
      File_Last := I - 1;
      J := I + 1;
      Line_First := J;
      while J <= L'Last and then L (J) in '0' .. '9' loop
         J := J + 1;
      end loop;
      if J = Line_First or else J > L'Last or else L (J) /= ':' then
         return;
      end if;
      Line_Last := J - 1;
      J := J + 1;
      declare
         Col_First : constant Positive := J;
      begin
         while J <= L'Last and then L (J) in '0' .. '9' loop
            J := J + 1;
         end loop;
         if J = Col_First or else J > L'Last or else L (J) /= ':' then
            return;
         end if;
      end;
      J := J + 1;
      if J > L'Last or else not Is_Re_Space (L (J)) then
         return;
      end if;
      while J <= L'Last and then Is_Re_Space (L (J)) loop
         J := J + 1;
      end loop;
      declare
         function Word_Is (W : String) return Boolean is
           (W'Length + 1 <= L'Last - J + 1 and then L (J .. J + W'Length - 1) = W
            and then L (J + W'Length) = ':');
         Word_Len : Natural := 0;
      begin
         if Word_Is ("info") then
            Level := M.Info_Level;
            Word_Len := 4;
         elsif Word_Is ("medium") then
            Level := M.Medium_Level;
            Word_Len := 6;
         elsif Word_Is ("high") then
            Level := M.High_Level;
            Word_Len := 4;
         elsif Word_Is ("low") then
            Level := M.Low_Level;
            Word_Len := 3;
         elsif Word_Is ("warning") then
            Level := M.Warning_Level;
            Word_Len := 7;
         elsif Word_Is ("error") then
            Level := M.Error_Level;
            Word_Len := 5;
         else
            return;
         end if;
         J := J + Word_Len + 1;
      end;
      if J > L'Last or else not Is_Re_Space (L (J)) then
         return;
      end if;
      while J <= L'Last and then Is_Re_Space (L (J)) loop
         J := J + 1;
      end loop;
      Text_First := J;
      Is_Msg := True;
   end Parse_Message;

   --  Go's reEg: optional spaces, then "e.g. when ", then the example. Start is 0 when not an example line.
   function Example_Start (L : String) return Natural is
      Lead : constant String := "e.g. when ";
      J    : Natural := L'First;
   begin
      while J <= L'Last and then Is_Re_Space (L (J)) loop
         J := J + 1;
      end loop;
      if Lead'Length <= L'Last - J + 1 and then L (J .. J + Lead'Length - 1) = Lead then
         return J + Lead'Length;
      end if;
      return 0;
   end Example_Start;

   function Contains (S : String; P : String) return Boolean is
   begin
      if P'Length > S'Length then
         return False;
      end if;
      for K in S'First .. S'Last - P'Length + 1 loop
         if S (K .. K + P'Length - 1) = P then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Base_Name (F : String) return String is
   begin
      for K in reverse F'Range loop
         if F (K) = '/' then
            return F (K + 1 .. F'Last);
         end if;
      end loop;
      return F;
   end Base_Name;

   function Level_Word (L : M.Level_Kind) return String is
   begin
      case L is
         when M.Info_Level => return "info";
         when M.Medium_Level => return "medium";
         when M.High_Level => return "high";
         when M.Low_Level => return "low";
         when M.Warning_Level => return "warning";
         when M.Error_Level => return "error";
      end case;
   end Level_Word;

   procedure Print_Result (Reached : Boolean; Fault : String;
                           Msgs : Line_Vectors.Vector; Egs : Example_Maps.Map) is
   begin
      Ada.Text_IO.Put_Line ("reached " & (if Reached and then Fault = "" then "true" else "false"));
      Ada.Text_IO.Put_Line ("fault " & Fault);
      for S of Msgs loop
         Ada.Text_IO.Put_Line (S);
      end loop;
      for C in Egs.Iterate loop
         Ada.Text_IO.Put_Line ("eg " & Decimal (Example_Maps.Key (C)) & " " & Example_Maps.Element (C));
      end loop;
   end Print_Result;

   Msgs : Line_Vectors.Vector;
   Egs  : Example_Maps.Map;

begin
   if Ada.Command_Line.Argument_Count < 3
     or else Ada.Command_Line.Argument (2)'Length = 0
     or else Ada.Command_Line.Argument (2)'Length > 1_024
   then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "prover: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Package_Name : constant String := Ada.Command_Line.Argument (2);
      Tag          : constant String := Ada.Command_Line.Argument (3);
      Deps         : constant String :=
        (if Ada.Command_Line.Argument_Count >= 4 then Ada.Command_Line.Argument (4) else "");
      Unit         : constant String := Lower (Package_Name) & ".ads";
      Variant      : U.Unbounded_String;
      Ok           : Boolean;
      Err          : Integer;
   begin
      Read_File (Ada.Command_Line.Argument (1), Max_Variant, Variant, Ok, Err);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "prover: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      declare
         Tmp : constant String :=
           (if Ada.Environment_Variables.Exists ("TMPDIR")
              and then Ada.Environment_Variables.Value ("TMPDIR") /= ""
            then Ada.Environment_Variables.Value ("TMPDIR") else "/tmp");
         Pid : constant String := Decimal (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
         K   : Positive := 1;
      begin
         if not GNAT.OS_Lib.Is_Directory (Tmp) then
            Print_Result (False, "mkdtemp: no temp directory", Msgs, Egs);
            Ada.Command_Line.Set_Exit_Status (0);
            return;
         end if;
         while GNAT.OS_Lib.Is_Directory (Tmp & "/vacuity-" & Pid & "-" & Decimal (K))
           or else GNAT.OS_Lib.Is_Regular_File (Tmp & "/vacuity-" & Pid & "-" & Decimal (K))
         loop
            K := K + 1;
         end loop;
         declare
            Dir      : constant String := Tmp & "/vacuity-" & Pid & "-" & Decimal (K);
            Out_Name : constant String := Dir & ".out";
            Fault    : U.Unbounded_String;
            Program  : GNAT.OS_Lib.String_Access;
            Success  : Boolean := False;
            Code     : Integer := 0;
            Old_Dir  : constant String := Ada.Directories.Current_Directory;
            Output   : U.Unbounded_String;
            State    : M.Scan_State := M.Initial_State;
            Error_Seen : Boolean := False;
            Error_Line : Natural := 0;
            Error_Text : U.Unbounded_String;
            Deleted  : Boolean;
         begin
            Ada.Directories.Create_Directory (Dir);
            Write_File (Dir & "/" & Unit, U.To_String (Variant), Ok);
            if not Ok then
               Fault := U.To_Unbounded_String ("write spec: cannot write " & Dir & "/" & Unit);
            end if;
            if U.Length (Fault) = 0 and then Deps /= "" then
               for A in 5 .. Ada.Command_Line.Argument_Count loop
                  declare
                     Name : constant String := Ada.Command_Line.Argument (A);
                     Data : U.Unbounded_String;
                  begin
                     if U.Length (Fault) = 0 then
                        Read_File (Deps & "/" & Name, Max_Output, Data, Ok, Err);
                        if not Ok then
                           Fault := U.To_Unbounded_String
                             ("stage deps: open " & Deps & "/" & Name & ": " & Errno_Text (Err));
                        else
                           Write_File (Dir & "/" & Name, U.To_String (Data), Ok);
                           GNAT.OS_Lib.Set_Read_Only (Dir & "/" & Name);
                        end if;
                     end if;
                  end;
               end loop;
            end if;
            if U.Length (Fault) = 0 then
               Dump_Variant (Tag, U.To_String (Variant));
               Write_File (Dir & "/check.gpr",
                           "project Check is" & LF
                           & "   for Source_Dirs use (""."");" & LF
                           & "   for Object_Dir use ""obj"";" & LF
                           & "end Check;" & LF, Ok);
               Program := GNAT.OS_Lib.Locate_Exec_On_Path ("gnatprove");
               if Program = null then
                  Fault := U.To_Unbounded_String
                    ("gnatprove: exec: ""gnatprove"": executable file not found in $PATH");
               end if;
            end if;
            if U.Length (Fault) = 0 then
               declare
                  Args : GNAT.OS_Lib.Argument_List (1 .. 10) :=
                    (new String'("-P"), new String'("check.gpr"),
                     new String'("--level=" & Decimal (Lovelace_Run_Config_Pkg.Level)),
                     new String'("-j1"),
                     new String'("--steps=" & Decimal (Lovelace_Run_Config_Pkg.Steps)),
                     new String'("--report=all"), new String'("--counterexamples=on"),
                     new String'("-f"), new String'("-u"), new String'(Unit));
               begin
                  Ada.Directories.Set_Directory (Dir);
                  GNAT.OS_Lib.Spawn (Program.all, Args, Out_Name, Success, Code, Err_To_Out => True);
                  Ada.Directories.Set_Directory (Old_Dir);
                  for A of Args loop
                     GNAT.OS_Lib.Free (A);
                  end loop;
                  GNAT.OS_Lib.Free (Program);
               end;
               if not Success then
                  Fault := U.To_Unbounded_String ("gnatprove: could not be started");
               else
                  Read_File (Out_Name, Max_Output, Output, Ok, Err);
                  if not Ok then
                     Fault := U.To_Unbounded_String ("gnatprove output over 4194304 bytes");
                  end if;
               end if;
               GNAT.OS_Lib.Delete_File (Out_Name, Deleted);
            end if;
            if U.Length (Fault) = 0 then
               declare
                  O     : constant String := U.To_String (Output);
                  First : Positive := 1;
                  procedure Handle (Raw : String) is
                     L      : constant String :=
                       (if Raw'Length > 0 and then Raw (Raw'Last) = CR then Raw (Raw'First .. Raw'Last - 1) else Raw);
                     Is_Msg : Boolean;
                     F_Last, L_Last : Natural;
                     L_First, T_First : Positive;
                     Level  : M.Level_Kind;
                     Facts  : M.Line_Facts;
                     Target : Natural;
                     Ex     : Natural;
                  begin
                     if U.Length (Fault) /= 0 then
                        return;
                     end if;
                     Parse_Message (L, Is_Msg, F_Last, L_First, L_Last, Level, T_First);
                     if Is_Msg then
                        declare
                           Base : constant String := Base_Name (L (L'First .. F_Last));
                           Own  : constant Boolean :=
                             Base'Length <= 4_096 and then M.Is_Own_File (Base, Package_Name);
                           Line_No : Natural := 0;
                        begin
                           if Own then
                              if L_Last - L_First + 1 > 9 then
                                 Fault := U.To_Unbounded_String ("gnatprove line number out of range");
                                 return;
                              end if;
                              if L'Last - T_First + 1 > 1_048_576 then
                                 Fault := U.To_Unbounded_String ("gnatprove message over 1048576 bytes");
                                 return;
                              end if;
                              Line_No := Natural'Value (L (L_First .. L_Last));
                           end if;
                           Facts := (Class => M.Message_Line, Own => Own, Line => Line_No, Has_Summary => False);
                           if M.Keep_Message (Facts) then
                              Msgs.Append ("msg " & Decimal (Line_No) & " " & Level_Word (Level) & " "
                                           & L (T_First .. L'Last));
                              if Level = M.Error_Level and then not Error_Seen then
                                 Error_Seen := True;
                                 Error_Line := Line_No;
                                 Error_Text := U.To_Unbounded_String (L (T_First .. L'Last));
                              end if;
                           end if;
                        end;
                     else
                        Ex := Example_Start (L);
                        Facts := (Class => (if Ex > 0 then M.Example_Line else M.Other_Line),
                                  Own => False, Line => 0,
                                  Has_Summary => Contains (L, "Summary logged in"));
                        Target := M.Example_Target (State, Facts);
                        if Target > 0 then
                           Egs.Include (Target, L (Ex .. L'Last));
                        end if;
                     end if;
                     State := M.Next_State (State, Facts);
                  end Handle;
               begin
                  for I in O'Range loop
                     if O (I) = LF then
                        Handle (O (First .. I - 1));
                        First := I + 1;
                     end if;
                  end loop;
                  if First <= O'Last then
                     Handle (O (First .. O'Last));
                  end if;
               end;
            end if;
            if U.Length (Fault) = 0 then
               case M.Fault_Of (Error_Seen, Code /= 0, State.Summary_Seen) is
                  when M.Error_Message_Fault =>
                     Fault := U.To_Unbounded_String
                       ("gnatprove reported an error: " & U.To_String (Error_Text)
                        & " (line " & Decimal (Error_Line) & ")");
                  when M.Failed_Run_Fault =>
                     Fault := U.To_Unbounded_String ("gnatprove: exit status " & Decimal (Code));
                  when M.No_Fault =>
                     null;
               end case;
            end if;
            if GNAT.OS_Lib.Is_Directory (Dir) then
               Ada.Directories.Delete_Tree (Dir);
            end if;
            Print_Result (M.Reached_Of (State.Summary_Seen, Error_Seen), U.To_String (Fault), Msgs, Egs);
         end;
      end;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
end Prover_Main;
