with Ada.Text_IO;
with Ada.Streams;
with GNAT.Sockets;
with Reply_Text_Pkg;
with Model_Request_Pkg;

procedure Model_Caller_Main is
   use type Ada.Streams.Stream_Element_Offset;

   Request_Line  : constant String := "POST /api/generate HTTP/1.1";
   Host_Header   : constant String := "Host: ";
   Type_Header   : constant String := "Content-Type: application/json";
   Length_Header : constant String := "Content-Length: ";
   Close_Header  : constant String := "Connection: close";
   CRLF          : constant String := ASCII.CR & ASCII.LF;
   Max_Reply     : constant := 16384;
   Timeout_Seconds : constant Duration := 600.0;

   H_Buf  : String (1 .. 4096);
   P_Buf  : String (1 .. 4096);
   M_Buf  : String (1 .. 4096);
   R_Buf  : String (1 .. 4096);
   H_Last : Natural;
   P_Last : Natural;
   M_Last : Natural;
   R_Last : Natural;

   Reached     : Boolean := False;
   Timed_Out   : Boolean := False;
   Body_Length : Natural := 0;

begin
   Ada.Text_IO.Get_Line (H_Buf, H_Last);
   Ada.Text_IO.Get_Line (P_Buf, P_Last);
   Ada.Text_IO.Get_Line (M_Buf, M_Last);
   Ada.Text_IO.Get_Line (R_Buf, R_Last);

   declare
      Host      : constant String := H_Buf (1 .. H_Last);
      Port_Text : constant String := P_Buf (1 .. P_Last);
      Model     : constant String := M_Buf (1 .. M_Last);
      Prompt    : constant String := R_Buf (1 .. R_Last);
      Body_Text : constant String := Model_Request_Pkg.Request_Text (Model, Prompt);
      Port      : constant GNAT.Sockets.Port_Type :=
        GNAT.Sockets.Port_Type (Natural'Value (Port_Text));

      Request   : constant String :=
        Request_Line & CRLF & Host_Header & Host & CRLF & Type_Header & CRLF &
        Length_Header & Reply_Text_Pkg.Image_Of (Body_Text'Length) & CRLF &
        Close_Header & CRLF & CRLF & Body_Text;

      Out_Bytes : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Request'Length));

      Socket    : GNAT.Sockets.Socket_Type;
      Sent_Last : Ada.Streams.Stream_Element_Offset;
      Chunk     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Got_Last  : Ada.Streams.Stream_Element_Offset;
      Reply     : String (1 .. Max_Reply + 4096);
      Reply_Last : Natural := 0;

   begin
      for I in Request'Range loop
         Out_Bytes (Ada.Streams.Stream_Element_Offset (I)) :=
           Ada.Streams.Stream_Element (Character'Pos (Request (I)));
      end loop;

      GNAT.Sockets.Create_Socket (Socket);
      GNAT.Sockets.Set_Socket_Option
        (Socket,
         GNAT.Sockets.Socket_Level,
         (GNAT.Sockets.Receive_Timeout, Timeout_Seconds));

      begin
         GNAT.Sockets.Connect_Socket
           (Socket,
            (Family => GNAT.Sockets.Family_Inet,
             Addr   => GNAT.Sockets.Inet_Addr (Host),
             Port   => Port));
         Reached := True;
      exception
         when GNAT.Sockets.Socket_Error =>
            null;
      end;

      if Reached then
         GNAT.Sockets.Send_Socket (Socket, Out_Bytes, Sent_Last);

         begin
            loop
               GNAT.Sockets.Receive_Socket (Socket, Chunk, Got_Last);
               exit when Got_Last < Chunk'First;
               exit when Reply_Last + Natural (Got_Last - Chunk'First + 1) > Reply'Length;
               for K in Chunk'First .. Got_Last loop
                  Reply_Last := Reply_Last + 1;
                  Reply (Reply_Last) := Character'Val (Chunk (K));
               end loop;
            end loop;
         exception
            when GNAT.Sockets.Socket_Error =>
               Timed_Out := True;
         end;

         declare
            Blank : constant String := CRLF & CRLF;
            Start_Index : Natural := 0;
         begin
            for J in Reply'First .. Reply_Last - Blank'Length + 1 loop
               if Reply (J .. J + Blank'Length - 1) = Blank then
                  Start_Index := J + Blank'Length;
                  exit;
               end if;
            end loop;
            if Start_Index > 0 and then Start_Index <= Reply_Last then
               Body_Length := Reply_Last - Start_Index + 1;
            end if;
         end;

         GNAT.Sockets.Close_Socket (Socket);
      end if;

      Ada.Text_IO.Put_Line
        (Reply_Text_Pkg.Image_Of
           (Model_Request_Pkg.Fault_Kind'Pos
              (Model_Request_Pkg.Reply_Fault (Reached, Timed_Out, Body_Length))));

      if Reached and then not Timed_Out and then Body_Length > 0 then
         declare
            Blank : constant String := CRLF & CRLF;
            Start_Index : Natural := 0;
         begin
            for J in Reply'First .. Reply_Last - Blank'Length + 1 loop
               if Reply (J .. J + Blank'Length - 1) = Blank then
                  Start_Index := J + Blank'Length;
                  exit;
               end if;
            end loop;
            if Start_Index > 0 and then Start_Index <= Reply_Last then
               Ada.Text_IO.Put (Reply (Start_Index .. Reply_Last));
            end if;
         end;
      end if;

      Ada.Text_IO.Flush;
   end;
end Model_Caller_Main;
