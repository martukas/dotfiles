; Should load right after lib and generated

; ConEmu
RunWait('komorebic.exe float-rule exe "ConEmu64.exe"', , "Hide")
RunWait('komorebic.exe identify-tray-application exe "ConEmu64.exe"', , "Hide")

; KeePass
RunWait('komorebic.exe float-rule exe "KeePass.exe"', , "Hide")
RunWait('komorebic.exe identify-tray-application exe "KeePass.exe"', , "Hide")

; PyCharm
RunWait('komorebic.exe identify-object-name-change-application exe "pycharm64.exe"', , "Hide")
RunWait('komorebic.exe identify-border-overflow-application exe "pycharm64.exe"', , "Hide")

; CLion
RunWait('komorebic.exe identify-object-name-change-application exe "clion64.exe"', , "Hide")
RunWait('komorebic.exe identify-border-overflow-application exe "clion64.exe"', , "Hide")

; TuneIn
RunWait('komorebic.exe float-rule exe "TuneIn.exe"', , "Hide")

; Clementine
RunWait('komorebic.exe float-rule exe "clementine.exe"', , "Hide")

; Spotify
RunWait('komorebic.exe float-rule exe "Spotify.exe"', , "Hide")

; Telegram
RunWait('komorebic.exe identify-object-name-change-application exe "Telegram.exe"', , "Hide")
RunWait('komorebic.exe identify-border-overflow-application exe "Telegram.exe"', , "Hide")
RunWait('komorebic.exe identify-tray-application exe "Telegram.exe"', , "Hide")
