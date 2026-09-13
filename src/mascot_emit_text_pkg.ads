--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Mascot_Emit_Text_Pkg lineage 5 (2026-09-13): lineage 4 verbatim plus the UNIT-NAME and FILE-NAME fragments the
--  writer's MASCOT r2 names in its section F — Wire_Unit_Name, Store_Unit_Name, Types_Unit_Name, Stage_Unit_Name,
--  Main_Unit_Name, Body_File, Actual_Separator — and two constants (Types_Suffix, Adb_Suffix). Exact-length Posts
--  only. Lane wu-crucible-mascot-emit-text-5 round A, planner qwen3.8-27b-ada:v0.3, accepted first round, 0 unproved.
--  Body (Stem_Of) carried unchanged. Never hand-edited. Comment-stripped sha equals the round-A spec.
with Mascot_Emit_Pkg;
with Pool_Pkg;

package Mascot_Emit_Text_Pkg with SPARK_Mode is

   use type Pool_Pkg.Discipline_Kind;

   LF : constant Character := Character'Val (10);
   HT : constant Character := Character'Val (9);

   Package_Word      : constant String := "package ";
   Spark_Head        : constant String := " with SPARK_Mode is";
   End_Word          : constant String := "end ";
   Semicolon         : constant String := ";";
   Indent            : constant String := "   ";
   Marker_Prefix     : constant String := "--  SLOT ";
   Begin_Word        : constant String := "BEGIN (";
   End_Marker_Word   : constant String := "END (";
   Close_Paren       : constant String := ")";
   Type_Prefix       : constant String := "type-";
   Type_Word         : constant String := "type ";
   Null_Record       : constant String := " is null record;";
   With_Word         : constant String := "with ";
   Channel_Pkg_Name  : constant String := "Bounded_Channel_Pkg";
   Pool_Pkg_Name     : constant String := "Pool_Pkg";
   Is_New            : constant String := " is new ";
   Channel_Gen       : constant String := ".Channel (Element_Type => ";
   Pool_Gen          : constant String := ".Pool (State_Type => ";
   Capacity_Key      : constant String := ", Capacity => ";
   Discipline_Key    : constant String := ", Discipline => Pool_Pkg.";
   Close_Inst        : constant String := ");";
   Dot               : constant String := ".";
   Procedure_Word    : constant String := "procedure ";
   Is_Word           : constant String := " is";
   Discharge_Comment : constant String := "   --  discharge: ";
   Begin_Line        : constant String := "begin";
   Body_Name         : constant String := "body";
   Null_Stmt         : constant String := "   null;";
   Prompt_Head       : constant String := "Emit the slot fills for procedure ";
   Prompt_Sep        : constant String := " -- ";
   Prompt_Tail       : constant String := ". The channels and pools it touches are beside this prompt; the body is yours alone.";
   Name_Column       : constant String := "# name";
   Digest_Column     : constant String := "sha256 of comment-stripped source";
   Home_Column       : constant String := "proved home";
   Emitted_Word      : constant String := "emitted";
   Ads_Suffix        : constant String := ".ads";
   Read_Mostly_Word  : constant String := "Read_Mostly";
   Read_Write_Word   : constant String := "Read_Write";
   Set_Once_Word     : constant String := "Set_Once";

   function Slot_Begin (Slot : String) return String
   is (Indent & Marker_Prefix & Begin_Word & Slot & Close_Paren & LF)
   with Global => null,
        Pre  => Slot'First = 1 and then Slot'Length >= 1 and then Slot'Length <= 128,
        Post => Slot_Begin'Result'First = 1
                and then Slot_Begin'Result'Length = Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Slot'Length + Close_Paren'Length + 1;

   function Slot_End (Slot : String) return String
   is (Indent & Marker_Prefix & End_Marker_Word & Slot & Close_Paren & LF)
   with Global => null,
        Pre  => Slot'First = 1 and then Slot'Length >= 1 and then Slot'Length <= 128,
        Post => Slot_End'Result'First = 1
                and then Slot_End'Result'Length = Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Slot'Length + Close_Paren'Length + 1;

   function Types_Head (Types : String) return String
   is (Package_Word & Types & Spark_Head & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Types),
        Post => Types_Head'Result'First = 1
                and then Types_Head'Result'Length = Package_Word'Length + Types'Length + Spark_Head'Length + 1;

   function Types_Tail (Types : String) return String
   is (End_Word & Types & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Types),
        Post => Types_Tail'Result'First = 1
                and then Types_Tail'Result'Length = End_Word'Length + Types'Length + Semicolon'Length + 1;

   function Type_Slot (Element : String) return String
   is (Slot_Begin (Type_Prefix & Element) & Indent & Type_Word & Element & Null_Record & LF & Slot_End (Type_Prefix & Element))
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Element),
        Post => Type_Slot'Result'First = 1
                and then Type_Slot'Result'Length = Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Type_Prefix'Length + Element'Length + Close_Paren'Length + 1 + Indent'Length + Type_Word'Length + Element'Length + Null_Record'Length + 1 + Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Type_Prefix'Length + Element'Length + Close_Paren'Length + 1;

   function Channel_Instance (Name, Types, Element, Buffer : String) return String
   is (With_Word & Channel_Pkg_Name & Semicolon & LF & With_Word & Types & Semicolon & LF & Package_Word & Name & Is_New & Channel_Pkg_Name & Channel_Gen & Types & Dot & Element & Capacity_Key & Buffer & Close_Inst & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Types) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Element) and then Mascot_Emit_Pkg.Positive_Digits (Buffer),
        Post => Channel_Instance'Result'First = 1
                and then Channel_Instance'Result'Length = With_Word'Length + Channel_Pkg_Name'Length + Semicolon'Length + 1 + With_Word'Length + Types'Length + Semicolon'Length + 1 + Package_Word'Length + Name'Length + Is_New'Length + Channel_Pkg_Name'Length + Channel_Gen'Length + Types'Length + Dot'Length + Element'Length + Capacity_Key'Length + Buffer'Length + Close_Inst'Length + 1;

   function Discipline_Word (D : Pool_Pkg.Discipline_Kind) return String
   is ((if D = Pool_Pkg.Set_Once then Set_Once_Word elsif D = Pool_Pkg.Read_Mostly then Read_Mostly_Word else Read_Write_Word))
   with Global => null,
        Post => Discipline_Word'Result'First = 1 and then Discipline_Word'Result'Length >= 8 and then Discipline_Word'Result'Length <= 11;

   function Pool_Instance (Name, Types, Element : String; D : Pool_Pkg.Discipline_Kind) return String
   is (With_Word & Pool_Pkg_Name & Semicolon & LF & With_Word & Types & Semicolon & LF & Package_Word & Name & Is_New & Pool_Pkg_Name & Pool_Gen & Types & Dot & Element & Discipline_Key & Discipline_Word (D) & Close_Inst & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Types) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Element),
        Post => Pool_Instance'Result'First = 1
                and then Pool_Instance'Result'Length = With_Word'Length + Pool_Pkg_Name'Length + Semicolon'Length + 1 + With_Word'Length + Types'Length + Semicolon'Length + 1 + Package_Word'Length + Name'Length + Is_New'Length + Pool_Pkg_Name'Length + Pool_Gen'Length + Types'Length + Dot'Length + Element'Length + Discipline_Key'Length + Discipline_Word (D)'Length + Close_Inst'Length + 1;

   function With_Clause (Name : String) return String
   is (With_Word & Name & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => With_Clause'Result'First = 1
                and then With_Clause'Result'Length = Name'Length + With_Word'Length + Semicolon'Length + 1;

   function Template_Head (Name : String; Discharge : String) return String
   is (LF & Procedure_Word & Name & Is_Word & LF & Discharge_Comment & Discharge & LF & Begin_Line & LF & Slot_Begin (Body_Name) & Null_Stmt & LF & Slot_End (Body_Name))
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Discharge'First = 1 and then Discharge'Length <= 1024,
        Post => Template_Head'Result'First = 1
                and then Template_Head'Result'Length = 1 + Procedure_Word'Length + Name'Length + Is_Word'Length + 1 + Discharge_Comment'Length + Discharge'Length + 1 + Begin_Line'Length + 1 + Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Body_Name'Length + Close_Paren'Length + 1 + Null_Stmt'Length + 1 + Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Body_Name'Length + Close_Paren'Length + 1;

   function Template_Tail (Name : String) return String
   is (End_Word & Name & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Template_Tail'Result'First = 1
                and then Template_Tail'Result'Length = End_Word'Length + Name'Length + Semicolon'Length + 1;

   function Prompt_Line (Name : String; Discharge : String) return String
   is (Prompt_Head & Name & Prompt_Sep & Discharge & Prompt_Tail & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Discharge'First = 1 and then Discharge'Length <= 1024,
        Post => Prompt_Line'Result'First = 1
                and then Prompt_Line'Result'Length = Prompt_Head'Length + Name'Length + Prompt_Sep'Length + Discharge'Length + Prompt_Tail'Length + 1;

   function Carried_Header return String
   is (Name_Column & HT & Digest_Column & HT & Home_Column & LF)
   with Global => null,
        Post => Carried_Header'Result'First = 1
                and then Carried_Header'Result'Length = Name_Column'Length + 1 + Digest_Column'Length + 1 + Home_Column'Length + 1;

   function Carried_Row (Stem : String; Digest : String) return String
   is (Stem & Ads_Suffix & HT & Digest & HT & Emitted_Word & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Stem) and then Digest'First = 1 and then Digest'Length = 64,
        Post => Carried_Row'Result'First = 1
                and then Carried_Row'Result'Length = Stem'Length + Ads_Suffix'Length + 1 + Digest'Length + 1 + Emitted_Word'Length + 1;

   Context_Name : constant String := "context";

   function Context_Slot return String
   is (Slot_Begin (Context_Name) & Slot_End (Context_Name))
   with Global => null,
        Post => Context_Slot'Result'First = 1
                and then Context_Slot'Result'Length = Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Context_Name'Length + Close_Paren'Length + 1 + Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Context_Name'Length + Close_Paren'Length + 1;

   Initial_Prefix          : constant String := "Initial_";
   Colon_Constant          : constant String := " : constant ";
   Null_Aggregate          : constant String := " := (null record);";
   Wiring_Pkg_Name         : constant String := "Channel_Wiring_Pkg";
   Pool_Wiring_Pkg_Name    : constant String := "Pool_Wiring_Pkg";
   Wire_Suffix             : constant String := "_Wire";
   Store_Suffix            : constant String := "_Store";
   Wiring_Gen_Q            : constant String := ".Wiring (Q => ";
   Wiring_Gen_P            : constant String := ".Wiring (P => ";
   Initial_Key             : constant String := ", Initial => ";
   Port_Suffix             : constant String := "_Port";
   Colon                   : constant String := " : ";
   In_Out                  : constant String := "in out ";
   Wire_Type               : constant String := "Wire";
   Store_Type              : constant String := "Store";
   Open_Paren              : constant String := "(";
   Comma_Space             : constant String := ", ";
   Task_Word               : constant String := "task ";
   Task_Body_Words         : constant String := "task body ";
   Task_Suffix             : constant String := "_Task";
   Stage_Suffix            : constant String := "_Stage";
   Main_Suffix             : constant String := "_Main";
   Elaborate_Body          : constant String := " with Elaborate_Body is";
   Package_Body_Words      : constant String := "package body ";
   Null_Word               : constant String := "null;";

   function Type_Slot_With_Initial (Element : String) return String
   is (Slot_Begin (Type_Prefix & Element) & Indent & Type_Word & Element & Null_Record & LF & Indent & Initial_Prefix & Element & Colon_Constant & Element & Null_Aggregate & LF & Slot_End (Type_Prefix & Element))
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Element),
        Post => Type_Slot_With_Initial'Result'First = 1
                and then Type_Slot_With_Initial'Result'Length = Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Type_Prefix'Length + Element'Length + Close_Paren'Length + 1 + Indent'Length + Type_Word'Length + Element'Length + Null_Record'Length + 1 + Indent'Length + Initial_Prefix'Length + Element'Length + Colon_Constant'Length + Element'Length + Null_Aggregate'Length + 1 + Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Type_Prefix'Length + Element'Length + Close_Paren'Length + 1;

   function Wire_Instance (Name, Types, Element : String) return String
   is (With_Word & Wiring_Pkg_Name & Semicolon & LF & With_Word & Name & Semicolon & LF & With_Word & Types & Semicolon & LF & Package_Word & Name & Wire_Suffix & Is_New & Wiring_Pkg_Name & Wiring_Gen_Q & Name & Initial_Key & Types & Dot & Initial_Prefix & Element & Close_Inst & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Types) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Element),
        Post => Wire_Instance'Result'First = 1
                and then Wire_Instance'Result'Length = With_Word'Length + Wiring_Pkg_Name'Length + Semicolon'Length + 1 + With_Word'Length + Name'Length + Semicolon'Length + 1 + With_Word'Length + Types'Length + Semicolon'Length + 1 + Package_Word'Length + Name'Length + Wire_Suffix'Length + Is_New'Length + Wiring_Pkg_Name'Length + Wiring_Gen_Q'Length + Name'Length + Initial_Key'Length + Types'Length + Dot'Length + Initial_Prefix'Length + Element'Length + Close_Inst'Length + 1;

   function Store_Instance (Name, Types, Element : String) return String
   is (With_Word & Pool_Wiring_Pkg_Name & Semicolon & LF & With_Word & Name & Semicolon & LF & With_Word & Types & Semicolon & LF & Package_Word & Name & Store_Suffix & Is_New & Pool_Wiring_Pkg_Name & Wiring_Gen_P & Name & Initial_Key & Types & Dot & Initial_Prefix & Element & Close_Inst & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Types) and then Mascot_Emit_Pkg.Is_Ada_Identifier (Element),
        Post => Store_Instance'Result'First = 1
                and then Store_Instance'Result'Length = With_Word'Length + Pool_Wiring_Pkg_Name'Length + Semicolon'Length + 1 + With_Word'Length + Name'Length + Semicolon'Length + 1 + With_Word'Length + Types'Length + Semicolon'Length + 1 + Package_Word'Length + Name'Length + Store_Suffix'Length + Is_New'Length + Pool_Wiring_Pkg_Name'Length + Wiring_Gen_P'Length + Name'Length + Initial_Key'Length + Types'Length + Dot'Length + Initial_Prefix'Length + Element'Length + Close_Inst'Length + 1;

   function Wire_Object (Name, Buffer : String) return String
   is (Indent & Name & Port_Suffix & Colon & Name & Wire_Suffix & Dot & Wire_Type & Open_Paren & Buffer & Close_Paren & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name) and then Mascot_Emit_Pkg.Positive_Digits (Buffer),
        Post => Wire_Object'Result'First = 1
                and then Wire_Object'Result'Length = Indent'Length + Name'Length + Port_Suffix'Length + Colon'Length + Name'Length + Wire_Suffix'Length + Dot'Length + Wire_Type'Length + Open_Paren'Length + Buffer'Length + Close_Paren'Length + Semicolon'Length + 1;

   function Store_Object (Name : String) return String
   is (Indent & Name & Port_Suffix & Colon & Name & Store_Suffix & Dot & Store_Type & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Store_Object'Result'First = 1
                and then Store_Object'Result'Length = Indent'Length + Name'Length + Port_Suffix'Length + Colon'Length + Name'Length + Store_Suffix'Length + Dot'Length + Store_Type'Length + Semicolon'Length + 1;

   function Leaf_Open (Name : String) return String
   is (LF & Procedure_Word & Name & LF & Indent & Open_Paren)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Leaf_Open'Result'First = 1
                and then Leaf_Open'Result'Length = 1 + Procedure_Word'Length + Name'Length + 1 + Indent'Length + Open_Paren'Length;

   function Port_Parameter (Name : String; Is_Pool : Boolean) return String
   is (Name & Port_Suffix & Colon & In_Out & Name & (if Is_Pool then Store_Suffix & Dot & Store_Type else Wire_Suffix & Dot & Wire_Type))
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Port_Parameter'Result'First = 1
                and then Port_Parameter'Result'Length = Name'Length + Port_Suffix'Length + Colon'Length + In_Out'Length + Name'Length + (if Is_Pool then Store_Suffix'Length + Dot'Length + Store_Type'Length else Wire_Suffix'Length + Dot'Length + Wire_Type'Length);

   function Parameter_Separator return String
   is (Semicolon & LF & Indent & Indent)
   with Global => null,
        Post => Parameter_Separator'Result'First = 1
                and then Parameter_Separator'Result'Length = Semicolon'Length + 1 + Indent'Length + Indent'Length;

   function Leaf_Close (Discharge : String) return String
   is (Close_Paren & Is_Word & LF & Discharge_Comment & Discharge & LF & Begin_Line & LF & Slot_Begin (Body_Name) & Null_Stmt & LF & Slot_End (Body_Name))
   with Global => null,
        Pre  => Discharge'First = 1 and then Discharge'Length <= 1024,
        Post => Leaf_Close'Result'First = 1
                and then Leaf_Close'Result'Length = Close_Paren'Length + Is_Word'Length + 1 + Discharge_Comment'Length + Discharge'Length + 1 + Begin_Line'Length + 1 + Indent'Length + Marker_Prefix'Length + Begin_Word'Length + Body_Name'Length + Close_Paren'Length + 1 + Null_Stmt'Length + 1 + Indent'Length + Marker_Prefix'Length + End_Marker_Word'Length + Body_Name'Length + Close_Paren'Length + 1;

   function Stage_Spec (System : String) return String
   is (Package_Word & System & Stage_Suffix & Elaborate_Body & LF & End_Word & System & Stage_Suffix & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Stage_Spec'Result'First = 1
                and then Stage_Spec'Result'Length = Package_Word'Length + System'Length + Stage_Suffix'Length + Elaborate_Body'Length + 1 + End_Word'Length + System'Length + Stage_Suffix'Length + Semicolon'Length + 1;

   function Stage_Body_Head (System : String) return String
   is (Package_Body_Words & System & Stage_Suffix & Is_Word & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Stage_Body_Head'Result'First = 1
                and then Stage_Body_Head'Result'Length = Package_Body_Words'Length + System'Length + Stage_Suffix'Length + Is_Word'Length + 1;

   function Task_Declaration (Name : String) return String
   is (Indent & Task_Word & Name & Task_Suffix & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Task_Declaration'Result'First = 1
                and then Task_Declaration'Result'Length = Indent'Length + Task_Word'Length + Name'Length + Task_Suffix'Length + Semicolon'Length + 1;

   function Task_Body_Open (Name : String) return String
   is (Indent & Task_Body_Words & Name & Task_Suffix & Is_Word & LF & Indent & Begin_Line & LF & Indent & Indent & Name & Open_Paren)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Task_Body_Open'Result'First = 1
                and then Task_Body_Open'Result'Length = Indent'Length + Task_Body_Words'Length + Name'Length + Task_Suffix'Length + Is_Word'Length + 1 + Indent'Length + Begin_Line'Length + 1 + Indent'Length + Indent'Length + Name'Length + Open_Paren'Length;

   function Port_Actual (Name : String) return String
   is (Name & Port_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Port_Actual'Result'First = 1
                and then Port_Actual'Result'Length = Name'Length + Port_Suffix'Length;

   function Task_Body_Close (Name : String) return String
   is (Close_Paren & Semicolon & LF & Indent & End_Word & Name & Task_Suffix & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Task_Body_Close'Result'First = 1
                and then Task_Body_Close'Result'Length = Close_Paren'Length + Semicolon'Length + 1 + Indent'Length + End_Word'Length + Name'Length + Task_Suffix'Length + Semicolon'Length + 1;

   function Stage_Body_Tail (System : String) return String
   is (End_Word & System & Stage_Suffix & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Stage_Body_Tail'Result'First = 1
                and then Stage_Body_Tail'Result'Length = End_Word'Length + System'Length + Stage_Suffix'Length + Semicolon'Length + 1;

   function Stage_Main (System : String) return String
   is (Procedure_Word & System & Main_Suffix & Is_Word & LF & Begin_Line & LF & Indent & Null_Word & LF & End_Word & System & Main_Suffix & Semicolon & LF)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Stage_Main'Result'First = 1
                and then Stage_Main'Result'Length = Procedure_Word'Length + System'Length + Main_Suffix'Length + Is_Word'Length + 1 + Begin_Line'Length + 1 + Indent'Length + Null_Word'Length + 1 + End_Word'Length + System'Length + Main_Suffix'Length + Semicolon'Length + 1;

   Slash               : constant String := "/";
   Types_File_Suffix   : constant String := "_types.ads";
   Template_File       : constant String := "template.adb";
   Prompt_File         : constant String := "planner-prompt.txt";
   Carried_File        : constant String := "carried.tsv";

   function Lower (C : Character) return Character
   is ((if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C))
   with Global => null;

   function Stem_Of (Name : String) return String
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Stem_Of'Result'First = 1
                and then Stem_Of'Result'Length = Name'Length
                and then (for all K in Name'Range => Stem_Of'Result (K) = Lower (Name (K)));

   function Unit_File (Name : String) return String
   is (Stem_Of (Name) & Ads_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Unit_File'Result'First = 1
                and then Unit_File'Result'Length = Name'Length + Ads_Suffix'Length;

   function Types_File (System_Ada : String) return String
   is (Stem_Of (System_Ada) & Types_File_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System_Ada),
        Post => Types_File'Result'First = 1
                and then Types_File'Result'Length = System_Ada'Length + Types_File_Suffix'Length;

   function Path_Join (Dir : String; Name : String) return String
   is (Dir & Slash & Name)
   with Global => null,
        Pre  => Dir'First = 1 and then Dir'Length >= 1 and then Dir'Length <= 1024
                and then Name'First = 1 and then Name'Length >= 1 and then Name'Length <= 256,
        Post => Path_Join'Result'First = 1
                and then Path_Join'Result'Length = Dir'Length + Slash'Length + Name'Length;

   Types_Suffix : constant String := "_Types";
   Adb_Suffix   : constant String := ".adb";

   function Wire_Unit_Name (Name : String) return String
   is (Name & Wire_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Wire_Unit_Name'Result'First = 1 and then Wire_Unit_Name'Result'Length = Name'Length + Wire_Suffix'Length;

   function Store_Unit_Name (Name : String) return String
   is (Name & Store_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Store_Unit_Name'Result'First = 1 and then Store_Unit_Name'Result'Length = Name'Length + Store_Suffix'Length;

   function Types_Unit_Name (System : String) return String
   is (System & Types_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Types_Unit_Name'Result'First = 1 and then Types_Unit_Name'Result'Length = System'Length + Types_Suffix'Length;

   function Stage_Unit_Name (System : String) return String
   is (System & Stage_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Stage_Unit_Name'Result'First = 1 and then Stage_Unit_Name'Result'Length = System'Length + Stage_Suffix'Length;

   function Main_Unit_Name (System : String) return String
   is (System & Main_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (System),
        Post => Main_Unit_Name'Result'First = 1 and then Main_Unit_Name'Result'Length = System'Length + Main_Suffix'Length;

   function Body_File (Name : String) return String
   is (Stem_Of (Name) & Adb_Suffix)
   with Global => null,
        Pre  => Mascot_Emit_Pkg.Is_Ada_Identifier (Name),
        Post => Body_File'Result'First = 1 and then Body_File'Result'Length = Name'Length + Adb_Suffix'Length;

   function Actual_Separator return String
   is (Comma_Space)
   with Global => null,
        Post => Actual_Separator'Result'First = 1 and then Actual_Separator'Result'Length = Comma_Space'Length;

end Mascot_Emit_Text_Pkg;
