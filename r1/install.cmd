@echo off
chcp 65001 >nul
title CÀI ĐẶT & QUẢN TRỊ LOA PHICOMM R1 (WINDOWS)
color 0B

echo ==========================================================
echo    ĐANG KHỞI CHẠY BỘ CÀI ĐẶT PHICOMM R1 V2 (WINDOWS)...
echo ==========================================================
echo.

:: 1. Ưu tiên PowerShell 7 (pwsh) nếu máy đã cài, nếu không dùng Windows PowerShell 5.1
set "PS_BIN=powershell"
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    set "PS_BIN=pwsh"
)

:: 2. Khởi chạy install.ps1 với quyền Bypass ExecutionPolicy
"%PS_BIN%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if %errorlevel% neq 0 (
    echo.
    echo [*] Thử chạy bằng phương thức đọc trực tiếp ScriptBlock...
    "%PS_BIN%" -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content '%~dp0install.ps1' -Raw)))" %*
)

if %errorlevel% neq 0 (
    echo.
    echo ==========================================================
    echo [LỖI] Không thể khởi chạy script PowerShell.
    echo Vui lòng mở PowerShell và gõ:
    echo Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
    echo ==========================================================
    pause
)
