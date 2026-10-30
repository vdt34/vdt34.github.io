@echo off
chcp 65001 >nul
title CÀI ĐẶT PHICOMM R1 - WINDOWS
color 0B

echo ==========================================================
echo    ĐANG KHỞI CHẠY BỘ CÀI ĐẶT PHICOMM R1 TRÊN WINDOWS...
echo ==========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [*] Thử chạy trực tiếp qua môi trường PowerShell...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content '%~dp0install.ps1' -Raw)))"
)
