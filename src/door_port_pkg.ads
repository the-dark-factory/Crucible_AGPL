--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a678369c228ba09a7e83ab454528af30ce475783be11cc9e7eee64d51a1fff5c
--
with Json_Scan_Pkg;
with Json_Rpc_Frame_Pkg;
with Frame_Facts_Pkg;
with Edition_Licence_Pkg;

package Door_Port_Pkg with SPARK_Mode is

   use type Json_Rpc_Frame_Pkg.Method_Type;
   use type Json_Scan_Pkg.Kind_Type;

   Key_Name       : constant String := "name";
   Key_Brief      : constant String := "brief";
   Lit_Expand_Brief : constant String := "expand_brief";

   function Is_Tools_Call (Line : String) return Boolean is
     (Frame_Facts_Pkg.Method_Of (Line) = Json_Rpc_Frame_Pkg.M_Tools_Call)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536;

   function Names_Expand_Brief (Line : String) return Boolean is
     (Frame_Facts_Pkg.Tool_Name_Span (Line).found
      and then Frame_Facts_Pkg.Tool_Name_Span (Line).kind = Json_Scan_Pkg.K_String
      and then Json_Scan_Pkg.Equals_Literal (Line,
        Json_Scan_Pkg.String_Contents (Line, Frame_Facts_Pkg.Tool_Name_Span (Line)),
        Lit_Expand_Brief))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536;

   function Brief_Present (Line : String) return Boolean is
     (Frame_Facts_Pkg.Arg_Span (Line, Key_Brief).found
      and then Frame_Facts_Pkg.Arg_Span (Line, Key_Brief).kind = Json_Scan_Pkg.K_String)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536;

   function Brief_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.String_Contents (Line, Frame_Facts_Pkg.Arg_Span (Line, Key_Brief)))
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536 and then Brief_Present (Line);

   type Fault_Kind is
     (No_Fault, Not_A_Tools_Call, Not_Expand_Brief, No_Brief, Licence_Absent, Edition_Refuses);

   function Fault_Of
     (Line            : String;
      Licence_Present : Boolean;
      Edition         : Edition_Licence_Pkg.Edition_Type;
      Requested       : Edition_Licence_Pkg.Requested_Licence_Type)
      return Fault_Kind
   is (if not Is_Tools_Call (Line) then Not_A_Tools_Call
       elsif not Names_Expand_Brief (Line) then Not_Expand_Brief
       elsif not Brief_Present (Line) then No_Brief
       elsif not Licence_Present then Licence_Absent
       elsif not Edition_Licence_Pkg.Permits (Edition, Requested) then Edition_Refuses
       else No_Fault)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536;

   function Admitted
     (Line            : String;
      Licence_Present : Boolean;
      Edition         : Edition_Licence_Pkg.Edition_Type;
      Requested       : Edition_Licence_Pkg.Requested_Licence_Type)
      return Boolean
   is (Fault_Of (Line, Licence_Present, Edition, Requested) = No_Fault)
   with Global => null,
        Pre => Line'First = 1 and then Line'Length <= 65536,
        Post => Admitted'Result = (Is_Tools_Call (Line)
          and then Names_Expand_Brief (Line)
          and then Brief_Present (Line)
          and then Licence_Present
          and then Edition_Licence_Pkg.Permits (Edition, Requested));

end Door_Port_Pkg;
