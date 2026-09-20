--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 7e595c7ec8d4d96b37bcc8311481c6c2b6864ea641e48a0c6f7a9479e2e9b116
--
with Json_Scan_Pkg;
with Tower_Stamp_Pkg;

package Tower_Payload_Pkg with SPARK_Mode is
   --  PURPOSE: questions about LINE 1 of a tower SHARER bundle, the sealed
   --  payload. Is version the first key and well formed; does expires sit
   --  directly after it and read as a time; is the bundle in date.
   --  USAGE: VERIFY THE SEAL FIRST, then ask Payload_Ok, once. Convert the
   --  version span to a number ONLY when Version_Text_Ok holds. No clock here.

   use type Json_Scan_Pkg.Kind_Type;
   use type Json_Scan_Pkg.Span_Type;

   Max_Line : constant := 1048576;

   Version_Key : constant String := "version";
   Expires_Key : constant String := "expires";
   Entries_Key : constant String := "entries";

   function First_Key_Is_Version (Line : String) return Boolean is
     (Line'Length >= 11 and then Line (1) = '{' and then Json_Scan_Pkg.Key_Position (Line, Version_Key) = 2)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => First_Key_Is_Version'Result = (not (Line'Length < 11 or else Line (1) /= '{' or else Json_Scan_Pkg.Key_Position (Line, Version_Key) /= 2));

   function Version_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Version_Key))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Version_Span'Result = Json_Scan_Pkg.Value_Span (Line, Version_Key)
                and then (if Version_Span'Result.found then (Version_Span'Result.first in Line'Range and then Version_Span'Result.last in Line'Range and then Version_Span'Result.first <= Version_Span'Result.last));

   function Version_Text_Ok (Line : String) return Boolean is
     (First_Key_Is_Version (Line) and then Version_Span (Line).found and then Version_Span (Line).kind = Json_Scan_Pkg.K_Bare and then Tower_Stamp_Pkg.Is_Version_Text (Line (Version_Span (Line).first .. Version_Span (Line).last)))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Version_Text_Ok'Result = (not (not First_Key_Is_Version (Line) or else not Version_Span (Line).found or else Version_Span (Line).kind /= Json_Scan_Pkg.K_Bare or else not Tower_Stamp_Pkg.Is_Version_Text (Line (Version_Span (Line).first .. Version_Span (Line).last))))
                and then (if Version_Text_Ok'Result then (First_Key_Is_Version (Line) and then Version_Span (Line).found and then Version_Span (Line).kind = Json_Scan_Pkg.K_Bare))
                and then (if Version_Text_Ok'Result then Tower_Stamp_Pkg.Is_Version_Text (Line (Version_Span (Line).first .. Version_Span (Line).last)));

   function Expires_Position_Ok (Line : String) return Boolean is
     (Version_Text_Ok (Line) and then Version_Span (Line).last <= Line'Last - 2 and then Line (Version_Span (Line).last + 1) = ',' and then Json_Scan_Pkg.Key_Position (Line, Expires_Key) = Version_Span (Line).last + 2)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Expires_Position_Ok'Result = (not (not Version_Text_Ok (Line) or else Version_Span (Line).last > Line'Last - 2 or else Line (Version_Span (Line).last + 1) /= ',' or else Json_Scan_Pkg.Key_Position (Line, Expires_Key) /= Version_Span (Line).last + 2))
                and then (if Expires_Position_Ok'Result then Version_Text_Ok (Line))
                and then (if Expires_Position_Ok'Result then Json_Scan_Pkg.Key_Position (Line, Expires_Key) > Version_Span (Line).last);

   function Expires_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Expires_Key))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Expires_Span'Result = Json_Scan_Pkg.Value_Span (Line, Expires_Key)
                and then (if Expires_Span'Result.found then (Expires_Span'Result.first in Line'Range and then Expires_Span'Result.last in Line'Range and then Expires_Span'Result.first <= Expires_Span'Result.last));

   function Is_Seconds_Text (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= 10 and then (for all I in S'Range => S (I) in '0' .. '9') and then (S'Length = 1 or else S (S'First) /= '0'))
   with Global => null,
        Post => Is_Seconds_Text'Result = (not (S'Length < 1 or else S'Length > 10 or else (for some I in S'Range => S (I) not in '0' .. '9') or else (S'Length > 1 and then S (S'First) = '0')))
                and then (if Is_Seconds_Text'Result then (S'Length >= 1 and then S'Length <= 10))
                and then (if Is_Seconds_Text'Result then (for all I in S'Range => S (I) in '0' .. '9'));

   function Expires_Text_Ok (Line : String) return Boolean is
     (Expires_Position_Ok (Line) and then Expires_Span (Line).found and then Expires_Span (Line).kind = Json_Scan_Pkg.K_String and then Expires_Span (Line).first < Expires_Span (Line).last and then Is_Seconds_Text (Line (Expires_Span (Line).first + 1 .. Expires_Span (Line).last - 1)))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Expires_Text_Ok'Result = (not (not Expires_Position_Ok (Line) or else not Expires_Span (Line).found or else Expires_Span (Line).kind /= Json_Scan_Pkg.K_String or else Expires_Span (Line).first >= Expires_Span (Line).last or else not Is_Seconds_Text (Line (Expires_Span (Line).first + 1 .. Expires_Span (Line).last - 1))))
                and then (if Expires_Text_Ok'Result then Expires_Position_Ok (Line))
                and then (if Expires_Text_Ok'Result then Is_Seconds_Text (Line (Expires_Span (Line).first + 1 .. Expires_Span (Line).last - 1)));

   function Entries_Position_Ok (Line : String) return Boolean is
     (Expires_Text_Ok (Line) and then Expires_Span (Line).found and then Expires_Span (Line).last <= Line'Last - 2 and then Line (Expires_Span (Line).last + 1) = ',' and then Json_Scan_Pkg.Key_Position (Line, Entries_Key) = Expires_Span (Line).last + 2)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Entries_Position_Ok'Result = (not (not Expires_Text_Ok (Line) or else not Expires_Span (Line).found or else Expires_Span (Line).last > Line'Last - 2 or else Line (Expires_Span (Line).last + 1) /= ',' or else Json_Scan_Pkg.Key_Position (Line, Entries_Key) /= Expires_Span (Line).last + 2))
                and then (if Entries_Position_Ok'Result then Expires_Text_Ok (Line));

   function Entries_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Entries_Key))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Entries_Span'Result = Json_Scan_Pkg.Value_Span (Line, Entries_Key)
                and then (if Entries_Span'Result.found then (Entries_Span'Result.first in Line'Range and then Entries_Span'Result.last in Line'Range and then Entries_Span'Result.first <= Entries_Span'Result.last));

   function Head_Is_Compact (Line : String) return Boolean is
     (Entries_Position_Ok (Line) and then Version_Span (Line).found and then Expires_Span (Line).found and then Entries_Span (Line).found and then Line (11) = ':' and then Version_Span (Line).first = 12 and then Version_Span (Line).last <= Line'Last - 12 and then Line (Version_Span (Line).last + 11) = ':' and then Expires_Span (Line).first = Version_Span (Line).last + 12 and then Expires_Span (Line).last <= Line'Last - 12 and then Line (Expires_Span (Line).last + 11) = ':' and then Entries_Span (Line).first = Expires_Span (Line).last + 12)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Head_Is_Compact'Result = (not (not Entries_Position_Ok (Line) or else not Version_Span (Line).found or else not Expires_Span (Line).found or else not Entries_Span (Line).found or else Line (11) /= ':' or else Version_Span (Line).first /= 12 or else Version_Span (Line).last > Line'Last - 12 or else Line (Version_Span (Line).last + 11) /= ':' or else Expires_Span (Line).first /= Version_Span (Line).last + 12 or else Expires_Span (Line).last > Line'Last - 12 or else Line (Expires_Span (Line).last + 11) /= ':' or else Entries_Span (Line).first /= Expires_Span (Line).last + 12))
                and then (if Head_Is_Compact'Result then Entries_Position_Ok (Line));

   function Shape_Closed (Line : String) return Boolean is
     (Head_Is_Compact (Line) and then Entries_Span (Line).found and then Entries_Span (Line).kind = Json_Scan_Pkg.K_Composite and then Line (Entries_Span (Line).first) = '[' and then Line (Entries_Span (Line).last) = ']' and then Entries_Span (Line).last = Line'Last - 1 and then Line (Line'Last) = '}')
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Shape_Closed'Result = (not (not Head_Is_Compact (Line) or else not Entries_Span (Line).found or else Entries_Span (Line).kind /= Json_Scan_Pkg.K_Composite or else Line (Entries_Span (Line).first) /= '[' or else Line (Entries_Span (Line).last) /= ']' or else Entries_Span (Line).last /= Line'Last - 1 or else Line (Line'Last) /= '}'))
                and then (if Shape_Closed'Result then Head_Is_Compact (Line));

   function Payload_Ok (Line : String) return Boolean is
     (Shape_Closed (Line))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => Payload_Ok'Result = (Version_Text_Ok (Line) and then Expires_Text_Ok (Line) and then Shape_Closed (Line));

   function Before (A : String; B : String) return Boolean is
     (A'Length < B'Length or else (A'Length = B'Length and then A < B))
   with Global => null,
        Pre => Is_Seconds_Text (A) and then Is_Seconds_Text (B),
        Post => Before'Result = (not (A'Length > B'Length or else (A'Length = B'Length and then A >= B)))
                and then (if A'Length < B'Length then Before'Result)
                and then (if A'Length > B'Length then not Before'Result);

   function Clock_Plausible (Now : String; Floor : String) return Boolean is
     (Is_Seconds_Text (Now) and then Is_Seconds_Text (Floor) and then Floor'Length = 10 and then not Before (Now, Floor))
   with Global => null,
        Post => Clock_Plausible'Result = (not (not Is_Seconds_Text (Now) or else not Is_Seconds_Text (Floor) or else Floor'Length /= 10 or else Before (Now, Floor)))
                and then (if Clock_Plausible'Result then Is_Seconds_Text (Now))
                and then (if Clock_Plausible'Result then Is_Seconds_Text (Floor));

   function In_Date (Line : String; Now : String; Floor : String) return Boolean is
     (Payload_Ok (Line) and then Clock_Plausible (Now, Floor) and then Before (Now, Line (Expires_Span (Line).first + 1 .. Expires_Span (Line).last - 1)))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= Max_Line,
        Post => In_Date'Result = (not (not Payload_Ok (Line) or else not Clock_Plausible (Now, Floor) or else not Before (Now, Line (Expires_Span (Line).first + 1 .. Expires_Span (Line).last - 1))))
                and then (if In_Date'Result then Payload_Ok (Line))
                and then (if In_Date'Result then Clock_Plausible (Now, Floor));

end Tower_Payload_Pkg;
