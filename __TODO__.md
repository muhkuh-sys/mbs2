* Welche Module sollen vom vorherigen mbs noch übernommen werden?
* Bisherige Funktionen in mbs2 aufteilen auf mehrere Module?
* LDOC hinzufpügen
* github page als Doku hinzufügen
* Download von Dateien ".mbs/depack/org.gnu.gcc/" automatisieren
* Path von Objdump, Objcopy und Elf automatisch im tEnv Object in atVars hinzufügen
* Input Argumente überprüfen auf Fehler - bei allen Funktionen überprüfen (mbs2)
  * Auch allgemeine Fehlererkennung überprüfen und ggf. hinzufügen
* setup.json hinzufügen - auslesen und überprüfen der setup file
* build.properties hinzufügen - auslesen und überprüfen der build.properties file
* setup.json und build.properties in einer File?
* Builder Scripte umbauen:
  * Funktionen von tEnv und BAM/AddJob separieren in 2 Modulen
  * builder_{NAME} und jobEnv_{NAME}
  * AddBuilder nicht mehr notwendig? - wegen package.path? -- Pfade müssen weiterhin angegeben werden wegen AddJob
* Tools Scripte umbauen - keine Übergabeparameter mehr - nur ein Rückgabe Objekt - per __init tEnv vererben
* wie in scons: "Create a compile database." mit CompileDb
* Import und SubBAM ändern -> import_mbs verwenden?
* "test build" hinzufügen, um die gebauten Dateien zu testen
* Builder in einem table zusammenfassen und am Anfang von mbs.lua hinzufügen - am Ende ein Funktion hinzufügen aller Builder im Table
* swig Abindung (siehe CMAGE lua-archive)
* Testing von Builds (siehe CMAKE lua-archive)
* find package (siehe CMAKE lua-archive) - überprüfen, ob bestimmte vorinstallierte Programme vorhanden?
* logger für mbs2