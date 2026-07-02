; teapod_connect.ahk
WinWait, TeapodStream,, 10
if !WinExist("TeapodStream")
{
    MsgBox, Окно TeapodStream не найдено
    ExitApp
}
WinActivate
WinWaitActive
Sleep 1000
; Ищем кнопку Connect/Подключиться/Стоп и кликаем
CoordMode, Pixel, Window
CoordMode, Mouse, Window
; Пробуем найти кнопку по тексту
if WinExist("TeapodStream")
{
    ; Кликаем в область кнопки (центр окна, нижняя часть)
    WinGetPos,,, WinW, WinH
    btnX := WinW / 2
    btnY := WinH * 0.65
    Click, %btnX%, %btnY%
}