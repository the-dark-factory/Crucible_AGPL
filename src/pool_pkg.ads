package Pool_Pkg with SPARK_Mode is

   type Discipline_Kind is (Read_Mostly, Read_Write, Set_Once);

   generic
      type State_Type is private;
      Discipline : Discipline_Kind;
   package Pool is

      type Pool_Type is record
         Value  : State_Type;
         Writes : Natural;
      end record;

      function Read (P : Pool_Type) return State_Type is (P.Value)
        with Global => null;

      function Write_Count (P : Pool_Type) return Natural is (P.Writes)
        with Global => null;

      function Access_Discipline return Discipline_Kind is (Discipline)
        with Global => null;

      function May_Write (P : Pool_Type) return Boolean is
        ((if Discipline = Set_Once then P.Writes = 0 else True))
        with Global => null;

      function Write (P : Pool_Type; V : State_Type) return Pool_Type is
        ((P with delta Value => V, Writes => P.Writes + 1))
        with Pre  => May_Write (P) and then P.Writes < Natural'Last,
             Post => Read (Write'Result) = V
                     and then Write_Count (Write'Result) = P.Writes + 1,
             Global => null;

   end Pool;

   package Reference is new Pool (State_Type => Integer, Discipline => Read_Mostly);

end Pool_Pkg;
