with Ada.Text_IO;
with GNAT.OS_Lib;
with GNAT.Expect;
with Json_Scan_Pkg;
with Reply_Text_Pkg;
with Door_Responder_Pkg;

procedure Expand_Brief_Main is
   use type GNAT.Expect.Expect_Match;
   use type Json_Scan_Pkg.Kind_Type;

   Config_Path   : constant String := "config/rail.conf";
   Front_Path    : constant String := "bin/expand_front";
   Caller_Path   : constant String := "bin/model_caller_main";
   Back_Path     : constant String := "bin/expand_back";
   Host_Key      : constant String := "host";
   Port_Key      : constant String := "port";
   Model_Key     : constant String := "model";
   Sovereign_Key : constant String := "sovereign";
   Lit_True      : constant String := "true";
   Null_Id       : constant String := "null";
   Sov_On        : constant String := "1";
   Sov_Off       : constant String := "0";
   Msg_Config    : constant String := "rail config unreadable";
   Msg_Stage     : constant String := "stage could not run";
   Msg_Timeout   : constant String := "stage timed out";
   Prompt_Mark   : constant Character := 'P';
   LF            : constant Character := ASCII.LF;
   Line_End      : constant String := "[^[:space:]]*[[:space:]]+";
   Max_Text      : constant := 131072;
   Front_Ms      : constant Integer := 20_000;
   Caller_Ms     : constant Integer := 700_000;
   Back_Ms       : constant Integer := 20_000;

   procedure Run_Stage (Command : String; Input : String; Timeout_Ms : Integer;
                        Output : out String; Output_Last : out Natural;
                        Timed_Out : out Boolean; Failed : out Boolean) is
      Pd     : GNAT.Expect.Process_Descriptor;
      Args   : GNAT.OS_Lib.Argument_List (1 .. 0);
      Result : GNAT.Expect.Expect_Match;
   begin
      Output_Last := 0;
      Timed_Out := False;
      Failed := False;
      GNAT.Expect.Non_Blocking_Spawn (Pd, Command, Args, Buffer_Size => Max_Text, Err_To_Out => False);
      GNAT.Expect.Send (Pd, Input, Add_LF => False);
      loop
         GNAT.Expect.Expect (Pd, Result, Line_End, Timeout_Ms);
         if Result = GNAT.Expect.Expect_Timeout then
            Timed_Out := True;
            exit;
         end if;
         declare
            Chunk : constant String := GNAT.Expect.Expect_Out (Pd);
         begin
            for K in Chunk'Range loop
               if Output_Last < Output'Last then
                  Output_Last := Output_Last + 1;
                  Output (Output_Last) := Chunk (K);
               end if;
            end loop;
         end;
      end loop;
      GNAT.Expect.Close (Pd);
   exception
      when GNAT.Expect.Process_Died =>
         GNAT.Expect.Close (Pd);
      when GNAT.Expect.Invalid_Process =>
         Failed := True;
   end Run_Stage;

   function Nth_Line (S : String; N : Positive) return String is
      Line_Nth  : Positive := 1;
      Start_Nth : Positive := S'First;
   begin
      for J in S'Range loop
         if S (J) = LF then
            if Line_Nth = N then
               return S (Start_Nth .. J - 1);
            end if;
            Line_Nth := Line_Nth + 1;
            Start_Nth := J + 1;
         end if;
      end loop;
      if Line_Nth = N and then Start_Nth <= S'Last then
         return S (Start_Nth .. S'Last);
      else
         return "";
      end if;
   end Nth_Line;

   function After_First_Line (S : String) return String is
      Buf : String (1 .. Max_Text);
      Last : Natural := 0;
      Passed : Boolean := False;
   begin
      for J in S'Range loop
         if Passed then
            if S (J) /= LF then
               if Last < Buf'Last then
                  Last := Last + 1;
                  Buf (Last) := S (J);
               end if;
            end if;
         else
            if S (J) = LF then
               Passed := True;
            end if;
         end if;
      end loop;
      return Buf (1 .. Last);
   end After_First_Line;

   Line_Buf  : String (1 .. 65536);
   Line_Last : Natural;
   Conf_Buf  : String (1 .. 4096);
   Conf_Last : Natural;

begin
   Ada.Text_IO.Get_Line (Line_Buf, Line_Last);
   begin
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Config_Path);
         Ada.Text_IO.Get_Line (F, Conf_Buf, Conf_Last);
         Ada.Text_IO.Close (F);
      end;
   exception
      when others =>
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Null_Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Config));
         Ada.Text_IO.Flush;
         return;
   end;
   declare
      Conf : constant String := Conf_Buf (1 .. Conf_Last);
      H    : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Conf, Host_Key);
      P    : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Conf, Port_Key);
      M    : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Conf, Model_Key);
      V    : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Conf, Sovereign_Key);
   begin
      if not H.found or else H.kind /= Json_Scan_Pkg.K_String or else H.first >= H.last
        or else not P.found or else P.kind /= Json_Scan_Pkg.K_String or else P.first >= P.last
        or else not M.found or else M.kind /= Json_Scan_Pkg.K_String or else M.first >= M.last
      then
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Null_Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Config));
         Ada.Text_IO.Flush;
         return;
      end if;
      declare
         Host  : constant String := Conf (H.first + 1 .. H.last - 1);
         Port  : constant String := Conf (P.first + 1 .. P.last - 1);
         Model : constant String := Conf (M.first + 1 .. M.last - 1);
         Sov   : constant String :=
           (if V.found and then V.kind = Json_Scan_Pkg.K_Bare and then Json_Scan_Pkg.Equals_Literal (Conf, V, Lit_True)
            then Sov_On else Sov_Off);
      begin
         declare
            Out_Text  : String (1 .. Max_Text);
            Out_Last  : Natural;
            Timed_Out : Boolean;
            Failed    : Boolean;
            Line      : constant String := Line_Buf (1 .. Line_Last);
         begin
            Run_Stage (Front_Path, Host & LF & Port & LF & Sov & LF & Line & LF, Front_Ms, Out_Text, Out_Last, Timed_Out, Failed);

            if Failed then
               Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Null_Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Stage));
               Ada.Text_IO.Flush;
               return;
            end if;

            if Timed_Out then
               Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Null_Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Timeout));
               Ada.Text_IO.Flush;
               return;
            end if;

            declare
               First : constant String := Nth_Line (Out_Text (1 .. Out_Last), 1);
            begin
               if First'Length = 0 or else First (First'First) /= Prompt_Mark then
                  Ada.Text_IO.Put_Line (Nth_Line (Out_Text (1 .. Out_Last), 2));
                  Ada.Text_IO.Flush;
                  return;
               end if;

               declare
                  Id     : constant String := Nth_Line (Out_Text (1 .. Out_Last), 2);
                  Prompt : constant String := Nth_Line (Out_Text (1 .. Out_Last), 3);
               begin
                  Run_Stage (Caller_Path, Host & LF & Port & LF & Model & LF & Prompt & LF, Caller_Ms, Out_Text, Out_Last, Timed_Out, Failed);

                  if Failed then
                     Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Stage));
                     Ada.Text_IO.Flush;
                     return;
                  end if;

                  if Timed_Out then
                     Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Timeout));
                     Ada.Text_IO.Flush;
                     return;
                  end if;

                  declare
                     Fault : constant String := Nth_Line (Out_Text (1 .. Out_Last), 1);
                     Reply_Body  : constant String := After_First_Line (Out_Text (1 .. Out_Last));
                  begin
                     Run_Stage (Back_Path, Id & LF & Fault & LF & Reply_Body & LF, Back_Ms, Out_Text, Out_Last, Timed_Out, Failed);

                     if Failed then
                        Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Stage));
                        Ada.Text_IO.Flush;
                        return;
                     end if;

                     if Timed_Out then
                        Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Timeout));
                        Ada.Text_IO.Flush;
                        return;
                     end if;

                     Ada.Text_IO.Put_Line (Nth_Line (Out_Text (1 .. Out_Last), 1));
                     Ada.Text_IO.Flush;
                  end;
               end;
            end;
         end;
      end;
   end;
end Expand_Brief_Main;
