 * Welche Module sollen vom vorherigen mbs noch übernommen werden?
 * Bisherige Funktionen in mbs2 aufteilen auf mehrere Module?
 * Lua Script "import_mbs" in mbs2 local Ordner hinzufügen:
 * Statt den "load" Befehl "require" verwenden? 
   * Lua package paths erweitern mit einem Modul? 
   * Oder mit "import_mbs" den chunk einzelner Module laden?
   *  "import_mbs" muss über jonchki in target/jonchki/install hinzugefügt werden
* LDOC hinzufpügen
* github page als Doku hinzufügen
* Download von Dateien ".mbs/depack/org.gnu.gcc/" automatisieren
* Path von Objdump, Objcopy und Elf automatisch im tEnv Object in atVars hinzufügen
* Input Argumente überprüfen auf Fehler - bei allen Funktionen überprüfen
  * Auch allgemeine Fehlererkennung überprüfen und ggf. hinzufügen
* setup.json hinzufügen - auslesen und überprüfen der setup file
* build.properties hinzufügen - auslesen und überprüfen der build.properties file
* setup.json und build.properties in einer File?
* Builder Scripte umbauen:
  * Funktionen von tEnv und BAM/AddJob separieren in 2 Modulen
  * builder_{NAME} und jobEnv_{NAME}
  * AddBuilder nicht mehr notwendig? - wegen package.path? -- Pfade müssen weiterhin angegeben werden wegen AddJob
* Tools Scripte umbauen - keine Übergabeparameter mehr - nur ein Rückgabe Objekt - per __init tEnv vererben