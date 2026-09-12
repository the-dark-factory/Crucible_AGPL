with Ada.Text_IO;
with Audit_Ledger_Pkg;
with Reply_Text_Pkg;
procedure Audit_Sink_Main is
   Started_Mark : constant String := "S";
   Full_Mark    : constant String := "F ";
   Sealed_Mark  : constant String := "Z";
   Sep          : constant Character := ' ';
   Channel_Size : constant := 256;

   use type Audit_Ledger_Pkg.Activity_Kind;

   type Event_Ring is array (1 .. Channel_Size) of Audit_Ledger_Pkg.Event;

   protected Events is
      procedure Put (E : Audit_Ledger_Pkg.Event; Accepted : out Boolean);
      entry Take (E : out Audit_Ledger_Pkg.Event; Done : out Boolean);
      procedure Close;
   private
      Buffer : Event_Ring;
      Head, Tail, Fill : Natural := 0;
      Closed : Boolean := False;
   end Events;

   protected body Events is
      procedure Put (E : Audit_Ledger_Pkg.Event; Accepted : out Boolean) is
      begin
         if (Fill = Channel_Size) then
            Accepted := False;
         else
            Tail := Tail + 1;
            if (Tail > Channel_Size) then
               Tail := 1;
            end if;
            Buffer (Tail) := E;
            Fill := Fill + 1;
            Accepted := True;
         end if;
      end Put;

      entry Take (E : out Audit_Ledger_Pkg.Event; Done : out Boolean) when (Fill > 0 or else Closed) is
      begin
         if (Fill = 0 and Closed) then
            Done := True;
         else
            Head := Head + 1;
            if (Head > Channel_Size) then
               Head := 1;
            end if;
            E := Buffer (Head);
            Fill := Fill - 1;
            Done := False;
         end if;
      end Take;

      procedure Close is
      begin
         Closed := True;
      end Close;
   end Events;

   task Sink;

   task body Sink is
      L : Audit_Ledger_Pkg.Ledger := (Entries => (others => (Source => Audit_Ledger_Pkg.Audit_Sink, Code => 0)), Count => 0, Full => False);
      E : Audit_Ledger_Pkg.Event;
      Done : Boolean;
   begin
      L := Audit_Ledger_Pkg.Appended (L, (Source => Audit_Ledger_Pkg.Audit_Sink, Code => Audit_Ledger_Pkg.Sink_Started));
      Ada.Text_IO.Put_Line (Started_Mark);
      loop
         Events.Take (E, Done);
         exit when Done;
         L := Audit_Ledger_Pkg.Appended (L, E);
      end loop;
      L := Audit_Ledger_Pkg.Appended (L, (Source => Audit_Ledger_Pkg.Audit_Sink, Code => Audit_Ledger_Pkg.Ledger_Sealed));
      for I in 1 .. L.Count loop
         Ada.Text_IO.Put_Line (Reply_Text_Pkg.Image_Of (Audit_Ledger_Pkg.Activity_Kind'Pos (L.Entries (I).Source))
                              & Sep & Reply_Text_Pkg.Image_Of (L.Entries (I).Code));
      end loop;
      Ada.Text_IO.Put_Line (Full_Mark & Reply_Text_Pkg.Image_Of (Boolean'Pos (L.Full)) & Sep & Reply_Text_Pkg.Image_Of (L.Count));
      Ada.Text_IO.Put_Line (Sealed_Mark);
      Ada.Text_IO.Flush;
   end Sink;

begin
   declare
      Buffer : String (1 .. 256);
      Last   : Natural;
   begin
      while not Ada.Text_IO.End_Of_File loop
         Ada.Text_IO.Get_Line (Buffer, Last);
         declare
            Space_Index : Natural := 0;
         begin
            for I in Buffer'Range loop
               if Buffer (I) = Sep then
                  Space_Index := I;
                  exit;
               end if;
            end loop;
            if Space_Index = 0 then
               return;
            end if;
            declare
               Src_Val : constant Natural := Natural'Value (Buffer (1 .. Space_Index - 1));
               Code_Val : constant Natural := Natural'Value (Buffer (Space_Index + 1 .. Last));
               E : Audit_Ledger_Pkg.Event := (Source => Audit_Ledger_Pkg.Activity_Kind'Val (Src_Val), Code => Code_Val);
               Accepted : Boolean;
            begin
               Events.Put (E, Accepted);
               while not Accepted loop
                  delay 0.001;
                  Events.Put (E, Accepted);
               end loop;
            end;
         end;
      end loop;
      Events.Close;
   end;
end Audit_Sink_Main;
