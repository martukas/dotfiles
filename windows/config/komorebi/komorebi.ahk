#SingleInstance Force

; Load library
#Include komorebic.lib.ahk
; Load configuration
#Include komorebi.generated.ahk
#Include komorebi.custom.ahk

; Send the ALT key whenever changing focus to force focus changes
AltFocusHack("enable")
; Default to cloaking windows when switching workspaces
WindowHidingBehaviour("cloak")
; Set cross-monitor move behaviour to insert instead of swap
CrossMonitorMoveBehaviour("Insert")
; Enable hot reloading of changes to this file
WatchConfiguration("enable")

; Create named workspaces I-V on monitor 0
EnsureNamedWorkspaces(0, "I II III IV V")
; You can do the same thing for secondary monitors too
; EnsureNamedWorkspaces(1, "A B C D E F")

; Assign layouts to workspaces, possible values: bsp, columns, rows, vertical-stack, horizontal-stack, ultrawide-vertical-stack
NamedWorkspaceLayout("I", "bsp")

; Set the gaps around the edge of the screen for a workspace
NamedWorkspacePadding("I", 1)
; Set the gaps between the containers for a workspace
NamedWorkspaceContainerPadding("I", 1)

; You can assign specific apps to named workspaces
; NamedWorkspaceRule("exe", "Firefox.exe", "III")

; Configure the invisible border dimensions
InvisibleBorders(0, 0, 0, 0)

; Uncomment the next lines if you want a visual border around the active window
; ActiveWindowBorder("enable")
; ActiveWindowBorderColour(26, 66, 98, "single")
; ActiveWindowBorderColour(66, 165, 245, "single")
; ActiveWindowBorderColour(256, 165, 66, "stack")
; ActiveWindowBorderColour(255, 51, 153, "monocle")

CompleteConfiguration()

; Move windows
<!<^<#Left::Move("left")
<!<^<#Down::Move("down")
<!<^<#Up::Move("up")
<!<^<#Right::Move("right")
<!<^<#\::Promote()

; Resize
<!<^<#-::ResizeAxis("horizontal", "increase")
<!<^<#=::ResizeAxis("horizontal", "decrease")
<!<^<#9::ResizeAxis("vertical", "increase")
<!<^<#0::ResizeAxis("vertical", "decrease")

; Manipulate windows
<!<^<#f::ToggleFloat()
<!<^<#g::ToggleMonocle()

; Window manager options
<!<^<#r::Retile()
<!<^<#t::TogglePause()

; Layouts
<!<^<#,::FlipLayout("horizontal")
<!<^<#.::FlipLayout("vertical")

; Workspaces
<!<^<#F1::FocusWorkspace(0)
<!<^<#F2::FocusWorkspace(1)
<!<^<#F3::FocusWorkspace(2)

; Move windows across workspaces
<!<^<#F5::MoveToWorkspace(0)
<!<^<#F6::MoveToWorkspace(1)
<!<^<#F7::MoveToWorkspace(2)
