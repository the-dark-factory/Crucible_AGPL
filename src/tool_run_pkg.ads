--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fd7e363ac0a7367047b826a0a82b0875b89d708a3ab199dbdeddc70f34846b5f
--
with Json_Scan_Pkg;
with Frame_Facts_Pkg;
with Edition_Licence_Pkg;
with Sole_Interface_Pkg;
with Reply_Text_Pkg;

package Tool_Run_Pkg with SPARK_Mode is

   use type Json_Scan_Pkg.Kind_Type;
   use type Edition_Licence_Pkg.Edition_Type;
   use type Edition_Licence_Pkg.Requested_Licence_Type;
   use type Edition_Licence_Pkg.Reason_Type;

   Requested_Key      : constant String := "requested";
   Agpl_Lit           : constant String := "agpl";
   Mit_Lit            : constant String := "mit";
   Proprietary_Lit    : constant String := "proprietary";
   Other_Word         : constant String := "other";
   Permitted_Word     : constant String := "permitted";
   Agpl_Only_Word     : constant String := "edition_is_agpl_only";
   Not_Enumerated_Word : constant String := "entry_points_not_enumerated";
   No_Mcp_Word        : constant String := "no_mcp_endpoint";
   Another_Door_Word  : constant String := "another_door_open";
   No_Schema_Word     : constant String := "tool_without_schema";
   Unauthenticated_Word : constant String := "unauthenticated_entry";
   None_Word          : constant String := "none";

   function Requested_Of (Line : String) return Edition_Licence_Pkg.Requested_Licence_Type with
     Pre => Line'First = 1 and then Line'Length <= 1048576,
     Post => (if not Json_Scan_Pkg.Value_Span (Line, Requested_Key).found then Requested_Of'Result = Edition_Licence_Pkg.Other_Licence);

   function Requested_Of (Line : String) return Edition_Licence_Pkg.Requested_Licence_Type is
     (if not (Json_Scan_Pkg.Value_Span (Line, Requested_Key).found and then Json_Scan_Pkg.Value_Span (Line, Requested_Key).kind = Json_Scan_Pkg.K_String) then Edition_Licence_Pkg.Other_Licence
      elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Requested_Key)), Agpl_Lit) then Edition_Licence_Pkg.Agpl_Licence
      elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Requested_Key)), Mit_Lit) then Edition_Licence_Pkg.Mit_Licence
      elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Requested_Key)), Proprietary_Lit) then Edition_Licence_Pkg.Proprietary_Licence
      else Edition_Licence_Pkg.Other_Licence);

   function Word_Of (R : Edition_Licence_Pkg.Requested_Licence_Type) return String with
     Post => Word_Of'Result'First = 1 and then Word_Of'Result'Length <= 512;

   function Word_Of (R : Edition_Licence_Pkg.Requested_Licence_Type) return String is
     (if R = Edition_Licence_Pkg.Agpl_Licence then Agpl_Lit
      elsif R = Edition_Licence_Pkg.Mit_Licence then Mit_Lit
      elsif R = Edition_Licence_Pkg.Proprietary_Licence then Proprietary_Lit
      else Other_Word);

   function Reason_Word (R : Edition_Licence_Pkg.Reason_Type) return String with
     Post => Reason_Word'Result'First = 1 and then Reason_Word'Result'Length <= 512;

   function Reason_Word (R : Edition_Licence_Pkg.Reason_Type) return String is
     (if R = Edition_Licence_Pkg.Permitted then Permitted_Word
      else Agpl_Only_Word);

   function Gate_Refuses (Edition : Edition_Licence_Pkg.Edition_Type; Line : String) return Boolean with
     Pre => Line'First = 1 and then Line'Length <= 1048576,
     Post => (Gate_Refuses'Result = (if Edition_Licence_Pkg.Is_Refused (Edition_Licence_Pkg.Decide (Edition, Requested_Of (Line))) then True else False))
             and then (if Edition = Edition_Licence_Pkg.Commercial then not Gate_Refuses'Result)
             and then (if Requested_Of (Line) = Edition_Licence_Pkg.Agpl_Licence then not Gate_Refuses'Result);

   function Gate_Refuses (Edition : Edition_Licence_Pkg.Edition_Type; Line : String) return Boolean is
     (Edition_Licence_Pkg.Is_Refused (Edition_Licence_Pkg.Decide (Edition, Requested_Of (Line))));

   function Licence_Gate (Edition : Edition_Licence_Pkg.Edition_Type; Line : String) return String with
     Pre => Line'First = 1 and then Line'Length <= 1048576,
     Post => Licence_Gate'Result'Length >= 2
             and then Licence_Gate'Result (Licence_Gate'Result'First) = '{'
             and then Licence_Gate'Result (Licence_Gate'Result'Last) = '}'
             and then Licence_Gate'Result'Length <= 4096;

   function Licence_Gate (Edition : Edition_Licence_Pkg.Edition_Type; Line : String) return String is
     (Reply_Text_Pkg.Licence_Gate_Text
        (Edition = Edition_Licence_Pkg.Agpl,
         Word_Of (Requested_Of (Line)),
         Gate_Refuses (Edition, Line),
         Reason_Word (Edition_Licence_Pkg.Refusal_Reason (Edition, Requested_Of (Line)))));

   function First_Fault_Word (V : Sole_Interface_Pkg.Verdict_Type) return String with
     Post => First_Fault_Word'Result'First = 1 and then First_Fault_Word'Result'Length <= 512;

   function First_Fault_Word (V : Sole_Interface_Pkg.Verdict_Type) return String is
     (if V.fault_not_enumerated then Not_Enumerated_Word
      elsif V.fault_no_mcp_endpoint then No_Mcp_Word
      elsif V.fault_another_door_open then Another_Door_Word
      elsif V.fault_tool_without_schema then No_Schema_Word
      elsif V.fault_unauthenticated_entry then Unauthenticated_Word
      else None_Word);

   function Self_Judge (Facts : Sole_Interface_Pkg.Facts_Type) return String with
     Post => Self_Judge'Result'Length >= 2
             and then Self_Judge'Result (Self_Judge'Result'First) = '{'
             and then Self_Judge'Result (Self_Judge'Result'Last) = '}'
             and then Self_Judge'Result'Length <= 4096;

   function Self_Judge (Facts : Sole_Interface_Pkg.Facts_Type) return String is
     (Reply_Text_Pkg.Self_Judge_Text
        (Sole_Interface_Pkg.Assemble (Facts).interface_is_sole,
         Sole_Interface_Pkg.Assemble (Facts).fault_count,
         First_Fault_Word (Sole_Interface_Pkg.Assemble (Facts))));

end Tool_Run_Pkg;
