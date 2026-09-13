--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Mascot_Emit_Text_Pkg lineage 2 (2026-09-13): lineage 1 verbatim plus the file-name facts the writer's
--  accepted MASCOT named as a gap on this core — Lower, Stem_Of (body-filled, character-wise Post), Unit_File,
--  Types_File, Path_Join and the five file-name literals. Lane wu-crucible-mascot-emit-text-2 round A,
--  planner qwen3.8-27b-ada:v0.3, accepted first round, 0 unproved, 132 GPU s. Never hand-edited.
--  Comment-stripped sha equals the round-A spec.
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

end Mascot_Emit_Text_Pkg;
