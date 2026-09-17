--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e4d2c53036aa59f4d1923f77ad7a4b7ddf4adbd963b2269ebd7bb3866b78e1f4
--
with Unit_Extract_Pkg;

package Body_Unit_Pkg with SPARK_Mode is

   function Names_Body (Text : String; From : Positive; Name : String) return Boolean
     is ((for some I in From .. Text'Length =>
             Unit_Extract_Pkg.Starts_With_CI (Text, I, "package ")
             and then
           Unit_Extract_Pkg.Starts_With_CI (Text, I + 8, "body ")
             and then
           Unit_Extract_Pkg.Starts_With_CI (Text, I + 13, Name)
             and then
           I + 13 + Name'Length <= Text'Length
             and then
           Unit_Extract_Pkg.Is_Space (Text (I + 13 + Name'Length))))
     with Pre =>
       Text'First = 1
       and then
       Text'Length <= Unit_Extract_Pkg.Max_Text
       and then
       From <= Text'Length + 1
       and then
       Name'First = 1
       and then
       Name'Length >= 1
       and then
       Name'Length <= Unit_Extract_Pkg.Max_Name;

   function Is_Body (Text : String; Name : String) return Boolean
     is (Unit_Extract_Pkg.Is_Ascii (Text)
         and then
         Unit_Extract_Pkg.First_Content (Text, Unit_Extract_Pkg.After_Think (Text)) <= Text'Length
           and then
         Unit_Extract_Pkg.Begins_Unit (Text, Unit_Extract_Pkg.First_Content (Text, Unit_Extract_Pkg.After_Think (Text)))
           and then
         Names_Body (Text, Unit_Extract_Pkg.First_Content (Text, Unit_Extract_Pkg.After_Think (Text)), Name)
           and then
         Unit_Extract_Pkg.Last_Content (Text) >= 1
           and then
         Unit_Extract_Pkg.Ends_Unit (Text, Unit_Extract_Pkg.Last_Content (Text), Name))
     with Pre =>
       Text'First = 1
       and then
       Text'Length <= Unit_Extract_Pkg.Max_Text
       and then
       Name'First = 1
       and then
       Name'Length >= 1
       and then
       Name'Length <= Unit_Extract_Pkg.Max_Name,
          Post =>
            (if Is_Body'Result then Names_Body (Text, Unit_Extract_Pkg.First_Content (Text, Unit_Extract_Pkg.After_Think (Text)), Name))
            and then
            (if Is_Body'Result then Unit_Extract_Pkg.Ends_Unit (Text, Unit_Extract_Pkg.Last_Content (Text), Name))
            and then
            (if not Unit_Extract_Pkg.Is_Ascii (Text) then not Is_Body'Result);

end Body_Unit_Pkg;
