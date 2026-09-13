--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Mascot_Emit_Pkg lineage 4 (2026-09-13): lineage 3 verbatim plus the discharge facts — Max_Discharge (1000),
--  Has_Discharge and Discharge_Of over the scanner's Key_Discharge with the line's bound, so a leaf template
--  carries its discharge SENTENCE (the identifier-bounded Has_Text read every sentence as absent). Lane
--  wu-crucible-mascot-emit-4 round A, planner qwen3.8-27b-ada:v0.3, accepted first round, 0 unproved, 151 GPU s;
--  body (Ada_Name) carried unchanged. Never hand-edited. Comment-stripped sha equals the round-A spec.
with Json_Scan_Pkg;
with Mascot_Measure_Pkg;
with Mascot_Scan_Pkg;
with Pool_Pkg;

package Mascot_Emit_Pkg with SPARK_Mode is

   use type Json_Scan_Pkg.Kind_Type;

   Max_Name : constant Natural := 64;

   Key_Discipline : constant String := "discipline";
   Lit_Set_Once : constant String := "set_once";
   Lit_Read_Mostly : constant String := "read_mostly";

   function Is_Letter (C : Character) return Boolean
   is (C in 'a' .. 'z' or else C in 'A' .. 'Z')
   with Global => null;

   function Is_Digit (C : Character) return Boolean
   is (C in '0' .. '9')
   with Global => null;

   function Is_Separator (C : Character) return Boolean
   is (C = '-' or else C = '_' or else C = ' ')
   with Global => null;

   function Upper (C : Character) return Character
   is ((if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C))
   with Global => null;

   function Nameable (S : String) return Boolean
   is (S'First = 1 and then S'Length >= 1 and then S'Length <= Max_Name and then Is_Letter (S (S'First)) and then (for all K in S'Range => Is_Letter (S (K)) or else Is_Digit (S (K)) or else Is_Separator (S (K))) and then not Is_Separator (S (S'Last)) and then (for all K in S'First + 1 .. S'Last => not (Is_Separator (S (K)) and then Is_Separator (S (K - 1)))))
   with Global => null;

   function Is_Ada_Identifier (S : String) return Boolean
   is (Nameable (S) and then (for all K in S'Range => S (K) /= '-' and then S (K) /= ' '))
   with Global => null;

   function Positive_Digits (S : String) return Boolean
   is (S'First = 1 and then S'Length >= 1 and then S'Length <= 9 and then (for all K in S'Range => Is_Digit (S (K))) and then S (S'First) /= '0')
   with Global => null;

   function Ada_Name (S : String) return String
   with Global => null,
        Pre  => Nameable (S),
        Post => Ada_Name'Result'First = 1
                and then Ada_Name'Result'Length = S'Length
                and then (for all K in S'Range =>
                           Ada_Name'Result (K) = (if Is_Separator (S (K)) then '_'
                                                  elsif K = S'First or else Is_Separator (S (K - 1)) then Upper (S (K))
                                                  else S (K)));

   function Has_Text (L : Mascot_Scan_Pkg.Line_Rec; Key : String) return Boolean
   is (Mascot_Scan_Pkg.Present (L, Key) and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).last - Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).first >= 2 and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).last - Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).first <= Max_Name + 1)
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Text_Of (L : Mascot_Scan_Pkg.Line_Rec; Key : String) return String
   is (Mascot_Scan_Pkg.Slice_Of (L, Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then Has_Text (L, Key),
        Post   => Text_Of'Result'First = 1 and then Text_Of'Result'Length >= 1 and then Text_Of'Result'Length <= Max_Name;

   function Says (L : Mascot_Scan_Pkg.Line_Rec; Key : String; Lit : String) return Boolean
   is (Has_Text (L, Key) and then Json_Scan_Pkg.Equals_Literal (L.Text (1 .. L.Len), Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key)), Lit))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then Lit'First = 1 and then Lit'Length >= 1 and then Lit'Length <= 64;

   Max_Discharge : constant Natural := 1000;

   function Has_Discharge (L : Mascot_Scan_Pkg.Line_Rec) return Boolean
   is (Mascot_Scan_Pkg.Present (L, Mascot_Scan_Pkg.Key_Discharge) and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge).last - Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge).first >= 2 and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge).last - Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge).first <= Max_Discharge + 1)
   with Global => null;

   function Discharge_Of (L : Mascot_Scan_Pkg.Line_Rec) return String
   is (Mascot_Scan_Pkg.Slice_Of (L, Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Mascot_Scan_Pkg.Key_Discharge))))
   with Global => null,
        Pre  => Has_Discharge (L),
        Post => Discharge_Of'Result'First = 1 and then Discharge_Of'Result'Length >= 1 and then Discharge_Of'Result'Length <= Max_Discharge;

   function Id_Nameable (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Has_Text (S.Lines (I), Mascot_Scan_Pkg.Key_Id) and then Nameable (Text_Of (S.Lines (I), Mascot_Scan_Pkg.Key_Id)))
   with Global => null,
        Pre    => I <= S.Count;

   function Element_Ok (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Has_Text (S.Lines (I), Mascot_Scan_Pkg.Key_Element) and then Is_Ada_Identifier (Text_Of (S.Lines (I), Mascot_Scan_Pkg.Key_Element)))
   with Global => null,
        Pre    => I <= S.Count;

   function Buffer_Ok (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Has_Text (S.Lines (I), Mascot_Scan_Pkg.Key_Buffer) and then Positive_Digits (Text_Of (S.Lines (I), Mascot_Scan_Pkg.Key_Buffer)))
   with Global => null,
        Pre    => I <= S.Count;

   function Discipline_Of (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Pool_Pkg.Discipline_Kind
   is ((if Says (S.Lines (I), Key_Discipline, Lit_Set_Once) then Pool_Pkg.Set_Once elsif Says (S.Lines (I), Key_Discipline, Lit_Read_Mostly) then Pool_Pkg.Read_Mostly else Pool_Pkg.Read_Write))
   with Global => null,
        Pre    => I <= S.Count;

   function Ref_Of (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Mascot_Measure_Pkg.Node_Ref
   is (Mascot_Scan_Pkg.Find_Ref (S, I, Key, S.Count))
   with Global => null,
        Pre    => I <= S.Count and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Declared (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Boolean
   is (Mascot_Scan_Pkg.Every_Word_Declared (S, I, Key))
   with Global => null,
        Pre    => I <= S.Count and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Plumbing (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Boolean
   is (Mascot_Scan_Pkg.Every_Word_Plumbing (S, I, Key))
   with Global => null,
        Pre    => I <= S.Count and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Withs (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index; J : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Mascot_Scan_Pkg.Refers (S, I, Mascot_Scan_Pkg.Key_Reads, J)
     or else Mascot_Scan_Pkg.Refers (S, I, Mascot_Scan_Pkg.Key_Writes, J)
     or else Mascot_Scan_Pkg.Refers (S, I, Mascot_Scan_Pkg.Key_Reports, J)
     or else Mascot_Scan_Pkg.Refers (S, I, Mascot_Scan_Pkg.Key_Accessed, J))
   with Global => null,
        Pre    => I <= S.Count and then J <= S.Count;

   function Same_Element (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index; J : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Has_Text (S.Lines (I), Mascot_Scan_Pkg.Key_Element) and then Has_Text (S.Lines (J), Mascot_Scan_Pkg.Key_Element) and then Mascot_Scan_Pkg.Same_Id (S.Lines (I), S.Lines (J), Json_Scan_Pkg.String_Contents (S.Lines (I).Text (1 .. S.Lines (I).Len), Json_Scan_Pkg.Value_Span (S.Lines (I).Text (1 .. S.Lines (I).Len), Mascot_Scan_Pkg.Key_Element)), Mascot_Scan_Pkg.Key_Element))
   with Global => null,
        Pre    => I <= S.Count and then J <= S.Count;

   function First_Of_Its_Element (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Has_Text (S.Lines (I), Mascot_Scan_Pkg.Key_Element) and then (for all J in 1 .. I - 1 => not Same_Element (S, I, J)))
   with Global => null,
        Pre    => I <= S.Count;

   type Fault_Kind is (No_Fault, Id_Not_Nameable, Element_Not_Identifier, Buffer_Not_Positive, Reference_Undeclared, Reference_Not_Plumbing);

   function Line_Fault (S : Mascot_Scan_Pkg.Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Fault_Kind
   is ((if not Id_Nameable (S, I) then Id_Not_Nameable elsif (Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Channel) or else Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Pool)) and then not Element_Ok (S, I) then Element_Not_Identifier elsif Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Channel) and then not Buffer_Ok (S, I) then Buffer_Not_Positive elsif Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Activity) and then not (Declared (S, I, Mascot_Scan_Pkg.Key_Reads) and then Declared (S, I, Mascot_Scan_Pkg.Key_Writes) and then Declared (S, I, Mascot_Scan_Pkg.Key_Reports) and then Declared (S, I, Mascot_Scan_Pkg.Key_Accessed)) then Reference_Undeclared elsif Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Activity) and then not (Plumbing (S, I, Mascot_Scan_Pkg.Key_Reads) and then Plumbing (S, I, Mascot_Scan_Pkg.Key_Writes) and then Plumbing (S, I, Mascot_Scan_Pkg.Key_Reports) and then Plumbing (S, I, Mascot_Scan_Pkg.Key_Accessed)) then Reference_Not_Plumbing else No_Fault))
   with Global => null,
        Pre    => I <= S.Count,
        Post   => (if Line_Fault'Result = No_Fault then
                     Id_Nameable (S, I)
                     and then (if Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Channel)
                                  or else Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Pool)
                               then Element_Ok (S, I))
                     and then (if Mascot_Scan_Pkg.Kind_Is (S.Lines (I), Mascot_Scan_Pkg.Lit_Channel)
                               then Buffer_Ok (S, I)));

   function Faulty_Line (S : Mascot_Scan_Pkg.Line_Set; Upto : Mascot_Measure_Pkg.Node_Count) return Mascot_Measure_Pkg.Node_Ref
   is ((if Upto = 0 then 0 elsif Line_Fault (S, Upto) /= No_Fault then Upto else Faulty_Line (S, Upto - 1)))
   with Global => null,
        Pre    => Upto <= S.Count,
        Subprogram_Variant => (Decreases => Upto),
        Post   => Faulty_Line'Result <= Upto
                 and then (if Faulty_Line'Result /= 0 then Line_Fault (S, Faulty_Line'Result) /= No_Fault)
                 and then (if Faulty_Line'Result = 0 then (for all I in 1 .. Upto => Line_Fault (S, I) = No_Fault));

   function Emit_Ok (S : Mascot_Scan_Pkg.Line_Set) return Boolean
   is (Faulty_Line (S, S.Count) = 0)
   with Global => null,
        Post   => Emit_Ok'Result = (for all I in 1 .. S.Count => Line_Fault (S, I) = No_Fault);

   function Fault_Of (S : Mascot_Scan_Pkg.Line_Set) return Fault_Kind
   is ((if Faulty_Line (S, S.Count) = 0 then No_Fault else Line_Fault (S, Faulty_Line (S, S.Count))))
   with Global => null,
        Post   => (Fault_Of'Result = No_Fault) = Emit_Ok (S);

end Mascot_Emit_Pkg;
