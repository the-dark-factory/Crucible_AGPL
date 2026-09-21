--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: ef59069606b82a19f132d2ed855cc7be6c4de8e01c0991559f81f981b4bf175c
--
with Json_Scan_Pkg;
with Hex_Text_Pkg;
with Tower_Stamp_Pkg;
with Tower_Payload_Pkg;
with Tower_Admission_Pkg;

package Tower_Index_Pkg with SPARK_Mode is
   --  PURPOSE: what the FETCH edge judges about the Reef's freshness index and
   --  the two wire replies before it moves one catalog file into place: the
   --  reply shape, the two lines, the index shape, freshness, each entry, the
   --  choice of the highest version above the running one, the rate gate, the
   --  digest fact, and the word for the run -- fetched exactly when every fact
   --  was measured. USAGE: the edge measures, hands text and facts, and decides nothing.

   use type Json_Scan_Pkg.Kind_Type;
   use type Json_Scan_Pkg.Span_Type;
   use type Tower_Admission_Pkg.Version_Number;

   Fetch_Max_Reply  : constant := 4_194_304;
   Index_Max_Line   : constant := 65_536;
   Interval_Seconds : constant := 3_600;
   Max_File_Name    : constant := 128;
   Line_Feed        : constant Character := ASCII.LF;
   Reply_Tail       : constant String := '"' & '}';
   Index_Reply_Head : constant String :=
     '{' & '"' & "op" & '"' & ':' & '"' & "index" & '"' & ',' & '"' & "bytes_hex" & '"' & ':' & '"';
   Fetch_Reply_Head : constant String :=
     '{' & '"' & "op" & '"' & ':' & '"' & "fetch" & '"' & ',' & '"' & "bytes_hex" & '"' & ':' & '"';
   Current_Key : constant String := "current";
   Name_Key    : constant String := "name";
   Sha_Key     : constant String := "sha256";
   Bytes_Key   : constant String := "bytes";

   subtype Seconds_Count is Long_Long_Integer range 0 .. 9_999_999_999;

   function Reply_Is (Line : String; Head : String) return Boolean is
     (Line'Length >= Head'Length + Reply_Tail'Length + 2
      and then Line'Length <= Fetch_Max_Reply
      and then Line (1 .. Head'Length) = Head
      and then Line (Line'Length - Reply_Tail'Length + 1 .. Line'Length) = Reply_Tail
      and then Hex_Text_Pkg.Is_Hex_Text (Line (Head'Length + 1 .. Line'Length - Reply_Tail'Length)))
   with Global => null,
        Pre => Line'First = 1 and then Head'First = 1 and then Head'Length in 1 .. 64,
        Post => (Reply_Is'Result =
                   (not (Line'Length < Head'Length + Reply_Tail'Length + 2
                         or else Line'Length > Fetch_Max_Reply
                         or else Line (1 .. Head'Length) /= Head
                         or else Line (Line'Length - Reply_Tail'Length + 1 .. Line'Length) /= Reply_Tail
                         or else not Hex_Text_Pkg.Is_Hex_Text
                                   (Line (Head'Length + 1 .. Line'Length - Reply_Tail'Length)))))
               and then (if Reply_Is'Result then Line'Length in Head'Length + Reply_Tail'Length + 2 .. Fetch_Max_Reply);

   function Hex_Last (Line : String; Head : String) return Natural is
     (Line'Length - Reply_Tail'Length)
   with Global => null,
        Pre => Line'First = 1 and then Head'First = 1 and then Head'Length in 1 .. 64
               and then Reply_Is (Line, Head),
        Post => (Hex_Last'Result = Line'Length - Reply_Tail'Length)
                and then (Hex_Last'Result >= Head'Length + 2)
                and then Hex_Text_Pkg.Is_Hex_Text (Line (Head'Length + 1 .. Hex_Last'Result));

   function Two_Lines_At (B : String; P : Positive) return Boolean is
     (P >= 2
      and then P < B'Length
      and then P - 1 <= Index_Max_Line
      and then B (P) = Line_Feed
      and then B (B'Length) = Line_Feed
      and then (for all I in 1 .. B'Length - 1 => (I = P or else B (I) /= Line_Feed)))
   with Global => null,
        Pre => B'First = 1 and then B'Length <= Fetch_Max_Reply,
        Post => (Two_Lines_At'Result =
                   (not (P < 2 or else P >= B'Length or else P - 1 > Index_Max_Line
                         or else B (P) /= Line_Feed or else B (B'Length) /= Line_Feed
                         or else (for some I in 1 .. B'Length - 1 => (I /= P and then B (I) = Line_Feed)))))
               and then (if Two_Lines_At'Result then P in 2 .. B'Length - 1);

   function Current_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Current_Key))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Index_Max_Line,
        Post => (Current_Span'Result = Json_Scan_Pkg.Value_Span (Line, Current_Key))
                and then (if Current_Span'Result.found then
                             (Current_Span'Result.first in Line'Range
                              and then Current_Span'Result.last in Line'Range
                              and then Current_Span'Result.first <= Current_Span'Result.last));

   function Index_Ok (Line : String) return Boolean is
     (Tower_Payload_Pkg.Expires_Text_Ok (Line)
      and then Tower_Payload_Pkg.Expires_Span (Line).last <= Line'Last - 2
      and then Line (Tower_Payload_Pkg.Expires_Span (Line).last + 1) = ','
      and then Json_Scan_Pkg.Key_Position (Line, Current_Key) = Tower_Payload_Pkg.Expires_Span (Line).last + 2
      and then Current_Span (Line).found
      and then Current_Span (Line).kind = Json_Scan_Pkg.K_Composite
      and then Line (Current_Span (Line).first) = '['
      and then Line (Current_Span (Line).last) = ']'
      and then Current_Span (Line).last = Line'Last - 1
      and then Line (Line'Last) = '}')
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Index_Max_Line,
        Post => (Index_Ok'Result =
                   (not (not Tower_Payload_Pkg.Expires_Text_Ok (Line)
                         or else Tower_Payload_Pkg.Expires_Span (Line).last > Line'Last - 2
                         or else Line (Tower_Payload_Pkg.Expires_Span (Line).last + 1) /= ','
                         or else Json_Scan_Pkg.Key_Position (Line, Current_Key)
                                   /= Tower_Payload_Pkg.Expires_Span (Line).last + 2
                         or else not Current_Span (Line).found
                         or else Current_Span (Line).kind /= Json_Scan_Pkg.K_Composite
                         or else Line (Current_Span (Line).first) /= '['
                         or else Line (Current_Span (Line).last) /= ']'
                         or else Current_Span (Line).last /= Line'Last - 1
                         or else Line (Line'Last) /= '}')))
               and then (if Index_Ok'Result then Tower_Payload_Pkg.Expires_Text_Ok (Line))
               and then (if Index_Ok'Result then Current_Span (Line).found);

   function Fresh (Line : String; Now : String) return Boolean is
     (Tower_Payload_Pkg.Before
        (Now, Line (Tower_Payload_Pkg.Expires_Span (Line).first + 1
                    .. Tower_Payload_Pkg.Expires_Span (Line).last - 1)))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Index_Max_Line
               and then Index_Ok (Line) and then Tower_Payload_Pkg.Is_Seconds_Text (Now),
        Post => (Fresh'Result =
                   Tower_Payload_Pkg.Before
                     (Now, Line (Tower_Payload_Pkg.Expires_Span (Line).first + 1
                                 .. Tower_Payload_Pkg.Expires_Span (Line).last - 1)));

   function Is_Safe_File_Name (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= Max_File_Name
      and then S (S'First) /= '.'
      and then (for all I in S'Range =>
                  S (I) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '.' | '_' | '-'))
   with Global => null,
        Post => (Is_Safe_File_Name'Result =
                   (not (S'Length < 1 or else S'Length > Max_File_Name
                         or else S (S'First) = '.'
                         or else (for some I in S'Range =>
                                   S (I) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '.' | '_' | '-'))))
               and then (if Is_Safe_File_Name'Result then S'Length in 1 .. Max_File_Name);

   function Name_Span (E : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (E, Name_Key))
   with Global => null,
        Pre => E'First = 1 and then E'Length <= Index_Max_Line,
        Post => (Name_Span'Result = Json_Scan_Pkg.Value_Span (E, Name_Key))
                and then (if Name_Span'Result.found then
                             (Name_Span'Result.first in E'Range
                              and then Name_Span'Result.last in E'Range
                              and then Name_Span'Result.first <= Name_Span'Result.last));

   function Sha_Span (E : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (E, Sha_Key))
   with Global => null,
        Pre => E'First = 1 and then E'Length <= Index_Max_Line,
        Post => (Sha_Span'Result = Json_Scan_Pkg.Value_Span (E, Sha_Key))
                and then (if Sha_Span'Result.found then
                             (Sha_Span'Result.first in E'Range
                              and then Sha_Span'Result.last in E'Range
                              and then Sha_Span'Result.first <= Sha_Span'Result.last));

   function Bytes_Span (E : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (E, Bytes_Key))
   with Global => null,
        Pre => E'First = 1 and then E'Length <= Index_Max_Line,
        Post => (Bytes_Span'Result = Json_Scan_Pkg.Value_Span (E, Bytes_Key))
                and then (if Bytes_Span'Result.found then
                             (Bytes_Span'Result.first in E'Range
                              and then Bytes_Span'Result.last in E'Range
                              and then Bytes_Span'Result.first <= Bytes_Span'Result.last));

   function Entry_Ok (E : String) return Boolean is
     (E'Length >= 2
      and then E (1) = '{'
      and then E (E'Length) = '}'
      and then Name_Span (E).found
      and then Name_Span (E).kind = Json_Scan_Pkg.K_String
      and then Name_Span (E).first < Name_Span (E).last
      and then Is_Safe_File_Name (E (Name_Span (E).first + 1 .. Name_Span (E).last - 1))
      and then Tower_Payload_Pkg.Version_Span (E).found
      and then Tower_Payload_Pkg.Version_Span (E).kind = Json_Scan_Pkg.K_Bare
      and then Tower_Stamp_Pkg.Is_Version_Text
                 (E (Tower_Payload_Pkg.Version_Span (E).first .. Tower_Payload_Pkg.Version_Span (E).last))
      and then Sha_Span (E).found
      and then Sha_Span (E).kind = Json_Scan_Pkg.K_String
      and then Sha_Span (E).first < Sha_Span (E).last
      and then Tower_Stamp_Pkg.Is_Hex_Digest (E (Sha_Span (E).first + 1 .. Sha_Span (E).last - 1))
      and then Bytes_Span (E).found
      and then Bytes_Span (E).kind = Json_Scan_Pkg.K_Bare
      and then Tower_Stamp_Pkg.Is_Version_Text (E (Bytes_Span (E).first .. Bytes_Span (E).last)))
   with Global => null,
        Pre => E'First = 1 and then E'Length <= Index_Max_Line,
        Post => (Entry_Ok'Result =
                   (not (E'Length < 2 or else E (1) /= '{' or else E (E'Length) /= '}'
                         or else not Name_Span (E).found
                         or else Name_Span (E).kind /= Json_Scan_Pkg.K_String
                         or else Name_Span (E).first >= Name_Span (E).last
                         or else not Is_Safe_File_Name (E (Name_Span (E).first + 1 .. Name_Span (E).last - 1))
                         or else not Tower_Payload_Pkg.Version_Span (E).found
                         or else Tower_Payload_Pkg.Version_Span (E).kind /= Json_Scan_Pkg.K_Bare
                         or else not Tower_Stamp_Pkg.Is_Version_Text
                                   (E (Tower_Payload_Pkg.Version_Span (E).first
                                       .. Tower_Payload_Pkg.Version_Span (E).last))
                         or else not Sha_Span (E).found
                         or else Sha_Span (E).kind /= Json_Scan_Pkg.K_String
                         or else Sha_Span (E).first >= Sha_Span (E).last
                         or else not Tower_Stamp_Pkg.Is_Hex_Digest (E (Sha_Span (E).first + 1 .. Sha_Span (E).last - 1))
                         or else not Bytes_Span (E).found
                         or else Bytes_Span (E).kind /= Json_Scan_Pkg.K_Bare
                         or else not Tower_Stamp_Pkg.Is_Version_Text (E (Bytes_Span (E).first .. Bytes_Span (E).last)))))
               and then (if Entry_Ok'Result then
                            Tower_Stamp_Pkg.Is_Hex_Digest (E (Sha_Span (E).first + 1 .. Sha_Span (E).last - 1)))
               and then (if Entry_Ok'Result then
                            Tower_Stamp_Pkg.Is_Version_Text
                              (E (Tower_Payload_Pkg.Version_Span (E).first .. Tower_Payload_Pkg.Version_Span (E).last)));

   function Digest_Names (Digest : String; E : String) return Boolean is
     (Digest = E (Sha_Span (E).first + 1 .. Sha_Span (E).last - 1))
   with Global => null,
        Pre => E'First = 1 and then E'Length <= Index_Max_Line
               and then Tower_Stamp_Pkg.Is_Hex_Digest (Digest) and then Entry_Ok (E),
        Post => (Digest_Names'Result = (Digest = E (Sha_Span (E).first + 1 .. Sha_Span (E).last - 1)));

   function Object_At (Line : String; I : Positive; J : Positive) return Boolean is
     (I < J
      and then Line (I) = '{'
      and then Line (J) = '}'
      and then (for all K in I + 1 .. J - 1 => (Line (K) /= '{' and then Line (K) /= '}')))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Index_Max_Line
               and then I in Line'Range and then J in Line'Range,
        Post => (Object_At'Result =
                   (not (I >= J or else Line (I) /= '{' or else Line (J) /= '}'
                         or else (for some K in I + 1 .. J - 1 => (Line (K) = '{' or else Line (K) = '}')))))
               and then (if Object_At'Result then I < J);

   type Pick_State is record
      have : Boolean := False;
      best : Tower_Admission_Pkg.Version_Number := 0;
   end record;

   function Taken (P : Pick_State; V : Tower_Admission_Pkg.Version_Number;
                   Running : Tower_Admission_Pkg.Version_Number) return Boolean is
     (Tower_Admission_Pkg.Is_Forward (V, Running) and then V > P.best)
   with Global => null,
        Post => (Taken'Result = (Tower_Admission_Pkg.Is_Forward (V, Running) and then V > P.best))
                and then (if Taken'Result then V > Running);

   function Consider (P : Pick_State; V : Tower_Admission_Pkg.Version_Number;
                      Running : Tower_Admission_Pkg.Version_Number) return Pick_State is
     ((if Taken (P, V, Running) then Pick_State'(have => True, best => V) else P))
   with Global => null,
        Post => (Consider'Result.best >= P.best)
                and then (if Taken (P, V, Running) then
                             (Consider'Result.have and then Consider'Result.best = V))
                and then (if not Taken (P, V, Running) then Consider'Result = P)
                and then (if Tower_Admission_Pkg.Is_Forward (V, Running) then Consider'Result.best >= V)
                and then (if (if P.have then Tower_Admission_Pkg.Is_Forward (P.best, Running)) then
                             (if Consider'Result.have then
                                Tower_Admission_Pkg.Is_Forward (Consider'Result.best, Running)));

   function May_Ask (Now : Seconds_Count; Last_At : Seconds_Count) return Boolean is
     (Now >= Last_At and then Now - Last_At >= Interval_Seconds)
   with Global => null,
        Post => (May_Ask'Result = (Now >= Last_At and then Now - Last_At >= Interval_Seconds))
                and then (if Now < Last_At then not May_Ask'Result);

   type Fetch_Facts is record
      have_rail      : Boolean := False;
      may_ask        : Boolean := False;
      reached        : Boolean := False;
      index_readable : Boolean := False;
      sealed         : Boolean := False;
      fresh          : Boolean := False;
      newer          : Boolean := False;
      fetched        : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Fetched, Out_No_Reef_Rail, Out_Rate_Limited, Out_Reef_Unreachable,
      Out_Index_Unreadable, Out_Index_Unverified, Out_Index_Stale, Out_Current,
      Out_Fetch_Failed);

   function Outcome (F : Fetch_Facts) return Outcome_Kind is
     ((if not F.have_rail then Out_No_Reef_Rail
       elsif not F.may_ask then Out_Rate_Limited
       elsif not F.reached then Out_Reef_Unreachable
       elsif not F.index_readable then Out_Index_Unreadable
       elsif not F.sealed then Out_Index_Unverified
       elsif not F.fresh then Out_Index_Stale
       elsif not F.newer then Out_Current
       elsif not F.fetched then Out_Fetch_Failed
       else Out_Fetched))
   with Global => null,
        Post => ((Outcome'Result = Out_Fetched) =
                   (F.have_rail and then F.may_ask and then F.reached and then F.index_readable
                    and then F.sealed and then F.fresh and then F.newer and then F.fetched))
                and then (if not F.have_rail then Outcome'Result = Out_No_Reef_Rail)
                and then (if F.have_rail and then not F.may_ask then Outcome'Result = Out_Rate_Limited)
                and then (if F.have_rail and then F.may_ask and then not F.reached then
                             Outcome'Result = Out_Reef_Unreachable)
                and then (if F.have_rail and then F.may_ask and then F.reached and then not F.index_readable then
                             Outcome'Result = Out_Index_Unreadable)
                and then (if F.have_rail and then F.may_ask and then F.reached and then F.index_readable
                           and then not F.sealed then
                             Outcome'Result = Out_Index_Unverified)
                and then (if F.have_rail and then F.may_ask and then F.reached and then F.index_readable
                           and then F.sealed and then not F.fresh then
                             Outcome'Result = Out_Index_Stale)
                and then (if F.have_rail and then F.may_ask and then F.reached and then F.index_readable
                           and then F.sealed and then F.fresh and then not F.newer then
                             Outcome'Result = Out_Current)
                and then (if F.have_rail and then F.may_ask and then F.reached and then F.index_readable
                           and then F.sealed and then F.fresh and then F.newer and then not F.fetched then
                             Outcome'Result = Out_Fetch_Failed)
                and then (if not F.sealed then Outcome'Result /= Out_Fetched)
                and then (if not F.fetched then Outcome'Result /= Out_Fetched);

end Tower_Index_Pkg;
