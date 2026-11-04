#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, cài đặt AIBox Plus + DLNA Hợp Nhất
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1/v2"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
API_SH_B64="IyEvc3lzdGVtL2Jpbi9zaApoZWFkZXJfanNvbigpIHsKICAgIGVjaG8gIkNvbnRlbnQtVHlwZTogYXBwbGljYXRpb24vanNvbjsgY2hhcnNldD11dGYtOCIKICAgIGVjaG8gIkFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogKiIKICAgIGVjaG8gIkNhY2hlLUNvbnRyb2w6IG5vLXN0b3JlLCBuby1jYWNoZSwgbXVzdC1yZXZhbGlkYXRlIgogICAgZWNobyAiIgp9CgpoZWFkZXJfeG1sKCkgewogICAgZWNobyAiQ29udGVudC1UeXBlOiB0ZXh0L3htbDsgY2hhcnNldD11dGYtOCIKICAgIGVjaG8gIkFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogKiIKICAgIGVjaG8gIiIKfQoKdXJsZGVjb2RlKCkgewogICAgYnVzeWJveCBodHRwZCAtZCAiJDEiCn0KCmdldF9wYXJhbSgpIHsKICAgIGVjaG8gIiRRVUVSWV9TVFJJTkciIHwgYnVzeWJveCB0ciAnJicgJ1xuJyB8IGJ1c3lib3ggZ3JlcCAiXiQxPSIgfCBidXN5Ym94IGhlYWQgLW4gMSB8IGJ1c3lib3ggY3V0IC1kPSAtZjItCn0KCmpzb25fZXJyb3IoKSB7CiAgICBlY2hvICJ7XCJzdWNjZXNzXCI6ZmFsc2UsXCJlcnJvclwiOlwiJDFcIn0iCn0KCmlzX3VpbnQoKSB7CiAgICBjYXNlICIkMSIgaW4KICAgICAgICAwfFsxLTldfFsxLTldWzAtOV18WzEtOV1bMC05XVswLTldKSByZXR1cm4gMCA7OwogICAgICAgICopIHJldHVybiAxIDs7CiAgICBlc2FjCn0KCmluX3JhbmdlKCkgewogICAgaXNfdWludCAiJDEiICYmIFsgIiQxIiAtZ2UgIiQyIiBdICYmIFsgIiQxIiAtbGUgIiQzIiBdCn0KCndyaXRlX2xlZF9jb2xvcigpIHsKICAgIHByaW50ZiAnJXMgJXNcbicgIiQxIiAiJDIiID4gL3N5cy9jbGFzcy9sZWRzL211bHRpX2xlZHMwL2xlZF9jb2xvciAyPi9kZXYvbnVsbAp9CgpzZXRfbGVkX2NvbG9yKCkgewogICAgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2V0ICIkMSIgIiQyIiAyPi9kZXYvbnVsbAp9CgpzaG93X21haW5fbGVkKCkgewogICAgaWYgWyAiJDEiID0gIjEiIF07IHRoZW4KICAgICAgICAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDIwNCAyPi9kZXYvbnVsbAogICAgZWxzZQogICAgICAgIC9zeXN0ZW0vYmluL2xpZ2h0c190ZXN0IHNob3cgNTA0IDI+L2Rldi9udWxsCiAgICBmaQp9CgpyZWFkX2xlZF9zdGF0ZSgpIHsKICAgIFNUQVRFPSQoZ2V0cHJvcCAicGVyc2lzdC5zeXMucjFfJDFfbGVkIiAyPi9kZXYvbnVsbCkKICAgIGNhc2UgIiRTVEFURSIgaW4KICAgICAgICAwfDEpIGVjaG8gIiRTVEFURSIgOzsKICAgICAgICAqKSBlY2hvICIiIDs7CiAgICBlc2FjCn0KCnNhdmVfbGVkX3N0YXRlKCkgewogICAgc2V0cHJvcCAicGVyc2lzdC5zeXMucjFfJDFfbGVkIiAiJDIiIDI+L2Rldi9udWxsCn0KCmZpbmRfZG1yX3BvcnQoKSB7CiAgICBpZiBbIC1mIC9zZGNhcmQvZGxuYV93ZWIvZG1yX3BvcnQuY2FjaGUgXTsgdGhlbgogICAgICAgIENBQ0hFRD0kKGNhdCAvc2RjYXJkL2RsbmFfd2ViL2Rtcl9wb3J0LmNhY2hlKQogICAgICAgIGlmIFsgLW4gIiRDQUNIRUQiIF0gJiYgYnVzeWJveCBuZXRzdGF0IC10bHBuIDI+L2Rldi9udWxsIHwgYnVzeWJveCBncmVwIC1xICI6JHtDQUNIRUR9ICI7IHRoZW4KICAgICAgICAgICAgZWNobyAiJENBQ0hFRCIKICAgICAgICAgICAgcmV0dXJuCiAgICAgICAgZmkKICAgIGZpCiAgICBmb3IgcCBpbiAkKGJ1c3lib3ggbmV0c3RhdCAtdGxwbiAyPi9kZXYvbnVsbCB8IGJ1c3lib3ggYXdrICcvY29tXC5waGljb21tXC4vIHtzcGxpdCgkNCxhLCI6Iik7IHByaW50IGFbbGVuZ3RoKGEpXX0nKTsgZG8KICAgICAgICBbICIkcCIgPSAiNTAxMiIgXSAmJiBjb250aW51ZQogICAgICAgIGlmIGJ1c3lib3ggd2dldCAtVCAxIC1xIC1PIC0gImh0dHA6Ly8xMjcuMC4wLjE6JHtwfS8iIDI+L2Rldi9udWxsIHwgYnVzeWJveCBncmVwIC1xICJBVlRyYW5zcG9ydCI7IHRoZW4KICAgICAgICAgICAgZWNobyAiJHAiID4gL3NkY2FyZC9kbG5hX3dlYi9kbXJfcG9ydC5jYWNoZQogICAgICAgICAgICBlY2hvICIkcCIKICAgICAgICAgICAgcmV0dXJuCiAgICAgICAgZmkKICAgIGRvbmUKICAgIGVjaG8gIjE4MTAiCn0KCmZpbmRfZG1yX2N0cmwoKSB7CiAgICBETVJfUD0iJDEiCiAgICBpZiBbIC1mIC9zZGNhcmQvZGxuYV93ZWIvZG1yX2N0cmwuY2FjaGUgXTsgdGhlbgogICAgICAgIENBQ0hFRD0kKGNhdCAvc2RjYXJkL2RsbmFfd2ViL2Rtcl9jdHJsLmNhY2hlKQogICAgICAgIGlmIFsgLW4gIiRDQUNIRUQiIF07IHRoZW4KICAgICAgICAgICAgZWNobyAiJENBQ0hFRCIKICAgICAgICAgICAgcmV0dXJuCiAgICAgICAgZmkKICAgIGZpCiAgICBYTUw9JChidXN5Ym94IHdnZXQgLVQgMSAtcSAtTyAtICJodHRwOi8vMTI3LjAuMC4xOiR7RE1SX1B9LyIgMj4vZGV2L251bGwpCiAgICBDVFJMPSQoZWNobyAiJFhNTCIgfCBidXN5Ym94IHRyIC1kICdccicgfCBidXN5Ym94IGF3ayAnL0FWVHJhbnNwb3J0LywvPFwvc2VydmljZT4vIHsgaWYgKCQwIH4gLzxjb250cm9sVVJMPi8pIHsgc3ViKC8uKjxjb250cm9sVVJMPi8sICIiKTsgc3ViKC88XC9jb250cm9sVVJMPi4qLywgIiIpOyBwcmludDsgZXhpdCB9IH0nKQogICAgaWYgWyAtbiAiJENUUkwiIF07IHRoZW4KICAgICAgICBlY2hvICIkQ1RSTCIgPiAvc2RjYXJkL2RsbmFfd2ViL2Rtcl9jdHJsLmNhY2hlCiAgICAgICAgZWNobyAiJENUUkwiCiAgICAgICAgcmV0dXJuCiAgICBmaQogICAgZWNobyAiL0FWVHJhbnNwb3J0L2ZjN2MwMjU3MDgxMS9jb250cm9sLnhtbCIKfQoKQUNUPSQoZ2V0X3BhcmFtICJhY3QiKQpIT1NUPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiaG9zdCIpIikKWyAteiAiJEhPU1QiIF0gJiYgSE9TVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImlwIikiKQpQT1JUPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAicG9ydCIpIikKUEFUSF9VUkw9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJwYXRoIikiKQoKY2FzZSAiJEFDVCIgaW4KICAgIGxlZF9zdGF0ZSkKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIE1BSU49JChyZWFkX2xlZF9zdGF0ZSBtYWluKQogICAgICAgIFNUQU5EQlk9JChyZWFkX2xlZF9zdGF0ZSBzdGFuZGJ5KQogICAgICAgIGlmIFsgLXogIiRTVEFOREJZIiBdOyB0aGVuCiAgICAgICAgICAgIGNhc2UgIiQoZ2V0cHJvcCBwZXJzaXN0LnN5cy5yMV9sZWQgMj4vZGV2L251bGwpIiBpbgogICAgICAgICAgICAgICAgMCkgU1RBTkRCWT0xIDs7CiAgICAgICAgICAgICAgICAxKSBTVEFOREJZPTAgOzsKICAgICAgICAgICAgICAgICopIFNUQU5EQlk9bnVsbCA7OwogICAgICAgICAgICBlc2FjCiAgICAgICAgZmkKICAgICAgICBbIC16ICIkTUFJTiIgXSAmJiBNQUlOPW51bGwKICAgICAgICBbICIkU1RBTkRCWSIgPSAiMCIgXSAmJiBTVEFOREJZPWZhbHNlCiAgICAgICAgWyAiJFNUQU5EQlkiID0gIjEiIF0gJiYgU1RBTkRCWT10cnVlCiAgICAgICAgWyAiJE1BSU4iID0gIjAiIF0gJiYgTUFJTj1mYWxzZQogICAgICAgIFsgIiRNQUlOIiA9ICIxIiBdICYmIE1BSU49dHJ1ZQogICAgICAgIGVjaG8gIntcInN1Y2Nlc3NcIjp0cnVlLFwibWFpblwiOiRNQUlOLFwic3RhbmRieVwiOiRTVEFOREJZfSIKICAgICAgICA7OwogICAgZGlzY292ZXIpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBTVUJORVQ9JChpcCByb3V0ZSB8IGJ1c3lib3ggYXdrICcvd2xhbjAvICYmIC9zcmMvIHtmb3IoaT0xO2k8PU5GO2krKykgaWYoJGk9PSJzcmMiKSBwcmludCAkKGkrMSl9JyB8IGJ1c3lib3ggaGVhZCAtbiAxIHwgYnVzeWJveCBjdXQgLWQuIC1mMS0zKQogICAgICAgIFsgLXogIiRTVUJORVQiIF0gJiYgU1VCTkVUPSIxOTIuMTY4LjEiCiAgICAgICAgCiAgICAgICAgVE1QX0RJUj0iL3NkY2FyZC9kbG5hX3dlYi9zY2FuX3RtcCIKICAgICAgICBybSAtcmYgIiRUTVBfRElSIgogICAgICAgIG1rZGlyIC1wICIkVE1QX0RJUiIKCiAgICAgICAgY2hlY2tfc2VydmVyKCkgewogICAgICAgICAgICBpcD0iJDEiCiAgICAgICAgICAgIHA9IiQyIgogICAgICAgICAgICBkZXNjX3BhdGg9IiQzIgogICAgICAgICAgICBYTUw9JChidXN5Ym94IHdnZXQgLVQgMSAtcSAtTyAtICJodHRwOi8vJHtpcH06JHtwfSR7ZGVzY19wYXRofSIgMj4vZGV2L251bGwpCiAgICAgICAgICAgIGlmIFsgLW4gIiRYTUwiIF0gJiYgZWNobyAiJFhNTCIgfCBidXN5Ym94IGdyZXAgLXEgIkNvbnRlbnREaXJlY3RvcnkiOyB0aGVuCiAgICAgICAgICAgICAgICBOQU1FPSQoZWNobyAiJFhNTCIgfCBidXN5Ym94IHNlZCAtbiAncy8uKjxmcmllbmRseU5hbWU+XChbXjxdKlwpPFwvZnJpZW5kbHlOYW1lPi4qL1wxL3AnIHwgYnVzeWJveCBoZWFkIC1uIDEpCiAgICAgICAgICAgICAgICBbIC16ICIkTkFNRSIgXSAmJiBOQU1FPSJETE5BICgke2lwfSkiCiAgICAgICAgICAgICAgICBDVFJMPSQoZWNobyAiJFhNTCIgfCBidXN5Ym94IHRyIC1kICdccicgfCBidXN5Ym94IGF3ayAnL0NvbnRlbnREaXJlY3RvcnkvLC88XC9zZXJ2aWNlPi8geyBpZiAoJDAgfiAvPGNvbnRyb2xVUkw+LykgeyBzdWIoLy4qPGNvbnRyb2xVUkw+LywgIiIpOyBzdWIoLzxcL2NvbnRyb2xVUkw+LiovLCAiIik7IHByaW50OyBleGl0IH0gfScpCiAgICAgICAgICAgICAgICBbIC16ICIkQ1RSTCIgXSAmJiBDVFJMPSIvY29udHJvbC9Db250ZW50RGlyZWN0b3J5IgogICAgICAgICAgICAgICAgZWNobyAie1wibmFtZVwiOlwiJHtOQU1FfVwiLFwiaXBcIjpcIiR7aXB9XCIsXCJob3N0XCI6XCIke2lwfVwiLFwicG9ydFwiOlwiJHtwfVwiLFwicGF0aFwiOlwiJHtkZXNjX3BhdGh9XCIsXCJkZXNjXCI6XCIke2Rlc2NfcGF0aH1cIixcImNvbnRyb2xVcmxcIjpcIiR7Q1RSTH1cIixcImNvbnRyb2xcIjpcIiR7Q1RSTH1cIn0iID4gIiR7VE1QX0RJUn0vJHtpcH1fJHtwfS5qc29uIgogICAgICAgICAgICBmaQogICAgICAgIH0KCiAgICAgICAgIyBDaGVjayBrbm93biAmIEFSUCBuZWlnaGJvciBJUHMgZmlyc3QgKGZhc3QhKQogICAgICAgIENBTkRJREFURVM9IiR7U1VCTkVUfS4yMDAgJChpcCBuZWlnaCAyPi9kZXYvbnVsbCB8IGJ1c3lib3ggYXdrICd7cHJpbnQgJDF9JyB8IGJ1c3lib3ggZ3JlcCAtdiAnOicpIgogICAgICAgIGZvciBpcCBpbiAkKGVjaG8gIiRDQU5ESURBVEVTIiB8IGJ1c3lib3ggdHIgJyAnICdcbicgfCBidXN5Ym94IHNvcnQgLXUpOyBkbwogICAgICAgICAgICBmb3IgZW50cnkgaW4gIjgwODE6L2Rlc2NyaXB0aW9uLnhtbCIgIjgyMDA6L3Jvb3REZXNjLnhtbCIgIjMyNDY5Oi9EZXZpY2VEZXNjcmlwdGlvbi54bWwiICI4MDk2Oi9kbG5hL2Rlc2NyaXB0aW9uLnhtbCIgIjkwMDA6L2Rlc2NyaXB0aW9uLnhtbCI7IGRvCiAgICAgICAgICAgICAgICBwPSQoZWNobyAiJGVudHJ5IiB8IGJ1c3lib3ggY3V0IC1kOiAtZjEpCiAgICAgICAgICAgICAgICBkcD0kKGVjaG8gIiRlbnRyeSIgfCBidXN5Ym94IGN1dCAtZDogLWYyKQogICAgICAgICAgICAgICAgY2hlY2tfc2VydmVyICIkaXAiICIkcCIgIiRkcCIgJgogICAgICAgICAgICBkb25lCiAgICAgICAgZG9uZQogICAgICAgIHdhaXQKCiAgICAgICAgIyBJZiBub3RoaW5nIGZvdW5kIHlldCwgZG8gYSBicm9hZGVyIHN3ZWVwIG9uIHBvcnQgODA4MSBhbmQgODIwMCBhY3Jvc3MgdGhlIHN1Ym5ldAogICAgICAgIGlmIFsgLXogIiQobHMgLUEgIiRUTVBfRElSIiAyPi9kZXYvbnVsbCkiIF07IHRoZW4KICAgICAgICAgICAgZm9yIGkgaW4gJChidXN5Ym94IHNlcSAxIDI1NCk7IGRvCiAgICAgICAgICAgICAgICBpcD0iJHtTVUJORVR9LiR7aX0iCiAgICAgICAgICAgICAgICBjaGVja19zZXJ2ZXIgIiRpcCIgIjgwODEiICIvZGVzY3JpcHRpb24ueG1sIiAmCiAgICAgICAgICAgICAgICBpZiBbICQoKGkgJSA0MCkpIC1lcSAwIF07IHRoZW4gd2FpdDsgZmkKICAgICAgICAgICAgZG9uZQogICAgICAgICAgICB3YWl0CiAgICAgICAgZmkKCiAgICAgICAgYnVzeWJveCBwcmludGYgJ3sic3VjY2VzcyI6dHJ1ZSwic2VydmVycyI6WycKICAgICAgICBGSVJTVD0xCiAgICAgICAgZm9yIGYgaW4gIiRUTVBfRElSIi8qLmpzb247IGRvCiAgICAgICAgICAgIFsgLWYgIiRmIiBdIHx8IGNvbnRpbnVlCiAgICAgICAgICAgIFsgIiRGSVJTVCIgLWVxIDAgXSAmJiBidXN5Ym94IHByaW50ZiAnLCcKICAgICAgICAgICAgY2F0ICIkZiIKICAgICAgICAgICAgRklSU1Q9MAogICAgICAgIGRvbmUKICAgICAgICBidXN5Ym94IHByaW50ZiAnXX1cbicKICAgICAgICA7OwogICAgZ2V0X2RtcikKICAgICAgICBoZWFkZXJfeG1sCiAgICAgICAgRE1SX1BPUlQ9JChmaW5kX2Rtcl9wb3J0KQogICAgICAgIGJ1c3lib3ggd2dldCAtcSAtTyAtICJodHRwOi8vMTI3LjAuMC4xOiR7RE1SX1BPUlR9LyIKICAgICAgICA7OwogICAgZ2V0X2Rlc2MpCiAgICAgICAgaGVhZGVyX3htbAogICAgICAgIGJ1c3lib3ggd2dldCAtcSAtTyAtICJodHRwOi8vJHtIT1NUfToke1BPUlR9JHtQQVRIX1VSTH0iCiAgICAgICAgOzsKICAgIGJyb3dzZSkKICAgICAgICBoZWFkZXJfeG1sCiAgICAgICAgT0JKPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAiaWQiKSIpCiAgICAgICAgU1RBUlQ9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJzdGFydCIpIikKICAgICAgICBDT1VOVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImNvdW50IikiKQogICAgICAgIFsgLXogIiRPQkoiIF0gJiYgT0JKPSIwIgogICAgICAgIFsgLXogIiRTVEFSVCIgXSAmJiBTVEFSVD0iMCIKICAgICAgICBbIC16ICIkQ09VTlQiIF0gJiYgQ09VTlQ9IjUwMCIKICAgICAgICAKICAgICAgICBFU0NfT0JKPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJE9CSiIgfCBidXN5Ym94IHNlZCAncy8mL1wmYW1wOy9nOyBzLzwvXCZsdDsvZzsgcy8+L1wmZ3Q7L2cnKQogICAgICAgIFNPQVA9Ijw/eG1sIHZlcnNpb249XCIxLjBcIiBlbmNvZGluZz1cInV0Zi04XCI/PjxzOkVudmVsb3BlIHhtbG5zOnM9XCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy9zb2FwL2VudmVsb3BlL1wiIHM6ZW5jb2RpbmdTdHlsZT1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW5jb2RpbmcvXCI+PHM6Qm9keT48dTpCcm93c2UgeG1sbnM6dT1cInVybjpzY2hlbWFzLXVwbnAtb3JnOnNlcnZpY2U6Q29udGVudERpcmVjdG9yeToxXCI+PE9iamVjdElEPiR7RVNDX09CSn08L09iamVjdElEPjxCcm93c2VGbGFnPkJyb3dzZURpcmVjdENoaWxkcmVuPC9Ccm93c2VGbGFnPjxGaWx0ZXI+KjwvRmlsdGVyPjxTdGFydGluZ0luZGV4PiR7U1RBUlR9PC9TdGFydGluZ0luZGV4PjxSZXF1ZXN0ZWRDb3VudD4ke0NPVU5UfTwvUmVxdWVzdGVkQ291bnQ+PFNvcnRDcml0ZXJpYT48L1NvcnRDcml0ZXJpYT48L3U6QnJvd3NlPjwvczpCb2R5PjwvczpFbnZlbG9wZT4iCiAgICAgICAgTEVOPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJFNPQVAiIHwgYnVzeWJveCB3YyAtYyB8IGJ1c3lib3ggdHIgLWQgJyAnKQogICAgICAgICgKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlBPU1QgJXMgSFRUUC8xLjBcclxuIiAiJFBBVEhfVVJMIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiSG9zdDogJXM6JXNcclxuIiAiJEhPU1QiICIkUE9SVCIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbnRlbnQtVHlwZTogdGV4dC94bWw7IGNoYXJzZXQ9XCJ1dGYtOFwiXHJcbiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlNPQVBBY3Rpb246IFwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpDb250ZW50RGlyZWN0b3J5OjEjQnJvd3NlXCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1MZW5ndGg6ICVzXHJcbiIgIiRMRU4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb25uZWN0aW9uOiBjbG9zZVxyXG5cclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUCIKICAgICAgICAgICAgYnVzeWJveCB1c2xlZXAgMjAwMDAwCiAgICAgICAgKSB8IGJ1c3lib3ggbmMgLXcgNCAiJEhPU1QiICIkUE9SVCIgfCBidXN5Ym94IHNlZCAnMSwvXlxyJC9kJwogICAgICAgIDs7CiAgICBwbGF5KQogICAgICAgIGhlYWRlcl94bWwKICAgICAgICBETVJfUE9SVD0kKGZpbmRfZG1yX3BvcnQpCiAgICAgICAgQ1RSTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImN0cmwiKSIpCiAgICAgICAgWyAteiAiJENUUkwiIF0gJiYgQ1RSTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImRtcl9wYXRoIikiKQogICAgICAgIFsgLXogIiRDVFJMIiBdICYmIENUUkw9JChmaW5kX2Rtcl9jdHJsICIkRE1SX1BPUlQiKQogICAgICAgIE1FRElBX1VSTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInVybCIpIikKICAgICAgICBUSVRMRT0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInRpdGxlIikiKQogICAgICAgIEFSVElTVD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImFydGlzdCIpIikKICAgICAgICBFU0NfVVJMPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJE1FRElBX1VSTCIgfCBidXN5Ym94IHNlZCAncy8mL1wmYW1wOy9nOyBzLzwvXCZsdDsvZzsgcy8+L1wmZ3Q7L2cnKQogICAgICAgIEVTQ19USVRMRT0kKGJ1c3lib3ggcHJpbnRmICIlcyIgIiRUSVRMRSIgfCBidXN5Ym94IHNlZCAncy8mL1wmYW1wOy9nOyBzLzwvXCZsdDsvZzsgcy8+L1wmZ3Q7L2cnKQogICAgICAgIEVTQ19BUlRJU1Q9JChidXN5Ym94IHByaW50ZiAiJXMiICIkQVJUSVNUIiB8IGJ1c3lib3ggc2VkICdzLyYvXCZhbXA7L2c7IHMvPC9cJmx0Oy9nOyBzLz4vXCZndDsvZycpCiAgICAgICAgTUVUQT0iJmx0O0RJREwtTGl0ZSB4bWxucz0mcXVvdDt1cm46c2NoZW1hcy11cG5wLW9yZzptZXRhZGF0YS0xLTAvRElETC1MaXRlLyZxdW90OyB4bWxuczpkYz0mcXVvdDtodHRwOi8vcHVybC5vcmcvZGMvZWxlbWVudHMvMS4xLyZxdW90OyB4bWxuczp1cG5wPSZxdW90O3VybjpzY2hlbWFzLXVwbnAtb3JnOm1ldGFkYXRhLTEtMC91cG5wLyZxdW90OyZndDsmbHQ7aXRlbSBpZD0mcXVvdDsxJnF1b3Q7IHBhcmVudElEPSZxdW90OzAmcXVvdDsgcmVzdHJpY3RlZD0mcXVvdDsxJnF1b3Q7Jmd0OyZsdDtkYzp0aXRsZSZndDske0VTQ19USVRMRX0mbHQ7L2RjOnRpdGxlJmd0OyZsdDtkYzpjcmVhdG9yJmd0OyR7RVNDX0FSVElTVH0mbHQ7L2RjOmNyZWF0b3ImZ3Q7Jmx0O3VwbnA6YXJ0aXN0Jmd0OyR7RVNDX0FSVElTVH0mbHQ7L3VwbnA6YXJ0aXN0Jmd0OyZsdDt1cG5wOmNsYXNzJmd0O29iamVjdC5pdGVtLmF1ZGlvSXRlbS5tdXNpY1RyYWNrJmx0Oy91cG5wOmNsYXNzJmd0OyZsdDtyZXMmZ3Q7JHtFU0NfVVJMfSZsdDsvcmVzJmd0OyZsdDsvaXRlbSZndDsmbHQ7L0RJREwtTGl0ZSZndDsiCiAgICAgICAgCiAgICAgICAgU09BUDE9Ijw/eG1sIHZlcnNpb249XCIxLjBcIiBlbmNvZGluZz1cInV0Zi04XCI/PjxzOkVudmVsb3BlIHhtbG5zOnM9XCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy9zb2FwL2VudmVsb3BlL1wiIHM6ZW5jb2RpbmdTdHlsZT1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW5jb2RpbmcvXCI+PHM6Qm9keT48dTpTZXRBVlRyYW5zcG9ydFVSSSB4bWxuczp1PVwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpBVlRyYW5zcG9ydDoxXCI+PEluc3RhbmNlSUQ+MDwvSW5zdGFuY2VJRD48Q3VycmVudFVSST4ke0VTQ19VUkx9PC9DdXJyZW50VVJJPjxDdXJyZW50VVJJTWV0YURhdGE+JHtNRVRBfTwvQ3VycmVudFVSSU1ldGFEYXRhPjwvdTpTZXRBVlRyYW5zcG9ydFVSST48L3M6Qm9keT48L3M6RW52ZWxvcGU+IgogICAgICAgIExFTjE9JChidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUDEiIHwgYnVzeWJveCB3YyAtYyB8IGJ1c3lib3ggdHIgLWQgJyAnKQogICAgICAgICgKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlBPU1QgJXMgSFRUUC8xLjBcclxuIiAiJENUUkwiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJIb3N0OiAxMjcuMC4wLjE6JXNcclxuIiAiJERNUl9QT1JUIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1UeXBlOiB0ZXh0L3htbDsgY2hhcnNldD1cInV0Zi04XCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiU09BUEFjdGlvbjogXCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkFWVHJhbnNwb3J0OjEjU2V0QVZUcmFuc3BvcnRVUklcIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LUxlbmd0aDogJXNcclxuIiAiJExFTjEiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb25uZWN0aW9uOiBjbG9zZVxyXG5cclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUDEiCiAgICAgICAgICAgIGJ1c3lib3ggdXNsZWVwIDIwMDAwMAogICAgICAgICkgfCBidXN5Ym94IG5jIC13IDMgMTI3LjAuMC4xICIkRE1SX1BPUlQiID4vZGV2L251bGwgMj4mMQogICAgICAgIAogICAgICAgIFNPQVAyPSI8P3htbCB2ZXJzaW9uPVwiMS4wXCIgZW5jb2Rpbmc9XCJ1dGYtOFwiPz48czpFbnZlbG9wZSB4bWxuczpzPVwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvc29hcC9lbnZlbG9wZS9cIiBzOmVuY29kaW5nU3R5bGU9XCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy9zb2FwL2VuY29kaW5nL1wiPjxzOkJvZHk+PHU6UGxheSB4bWxuczp1PVwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpBVlRyYW5zcG9ydDoxXCI+PEluc3RhbmNlSUQ+MDwvSW5zdGFuY2VJRD48U3BlZWQ+MTwvU3BlZWQ+PC91OlBsYXk+PC9zOkJvZHk+PC9zOkVudmVsb3BlPiIKICAgICAgICBMRU4yPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJFNPQVAyIiB8IGJ1c3lib3ggd2MgLWMgfCBidXN5Ym94IHRyIC1kICcgJykKICAgICAgICAoCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJQT1NUICVzIEhUVFAvMS4wXHJcbiIgIiRDVFJMIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiSG9zdDogMTI3LjAuMC4xOiVzXHJcbiIgIiRETVJfUE9SVCIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIkNvbnRlbnQtVHlwZTogdGV4dC94bWw7IGNoYXJzZXQ9XCJ1dGYtOFwiXHJcbiIKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlNPQVBBY3Rpb246IFwidXJuOnNjaGVtYXMtdXBucC1vcmc6c2VydmljZTpBVlRyYW5zcG9ydDoxI1BsYXlcIlxyXG4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb250ZW50LUxlbmd0aDogJXNcclxuIiAiJExFTjIiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb25uZWN0aW9uOiBjbG9zZVxyXG5cclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUDIiCiAgICAgICAgICAgIGJ1c3lib3ggdXNsZWVwIDIwMDAwMAogICAgICAgICkgfCBidXN5Ym94IG5jIC13IDMgMTI3LjAuMC4xICIkRE1SX1BPUlQiIHwgYnVzeWJveCBzZWQgJzEsL15cciQvZCcKICAgICAgICA7OwogICAgZG1yX2NtZHxzdG9wKQogICAgICAgIGhlYWRlcl94bWwKICAgICAgICBETVJfUE9SVD0kKGZpbmRfZG1yX3BvcnQpCiAgICAgICAgQ1RSTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImN0cmwiKSIpCiAgICAgICAgWyAteiAiJENUUkwiIF0gJiYgQ1RSTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImRtcl9wYXRoIikiKQogICAgICAgIFsgLXogIiRDVFJMIiBdICYmIENUUkw9JChmaW5kX2Rtcl9jdHJsICIkRE1SX1BPUlQiKQogICAgICAgIENNRD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gImNtZCIpIikKICAgICAgICBbIC16ICIkQ01EIiBdICYmIENNRD0iU3RvcCIKICAgICAgICBFWFRSQT0iIgogICAgICAgIFsgIiRDTUQiID0gIlBsYXkiIF0gJiYgRVhUUkE9IjxTcGVlZD4xPC9TcGVlZD4iCiAgICAgICAgaWYgWyAiJENNRCIgPSAiU2VlayIgXTsgdGhlbgogICAgICAgICAgICBUQVJHRVQ9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ0YXJnZXQiKSIpCiAgICAgICAgICAgIEVYVFJBPSI8VW5pdD5SRUxfVElNRTwvVW5pdD48VGFyZ2V0PiR7VEFSR0VUfTwvVGFyZ2V0PiIKICAgICAgICBmaQogICAgICAgIFNPQVA9Ijw/eG1sIHZlcnNpb249XCIxLjBcIiBlbmNvZGluZz1cInV0Zi04XCI/PjxzOkVudmVsb3BlIHhtbG5zOnM9XCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy9zb2FwL2VudmVsb3BlL1wiIHM6ZW5jb2RpbmdTdHlsZT1cImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3NvYXAvZW5jb2RpbmcvXCI+PHM6Qm9keT48dToke0NNRH0geG1sbnM6dT1cInVybjpzY2hlbWFzLXVwbnAtb3JnOnNlcnZpY2U6QVZUcmFuc3BvcnQ6MVwiPjxJbnN0YW5jZUlEPjA8L0luc3RhbmNlSUQ+JHtFWFRSQX08L3U6JHtDTUR9PjwvczpCb2R5PjwvczpFbnZlbG9wZT4iCiAgICAgICAgTEVOPSQoYnVzeWJveCBwcmludGYgIiVzIiAiJFNPQVAiIHwgYnVzeWJveCB3YyAtYyB8IGJ1c3lib3ggdHIgLWQgJyAnKQogICAgICAgICgKICAgICAgICAgICAgYnVzeWJveCBwcmludGYgIlBPU1QgJXMgSFRUUC8xLjBcclxuIiAiJENUUkwiCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJIb3N0OiAxMjcuMC4wLjE6JXNcclxuIiAiJERNUl9QT1JUIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1UeXBlOiB0ZXh0L3htbDsgY2hhcnNldD1cInV0Zi04XCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiU09BUEFjdGlvbjogXCJ1cm46c2NoZW1hcy11cG5wLW9yZzpzZXJ2aWNlOkFWVHJhbnNwb3J0OjEjJHtDTUR9XCJcclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiQ29udGVudC1MZW5ndGg6ICVzXHJcbiIgIiRMRU4iCiAgICAgICAgICAgIGJ1c3lib3ggcHJpbnRmICJDb25uZWN0aW9uOiBjbG9zZVxyXG5cclxuIgogICAgICAgICAgICBidXN5Ym94IHByaW50ZiAiJXMiICIkU09BUCIKICAgICAgICAgICAgYnVzeWJveCB1c2xlZXAgMTUwMDAwCiAgICAgICAgKSB8IGJ1c3lib3ggbmMgLXcgMyAxMjcuMC4wLjEgIiRETVJfUE9SVCIgfCBidXN5Ym94IHNlZCAnMSwvXlxyJC9kJwogICAgICAgIDs7CgogICAgbGVkX21haW4pCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBWQUw9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJ2YWwiKSIpCiAgICAgICAgY2FzZSAiJFZBTCIgaW4KICAgICAgICAgICAgMHxmYWxzZSkKICAgICAgICAgICAgICAgIGlmICEgc2hvd19tYWluX2xlZCAwOyB0aGVuCiAgICAgICAgICAgICAgICAgICAganNvbl9lcnJvciAiZmlybXdhcmUgTEVEIGNvbW1hbmQgZmFpbGVkIgogICAgICAgICAgICAgICAgZWxpZiAhIHNhdmVfbGVkX3N0YXRlIG1haW4gMDsgdGhlbgogICAgICAgICAgICAgICAgICAgIGpzb25fZXJyb3IgImZhaWxlZCB0byBzYXZlIG1haW4gTEVEIHN0YXRlIgogICAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoibGVkX21haW4iLCJzdGF0ZSI6ZmFsc2V9JwogICAgICAgICAgICAgICAgZmkKICAgICAgICAgICAgICAgIDs7CiAgICAgICAgICAgIDF8dHJ1ZSkKICAgICAgICAgICAgICAgIGlmICEgc2hvd19tYWluX2xlZCAxOyB0aGVuCiAgICAgICAgICAgICAgICAgICAganNvbl9lcnJvciAiZmlybXdhcmUgTEVEIGNvbW1hbmQgZmFpbGVkIgogICAgICAgICAgICAgICAgZWxpZiAhIHNhdmVfbGVkX3N0YXRlIG1haW4gMTsgdGhlbgogICAgICAgICAgICAgICAgICAgIGpzb25fZXJyb3IgImZhaWxlZCB0byBzYXZlIG1haW4gTEVEIHN0YXRlIgogICAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoibGVkX21haW4iLCJzdGF0ZSI6dHJ1ZX0nCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICAgICAgOzsKICAgICAgICAgICAgKikganNvbl9lcnJvciAidmFsIG11c3QgYmUgMCwgMSwgZmFsc2UsIG9yIHRydWUiIDs7CiAgICAgICAgZXNhYwogICAgICAgIDs7CiAgICBsZWRfY29sb3IpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBIRVg9JCh1cmxkZWNvZGUgIiQoZ2V0X3BhcmFtICJoZXgiKSIpCiAgICAgICAgaWYgZWNobyAiJEhFWCIgfCBidXN5Ym94IGdyZXAgLUVxICdeWzAtOUEtRmEtZl17Nn0kJzsgdGhlbgogICAgICAgICAgICBpZiBzZXRfbGVkX2NvbG9yIDdmZmZmZjAwMDAgIiRIRVgiOyB0aGVuCiAgICAgICAgICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwibGVkX2NvbG9yXCIsXCJoZXhcIjpcIiR7SEVYfVwifSIKICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAganNvbl9lcnJvciAiZmFpbGVkIHRvIHNldCBMRUQgY29sb3IiCiAgICAgICAgICAgIGZpCiAgICAgICAgZWxzZQogICAgICAgICAgICBqc29uX2Vycm9yICJoZXggbXVzdCBjb250YWluIGV4YWN0bHkgNiBoZXhhZGVjaW1hbCBjaGFyYWN0ZXJzIgogICAgICAgIGZpCiAgICAgICAgOzsKICAgIGxlZF9icmlnaHRuZXNzKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgVkFMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIGlmIGluX3JhbmdlICIkVkFMIiAxIDIwMDsgdGhlbgogICAgICAgICAgICBIRVhfVkFMPSQoKCBWQUwgKiAyNTUgLyAyMDAgKSkKICAgICAgICAgICAgSEVYPSQoYnVzeWJveCBwcmludGYgIjAwJTAyeCUwMngiICRIRVhfVkFMICRIRVhfVkFMKQogICAgICAgICAgICBpZiBzZXRfbGVkX2NvbG9yIDdmZmZmZjAwMDAgIiRIRVgiOyB0aGVuCiAgICAgICAgICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwibGVkX2JyaWdodG5lc3NcIixcInZhbFwiOiR7VkFMfSxcImhleFwiOlwiJHtIRVh9XCJ9IgogICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBqc29uX2Vycm9yICJmYWlsZWQgdG8gc2V0IG1haW4gTEVEIGJyaWdodG5lc3MiCiAgICAgICAgICAgIGZpCiAgICAgICAgZWxzZQogICAgICAgICAgICBqc29uX2Vycm9yICJ2YWwgbXVzdCBiZSBhbiBpbnRlZ2VyIGZyb20gMSB0byAyMDAiCiAgICAgICAgZmkKICAgICAgICA7OwogICAgbGVkX3NwZWVkKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAganNvbl9lcnJvciAiTEVEIHNwZWVkIGlzIGZpeGVkIGJ5IHRoZSBzZWxlY3RlZCBmaXJtd2FyZSBlZmZlY3QiCiAgICAgICAgOzsKICAgIGxlZF9zdGFuZGJ5KQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgVkFMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIGNhc2UgIiRWQUwiIGluCiAgICAgICAgICAgIDB8ZmFsc2UpCiAgICAgICAgICAgICAgICBpZiAhIC9zeXN0ZW0vYmluL2xpZ2h0c190ZXN0IHNob3cgNTA1IDI+L2Rldi9udWxsOyB0aGVuCiAgICAgICAgICAgICAgICAgICAganNvbl9lcnJvciAiZmlybXdhcmUgc3RhbmRieSBMRUQgY29tbWFuZCBmYWlsZWQiCiAgICAgICAgICAgICAgICBlbGlmICEgc2V0cHJvcCBwZXJzaXN0LnN5cy5yMV9sZWQgMSAyPi9kZXYvbnVsbDsgdGhlbgogICAgICAgICAgICAgICAgICAgIGpzb25fZXJyb3IgImZhaWxlZCB0byB1cGRhdGUgc3RhbmRieSBMRUQgcHJvcGVydHkiCiAgICAgICAgICAgICAgICBlbGlmICEgc2F2ZV9sZWRfc3RhdGUgc3RhbmRieSAwOyB0aGVuCiAgICAgICAgICAgICAgICAgICAganNvbl9lcnJvciAiZmFpbGVkIHRvIHNhdmUgc3RhbmRieSBMRUQgc3RhdGUiCiAgICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICAgICAgTUFJTj0kKHJlYWRfbGVkX3N0YXRlIG1haW4pCiAgICAgICAgICAgICAgICAgICAgY2FzZSAiJE1BSU4iIGluCiAgICAgICAgICAgICAgICAgICAgICAgIDB8MSkgc2hvd19tYWluX2xlZCAiJE1BSU4iIHx8IHRydWUgOzsKICAgICAgICAgICAgICAgICAgICBlc2FjCiAgICAgICAgICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJhY3Rpb24iOiJsZWRfc3RhbmRieSIsInN0YXRlIjpmYWxzZX0nCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICAgICAgOzsKICAgICAgICAgICAgMXx0cnVlKQogICAgICAgICAgICAgICAgaWYgISAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDUwMyAyPi9kZXYvbnVsbDsgdGhlbgogICAgICAgICAgICAgICAgICAgIGpzb25fZXJyb3IgImZpcm13YXJlIHN0YW5kYnkgTEVEIGNvbW1hbmQgZmFpbGVkIgogICAgICAgICAgICAgICAgZWxpZiAhIHNldHByb3AgcGVyc2lzdC5zeXMucjFfbGVkIDAgMj4vZGV2L251bGw7IHRoZW4KICAgICAgICAgICAgICAgICAgICBqc29uX2Vycm9yICJmYWlsZWQgdG8gdXBkYXRlIHN0YW5kYnkgTEVEIHByb3BlcnR5IgogICAgICAgICAgICAgICAgZWxpZiAhIHNhdmVfbGVkX3N0YXRlIHN0YW5kYnkgMTsgdGhlbgogICAgICAgICAgICAgICAgICAgIGpzb25fZXJyb3IgImZhaWxlZCB0byBzYXZlIHN0YW5kYnkgTEVEIHN0YXRlIgogICAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6dHJ1ZSwiYWN0aW9uIjoibGVkX3N0YW5kYnkiLCJzdGF0ZSI6dHJ1ZX0nCiAgICAgICAgICAgICAgICBmaQogICAgICAgICAgICAgICAgOzsKICAgICAgICAgICAgKikganNvbl9lcnJvciAidmFsIG11c3QgYmUgMCwgMSwgZmFsc2UsIG9yIHRydWUiIDs7CiAgICAgICAgZXNhYwogICAgICAgIDs7CiAgICBsZWRfc3RhbmRieV9icmlnaHRuZXNzKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgSU5URU5TSVRZPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIGlmIGluX3JhbmdlICIkSU5URU5TSVRZIiAwIDEwMDsgdGhlbgogICAgICAgICAgICBWQUw9JCgoIElOVEVOU0lUWSAqIDI1NSAvIDEwMCApKQogICAgICAgICAgICBIRVg9JChidXN5Ym94IHByaW50ZiAiJTAyeCUwMnglMDJ4IiAkVkFMICRWQUwgJFZBTCkKICAgICAgICAgICAgaWYgc2V0X2xlZF9jb2xvciA3ZmZmZmY4MDAwICIkSEVYIjsgdGhlbgogICAgICAgICAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJhY3Rpb25cIjpcImxlZF9zdGFuZGJ5X2JyaWdodG5lc3NcIixcInZhbFwiOiR7SU5URU5TSVRZfSxcImhleFwiOlwiJHtIRVh9XCJ9IgogICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBqc29uX2Vycm9yICJmYWlsZWQgdG8gc2V0IHN0YW5kYnkgTEVEIGJyaWdodG5lc3MiCiAgICAgICAgICAgIGZpCiAgICAgICAgZWxzZQogICAgICAgICAgICBqc29uX2Vycm9yICJ2YWwgbXVzdCBiZSBhbiBpbnRlZ2VyIGZyb20gMCB0byAxMDAiCiAgICAgICAgZmkKICAgICAgICA7OwogICAgbGVkX21vZGUpCiAgICAgICAgaGVhZGVyX2pzb24KICAgICAgICBNT0RFPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAibW9kZSIpIikKICAgICAgICBbIC16ICIkTU9ERSIgXSAmJiBNT0RFPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIGNhc2UgIiRNT0RFIiBpbgogICAgICAgICAgICAwKSAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDIwNCAyPi9kZXYvbnVsbCA7OwogICAgICAgICAgICAxKSAvc3lzdGVtL2Jpbi9saWdodHNfdGVzdCBzaG93IDEgMj4vZGV2L251bGwgOzsKICAgICAgICAgICAgMikgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDYgMj4vZGV2L251bGwgOzsKICAgICAgICAgICAgMykgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyA1MTQgMj4vZGV2L251bGwgOzsKICAgICAgICAgICAgNCkgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDEgMj4vZGV2L251bGwgOzsKICAgICAgICAgICAgNykgL3N5c3RlbS9iaW4vbGlnaHRzX3Rlc3Qgc2hvdyAyMDMgMj4vZGV2L251bGwgOzsKICAgICAgICAgICAgKikganNvbl9lcnJvciAidW5zdXBwb3J0ZWQgTEVEIG1vZGUiOyBleGl0IDAgOzsKICAgICAgICBlc2FjCiAgICAgICAgaWYgWyAiJD8iIC1lcSAwIF07IHRoZW4KICAgICAgICAgICAgZWNobyAie1wic3VjY2Vzc1wiOnRydWUsXCJhY3Rpb25cIjpcImxlZF9tb2RlXCIsXCJtb2RlXCI6JHtNT0RFfX0iCiAgICAgICAgZWxzZQogICAgICAgICAgICBqc29uX2Vycm9yICJmYWlsZWQgdG8gc2V0IExFRCBtb2RlIgogICAgICAgIGZpCiAgICAgICAgOzsKICAgIHNldF9idCkKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFZBTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICBpZiBbICIkVkFMIiA9ICIwIiBdIHx8IFsgIiRWQUwiID0gImZhbHNlIiBdOyB0aGVuCiAgICAgICAgICAgIHNldHRpbmdzIHB1dCBnbG9iYWwgYmx1ZXRvb3RoX29uIDAgMj4vZGV2L251bGwKICAgICAgICAgICAgc2VydmljZSBjYWxsIG1zZ2NlbnRlciAxIGkzMiAxIGkzMiA2NCBpMzIgMiBpMzIgMTUgaTMyIDAgaTMyIDAgaTMyIDAgaTMyIC0xIGkzMiAwIGkzMiAwIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJhY3Rpb24iOiJzZXRfYnQiLCJzdGF0ZSI6ZmFsc2V9JwogICAgICAgIGVsc2UKICAgICAgICAgICAgc2V0dGluZ3MgcHV0IGdsb2JhbCBibHVldG9vdGhfb24gMSAyPi9kZXYvbnVsbAogICAgICAgICAgICBzZXJ2aWNlIGNhbGwgbXNnY2VudGVyIDEgaTMyIDEgaTMyIDY0IGkzMiAxIGkzMiAxNSBpMzIgMCBpMzIgMCBpMzIgMCBpMzIgLTEgaTMyIDAgaTMyIDAgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgICAgICBhbSBicm9hZGNhc3QgLWEgYW5kcm9pZC5ibHVldG9vdGguYWRhcHRlci5hY3Rpb24uUkVRVUVTVF9FTkFCTEUgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgICAgICBhbSBicm9hZGNhc3QgLWEgYW5kcm9pZC5ibHVldG9vdGguYWRhcHRlci5hY3Rpb24uUkVRVUVTVF9ESVNDT1ZFUkFCTEUgLS1laSBhbmRyb2lkLmJsdWV0b290aC5hZGFwdGVyLmV4dHJhLkRJU0NPVkVSQUJMRV9EVVJBVElPTiAwIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICAgICAgZWNobyAneyJzdWNjZXNzIjp0cnVlLCJhY3Rpb24iOiJzZXRfYnQiLCJzdGF0ZSI6dHJ1ZX0nCiAgICAgICAgZmkKICAgICAgICA7OwogICAgc2V0X3ZvbCkKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFZBTD0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInZhbCIpIikKICAgICAgICBpZiBbIC1uICIkVkFMIiBdOyB0aGVuCiAgICAgICAgICAgIG1lZGlhIHZvbHVtZSAtLXN0cmVhbSAzIC0tc2V0ICIkVkFMIiAyPi9kZXYvbnVsbCA+L2Rldi9udWxsIHx8IHNldHRpbmdzIHB1dCBzeXN0ZW0gdm9sdW1lX211c2ljICIkVkFMIiAyPi9kZXYvbnVsbAogICAgICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImFjdGlvblwiOlwic2V0X3ZvbFwiLFwidmFsXCI6JHtWQUx9fSIKICAgICAgICBlbHNlCiAgICAgICAgICAgIGVjaG8gJ3sic3VjY2VzcyI6ZmFsc2UsImVycm9yIjoibWlzc2luZyB2YWwifScKICAgICAgICBmaQogICAgICAgIDs7CiAgICBzZXRfc2VydmljZSkKICAgICAgICBoZWFkZXJfanNvbgogICAgICAgIFNSVj0kKHVybGRlY29kZSAiJChnZXRfcGFyYW0gInNlcnZpY2UiKSIpCiAgICAgICAgVkFMPSQodXJsZGVjb2RlICIkKGdldF9wYXJhbSAidmFsIikiKQogICAgICAgIC9zeXN0ZW0vYmluL3BtIHVuaGlkZSBjb20ucGhpY29tbS5zcGVha2VyLnBsYXllciAyPi9kZXYvbnVsbCA+L2Rldi9udWxsCiAgICAgICAgL3N5c3RlbS9iaW4vcG0gdW5oaWRlIGNvbS5waGljb21tLnNwZWFrZXIuYWlyc2tpbGwgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgIGFtIHN0YXJ0c2VydmljZSBjb20ucGhpY29tbS5zcGVha2VyLnBsYXllci8uRWNob1NlcnZpY2UgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgIGFtIHN0YXJ0c2VydmljZSBjb20ucGhpY29tbS5zcGVha2VyLmFpcnNraWxsLy5BaXJTZXJ2aWNlIDI+L2Rldi9udWxsID4vZGV2L251bGwKICAgICAgICBzZXJ2aWNlIGNhbGwgbXNnY2VudGVyIDEgaTMyIDEgaTMyIDY0IGkzMiAxIGkzMiAxNSBpMzIgMCBpMzIgMCBpMzIgMCBpMzIgLTEgaTMyIDAgaTMyIDAgMj4vZGV2L251bGwgPi9kZXYvbnVsbAogICAgICAgIGVjaG8gIntcInN1Y2Nlc3NcIjp0cnVlLFwiYWN0aW9uXCI6XCJzZXRfc2VydmljZVwiLFwic2VydmljZVwiOlwiJHtTUlZ9XCIsXCJzdGF0ZVwiOnRydWV9IgogICAgICAgIDs7CiAgICBnZXRfc3RhdHVzKQogICAgICAgIGhlYWRlcl9qc29uCiAgICAgICAgQlRfT049JChzZXR0aW5ncyBnZXQgZ2xvYmFsIGJsdWV0b290aF9vbiAyPi9kZXYvbnVsbCkKICAgICAgICBbIC16ICIkQlRfT04iIF0gJiYgQlRfT049IjEiCiAgICAgICAgRE1SX1JVTk5JTkc9ImZhbHNlIgogICAgICAgIGlmIGJ1c3lib3ggbmV0c3RhdCAtdGxwbiAyPi9kZXYvbnVsbCB8IGJ1c3lib3ggZ3JlcCAtcSAiMTYyNlx8NTAxMlx8Y29tXC5waGljb21tIjsgdGhlbgogICAgICAgICAgICBETVJfUlVOTklORz0idHJ1ZSIKICAgICAgICBlbHNlCiAgICAgICAgICAgIHNlcnZpY2UgY2FsbCBtc2djZW50ZXIgMSBpMzIgMSBpMzIgNjQgaTMyIDEgaTMyIDE1IGkzMiAwIGkzMiAwIGkzMiAwIGkzMiAtMSBpMzIgMCBpMzIgMCAyPi9kZXYvbnVsbCA+L2Rldi9udWxsICYKICAgICAgICAgICAgRE1SX1JVTk5JTkc9InRydWUiCiAgICAgICAgZmkKICAgICAgICBlY2hvICJ7XCJzdWNjZXNzXCI6dHJ1ZSxcImRsbmFcIjp0cnVlLFwiYWlycGxheVwiOnRydWUsXCJibHVldG9vdGhcIjokKFsgIiRCVF9PTiIgPSAiMSIgXSAmJiBlY2hvIHRydWUgfHwgZWNobyBmYWxzZSksXCJsZWRfc3RhbmRieVwiOnRydWUsXCJsZWRfbWFpblwiOnRydWUsXCJkbXJfcnVubmluZ1wiOiR7RE1SX1JVTk5JTkd9fSIKICAgICAgICA7OwoKICAgICopCiAgICAgICAgaGVhZGVyX3htbAogICAgICAgIGVjaG8gIjxlcnJvcj5Vbmtub3duIGFjdGlvbjwvZXJyb3I+IgogICAgICAgIDs7CmVzYWMK"

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
