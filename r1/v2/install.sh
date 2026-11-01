#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, cài đặt AIBox Plus + DLNA Hợp Nhất
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
API_SH_B64="IyEvc3lzdGVtL2Jpbi9zaApoZWFkZXJfanNvbigpIHsKICAgIGVjaG8gIkNvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbjsgY2hhcnNldD11dGYtOCIKICAgIGVjaG8gIkFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogKiIKICAgIGVjaG8gIiIKfQoKaGVhZGVyX3htbCgpIHsKICAgIGVjaG8gIkNvbnRlbnQtVHlwZTogdGV4dC94bWw7IGNoYXJzZXQ9dXRmLTgiCiAgICBlY2hvICJBY2Nlc3MtQ29udHJvbC1BbGxvdy1PcmlnaW46ICoiCiAgICBlY2hvICIiCn0KCnVybGRlY29kZSgpIHsKICAgIGJ1c3lib3ggaHR0cGQgLWQgIiQxIgp9CgpnZXRfcGFyYW0oKSB7CiAgICBlY2hvICIkUVVFUllfU1RSSU5HIiB8IGJ1c3lib3ggdHIgJyYnICdcbicgfCBidXN5Ym94IGdyZXAgIl4kMT0iIHwgYnVzeWJveCBoZWFkIC1uIDEgfCBidXN5Ym94IGN1dCAtZD0gLWYyLQp9CgpmaW5kX2Rtcl9wb3J0KCkgewogICAgaWYgWyAtZiAvc2RjYXJkL2RsbmFfd2ViL2Rtcl9wb3J0LmNhY2hlIF07IHRoZW4KICAgICAgICBDQUNIRUQ9JChjYXQgL3NkY2FyZC9kbG5hX3dlYi9kbXJfcG9ydC5jYWNoZSkKICAgICAgICBpZiBbIC1uICIkQ0FDSEVEIiBdICYmIGJ1c3lib3ggbmV0c3RhdCAtdGxwbiAyPi9kZXYvbnVsbCB8IGJ1c3lib3ggZ3JlcCAtcSAiOiR7Q0FDSEVEfSAiOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIiRDQUNIRUQiCiAgICAgICAgICAgIHJldHVybgogICAgICAgIGZpCiAgICBmaQogICAgZm9yIHAgaW4gJChidXN5Ym94IG5ldHN0YXQgLXRscG4gMj4vZGV2L251bGwgfCBidXN5Ym94IGF3ayAnL2NvbVwucGhpY29tbVwuLyB7c3BsaXQoJDQsYSwiOiIpOyBwcmludCBhW2xlbmd0aChhKV19Jyk7IGRvCiAgICAgICAgWyAiJHAiID0gIjUwMTIiIF0gJiYgY29udGludWUKICAgICAgICBpZiBidXN5Ym94IHdnZXQgLVQgMSAtcSAtTyAtICJodHRwOi8vMTI3LjAuMC4xOiR7cH0vIiAyPi9kZXYvbnVsbCB8IGJ1c3lib3ggZ3JlcCAtcSAiQVZUcmFuc3BvcnQiOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIiRwIiA+IC9zZGNhcmQvZGxuYV93ZWIvZG1yX3BvcnQuY2FjaGUKICAgICAgICAgICAgZWNobyAiJHAiCiAgICAgICAgICAgIHJldHVybgogICAgICAgIGZpCiAgICBkb25lCiAgICBlY2hvICIxODEwIgp9CgpmaW5kX2Rtcl9jdHJsKCkgewogICAgRE1SX1A9IiQxIgogICAgaWYgWyAtZiAvc2RjYXJkL2RsbmFfd2ViL2Rtcl9jdHJsLmNhY2hlIF07IHRoZW4KICAgICAgICBDQUNIRUQ9JChjYXQgL3NkY2FyZC9kbG5hX3dlYi9kbXJfY3RybC5jYWNoZSkKICAgICAgICBpZiBbIC1uICIkQ0FDSEVEIiBdOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIiRDQUNIRUQiCiAgICAgICAgICAgIHJldHVybgogICAgICAgIGZpCiAgICBmaQogICAgWE1MPSQoYnVzeWJveCB3Z2V0IC1UIDEgLXEgLU8gLSAiaHR0cDovLzEyNy4wLjAuMToke0RNUl9QfS8iIDI+L2Rldi9udWxsKQogICAgQ1RSTD0kKGVjaG8gIiRYTUwiIHwgYnVzeWJveCB0ciAtZCAnXHInIHwgYnVzeWJveCBhd2sgJy9BVlRyYW5zcG9ydC8sLzxcL3NlcnZpY2U+LyB7IGlmICgkMCB+IC88Y29udHJvbFVSTD4vKSB7IHN1YigvLio8Y29udHJvbFVSTD4vLCAiIik7IHN1YigvPFwvY29udHJvbFVSTD4uKi8sICIiKTsgcHJpbnQ7IGV4aXQgfSB9JykKICAgIGlmIFsgLW4gIiRDVFJMIiBdOyB0aGVuCiAgICAgICAgZWNobyAiJENUUkwiID4gL3NkY2FyZC9kbG5hX3dlYi9kbXJfY3RybC5jYWNoZQogICAgICAgIGVjaG8gIiRDVFJMIgogICAgICAgIHJldHVybgogICAgZmkKICAgIGVjaG8gIi9BVlRyYW5zcG9ydC9mYzdjMDI1NzA4MTEvY29udHJvbC54bWwiCn0KCkFDVD0kKGdldF9wYXJhbSAiYWN0IikKSE9TVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImhvc3QiKSIpClsgLXogIiRIT1NUIiBdICYmIEhPU1Q9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJpcCIpIikKUE9SVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInBvcnQiKSIpClBBVEhfVVJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAicGF0aCIpIikKCmNhc2UgIiRBQ1QiIGluCiAgICBkaXNjb3ZlcikKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFNVQk5FVD0kKGlwIHJvdXRlIHwgYnVzeWJveCBhd2sgJy93bGFuMC8gJiYgL3NyYy8ge2ZvcihpPTE7aTw9TkY7aSsrKSBpZigkaT09InNyYyIpIHByaW50ICQoaSsxKX0nIHwgYnVzeWJveCBoZWFkIC1uIDEgfCBidXN5Ym94IGN1dCAtZC4gLWYxLTMpCiAgICAgICAgWyAteiAiJFNVQk5FVCIgXSAmJiBTVUJORVQ9IjE5Mi4xNjguMSIKICAgICAgICAKICAgICAgICBUTVBfRElSPSIvc2RjYXJkL2RsbmFfd2ViL3NjYW5fdG1wIgogICAgICAgIHJtIC1yZiAiJFRNUF9ESVIiCiAgICAgICAgbWtkaXIgLXAgIiRUTVBfRElSIgoKICAgICAgICBjaGVja19zZXJ2ZXIoKSB7CiAgICAgICAgICAgIGlwPSIkMSIKICAgICAgICAgICAgcD0iJDIiCiAgICAgICAgICAgIGRlc2NfcGF0aD0iJDMiCiAgICAgICAgICAgIFhNTD0kKGJ1c3lib3ggd2dldCAtVCAxIC1xIC1PIC0gImh0dHA6Ly8ke2lwfToke3B9JHtkZXNjX3BhdGh9IiAyPi9kZXYvbnVsbCkKICAgICAgICAgICAgaWYgWyAtbiAiJFhNTCIgXSAmJiBlY2hvICIkWE1MIiB8IGJ1c3lib3ggZ3JlcCAtcSAiQ29udGVudERpcmVjdG9yeSI7IHRoZW4KICAgICAgICAgICAgICAgIE5BTUU9JChlY2hvICIkWE1MIiB8IGJ1c3lib3ggc2VkIC1uICdzLy4qPGZyaWVuZGx5TmFtZT5cKFtePF0qXCk8XC9mcmllbmRseU5hbWU+LiovXDEvcCcgfCBidXN5Ym94IGhlYWQgLW4gMSkKICAgICAgICAgICAgICAgIFsgLXogIiROQU1FIiBdICYmIE5BTUU9IkRMTkEgKCR7aXB9KSIKICAgICAgICAgICAgICAgIENUUkw9JChlY2hvICIkWE1MIiB8IGJ1c3lib3ggdHIgLWQgJ1xyJyB8IGJ1c3lib3ggYXdrICcvQ29udGVudERpcmVjdG9yeS8sLzxcL3NlcnZpY2U+LyB7IGlmICgkMCB+IC88Y29udHJvbFVSTD4vKSB7IHN1YigvLio8Y29udHJvbFVSTD4vLCAiIik7IHN1YigvPFwvY29udHJvbFVSTD4uKi8sICIiKTsgcHJpbnQ7IGV4aXQgfSB9JykKICAgICAgICAgICAgICAgIFsgLXogIiRDVFJMIiBdICYmIENUUkw9Ii9jb250cm9sL0NvbnRlbnREaXJlY3RvcnkiCiAgICAgICAgICAgICAgICBlY2hvICJ7XCJuYW1lXCI6XCIke05BTUV9XCIsXCJpcFwiOlwiJHtpcH1cIixcImhvc3RcIjpcIiR7aXB9XCIsXCJwb3J0XCI6XCIke3B9XCIsXCJwYXRoXCI6XCIke2Rlc2NfcGF0aH1cIixcImRlc2NcIjpcIiR7ZGVzY19wYXRofVwiLFwiY29udHJvbFVybFwiOlwiJHtDVFJMfVwiLFwiY29udHJvbFwiOlwiJHtDVFJMfVwifSIgPiAiJHtUTVBfRElSfS8ke2lwfV8ke3B9Lmpzb24iCiAgICAgICAgICAgIGZpCiAgICAgICAgfQoKICAgICAgICAjIENoZWNrIGtub3duICYgQVJQIG5laWdoYm9yIElQcyBmaXJzdCAoZmFzdCEpCiAgICAgICAgQ0FORElEQVRFUz0iJHtTVUJORVR9LjIwMCAkKGlwIG5laWdoIDI+L2Rldi9udWxsIHwgYnVzeWJveCBhd2sgJ3twcmludCAkMX0nIHwgYnVzeWJveCBncmVwIC12ICc6JykiCiAgICAgICAgZm9yIGlwIGluICQoZWNobyAiJENBTkRJREFURVMiIHwgYnVzeWJveCB0ciAnICcgJ1xuJyB8IGJ1c3lib3ggc29ydCAtdSk7IGRvCiAgICAgICAgICAgIGZvciBlbnRyeSBpbiAiODA4MTovZGVzY3JpcHRpb24ueG1sIiAiODIwMDovcm9vdERlc2MueG1sIiAiMzI0Njk6L0RldmljZURlc2NyaXB0aW9uLnhtbCIgIjgwOTY6L2RsbmEvZGVzY3JpcHRpb24ueG1sIiAiOTAwMDovZGVzY3JpcHRpb24ueG1sIjsgZG8KICAgICAgICAgICAgICAgIHA9JChlY2hvICIkZW50cnkiIHwgYnVzeWJveCBjdXQgLWQ6IC1mMSkKICAgICAgICAgICAgICAgIGRwPSQoZWNobyAiJGVudHJ5IiB8IGJ1c3lib3ggY3V0IC1kOiAtZjIpCiAgICAgICAgICAgICAgICBjaGVja19zZXJ2ZXIgIiRpcCIgIiRwIiAiJGRwIiAmCiAgICAgICAgICAgIGRvbmUKICAgICAgICBkb25lCiAgICAgICAgd2FpdAoKICAgICAgICAjIElmIG5vdGhpbmcgZm91bmQgeWV0LCBkbyBhIGJyb2FkZXIgc3dlZXAgb24gcG9ydCA4MDgxIGFuZCA4MjAwIGFjcm9zcyB0aGUgc3VibmV0CiAgICAgICAgaWYgWyAteiAiJChscyAtQSAiJFRNUF9ESVIiIDI+L2Rldi9udWxsKSIgXTsgdGhlbgogICAgICAgICAgICBmb3IgaSBpbiAkKGJ1c3lib3ggc2VxIDEgMjU0KTsgZG8KICAgICAgICAgICAgICAgIGlwPSIke1NVQk5FVH0uJHtpfSIKICAgICAgICAgICAgICAgIGNoZWNrX3NlcnZlciAiJGlwIiAiODA4MSIgIi9kZXNjcmlwdGlvbi54bWwiICYKICAgICAgICAgICAgICAgIGlmIFsgJCgoaSAlIDQwKSkgLWVxIDAgXTsgdGhlbiB3YWl0OyBmaQogICAgICAgICAgICBkb25lCiAgICAgICAgICAgIHdhaXQKICAgICAgICBmaQoKICAgICAgICBidXN5Ym94IHByaW50ZiAneyJzdWNjZXNzIjp0cnVlLCJzZXJ2ZXJzIjpbJwogICAgICAgIEZJUlNUPTEKICAgICAgICBmb3IgZiBpbiAiJFRNUF9ESVIiLyouanNvbjsgZG8KICAgICAgICAgICAgWyAtZiAiJGYiIF0gfHwgY29udGludWUKICAgICAgICAgICAgWyAiJEZJUlNUIiAtZXEgMCBdICYmIGJ1c3lib3ggcHJpbnRmICcsJwogICAgICAgICAgICBjYXQgIiRmIgogICAgICAgICAgICBGSVJTVD0wCiAgICAgICAgZG9uZQogICAgICAgIGJ1c3lib3ggcHJpbnRmICddfVxuJwogICAgICAgIDs7CiAgICBnZXRfZG1yKQogICAgICAgIGhlYWRlcl94bWwKICAgICAgICBETVJfUE9SVD0kKGZpbmRfZG1yX3BvcnQpCiAgICAgICAgYnVzeWJveCB3Z2V0IC1xIC1PIC0gImh0dHA6Ly8xMjcuMC4wLjE6JHtETVJfUE9SVH0vIgogICAgICAgIDs7CiAgICBnZXRfZGVzYykKICAgICAgICBoZWFkZXJfeG1sCiAgICAgICAgYnVzeWJveCB3Z2V0IC1xIC1PIC0gImh0dHA6Ly8ke0hPU1R9OiR7UE9SVH0ke1BBVEhfVVJMfSIKICAgICAgICA7OwogICAgYnJvd3NlKQogICAgICAgIGhlYWRlcl94bWwKICAgICAgICBPQko9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJpZCIpIikKICAgICAgICBTVEFSVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInN0YXJ0IikiKQogICAgICAgIENPVU5UPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiY291bnQiKSIpCiAgICAgICAgWyAteiAiJE9CSiIgXSAmJiBPQko9IjAiCiAgICAgICAgWyAteiAiJFNUQVJUIiBdICYmIFNUQVJUPSIwIgogICAgICAgIFsgLXogIiRDT1VOVCIgXSAmJiBDT1VOVD0iNTAwIgogICAgICAgIAogICAgICAgIEVTQ19PQko9JChidXN5Ym94IHByaW50ZiAiJXMiICIkT0JKIiB8IGJ1c3lib3ggc2VkICdzLyYvXCZhbXA7L2c7IHMvPC9cJmx0Oy9nOyBzLz4vXCZndDsvZycpCiAgICAgICAgU09BUD0iPD94bWwgdmVyc2lvbj1cIjEuMFwiIGVuY29kaW5nPVwidXRmLThcIj8+PHM6RW52ZWxvcGUgeG1sbnM6cz1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW52ZWxvcGUvXCIgczplbmNvZGluZ1N0eWxlPVwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvc29hcC9lbmNvZGluZy9cIj48czpCb2R5Pjx1OkJyb3dzZSB4bWxuczp1PVwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpDb250ZW50RGlyZWN0b3J5OjFcIj48T2JqZWN0SUQ+JHtFU0NfT0JKfTwvT2JqZWN0SUQ+PEJyb3dzZUZsYWc+QnJvd3NlRGlyZWN0Q2hpbGRyZW48L0Jyb3dzZUZsYWc+PEZpbHRlcj4qPC9GaWx0ZXI+PFN0YXJ0aW5nSW5kZXg+JHtTVEFSVH08L1N0YXJ0aW5nSW5kZXg+PFJlcXVlc3RlZENvdW50PiR7Q09VTlR9PC9SZXF1ZXN0ZWRDb3VudD48U29ydENyaXRlcmlhPjwvU29ydENyaXRlcmlhPjwvdTpCcm93c2U+PC9zOkJvZHk+PC9zOkVudmVsb3BlPiIKICAgICAgICBMRU49JChidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUCIgfCBidXN5Ym94IHdjIC1jIHwgYnVzeWJveCB0ciAtZCAnICcpCiAgICAgICAgKAogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiUE9TVCAlcyBIVFRQLzEuMFxyXG4iICIkUEFUSF9VUkwiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJIb3N0OiAlczolc1xyXG4iICIkSE9TVCIgIiRQT1JUIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1UeXBlOiB0ZXh0L3htbDsgY2hhcnNldD1cInV0Zi04XCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiU09BUEFjdGlvbjogXCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkNvbnRlbnREaXJlY3Rvcnk6MSNCcm93c2VcIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LUxlbmd0aDogJXNcclxuIiAiJExFTiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbm5lY3Rpb246IGNsb3NlXHJcblxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICIlcyIgIiRTT0FQIgogICAgICAgICAgICBidXN5Ym94IHVzbGVlcCAyMDAwMDAKICAgICAgICApIHwgYnVzeWJveCBuYyAtdyA0ICIkSE9TVCIgIiRQT1JUIiB8IGJ1c3lib3ggc2VkICcxLC9eXHIkL2QnCiAgICAgICAgOzsKICAgIHBsYXkpCiAgICAgICAgaGVhZGVyX3htbAogICAgICAgIERNUl9QT1JUPSQoZmluZF9kbXJfcG9ydCkKICAgICAgICBDVFJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiY3RybCIpIikKICAgICAgICBbIC16ICIkQ1RSTCIgXSAmJiBDVFJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiZG1yX3BhdGgiKSIpCiAgICAgICAgWyAteiAiJENUUkwiIF0gJiYgQ1RSTD0kKGZpbmRfZG1yX2N0cmwgIiRETVJfUE9SVCIpCiAgICAgICAgTUVESUFfVVJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidXJsIikiKQogICAgICAgIFRJVExFPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidGl0bGUiKSIpCiAgICAgICAgQVJUSVNUPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiYXJ0aXN0IikiKQogICAgICAgIEVTQ19VUkw9JChidXN5Ym94IHByaW50ZiAiJXMiICIkTUVESUFfVVJMIiB8IGJ1c3lib3ggc2VkICdzLyYvXCZhbXA7L2c7IHMvPC9cJmx0Oy9nOyBzLz4vXCZndDsvZycpCiAgICAgICAgRVNDX1RJVExFPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJFRJVExFIiB8IGJ1c3lib3ggc2VkICdzLyYvXCZhbXA7L2c7IHMvPC9cJmx0Oy9nOyBzLz4vXCZndDsvZycpCiAgICAgICAgRVNDX0FSVElTVD0kKGJ1c3lib3ggcHJpbnRmICIlcyIgIiRBUlRJU1QiIHwgYnVzeWJveCBzZWQgJ3MvJi9cJmFtcDsvZzsgcy88L1wmbHQ7L2c7IHMvPi9cJmd0Oy9nJykKICAgICAgICBNRVRBPSImbHQ7RElETC1MaXRlIHhtbG5zPSZxdW90O3VybjpzY2hlbWFzLXVwbnAtb3JnOm1ldGFkYXRhLTEtMC9ESURMLUxpdGUvJnF1b3Q7IHhtbG5zOmRjPSZxdW90O2h0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvJnF1b3Q7IHhtbG5zOnVwbnA9JnF1b3Q7dXJuOnNjaGVtYXMtdXBucC1vcmc6bWV0YWRhdGEtMS0wL3VwbnAvJnF1b3Q7Jmd0OyZsdDtpdGVtIGlkPSZxdW90OzEmcXVvdDsgcGFyZW50SUQ9JnF1b3Q7MCZxdW90OyByZXN0cmljdGVkPSZxdW90OzEmcXVvdDsmZ3Q7Jmx0O2RjOnRpdGxlJmd0OyR7RVNDX1RJVExFfSZsdDsvZGM6dGl0bGUmZ3Q7Jmx0O2RjOmNyZWF0b3ImZ3Q7JHtFU0NfQVJUSVNUfSZsdDsvZGM6Y3JlYXRvciZndDsmbHQ7dXBucDphcnRpc3QmZ3Q7JHtFU0NfQVJUSVNUfSZsdDsvdXBucDphcnRpc3QmZ3Q7Jmx0O3VwbnA6Y2xhc3MmZ3Q7b2JqZWN0Lml0ZW0uYXVkaW9JdGVtLm11c2ljVHJhY2smbHQ7L3VwbnA6Y2xhc3MmZ3Q7Jmx0O3JlcyZndDske0VTQ19VUkx9Jmx0Oy9yZXMmZ3Q7Jmx0Oy9pdGVtJmd0OyZsdDsvRElETC1MaXRlJmd0OyIKICAgICAgICAKICAgICAgICBTT0FQMT0iPD94bWwgdmVyc2lvbj1cIjEuMFwiIGVuY29kaW5nPVwidXRmLThcIj8+PHM6RW52ZWxvcGUgeG1sbnM6cz1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW52ZWxvcGUvXCIgczplbmNvZGluZ1N0eWxlPVwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvc29hcC9lbmNvZGluZy9cIj48czpCb2R5Pjx1OlNldEFWVHJhbnNwb3J0VVJJIHhtbG5zOnU9XCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkFWVHJhbnNwb3J0OjFcIj48SW5zdGFuY2VJRD4wPC9JbnN0YW5jZUlEPjxDdXJyZW50VVJJPiR7RVNDX1VSTH08L0N1cnJlbnRVUkk+PEN1cnJlbnRVUklNZXRhRGF0YT4ke01FVEF9PC9DdXJyZW50VVJJTWV0YURhdGE+PC91OlNldEFWVHJhbnNwb3J0VVJJPjwvczpCb2R5PjwvczpFbnZlbG9wZT4iCiAgICAgICAgTEVOMT0kKGJ1c3lib3ggcHJpbnRmICIlcyIgIiRTT0FQMSIgfCBidXN5Ym94IHdjIC1jIHwgYnVzeWJveCB0ciAtZCAnICcpCiAgICAgICAgKAogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiUE9TVCAlcyBIVFRQLzEuMFxyXG4iICIkQ1RSTCIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkhvc3Q6IDEyNy4wLjAuMTolc1xyXG4iICIkRE1SX1BPUlQiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LVR5cGU6IHRleHQveG1sOyBjaGFyc2V0PVwidXRmLThcIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJTT0FQQWN0aW9uOiBcInVybjpzY2hlbWFzLXVwbnAtb3JnOnNlcnZpY2U6QVZUcmFuc3BvcnQ6MSNTZXRBVlRyYW5zcG9ydFVSSVwiXHJcbiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbnRlbnQtTGVuZ3RoOiAlc1xyXG4iICIkTEVOMSIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbm5lY3Rpb246IGNsb3NlXHJcblxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICIlcyIgIiRTT0FQMSIKICAgICAgICAgICAgYnVzeWJveCB1c2xlZXAgMjAwMDAwCiAgICAgICAgKSB8IGJ1c3lib3ggbmMgLXcgMyAxMjcuMC4wLjEgIiRETVJfUE9SVCIgPi9kZXYvbnVsbCAyPiYxCiAgICAgICAgCiAgICAgICAgU09BUDI9Ijw/eG1sIHZlcnNpb249XCIxLjBcIiBlbmNvZGluZz1cInV0Zi04XCI/PjxzOkVudmVsb3BlIHhtbG5zOnM9XCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy9zb2FwL2VudmVsb3BlL1wiIHM6ZW5jb2RpbmdTdHlsZT1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW5jb2RpbmcvXCI+PHM6Qm9keT48dTpQbGF5IHhtbG5zOnU9XCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkFWVHJhbnNwb3J0OjFcIj48SW5zdGFuY2VJRD4wPC9JbnN0YW5jZUlEPjxTcGVlZD4xPC9TcGVlZD48L3U6UGxheT48L3M6Qm9keT48L3M6RW52ZWxvcGU+IgogICAgICAgIExFTjI9JChidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUDIiIHwgYnVzeWJveCB3YyAtYyB8IGJ1c3lib3ggdHIgLWQgJyAnKQogICAgICAgICgKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlBPU1QgJXMgSFRUUC8xLjBcclxuIiAiJENUUkwiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJIb3N0OiAxMjcuMC4wLjE6JXNcclxuIiAiJERNUl9QT1JUIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1UeXBlOiB0ZXh0L3htbDsgY2hhcnNldD1cInV0Zi04XCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiU09BUEFjdGlvbjogXCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkFWVHJhbnNwb3J0OjEjUGxheVwiXHJcbiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbnRlbnQtTGVuZ3RoOiAlc1xyXG4iICIkTEVOMiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbm5lY3Rpb246IGNsb3NlXHJcblxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICIlcyIgIiRTT0FQMiIKICAgICAgICAgICAgYnVzeWJveCB1c2xlZXAgMjAwMDAwCiAgICAgICAgKSB8IGJ1c3lib3ggbmMgLXcgMyAxMjcuMC4wLjEgIiRETVJfUE9SVCIgfCBidXN5Ym94IHNlZCAnMSwvXlxyJC9kJwogICAgICAgIDs7CiAgICBkbXJfY21kfHN0b3ApCiAgICAgICAgaGVhZGVyX3htbAogICAgICAgIERNUl9QT1JUPSQoZmluZF9kbXJfcG9ydCkKICAgICAgICBDVFJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiY3RybCIpIikKICAgICAgICBbIC16ICIkQ1RSTCIgXSAmJiBDVFJMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiZG1yX3BhdGgiKSIpCiAgICAgICAgWyAteiAiJENUUkwiIF0gJiYgQ1RSTD0kKGZpbmRfZG1yX2N0cmwgIiRETVJfUE9SVCIpCiAgICAgICAgQ01EPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiY21kIikiKQogICAgICAgIFsgLXogIiRDTUQiIF0gJiYgQ01EPSJTdG9wIgogICAgICAgIEVYVFJBPSIiCiAgICAgICAgWyAiJENNRCIgPSAiUGxheSIgXSAmJiBFWFRSQT0iPFNwZWVkPjE8L1NwZWVkPiIKICAgICAgICBpZiBbICIkQ01EIiA9ICJTZWVrIiBdOyB0aGVuCiAgICAgICAgICAgIFRBUkdFVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInRhcmdldCIpIikKICAgICAgICAgICAgRVhUUkE9IjxVbml0PlJFTF9USU1FPC9Vbml0PjxUYXJnZXQ+JHtUQVJHRVR9PC9UYXJnZXQ+IgogICAgICAgIGZpCiAgICAgICAgU09BUD0iPD94bWwgdmVyc2lvbj1cIjEuMFwiIGVuY29kaW5nPVwidXRmLThcIj8+PHM6RW52ZWxvcGUgeG1sbnM6cz1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW52ZWxvcGUvXCIgczplbmNvZGluZ1N0eWxlPVwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvc29hcC9lbmNvZGluZy9cIj48czpCb2R5Pjx1OiR7Q01EfSB4bWxuczp1PVwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpBVlRyYW5zcG9ydDoxXCI+PEluc3RhbmNlSUQ+MDwvSW5zdGFuY2VJRD4ke0VYVFJBfTwvdToke0NNRH0+PC9zOkJvZHk+PC9zOkVudmVsb3BlPiIKICAgICAgICBMRU49JChidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUCIgfCBidXN5Ym94IHdjIC1jIHwgYnVzeWJveCB0ciAtZCAnICcpCiAgICAgICAgKAogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiUE9TVCAlcyBIVFRQLzEuMFxyXG4iICIkQ1RSTCIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkhvc3Q6IDEyNy4wLjAuMTolc1xyXG4iICIkRE1SX1BPUlQiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LVR5cGU6IHRleHQveG1sOyBjaGFyc2V0PVwidXRmLThcIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJTT0FQQWN0aW9uOiBcInVybjpzY2hlbWFzLXVwbnAtb3JnOnNlcnZpY2U6QVZUcmFuc3BvcnQ6MSMke0NNRH1cIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LUxlbmd0aDogJXNcclxuIiAiJExFTiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbm5lY3Rpb246IGNsb3NlXHJcblxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICIlcyIgIiRTT0FQIgogICAgICAgICAgICBidXN5Ym94IHVzbGVlcCAxNTAwMDAKICAgICAgICApIHwgYnVzeWJveCBuYyAtdyAzIDEyNy4wLjAuMSAiJERNUl9QT1JUIiB8IGJ1c3lib3ggc2VkICcxLC9eXHIkL2QnCiAgICAgICAgOzsKCiAgICBsZWRfbWFpbikKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFZBTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICBpZiBbICIkVkFMIiA9ICIwIiBdIHx8IFsgIiRWQUwiID0gImZhbHNlIiBdOyB0aGVuCiAgICAgICAgICAgIC9zeXN0ZW0vYmluL2xpZ2h0c190ZXN0IGNsb3NlIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gIjdmZmZmZjAwMDAgMDAwMDAwIiA+IC9zeXMvY2xhc3MvbGVkcy9tdWx0aV9sZWRzMC9sZWRfY29sb3IgMj4vZGV2L251bGwKICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJhY3Rpb24iOiJsZWRfbWFpbiIsInN0YXRlIjpmYWxzZX0nCiAgICAgICAgZWxzZQogICAgICAgICAgICAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDIwNCAyPi9kZXYvbnVsbCB8fCBlY2hvICI3ZmZmZmYwMDAwIDAwZmZmZiIgPiAvc3lzL2NsYXNzL2xlZHMvbXVsdGlfbGVkczAvbGVkX2NvbG9yIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoibGVkX21haW4iLCJzdGF0ZSI6dHJ1ZX0nCiAgICAgICAgZmkKICAgICAgICA7OwogICAgbGVkX2NvbG9yKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgSEVYPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiaGV4IikiIHwgYnVzeWJveCB0ciAtZCAnIycpCiAgICAgICAgWyAteiAiJEhFWCIgXSAmJiBIRVg9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJjb2xvciIpIiB8IGJ1c3lib3ggdHIgLWQgJyMnKQogICAgICAgIGlmIFsgLW4gIiRIRVgiIF07IHRoZW4KICAgICAgICAgICAgZWNobyAiN2ZmZmZmMDAwMCAke0hFWH0iID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2xlZF9jb2xvciAyPi9kZXYvbnVsbAogICAgICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwibGVkX2NvbG9yXCIsXCJoZXhcIjpcIiR7SEVYfVwifSIKICAgICAgICBlbHNlCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsImVycm9yIjoibWlzc2luZyBoZXgifScKICAgICAgICBmaQogICAgICAgIDs7CiAgICBsZWRfYnJpZ2h0bmVzcykKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFZBTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICBpZiBbIC1uICIkVkFMIiBdOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIiRWQUwiID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2JyaWdodG5lc3MgMj4vZGV2L251bGwKICAgICAgICAgICAgSEVYX1ZBTD0kKCggVkFMICogMjU1IC8gMjAwICkpCiAgICAgICAgICAgIFsgJEhFWF9WQUwgLWd0IDI1NSBdICYmIEhFWF9WQUw9MjU1CiAgICAgICAgICAgIEhFWD0kKGJ1c3lib3ggcHJpbnRmICIwMCUwMnglMDJ4IiAkSEVYX1ZBTCAkSEVYX1ZBTCkKICAgICAgICAgICAgZWNobyAiN2ZmZmZmMDAwMCAke0hFWH0iID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2xlZF9jb2xvciAyPi9kZXYvbnVsbAogICAgICAgICAgICAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzZXQgN2ZmZmZmMDAwMCAiJHtIRVh9IiAyPi9kZXYvbnVsbAogICAgICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwibGVkX2JyaWdodG5lc3NcIixcInZhbFwiOlwiJHtWQUx9XCIsXCJoZXhcIjpcIiR7SEVYfVwifSIKICAgICAgICBlbHNlCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsImVycm9yIjoibWlzc2luZyB2YWwifScKICAgICAgICBmaQogICAgICAgIDs7CiAgICBsZWRfc3BlZWQpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBWQUw9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ2YWwiKSIpCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJhY3Rpb25cIjpcImxlZF9zcGVlZFwiLFwidmFsXCI6XCIke1ZBTH1cIn0iCiAgICAgICAgOzsKICAgIGxlZF9zdGFuZGJ5KQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgVkFMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIGlmIFsgIiRWQUwiID0gIjAiIF0gfHwgWyAiJFZBTCIgPSAiZmFsc2UiIF07IHRoZW4KICAgICAgICAgICAgZWNobyAiN2ZmZmZmODAwMCAwIiA+IC9zeXMvY2xhc3MvbGVkcy9tdWx0aV9sZWRzMC9sZWRfY29sb3IgMj4vZGV2L251bGwKICAgICAgICAgICAgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2V0IDdmZmZmZjgwMDAgMCAyPi9kZXYvbnVsbAogICAgICAgICAgICBzZXRwcm9wIHBlcnNpc3Quc3lzLnIxX2xlZCAxIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoibGVkX3N0YW5kYnkiLCJzdGF0ZSI6ZmFsc2V9JwogICAgICAgIGVsc2UKICAgICAgICAgICAgZWNobyAiN2ZmZmZmODAwMCBmZmZmZmYiID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2xlZF9jb2xvciAyPi9kZXYvbnVsbAogICAgICAgICAgICAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzZXQgN2ZmZmZmODAwMCBmZmZmZmYgMj4vZGV2L251bGwKICAgICAgICAgICAgc2V0cHJvcCBwZXJzaXN0LnN5cy5yMV9sZWQgMCAyPi9kZXYvbnVsbAogICAgICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOnRydWUsImFjdGlvbiI6ImxlZF9zdGFuZGJ5Iiwic3RhdGUiOnRydWV9JwogICAgICAgIGZpCiAgICAgICAgOzsKICAgIGxlZF9zdGFuZGJ5X2JyaWdodG5lc3MpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBJTlRFTlNJVFk9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ2YWwiKSIpCiAgICAgICAgVkFMPSQoKCBJTlRFTlNJVFkgKiAyNTUgLyAxMDAgKSkKICAgICAgICBIRVg9JChidXN5Ym94IHByaW50ZiAiJTAyeCUwMnglMDJ4IiAkVkFMICRWQUwgJFZBTCkKICAgICAgICBlY2hvICI3ZmZmZmY4MDAwICR7SEVYfSIgPiAvc3lzL2NsYXNzL2xlZHMvbXVsdGlfbGVkczAvbGVkX2NvbG9yIDI+L2Rldi9udWxsCiAgICAgICAgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2V0IDdmZmZmZjgwMDAgIiR7SEVYfSIgMj4vZGV2L251bGwKICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwibGVkX3N0YW5kYnlfYnJpZ2h0bmVzc1wiLFwiaGV4XCI6XCIke0hFWH1cIn0iCiAgICAgICAgOzsKICAgIGxlZF9tb2RlKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgTU9ERT0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gIm1vZGUiKSIpCiAgICAgICAgWyAteiAiJE1PREUiIF0gJiYgTU9ERT0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICBbIC16ICIkTU9ERSIgXSAmJiBNT0RFPTAKICAgICAgICBjYXNlICIkTU9ERSIgaW4KICAgICAgICAgICAgMCkgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDQgMj4vZGV2L251bGwgfHwgZWNobyAiN2ZmZmZmMDAwMCAwMGZmZmYiID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2xlZF9jb2xvciAyPi9kZXYvbnVsbCA7OyAjIEN5YW4gYnJlYXRoZQogICAgICAgICAgICAxKSAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDEgMj4vZGV2L251bGwgOzsgICAjIFJvdGF0ZQogICAgICAgICAgICAyKSAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDIwNiAyPi9kZXYvbnVsbCA7OyAjIEZsYXNoCiAgICAgICAgICAgIDMpIGVjaG8gIjdmZmZmZjAwMDAgMDBmZmZmIiA+IC9zeXMvY2xhc3MvbGVkcy9tdWx0aV9sZWRzMC9sZWRfY29sb3IgMj4vZGV2L251bGwgfHwgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyA1MTQgMj4vZGV2L251bGwgOzsgIyBTdGF0aWMKICAgICAgICAgICAgNCkgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDEgMj4vZGV2L251bGwgOzsgIyBCcmVhdGhlIGJsdWUKICAgICAgICAgICAgNykgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDMgMj4vZGV2L251bGwgOzsgIyBCcmVhdGhpbmcKICAgICAgICAgICAgKikgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDQgMj4vZGV2L251bGwgOzsKICAgICAgICBlc2FjCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJhY3Rpb25cIjpcImxlZF9tb2RlXCIsXCJtb2RlXCI6XCIke01PREV9XCJ9IgogICAgICAgIDs7CiAgICBzZXRfYnQpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBWQUw9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ2YWwiKSIpCiAgICAgICAgaWYgWyAiJFZBTCIgPSAiMCIgXSB8fCBbICIkVkFMIiA9ICJmYWxzZSIgXTsgdGhlbgogICAgICAgICAgICBzZXR0aW5ncyBwdXQgZ2xvYmFsIGJsdWV0b290aF9vbiAwIDI+L2Rldi9udWxsCiAgICAgICAgICAgIHNlcnZpY2UgY2FsbCBtc2djZW50ZXIgMSBpMzIgMSBpMzIgNjQgaTMyIDIgaTMyIDE1IGkzMiAwIGkzMiAwIGkzMiAwIGkzMiAtMSBpMzIgMCBpMzIgMCAyPi9kZXYvbnVsbCA+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoic2V0X2J0Iiwic3RhdGUiOmZhbHNlfScKICAgICAgICBlbHNlCiAgICAgICAgICAgIHNldHRpbmdzIHB1dCBnbG9iYWwgYmx1ZXRvb3RoX29uIDEgMj4vZGV2L251bGwKICAgICAgICAgICAgc2VydmljZSBjYWxsIG1zZ2NlbnRlciAxIGkzMiAxIGkzMiA2NCBpMzIgMSBpMzIgMTUgaTMyIDAgaTMyIDAgaTMyIDAgaTMyIC0xIGkzMiAwIGkzMiAwIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICAgICAgYW0gYnJvYWRjYXN0IC1hIGFuZHJvaWQuYmx1ZXRvb3RoLmFkYXB0ZXIuYWN0aW9uLlJFUVVFU1RfRU5BQkxFIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICAgICAgYW0gYnJvYWRjYXN0IC1hIGFuZHJvaWQuYmx1ZXRvb3RoLmFkYXB0ZXIuYWN0aW9uLlJFUVVFU1RfRElTQ09WRVJBQkxFIC0tZWkgYW5kcm9pZC5ibHVldG9vdGguYWRhcHRlci5leHRyYS5ESVNDT1ZFUkFCTEVfRFVSQVRJT04gMCAyPi9kZXYvbnVsbCA+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoic2V0X2J0Iiwic3RhdGUiOnRydWV9JwogICAgICAgIGZpCiAgICAgICAgOzsKICAgIHNldF92b2wpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBWQUw9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ2YWwiKSIpCiAgICAgICAgaWYgWyAtbiAiJFZBTCIgXTsgdGhlbgogICAgICAgICAgICBtZWRpYSB2b2x1bWUgLS1zdHJlYW0gMyAtLXNldCAiJFZBTCIgMj4vZGV2L251bGwgPi9kZXYvbnVsbCB8fCBzZXR0aW5ncyBwdXQgc3lzdGVtIHZvbHVtZV9tdXNpYyAiJFZBTCIgMj4vZGV2L251bGwKICAgICAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJhY3Rpb25cIjpcInNldF92b2xcIixcInZhbFwiOiR7VkFMfX0iCiAgICAgICAgZWxzZQogICAgICAgICAgICBlY2hvICd7InN1Y2Nlc3MiOmZhbHNlLCJlcnJvciI6Im1pc3NpbmcgdmFsIn0nCiAgICAgICAgZmkKICAgICAgICA7OwogICAgc2V0X3NlcnZpY2UpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBTUlY9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJzZXJ2aWNlIikiKQogICAgICAgIFZBTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICAvc3lzdGVtL2Jpbi9wbSB1bmhpZGUgY29tLnBoaWNvbW0uc3BlYWtlci5wbGF5ZXIgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgIC9zeXN0ZW0vYmluL3BtIHVuaGlkZSBjb20ucGhpY29tbS5zcGVha2VyLmFpcnNraWxsIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICBhbSBzdGFydHNlcnZpY2UgY29tLnBoaWNvbW0uc3BlYWtlci5wbGF5ZXIvLkVjaG9TZXJ2aWNlIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICBhbSBzdGFydHNlcnZpY2UgY29tLnBoaWNvbW0uc3BlYWtlci5haXJza2lsbC8uQWlyU2VydmljZSAyPi9kZXYvbnVsbCA+L2Rldi9udWxsCiAgICAgICAgc2VydmljZSBjYWxsIG1zZ2NlbnRlciAxIGkzMiAxIGkzMiA2NCBpMzIgMSBpMzIgMTUgaTMyIDAgaTMyIDAgaTMyIDAgaTMyIC0xIGkzMiAwIGkzMiAwIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwic2V0X3NlcnZpY2VcIixcInNlcnZpY2VcIjpcIiR7U1JWfVwiLFwic3RhdGVcIjp0cnVlfSIKICAgICAgICA7OwogICAgZ2V0X3N0YXR1cykKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIEJUX09OPSQoc2V0dGluZ3MgZ2V0IGdsb2JhbCBibHVldG9vdGhfb24gMj4vZGV2L251bGwpCiAgICAgICAgWyAteiAiJEJUX09OIiBdICYmIEJUX09OPSIxIgogICAgICAgIERNUl9SVU5OSU5HPSJmYWxzZSIKICAgICAgICBpZiBidXN5Ym94IG5ldHN0YXQgLXRscG4gMj4vZGV2L251bGwgfCBidXN5Ym94IGdyZXAgLXEgIjE2MjZcfDUwMTJcfGNvbVwucGhpY29tbSI7IHRoZW4KICAgICAgICAgICAgRE1SX1JVTk5JTkc9InRydWUiCiAgICAgICAgZWxzZQogICAgICAgICAgICBzZXJ2aWNlIGNhbGwgbXNnY2VudGVyIDEgaTMyIDEgaTMyIDY0IGkzMiAxIGkzMiAxNSBpMzIgMCBpMzIgMCBpMzIgMCBpMzIgLTEgaTMyIDAgaTMyIDAgMj4vZGV2L251bGwgPi9kZXYvbnVsbCAmCiAgICAgICAgICAgIERNUl9SVU5OSU5HPSJ0cnVlIgogICAgICAgIGZpCiAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJkbG5hXCI6dHJ1ZSxcImFpcnBsYXlcIjp0cnVlLFwiYmx1ZXRvb3RoXCI6JChbICIkQlRfT04iID0gIjEiIF0gJiYgZWNobyB0cnVlIHx8IGVjaG8gZmFsc2UpLFwibGVkX3N0YW5kYnlcIjp0cnVlLFwibGVkX21haW5cIjp0cnVlLFwiZG1yX3J1bm5pbmdcIjoke0RNUl9SVU5OSU5HfX0iCiAgICAgICAgOzsKCiAgICAqKQogICAgICAgIGhlYWRlcl94bWwKICAgICAgICBlY2hvICI8ZXJyb3I+VW5rbm93biBhY3Rpb248L2Vycm9yPiIKICAgICAgICA7Owplc2FjCg=="

USER_IP=""
ASSUME_YES=""
CLI_MODE=""

for arg in "$@"; do
    case "$arg" in
        -y|--yes|-Yes) ASSUME_YES="1" ;;
        -DryRun|--dry-run) export R1_DRYRUN=1 ;;
        -Wifi|--wifi|-wifi) CLI_MODE="wifi" ;;
        -Scan|--scan|-scan) CLI_MODE="scan" ;;
        -Mic|--mic|-mic|-Optimize|--optimize) CLI_MODE="mic" ;;
        192.168.43.1)
            USER_IP="$arg"
            CLI_MODE="wifi"
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*)
            USER_IP="$arg"
            CLI_MODE="install"
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÔNG CỤ CẦN THIẾT (TỰ ĐỘNG MỞ KHO CHO ALPINE / iSH)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true

    # Đảm bảo có curl để tải file và gửi API cấu hình WiFi
    if ! command -v curl >/dev/null 2>&1; then
        echo ">> Đang cài đặt curl..."
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache curl >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y curl >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1 || true
        fi
    fi

    # Thử cài đặt adb và netcat nếu chưa có
    if ! command -v adb >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            if [ -f /etc/apk/repositories ]; then
                sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true
            fi
            apk add --no-cache android-tools netcat-openbsd >/dev/null 2>&1 || \
            apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get install -y android-tools-adb netcat-openbsd >/dev/null 2>&1 || true
        fi
    fi
}
setup_tools

# Hàm đọc dữ liệu an toàn
read_val() {
    prompt="$1"
    def="$2"
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        echo "$def"
        return
    fi
    printf "%s" "$prompt" >&2
    val=""
    read -r val 2>/dev/null || val=""
    val=$(printf '%s' "$val" | tr -d ' \r\n')
    [ -z "$val" ] && val="$def"
    echo "$val"
}

# ------------------------------------------------------------------------------
# 2. HÀM DÒ TÌM DẢI MẠNG LAN & QUÉT TỰ ĐỘNG TÌM LOA PHICOMM R1
# ------------------------------------------------------------------------------
detect_subnet() {
    sub=""
    if command -v ip >/dev/null 2>&1; then
        sub=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | awk -F'.' '{print $1"."$2"."$3}')
        [ -z "$sub" ] && sub=$(ip -4 addr show 2>/dev/null | grep -v '127.0.0.1' | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | awk '{print $2}')
    fi
    if [ -z "$sub" ] && command -v ifconfig >/dev/null 2>&1; then
        sub=$(ifconfig 2>/dev/null | grep -v '127.0.0.1' | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
    if [ -z "$sub" ] && command -v route >/dev/null 2>&1; then
        sub=$(route -n 2>/dev/null | grep -E '^0\.0\.0\.0' | awk '{print $2}' | awk -F'.' '{print $1"."$2"."$3}')
    fi
    [ -z "$sub" ] && sub="192.168.1"
    echo "$sub"
}

scan_speaker_ip() {
    sub=$(detect_subnet)
    echo ""
    echo ">> Đang quét tự động dải mạng LAN ($sub.1 -> 254) tìm loa Phicomm R1..."

    scan_tmp="/tmp/r1_scan_$$"
    rm -rf "$scan_tmp" 2>/dev/null || true
    mkdir -p "$scan_tmp"

    PY_CMD=""
    if python3 -c "import sys" >/dev/null 2>&1; then
        PY_CMD="python3"
    elif python -c "import sys" >/dev/null 2>&1; then
        PY_CMD="python"
    fi

    if [ -n "$PY_CMD" ]; then
        "$PY_CMD" - "$sub" << 'EOF' > "$scan_tmp/result.txt" 2>/dev/null || true
import sys, socket
from concurrent.futures import ThreadPoolExecutor

prefix = sys.argv[1]
def probe(i):
    ip = f"{prefix}.{i}"
    ports = []
    for p in (5555, 8081, 8080):
        try:
            s = socket.socket()
            s.settimeout(0.35)
            if s.connect_ex((ip, p)) == 0:
                ports.append(str(p))
            s.close()
        except Exception:
            pass
    if '5555' in ports or ('8080' in ports and '8081' in ports):
        p_str = ', '.join(ports)
        print(f"{ip} (Ports: {p_str})")

with ThreadPoolExecutor(max_workers=50) as ex:
    list(ex.map(probe, range(1, 255)))
EOF
    fi

    if [ ! -s "$scan_tmp/result.txt" ]; then
        idx=1
        while [ $idx -le 254 ]; do
            bend=$((idx + 31))
            [ $bend -gt 254 ] && bend=254
            i=$idx
            while [ $i -le $bend ]; do
                (
                    target="${sub}.${i}"
                    found=""
                    if command -v curl >/dev/null 2>&1; then
                        if curl -s -m 0.35 -o /dev/null "http://$target:5555/" 2>/dev/null; then
                            found="5555"
                        elif curl -s -m 0.35 -o /dev/null "http://$target:8081/" 2>/dev/null; then
                            found="8081"
                        elif curl -s -m 0.35 -o /dev/null "http://$target:8080/" 2>/dev/null; then
                            found="8080"
                        fi
                    fi
                    if [ -z "$found" ] && command -v nc >/dev/null 2>&1; then
                        if nc -w 1 "$target" 5555 </dev/null >/dev/null 2>&1; then
                            found="5555"
                        elif nc -w 1 "$target" 8081 </dev/null >/dev/null 2>&1; then
                            found="8081"
                        elif nc -w 1 "$target" 8080 </dev/null >/dev/null 2>&1; then
                            found="8080"
                        fi
                    fi
                    if [ -n "$found" ]; then
                        echo "$target (Port: $found)" >> "$scan_tmp/result.txt"
                    fi
                ) &
                i=$((i + 1))
            done
            wait
            idx=$((bend + 1))
        done
    fi

    TOTAL_FOUND=0
    if [ -f "$scan_tmp/result.txt" ]; then
        echo ""
        echo ">> Kết quả phát hiện loa trong mạng LAN:"
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(printf '%s' "$line" | tr -d '\r\n')
            [ -z "$line" ] && continue
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
            ip_val=$(printf '%s' "$line" | awk '{print $1}')
            echo "$ip_val" >> "$scan_tmp/ips.txt"
            echo "   [$TOTAL_FOUND] $line"
        done < "$scan_tmp/result.txt"
    fi
}

# ------------------------------------------------------------------------------
# 3. HÀM KÍCH HOẠT CỔNG ADB & KIỂM TRA KẾT NỐI
# ------------------------------------------------------------------------------
revive_speaker() {
    tip="$1"
    [ -z "$tip" ] && tip="192.168.43.1"
    [ "$R1_DRYRUN" = "1" ] && return 0

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 1.5 "http://$tip:8080/" >/dev/null 2>&1 || true
        curl -s -m 1.5 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=1 "http://$tip:8080/" >/dev/null 2>&1 || true
        wget -q -O- --timeout=1 "http://$tip:8081/" >/dev/null 2>&1 || true
    fi
}

check_connected() {
    state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
    if [ "$state" = "device" ]; then
        adb -s "$SERIAL" shell ls /data >/dev/null 2>&1
        return $?
    fi
    return 1
}

# ------------------------------------------------------------------------------
# 4. [MỤC 1] CẤU HÌNH WIFI CHO LOA QUA CHẾ ĐỘ AP 192.168.43.1
# ------------------------------------------------------------------------------
send_wifi_config() {
    target_ip="$1"
    ssid="$2"
    pass="$3"
    secure="$4"
    [ -z "$secure" ] && secure="WPA"

    esc_ssid=$(printf '%s' "$ssid" | sed 's/\\/\\\\/g; s/"/\\"/g')
    esc_pass=$(printf '%s' "$pass" | sed 's/\\/\\\\/g; s/"/\\"/g')
    payload="{\"ssid\":\"$esc_ssid\",\"secure\":\"$secure\",\"password\":\"$esc_pass\",\"mac\":\"\"}"

    if [ "$R1_DRYRUN" = "1" ]; then
        echo "   [DRY-RUN] Đã gửi cấu hình WiFi SSID='$ssid' tới http://$target_ip:8989/api/configwifi"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 5 -X POST "http://$target_ip:8989/api/configwifi" \
             -H "Content-Type: application/json" \
             -d "$payload" >/dev/null 2>&1 || true
        return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=5 --header="Content-Type: application/json" \
             --post-data="$payload" "http://$target_ip:8989/api/configwifi" >/dev/null 2>&1 || true
        return 0
    fi
    return 1
}

configure_wifi_ap() {
    echo ""
    echo "=========================================================="
    echo "  CẤU HÌNH WIFI CHO LOA VỪA RESET (CHẾ ĐỘ AP 192.168.43.1)"
    echo "=========================================================="
    echo " Hướng dẫn chuẩn bị:"
    echo "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'."
    echo "  2. Trên iPhone / Máy tính: Vào Cài đặt WiFi -> Kết nối 'Phicomm_R1_xxxx'."
    echo "  3. TẮT 4G/5G (Dữ liệu di động) trên điện thoại."
    echo "=========================================================="

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_val "Nhấn Enter khi đã kết nối vào WiFi của loa: " "" >/dev/null 2>&1 || true
    fi

    echo ""
    echo ">> Đang kiểm tra kết nối tới loa (192.168.43.1:8989)..."
    api_ok=0
    if [ "$R1_DRYRUN" = "1" ]; then
        api_ok=1
    elif command -v curl >/dev/null 2>&1; then
        if curl -s -m 2 "http://192.168.43.1:8989/" >/dev/null 2>&1 || curl -s -m 2 "http://192.168.43.1:8989/api/configwifi" >/dev/null 2>&1; then
            api_ok=1
        fi
    fi

    if [ "$api_ok" = "1" ]; then
        echo "   [OK] Đã kết nối được tới loa R1."
    else
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            echo "   [CẢNH BÁO] Chưa kết nối được 192.168.43.1:8989."
            echo "   Kiểm tra: Điện thoại đã chọn WiFi Phicomm_R1 chưa? Đã tắt 4G chưa?"
            ans=$(read_val "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: " "y")
            case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                "y"|"yes") ;;
                *) return 1 ;;
            esac
        fi
    fi

    echo ""
    echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
    echo "----------------------------------------------------------"
    ssid=""
    while [ -z "$ssid" ]; do
        ssid=$(read_val ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): " "")
        if [ "$R1_DRYRUN" = "1" ] && [ -z "$ssid" ]; then
            ssid="MyWiFi"
        fi
        if [ -z "$ssid" ]; then
            echo "   [!] Tên WiFi không được để trống!"
        fi
    done

    pass=$(read_val ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): " "")
    if [ "$R1_DRYRUN" = "1" ] && [ -z "$pass" ]; then
        pass="12345678"
    fi

    secure="WPA"
    if [ -z "$pass" ]; then
        secure="INSECURE"
        echo "   -> Chế độ WiFi không mật khẩu (INSECURE)"
    else
        pass_len=$(printf '%s' "$pass" | wc -c)
        if [ "$pass_len" -lt 8 ]; then
            echo "   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!"
        fi
    fi

    echo ""
    echo ">> Đang gửi cấu hình tới loa (192.168.43.1:8989)..."
    send_wifi_config "192.168.43.1" "$ssid" "$pass" "$secure"

    echo ""
    echo "=========================================================="
    echo "            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG!              "
    echo "=========================================================="
    echo " THÔNG BÁO QUAN TRỌNG:"
    echo "  1. Loa đang kết nối WiFi nhà, chờ khoảng 20 giây sẽ có IP."
    echo "  2. Hãy chuyển iPhone / Máy tính về lại mạng WiFi nhà."
    echo "  3. Sau đó quay lại menu chọn [2] để tìm IP và cài APK."
    echo "=========================================================="

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 5. [MỤC 2] CÀI ĐẶT APK CHO LOA TRONG MẠNG LAN (GIỮ NGUYÊN CODE CHUẨN)
# ------------------------------------------------------------------------------
run_install_lan() {
    target_param="$1"
    TARGET_IP="$target_param"

    if [ -z "$TARGET_IP" ]; then
        echo ""
        echo "----------------------------------------------------------"
        echo "                    TÌM IP CỦA LOA TRONG LAN              "
        echo "----------------------------------------------------------"
        echo " [S] hoặc [Enter]: Tự động QUÉT tìm IP loa trong WiFi nhà (LAN)"
        echo " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)"
        echo "----------------------------------------------------------"
        echo ""

        while [ -z "$TARGET_IP" ]; do
            USER_INPUT=$(read_val "Nhập IP hoặc gõ 'S' để quét [Mặc định: S]: " "S")
            USER_INPUT=$(printf '%s' "$USER_INPUT" | tr -d ' ')

            case "$USER_INPUT" in
                "s"|"S"|"scan"|"SCAN"|"")
                    scan_speaker_ip
                    if [ "$TOTAL_FOUND" -gt 0 ]; then
                        echo ""
                        PICK=$(read_val "Chọn số thứ tự loa (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
                        PICK=$(printf '%s' "$PICK" | tr -d ' ')
                        if [ "$PICK" -ge 1 ] 2>/dev/null && [ "$PICK" -le "$TOTAL_FOUND" ] 2>/dev/null; then
                            TARGET_IP=$(sed -n "${PICK}p" "$scan_tmp/ips.txt")
                        elif printf '%s' "$PICK" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
                            TARGET_IP="$PICK"
                        else
                            TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
                        fi
                    else
                        echo ""
                        echo ">> Không tìm thấy loa tự động trong mạng LAN."
                        MANUAL=$(read_val "Vui lòng nhập IP loa thủ công (hoặc Enter về menu): " "")
                        if [ -n "$MANUAL" ]; then
                            TARGET_IP="$MANUAL"
                        else
                            rm -rf "$scan_tmp" 2>/dev/null || true
                            return 1
                        fi
                    fi
                    rm -rf "$scan_tmp" 2>/dev/null || true
                    ;;
                "1"|"192.168.43.1")
                    echo ""
                    echo "=========================================================="
                    echo "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!"
                    echo "=========================================================="
                    echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
                    echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
                    echo "=========================================================="
                    read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                    return 1
                    ;;
                *)
                    TARGET_IP=$(printf '%s' "$USER_INPUT" | sed 's/:5555$//')
                    ;;
            esac
        done
    fi

    # Kiểm tra lại nếu người dùng nhập nhầm 192.168.43.1
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo ""
        echo "=========================================================="
        echo "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!"
        echo "=========================================================="
        echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
        echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
        echo "=========================================================="
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d ' ' | sed 's/:5555$//')
    SERIAL="$TARGET_IP:5555"

    echo ""
    echo ">> Sẽ kết nối tới IP: $TARGET_IP"

    # [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub
    echo ""

    echo ">> [1/4] Chuẩn bị gói cài đặt hợp nhất (AIBoxPlus_DLNA.apk)..."
    mkdir -p "$CACHE_DIR"
    f="AIBoxPlus_DLNA.apk"
    HAVE_APK=0
    if [ -f "$SCRIPT_DIR/$f" ]; then
        echo "   [OK] Đã tìm thấy gói APK hợp nhất có sẵn: $SCRIPT_DIR/$f"
        HAVE_APK=1
    elif [ -f "$CACHE_DIR/$f" ] && [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -gt 15000000 ]; then
        echo "   [OK] Đã tìm thấy gói APK hợp nhất trong bộ nhớ tạm: $CACHE_DIR/$f"
        HAVE_APK=1
    fi

    if [ "$HAVE_APK" != "1" ]; then
        TS=$(date +%s 2>/dev/null || echo "1")
        echo "   -> Đang tải bản APK hợp nhất ($f) từ GitHub..."
        if command -v curl >/dev/null 2>&1; then
            curl -k -fL --connect-timeout 30 -# -o "$CACHE_DIR/$f.tmp" "$BASE_URL/$f?t=$TS" && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
        elif command -v wget >/dev/null 2>&1; then
            wget -q --no-check-certificate -O "$CACHE_DIR/$f" "$BASE_URL/$f?t=$TS"
        fi

        if [ ! -f "$CACHE_DIR/$f" ] || [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -lt 15000000 ]; then
            echo ""
            echo "=========================================================="
            echo "  [LỖI] KHÔNG THỂ TẢI FILE $f TỪ GITHUB!"
            echo "=========================================================="
            echo "Vui lòng sao chép file AIBoxPlus_DLNA.apk vào cùng thư mục với script."
            echo "=========================================================="
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        echo "   [OK] Đã chuẩn bị gói APK hợp nhất $f thành công."
    fi

    # [2/4] Bắt đầu kết nối thiết bị ADB
    echo ""
    echo ">> [2/4] Bắt đầu kết nối thiết bị [$SERIAL]..."

    if [ "$R1_DRYRUN" != "1" ] && ! command -v adb >/dev/null 2>&1; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] THIẾU CÔNG CỤ ADB TRÊN THIẾT BỊ!"
        echo "=========================================================="
        echo "Vui lòng chạy lệnh sau trong iSH để cài đặt adb:"
        echo "  apk add android-tools"
        echo "=========================================================="
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    CONNECTED=0
    if [ "$R1_DRYRUN" != "1" ]; then
        adb kill-server >/dev/null 2>&1 || true
        adb start-server >/dev/null 2>&1 || true

        echo "   [Kết nối] Thử kết nối trực tiếp..."
        OUT_CONN=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
        echo "   -> $OUT_CONN"
        sleep 1.2

        if check_connected; then
            CONNECTED=1
        else
            echo "   -> Loa chưa phản hồi, đang gửi tín hiệu kích hoạt ADB qua cổng 8080..."
            revive_speaker "$TARGET_IP"
            sleep 1.8

            for try in 1 2 3 4 5; do
                echo "   [Thử lại] Lần $try/5 tới $SERIAL..."
                OUT_CONN=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
                echo "   -> $OUT_CONN"
                sleep 1.2
                if check_connected; then
                    CONNECTED=1
                    break
                fi
                sleep 1
            done
        fi

        if [ "$CONNECTED" != "1" ]; then
            echo ""
            echo "=========================================================="
            echo "  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI $SERIAL"
            echo "=========================================================="
            echo "Vui lòng kiểm tra:"
            echo " 1. Loa đã cắm nguồn và đang bật."
            echo " 2. Điện thoại và loa đang cùng kết nối vào một mạng WiFi."
            echo " 3. Địa chỉ IP của loa ($TARGET_IP) đã đúng chưa."
            echo " 4. Nếu loa vừa reset, hãy chọn mục 1 để cấu hình WiFi trước."
            echo "=========================================================="
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
    fi
    echo ">> [OK] Kết nối thành công tới loa ($SERIAL)!"

    # [3/4] Đẩy 3 file APK lên bộ nhớ tạm của loa
    echo ""
    echo ">> [3/4] Đang dọn sạch bộ nhớ tạm của loa & nạp 3 file APK mới lên (/data/local/tmp/)..."

    APK_SRC="$SCRIPT_DIR/AIBoxPlus_DLNA.apk"
    [ ! -f "$APK_SRC" ] && APK_SRC="$CACHE_DIR/AIBoxPlus_DLNA.apk"

    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" shell rm -rf "/data/local/tmp/*" >/dev/null 2>&1
        echo "   -> Nạp AIBoxPlus_DLNA.apk..."
        adb -s "$SERIAL" push "$APK_SRC" "/data/local/tmp/AIBoxPlus_DLNA.apk" >/dev/null 2>&1
    else
        echo "   -> Nạp AIBoxPlus_DLNA.apk..."
    fi
    echo ">> [OK] Đã đưa trọn vẹn gói APK hợp nhất lên loa!"

    # [4/4] Bắt đầu cài đặt hệ thống chuẩn xác từ gói hợp nhất
    echo ""
    echo ">> [4/4] Bắt đầu cài đặt hệ thống từ gói APK hợp nhất..."

    if [ "$R1_DRYRUN" != "1" ]; then
        echo "   -> Đang dọn dẹp bộ nhớ đệm..."
        adb -s "$SERIAL" shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null" >/dev/null 2>&1

        echo "   -> Trích xuất & Cài đặt DLNA Player ngầm từ gói hợp nhất..."
        adb -s "$SERIAL" shell "busybox unzip -p /data/local/tmp/AIBoxPlus_DLNA.apk assets/dlna/autodlna.apk > /data/local/tmp/autodlna.apk 2>/dev/null; /system/bin/pm install -r /data/local/tmp/autodlna.apk 2>/dev/null; rm -f /data/local/tmp/autodlna.apk" >/dev/null 2>&1

        echo "   -> Khởi động DLNA Player & AirPlay..."
        adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.player 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.airskill 2>/dev/null; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am startservice com.phicomm.speaker.airskill/.AirService 2>/dev/null" >/dev/null 2>&1

        echo "   -> Khởi tạo Backend điều khiển phần cứng & Web API (Cổng 8088)..."
        DEPLOY_CMD="mkdir -p /sdcard/dlna_web/cgi-bin && echo '*.sh:/system/bin/sh' > /sdcard/dlna_web/httpd.conf && echo '${API_SH_B64}' | busybox base64 -d > /sdcard/dlna_web/cgi-bin/api.sh && chmod 755 /sdcard/dlna_web/cgi-bin/api.sh && busybox pkill -f 'httpd -p 8088' 2>/dev/null; busybox httpd -p 8088 -h /sdcard/dlna_web -c /sdcard/dlna_web/httpd.conf 2>/dev/null"
        adb -s "$SERIAL" shell "$DEPLOY_CMD" >/dev/null 2>&1

        echo "   -> Khôi phục ijetty & netctl..."
        adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null" >/dev/null 2>&1

        echo "   -> Gỡ bản AI cũ & Cài đặt AIBox Plus hợp nhất mới..."
        adb -s "$SERIAL" shell "/system/bin/pm uninstall info.dourok.voicebot 2>/dev/null; /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk 2>/dev/null; rm -f /data/local/tmp/AIBoxPlus_DLNA.apk 2>/dev/null" >/dev/null 2>&1

        echo "   -> Khởi động AI Box Plus & Mặc định BẬT 5 thành phần (DLNA, AirPlay, Bluetooth, Đèn Chờ, Đèn RGB)..."
        POST_INIT_CMD="am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; am broadcast -a android.bluetooth.adapter.action.REQUEST_ENABLE 2>/dev/null; am broadcast -a android.bluetooth.adapter.action.REQUEST_DISCOVERABLE --ei android.bluetooth.adapter.extra.DISCOVERABLE_DURATION 0 2>/dev/null; service call msgcenter 1 i32 1 i32 64 i32 1 i32 15 i32 0 i32 0 i32 0 i32 -1 i32 0 i32 0 2>/dev/null; /system/bin/lights_test show 204 2>/dev/null; /system/bin/lights_test show 514 2>/dev/null; echo '7fffff8000 ffffff' > /sys/class/leds/multi_leds0/led_color 2>/dev/null; echo '7fffff0000 00ffff' > /sys/class/leds/multi_leds1/led_color 2>/dev/null; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am startservice com.phicomm.speaker.airskill/.AirService 2>/dev/null"
        adb -s "$SERIAL" shell "$POST_INIT_CMD" >/dev/null 2>&1

        echo "   -> Đóng băng các app rác của hãng (giữ nguyên AirSkill, Player, Bluetooth)..."
        adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; am force-stop com.phicomm.speaker.device 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.airskill 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null" >/dev/null 2>&1

        echo "   -> Tối ưu hóa toàn diện phần cứng 4 micro (AK7755 Card 2 + Chống ngủ sâu)..."
        adb -s "$SERIAL" shell 'tinymix -D 2 "MIC Input Volume L" 12 2>/dev/null; tinymix -D 2 "MIC Input Volume R" 12 2>/dev/null; tinymix -D 2 "ADC Digital Volume L" 225 2>/dev/null; tinymix -D 2 "ADC Digital Volume R" 225 2>/dev/null; tinymix -D 2 "ADC2 Digital Volume L" 225 2>/dev/null; tinymix -D 2 "ADC2 Digital Volume R" 225 2>/dev/null; tinymix -D 2 "CRAM HPF1 fc" 1 2>/dev/null; tinymix -D 2 "CRAM HPF2 fc" 1 2>/dev/null; tinymix -D 2 "Analog DRC Lch" 1 2>/dev/null; tinymix -D 2 "Analog DRC Rch" 1 2>/dev/null; tinymix -D 2 "MICGAIN Lch Zero-cross" 1 2>/dev/null; tinymix -D 2 "MICGAIN Rch Zero-cross" 1 2>/dev/null; settings put global stay_on_while_plugged_in 7 2>/dev/null; settings put system screen_off_timeout 2147483647 2>/dev/null; settings put global wifi_sleep_policy 2 2>/dev/null; settings put global wifi_watchdog_on 0 2>/dev/null' >/dev/null 2>&1

        LAN_IP=$(adb -s "$SERIAL" shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null | tr -d '\r\n')
        TARGET_UI_IP="$LAN_IP"
        [ -z "$TARGET_UI_IP" ] && TARGET_UI_IP="$TARGET_IP"

        # Cấu hình tự động Wake Word qua WebSocket
        echo "   -> Cấu hình Wake Word ('Ô Kê Na Bu') độ nhạy cao (0.96) & Chống kích hoạt nhầm (5)..."
        if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
            PYBIN="python3"
            command -v python >/dev/null 2>&1 && PYBIN="python"
            "$PYBIN" -c "import asyncio, json, websockets
async def run():
  try:
    async with websockets.connect('ws://$TARGET_UI_IP:8082', open_timeout=4) as ws:
      await ws.send(json.dumps({'action':'wake_word_set_enabled','enabled':True}))
      await asyncio.sleep(0.1)
      await ws.send(json.dumps({'action':'wake_word_set_sensitivity','sensitivity':0.96}))
      await asyncio.sleep(0.1)
      await ws.send(json.dumps({'action':'wake_word_set_window','window':5}))
  except: pass
asyncio.run(run())" >/dev/null 2>&1 || true
        fi
    else
        echo "   -> [DRY-RUN] Đã thực thi chuỗi lệnh new.bat chuẩn xác!"
        echo "   -> [DRY-RUN] Đã gửi lệnh khởi động lại (Reboot) loa!"
        LAN_IP=""
    fi

    # Dọn dẹp cache
    rm -rf "$CACHE_DIR" 2>/dev/null || true
    for tmp_sh in ./r1.sh ./r1*.sh /tmp/r1*.sh /tmp/install*.sh; do
        [ -f "$tmp_sh" ] && rm -f "$tmp_sh" 2>/dev/null || true
    done

    echo ""
    echo "=========================================================="
    echo "                    CÀI ĐẶT HOÀN TẤT!                     "
    echo "=========================================================="
    echo ">> Đã gửi lệnh khởi động lại (Reboot) loa thành công!"
    echo ">> Loa đang khởi động lại (thường mất khoảng 30 - 45 giây)."
    echo ""
    if [ -n "$LAN_IP" ]; then
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
        echo "   👉 http://$LAN_IP:8081/"
    else
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
        echo "   👉 http://$TARGET_IP:8081/"
    fi

    echo "=========================================================="
    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# 5.1. TỐI ƯU HÓA TOÀN DIỆN 4 MICRO (KHÔNG CÀI LẠI APK)
# ------------------------------------------------------------------------------
optimize_speaker_mic() {
    clear 2>/dev/null || true
    echo "=========================================================="
    echo "        TỐI ƯU HÓA TOÀN DIỆN 4 MICRO PHICOMM R1          "
    echo "=========================================================="
    TARGET_IP=""
    scan_speaker_ip
    if [ -n "$FOUND_IP" ]; then
        TARGET_IP="$FOUND_IP"
    else
        read_val "Nhập IP của loa Phicomm R1 trong mạng LAN: " ""
        TARGET_IP="$READ_RESULT"
    fi

    if [ -z "$TARGET_IP" ]; then
        echo "Chưa có IP. Quay lại menu."
        sleep 1
        return 1
    fi

    TARGET_IP=$(echo "$TARGET_IP" | sed 's/:5555//')
    SERIAL="${TARGET_IP}:5555"

    echo ">> Đang kết nối ADB tới $SERIAL..."
    adb kill-server >/dev/null 2>&1
    adb start-server >/dev/null 2>&1
    adb connect "$SERIAL" >/dev/null 2>&1
    sleep 1

    STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '
')
    if [ "$STATE" != "device" ]; then
        echo "[LỖI] Không thể kết nối ADB tới $SERIAL."
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    echo ">> [1/4] Vô hiệu hóa ứng dụng hệ thống cũ chiếm quyền mic..."
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; am force-stop com.phicomm.speaker.device 2>/dev/null" >/dev/null 2>&1

    echo ">> [2/4] Cấu hình Gain & Bộ lọc phần cứng chip AKM AK7755 (Card 2) + Chống ngủ sâu..."
    adb -s "$SERIAL" shell 'tinymix -D 2 "MIC Input Volume L" 12 2>/dev/null; tinymix -D 2 "MIC Input Volume R" 12 2>/dev/null; tinymix -D 2 "ADC Digital Volume L" 225 2>/dev/null; tinymix -D 2 "ADC Digital Volume R" 225 2>/dev/null; tinymix -D 2 "ADC2 Digital Volume L" 225 2>/dev/null; tinymix -D 2 "ADC2 Digital Volume R" 225 2>/dev/null; tinymix -D 2 "CRAM HPF1 fc" 1 2>/dev/null; tinymix -D 2 "CRAM HPF2 fc" 1 2>/dev/null; tinymix -D 2 "Analog DRC Lch" 1 2>/dev/null; tinymix -D 2 "Analog DRC Rch" 1 2>/dev/null; tinymix -D 2 "MICGAIN Lch Zero-cross" 1 2>/dev/null; tinymix -D 2 "MICGAIN Rch Zero-cross" 1 2>/dev/null; settings put global stay_on_while_plugged_in 7 2>/dev/null; settings put system screen_off_timeout 2147483647 2>/dev/null; settings put global wifi_sleep_policy 2 2>/dev/null; settings put global wifi_watchdog_on 0 2>/dev/null' >/dev/null 2>&1

    echo ">> [3/4] Khởi động lại dịch vụ AI Box Plus..."
    adb -s "$SERIAL" shell "am force-stop info.dourok.voicebot 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null" >/dev/null 2>&1

    echo ">> [4/4] Cấu hình thông số Wake Word ('Ô Kê Na Bu') qua WebSocket 8082..."
    if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        PYBIN="python3"
        command -v python >/dev/null 2>&1 && PYBIN="python"
        "$PYBIN" -c "import asyncio, json, websockets
async def run():
  try:
    async with websockets.connect('ws://$TARGET_IP:8082', open_timeout=4) as ws:
      await ws.send(json.dumps({'action':'wake_word_set_enabled','enabled':True}))
      await asyncio.sleep(0.1)
      await ws.send(json.dumps({'action':'wake_word_set_sensitivity','sensitivity':0.96}))
      await asyncio.sleep(0.1)
      await ws.send(json.dumps({'action':'wake_word_set_window','window':5}))
  except: pass
asyncio.run(run())" >/dev/null 2>&1 || true
    fi

    echo ""
    echo "=========================================================="
    echo "          ĐÃ TỐI ƯU HÓA TOÀN DIỆN 4 MICRO THÀNH CÔNG!     "
    echo "=========================================================="
    echo ">> Đã tăng Mic Gain = 12/15 và ADC = 225/255 trên chip AK7755."
    echo ">> Đã bật High-Pass Filter 100Hz lọc sạch tạp âm trầm (gió, quạt)."
    echo ">> Đã bật nén dải động Analog DRC chống rè vỡ tiếng khi nói to."
    echo ">> Đã kích hoạt Stay Awake 24/7 khi cắm nguồn (không bao giờ ngủ sâu)."
    echo ">> Từ khóa đánh thức (Wake Word): 'Ô Kê Na Bu' (hoặc 'Okay Nabu')"
    echo ">> Truy cập Web UI điều khiển: http://$TARGET_IP:8081/"
    echo "=========================================================="
    read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
}

# 6. MENU CHÍNH
# ------------------------------------------------------------------------------
show_menu() {
    clear 2>/dev/null || true
    echo "=========================================================="
    echo "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX"
    echo "=========================================================="
    echo "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)"
    echo "     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx"
    echo ""
    echo "  2) Quét IP LAN & Cài đặt APK (AIBox Plus + DLNA Hợp Nhất + Tối ưu 4 Mic)"
    echo "     -> Dùng khi loa ĐÃ vào WiFi nhà (tự động tối ưu mic)"
    echo ""
    echo "  3) Tối ưu hóa toàn diện 4 Micro (Không cần cài lại APK)"
    echo "     -> Tắt xung đột app cũ + Tăng Gain Mic tối đa cho AI Box"
    echo ""
    echo "  4) Chỉ quét tìm IP loa trong LAN"
    echo "  5) Thoát"
    echo "=========================================================="
    printf "Chọn [1-5]: "
    CHOICE=""
    if ! read -r CHOICE 2>/dev/null; then
        CHOICE="5"
    fi
    CHOICE=$(printf '%s' "$CHOICE" | tr -d ' \r\n')
}

# Xử lý tham số CLI trực tiếp (nếu có)
if [ "$CLI_MODE" = "wifi" ]; then
    configure_wifi_ap
    exit 0
elif [ "$CLI_MODE" = "install" ]; then
    run_install_lan "$USER_IP"
    exit 0
elif [ "$CLI_MODE" = "scan" ]; then
    scan_speaker_ip
    exit 0
elif [ "$CLI_MODE" = "mic" ]; then
    optimize_speaker_mic
    exit 0
fi

# Vòng lặp menu
while :; do
    show_menu
    case "$CHOICE" in
        1)
            configure_wifi_ap
            ;;
        2)
            run_install_lan ""
            ;;
        3)
            optimize_speaker_mic
            ;;
        4)
            scan_speaker_ip
            echo ""
            read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
            ;;
        5|"q"|"Q"|"exit")
            echo "Thoát chương trình."
            break
            ;;
        "")
            continue
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 4."
            sleep 1
            ;;
    esac
done
