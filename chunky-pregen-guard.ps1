
param(
    [string]$ServerRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$coreScriptName = "chunky-autorestart.ps1"

function Get-EmbeddedCoreScript {
    $b64 = 'IyBDaHVua3kgUHJlZ2VuIEd1YXJkIENvcmUgdjINCnBhcmFtKAogICAgW2RvdWJsZV0kTWF4TWVtb3J5R0IgPSAxOCwKICAgIFtkb3VibGVdJEhhcmRNZW1vcnlHQiA9IDIyLAogICAgW2RvdWJsZV0kUHJlV2Fybk1lbW9yeUdCID0gMTcuNSwKICAgIFtpbnRdJENoZWNrSW50ZXJ2YWxTZWMgPSAzMCwKICAgIFtpbnRdJFdhcm11cFNlYyA9IDE4MCwKICAgIFtpbnRdJFN0YXJ0dXBEZWxheVNlYyA9IDYwLAogICAgW2ludF0kU3RvcFRpbWVvdXRTZWMgPSAxODAsCiAgICBbaW50XSRBdmVyYWdlV2luZG93Q2hlY2tzID0gMTAsCiAgICBbaW50XSRNaW5Db25zZWN1dGl2ZUFib3ZlVGhyZXNob2xkID0gNCwKICAgIFtpbnRdJEZsdXNoU2V0dGxlU2VjID0gMTUsCiAgICBbaW50XSRTdG9wR3JhY2VTZWMgPSAyMCwKICAgIFtkb3VibGVdJFByb2plY3Rpb25NaW5SYW1Qcml2YXRlR0IgPSAxNC4wLAogICAgW2ludF0kTG93RXRhQ29uc2VjdXRpdmVDaGVja3MgPSAzLAogICAgW2ludF0kQWRhcHRpdmVMZWFkTWluTWludXRlcyA9IDIsCiAgICBbaW50XSRBZGFwdGl2ZUxlYWRNYXhNaW51dGVzID0gNCwKICAgIFtWYWxpZGF0ZVNldCgicHJpdmF0ZSIsICJ3cyIsICJoeWJyaWQiKV0KICAgIFtzdHJpbmddJFRyZW5kU291cmNlTW9kZSA9ICJoeWJyaWQiLAogICAgW2ludF0kUHJlV2FyblByb2plY3Rpb25FbmFibGVkID0gMSwKICAgIFtpbnRdJEJyb2FkY2FzdEVuYWJsZWQgPSAxLAogICAgW3N0cmluZ10kQnJvYWRjYXN0UHJlZml4ID0gIltBdXRvUmVzdGFydF0iLAogICAgW3N0cmluZ10kUmVzdW1lQ29tbWFuZHMgPSAiY2h1bmt5IGNvbnRpbnVlIiwKICAgIFtzdHJpbmddJExvZ0ZpbGUgPSAibG9ncy9jaHVua3ktYXV0b3Jlc3RhcnQubG9nIiwKICAgIFtzdHJpbmddJExvY2tGaWxlID0gImxvZ3MvY2h1bmt5LWF1dG9yZXN0YXJ0LmxvY2siLAogICAgW3N3aXRjaF0kR3VpTW9kZSwKICAgIFtpbnRdJFN0b3BFeGlzdGluZ1NlcnZlciA9IDEKKQ0KClNldC1TdHJpY3RNb2RlIC1WZXJzaW9uIExhdGVzdAokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0gIlN0b3AiCgppZiAoLW5vdCAoVGVzdC1QYXRoIC1QYXRoICJ1c2VyX2p2bV9hcmdzLnR4dCIpKSB7CiAgICB0aHJvdyAiQXJxdWl2byB1c2VyX2p2bV9hcmdzLnR4dCBuYW8gZW5jb250cmFkbyBubyBkaXJldG9yaW8gYXR1YWwuIgp9Cgokd2luQXJnc0ZpbGUgPSAibGlicmFyaWVzL25ldC9taW5lY3JhZnRmb3JnZS9mb3JnZS8xLjIwLjEtNDcuNC4xMC93aW5fYXJncy50eHQiCmlmICgtbm90IChUZXN0LVBhdGggLVBhdGggJHdpbkFyZ3NGaWxlKSkgewogICAgJGF1dG9XaW5BcmdzID0gR2V0LUNoaWxkSXRlbSAtUGF0aCAibGlicmFyaWVzL25ldC9taW5lY3JhZnRmb3JnZS9mb3JnZSIgLVJlY3Vyc2UgLUZpbHRlciAid2luX2FyZ3MudHh0IiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNvcnQtT2JqZWN0IExhc3RXcml0ZVRpbWUgLURlc2NlbmRpbmcgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICBpZiAoJG51bGwgLW5lICRhdXRvV2luQXJncykgewogICAgICAgICR3aW5BcmdzRmlsZSA9ICRhdXRvV2luQXJncy5GdWxsTmFtZS5SZXBsYWNlKChHZXQtTG9jYXRpb24pLlBhdGggKyBbU3lzdGVtLklPLlBhdGhdOjpEaXJlY3RvcnlTZXBhcmF0b3JDaGFyLCAiIikKICAgIH0KfQppZiAoLW5vdCAoVGVzdC1QYXRoIC1QYXRoICR3aW5BcmdzRmlsZSkpIHsKICAgIHRocm93ICJBcnF1aXZvIEZvcmdlIHdpbl9hcmdzLnR4dCBuYW8gZW5jb250cmFkby4iCn0KCiRsb2dEaXIgPSBTcGxpdC1QYXRoIC1QYXRoICRMb2dGaWxlIC1QYXJlbnQKaWYgKCRsb2dEaXIgLWFuZCAtbm90IChUZXN0LVBhdGggLVBhdGggJGxvZ0RpcikpIHsKICAgIE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJGxvZ0RpciB8IE91dC1OdWxsCn0KCiRyZXN1bWVDb21tYW5kTGlzdCA9ICRSZXN1bWVDb21tYW5kcy5TcGxpdCgiOyIpIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAiIiB9CgpmdW5jdGlvbiBXcml0ZS1Mb2cgewogICAgcGFyYW0oW3N0cmluZ10kTWVzc2FnZSkKICAgICRsaW5lID0gIlt7MH1dIHsxfSIgLWYgKEdldC1EYXRlIC1Gb3JtYXQgInl5eXktTU0tZGQgSEg6bW06c3MiKSwgJE1lc3NhZ2UKICAgICRsaW5lIHwgVGVlLU9iamVjdCAtRmlsZVBhdGggJExvZ0ZpbGUgLUFwcGVuZAp9CgpmdW5jdGlvbiBHZXQtT3RoZXJTdXBlcnZpc29ycyB7CiAgICAkc2NyaXB0TmFtZSA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRQU0NvbW1hbmRQYXRoKQogICAgaWYgKC1ub3QgJHNjcmlwdE5hbWUpIHsKICAgICAgICByZXR1cm4gQCgpCiAgICB9CgogICAgJHByb2NMaXN0ID0gR2V0LUNpbUluc3RhbmNlIFdpbjMyX1Byb2Nlc3MgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgewogICAgICAgICgkXy5OYW1lIC1tYXRjaCAnXnBvd2Vyc2hlbGwoXC5leGUpPyR8XnB3c2goXC5leGUpPyQnKSAtYW5kCiAgICAgICAgJF8uQ29tbWFuZExpbmUgLWFuZAogICAgICAgICRfLkNvbW1hbmRMaW5lLkNvbnRhaW5zKCRzY3JpcHROYW1lKSAtYW5kCiAgICAgICAgJF8uUHJvY2Vzc0lkIC1uZSAkUElECiAgICB9CgogICAgcmV0dXJuIEAoJHByb2NMaXN0KQp9CgpmdW5jdGlvbiBTdG9wLU90aGVyU3VwZXJ2aXNvcnMgewogICAgcGFyYW0oW2FycmF5XSRTdXBlcnZpc29yUHJvY2Vzc2VzKQogICAgZm9yZWFjaCAoJHAgaW4gJFN1cGVydmlzb3JQcm9jZXNzZXMpIHsKICAgICAgICBXcml0ZS1Mb2cgIkVuY2VycmFuZG8gc3VwZXJ2aXNvciBhbnRpZ28gKFBJRD0kKCRwLlByb2Nlc3NJZCkpIHBhcmEgZXZpdGFyIGR1cGxpY2lkYWRlLiIKICAgICAgICB0cnkgewogICAgICAgICAgICBTdG9wLVByb2Nlc3MgLUlkICRwLlByb2Nlc3NJZCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgdGhyb3cgIkZhbGhhIGFvIGVuY2VycmFyIHN1cGVydmlzb3IgYW50aWdvIChQSUQ9JCgkcC5Qcm9jZXNzSWQpKTogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgfQogICAgfQp9CgpmdW5jdGlvbiBHZXQtTWFuYWdlZEphdmFQcm9jZXNzIHsKICAgICRwcm9jTGlzdCA9IEdldC1DaW1JbnN0YW5jZSBXaW4zMl9Qcm9jZXNzIC1GaWx0ZXIgIm5hbWU9J2phdmEuZXhlJyIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIGlmICgkbnVsbCAtZXEgJHByb2NMaXN0KSB7CiAgICAgICAgcmV0dXJuICRudWxsCiAgICB9CgogICAgJG1hdGNoID0gJHByb2NMaXN0IHwgV2hlcmUtT2JqZWN0IHsKICAgICAgICAkXy5Db21tYW5kTGluZSAtYW5kICRfLkNvbW1hbmRMaW5lLkNvbnRhaW5zKCJAJHdpbkFyZ3NGaWxlIikKICAgIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCgogICAgaWYgKCRudWxsIC1lcSAkbWF0Y2gpIHsKICAgICAgICByZXR1cm4gJG51bGwKICAgIH0KCiAgICByZXR1cm4gR2V0LVByb2Nlc3MgLUlkICRtYXRjaC5Qcm9jZXNzSWQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKfQoKZnVuY3Rpb24gU3RvcC1NYW5hZ2VkSmF2YVByb2Nlc3MgewogICAgcGFyYW0oW1N5c3RlbS5EaWFnbm9zdGljcy5Qcm9jZXNzXSRQcm9jZXNzKQogICAgaWYgKCRudWxsIC1lcSAkUHJvY2VzcykgewogICAgICAgIHJldHVybgogICAgfQoKICAgIGlmICgkUHJvY2Vzcy5IYXNFeGl0ZWQpIHsKICAgICAgICByZXR1cm4KICAgIH0KCiAgICBXcml0ZS1Mb2cgIkVuY2VycmFuZG8gc2Vydmlkb3IgZXhpc3RlbnRlIChQSUQ9JCgkUHJvY2Vzcy5JZCkpIHBhcmEgYXNzdW1pciBzdXBlcnZpc2FvLiIKICAgIHRyeSB7CiAgICAgICAgU3RvcC1Qcm9jZXNzIC1JZCAkUHJvY2Vzcy5JZCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAzCiAgICB9IGNhdGNoIHsKICAgICAgICB0aHJvdyAiRmFsaGEgYW8gZW5jZXJyYXIgc2Vydmlkb3IgZXhpc3RlbnRlIChQSUQ9JCgkUHJvY2Vzcy5JZCkpOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKZnVuY3Rpb24gU3RhcnQtU2VydmVyIHsKICAgICRwc2kgPSBOZXctT2JqZWN0IFN5c3RlbS5EaWFnbm9zdGljcy5Qcm9jZXNzU3RhcnRJbmZvCiAgICAkcHNpLkZpbGVOYW1lID0gImphdmEiCiAgICAkamF2YUFyZ3MgPSAiQHVzZXJfanZtX2FyZ3MudHh0IEAkd2luQXJnc0ZpbGUiCiAgICBpZiAoLW5vdCAkR3VpTW9kZSkgewogICAgICAgICRqYXZhQXJncyA9ICIkamF2YUFyZ3Mgbm9ndWkiCiAgICB9CiAgICAkcHNpLkFyZ3VtZW50cyA9ICRqYXZhQXJncwogICAgJHBzaS5Xb3JraW5nRGlyZWN0b3J5ID0gKEdldC1Mb2NhdGlvbikuUGF0aAogICAgJHBzaS5Vc2VTaGVsbEV4ZWN1dGUgPSAkZmFsc2UKICAgICRwc2kuUmVkaXJlY3RTdGFuZGFyZElucHV0ID0gJHRydWUKICAgICRwc2kuUmVkaXJlY3RTdGFuZGFyZE91dHB1dCA9ICR0cnVlCiAgICAkcHNpLlJlZGlyZWN0U3RhbmRhcmRFcnJvciA9ICR0cnVlCiAgICAkcHNpLkNyZWF0ZU5vV2luZG93ID0gJHRydWUKCiAgICAkcHJvY2VzcyA9IE5ldy1PYmplY3QgU3lzdGVtLkRpYWdub3N0aWNzLlByb2Nlc3MKICAgICRwcm9jZXNzLlN0YXJ0SW5mbyA9ICRwc2kKICAgICRwcm9jZXNzLkVuYWJsZVJhaXNpbmdFdmVudHMgPSAkdHJ1ZQoKICAgICRudWxsID0gJHByb2Nlc3MuU3RhcnQoKQoKICAgICRvdXRFdmVudCA9IFJlZ2lzdGVyLU9iamVjdEV2ZW50IC1JbnB1dE9iamVjdCAkcHJvY2VzcyAtRXZlbnROYW1lIE91dHB1dERhdGFSZWNlaXZlZCAtQWN0aW9uIHsKICAgICAgICBpZiAoJEV2ZW50QXJncy5EYXRhKSB7CiAgICAgICAgICAgICR0aW1lc3RhbXBlZCA9ICJbezB9XSBbU0VSVkVSXSB7MX0iIC1mIChHZXQtRGF0ZSAtRm9ybWF0ICJ5eXl5LU1NLWRkIEhIOm1tOnNzIiksICRFdmVudEFyZ3MuRGF0YQogICAgICAgICAgICBBZGQtQ29udGVudCAtUGF0aCAkdXNpbmc6TG9nRmlsZSAtVmFsdWUgJHRpbWVzdGFtcGVkCiAgICAgICAgfQogICAgfQogICAgJGVyckV2ZW50ID0gUmVnaXN0ZXItT2JqZWN0RXZlbnQgLUlucHV0T2JqZWN0ICRwcm9jZXNzIC1FdmVudE5hbWUgRXJyb3JEYXRhUmVjZWl2ZWQgLUFjdGlvbiB7CiAgICAgICAgaWYgKCRFdmVudEFyZ3MuRGF0YSkgewogICAgICAgICAgICAkdGltZXN0YW1wZWQgPSAiW3swfV0gW1NFUlZFUi1FUlJdIHsxfSIgLWYgKEdldC1EYXRlIC1Gb3JtYXQgInl5eXktTU0tZGQgSEg6bW06c3MiKSwgJEV2ZW50QXJncy5EYXRhCiAgICAgICAgICAgIEFkZC1Db250ZW50IC1QYXRoICR1c2luZzpMb2dGaWxlIC1WYWx1ZSAkdGltZXN0YW1wZWQKICAgICAgICB9CiAgICB9CgogICAgJHByb2Nlc3MuQmVnaW5PdXRwdXRSZWFkTGluZSgpCiAgICAkcHJvY2Vzcy5CZWdpbkVycm9yUmVhZExpbmUoKQoKICAgIHJldHVybiBAewogICAgICAgIFByb2Nlc3MgPSAkcHJvY2VzcwogICAgICAgIE91dEV2ZW50ID0gJG91dEV2ZW50CiAgICAgICAgRXJyRXZlbnQgPSAkZXJyRXZlbnQKICAgICAgICBTdGFydGVkQXQgPSBHZXQtRGF0ZQogICAgfQp9CgpmdW5jdGlvbiBDbGVhbnVwLUV2ZW50cyB7CiAgICBwYXJhbSgkc2VydmVyU3RhdGUpCiAgICBmb3JlYWNoICgkZXZ0IGluIEAoJHNlcnZlclN0YXRlLk91dEV2ZW50LCAkc2VydmVyU3RhdGUuRXJyRXZlbnQpKSB7CiAgICAgICAgaWYgKCRudWxsIC1uZSAkZXZ0KSB7CiAgICAgICAgICAgIFVucmVnaXN0ZXItRXZlbnQgLVN1YnNjcmlwdGlvbklkICRldnQuSWQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgUmVtb3ZlLUpvYiAtSWQgJGV2dC5JZCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICB9CiAgICB9Cn0KCmZ1bmN0aW9uIEdyYWNlZnVsLVN0b3AgewogICAgcGFyYW0oJHNlcnZlclN0YXRlLCBbc3RyaW5nXSRSZWFzb24pCiAgICAkcHJvYyA9ICRzZXJ2ZXJTdGF0ZS5Qcm9jZXNzCiAgICBpZiAoJHByb2MuSGFzRXhpdGVkKSB7CiAgICAgICAgcmV0dXJuCiAgICB9CgogICAgV3JpdGUtTG9nICJTb2xpY2l0YW5kbyBwYXJhZGE6ICRSZWFzb24iCiAgICB0cnkgeyAkcHJvYy5TdGFuZGFyZElucHV0LldyaXRlTGluZSgic2F5IFJlaW5pY2lhbmRvIHNlcnZpZG9yIGF1dG9tYXRpY2FtZW50ZSBlbSAyMHMuLi4iKSB9IGNhdGNoIHt9CiAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAyMAogICAgdHJ5IHsgJHByb2MuU3RhbmRhcmRJbnB1dC5Xcml0ZUxpbmUoInNhdmUtYWxsIGZsdXNoIikgfSBjYXRjaCB7fQogICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgNQogICAgdHJ5IHsgJHByb2MuU3RhbmRhcmRJbnB1dC5Xcml0ZUxpbmUoInN0b3AiKSB9IGNhdGNoIHt9CgogICAgaWYgKC1ub3QgJHByb2MuV2FpdEZvckV4aXQoJFN0b3BUaW1lb3V0U2VjICogMTAwMCkpIHsKICAgICAgICBXcml0ZS1Mb2cgIlBhcmFkYSBncmFjaW9zYSBleGNlZGV1IHRpbWVvdXQgZGUgJFN0b3BUaW1lb3V0U2VjIHMuIEZvcmNhbmRvIGVuY2VycmFtZW50by4iCiAgICAgICAgdHJ5IHsgJHByb2MuS2lsbCgkdHJ1ZSkgfSBjYXRjaCB7fQogICAgfQp9CgpXcml0ZS1Mb2cgIlN1cGVydmlzb3IgaW5pY2lhZG8uIExpbWl0ZSBSQU09JE1heE1lbW9yeUdCIEdCOyBpbnRlcnZhbG89JENoZWNrSW50ZXJ2YWxTZWMgczsgd2FybXVwPSRXYXJtdXBTZWMgczsgZ3VpPSQoJEd1aU1vZGUuSXNQcmVzZW50KSIKV3JpdGUtTG9nICJQb2xpdGljYSBSQU06IHNvZnQobWVkaWErc3VzdGVudGFkbyk9JE1heE1lbW9yeUdCIEdCOyBoYXJkKHBpY28pPSRIYXJkTWVtb3J5R0IgR0I7IGphbmVsYT0kQXZlcmFnZVdpbmRvd0NoZWNrcyBjaGVja3M7IGNvbnNlY3V0aXZvcz0kTWluQ29uc2VjdXRpdmVBYm92ZVRocmVzaG9sZCIKV3JpdGUtTG9nICJDb21hbmRvcyBkZSByZXRvbWFkYTogJCgkcmVzdW1lQ29tbWFuZExpc3QgLWpvaW4gJyB8ICcpIgoKaWYgKFRlc3QtUGF0aCAtUGF0aCAkTG9ja0ZpbGUpIHsKICAgICRleGlzdGluZ1BpZCA9IChHZXQtQ29udGVudCAtUGF0aCAkTG9ja0ZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5UcmltKCkKICAgIGlmICgkZXhpc3RpbmdQaWQgLW1hdGNoICdeXGQrJCcpIHsKICAgICAgICAkZXhpc3RpbmdQcm9jID0gR2V0LVByb2Nlc3MgLUlkIChbaW50XSRleGlzdGluZ1BpZCkgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICBpZiAoJGV4aXN0aW5nUHJvYykgewogICAgICAgICAgICB0aHJvdyAiSmEgZXhpc3RlIHVtIHN1cGVydmlzb3IgYXRpdm8gKFBJRD0kZXhpc3RpbmdQaWQpLiBGZWNoZS1vIGFudGVzIGRlIGluaWNpYXIgb3V0cm8uIgogICAgICAgIH0KICAgIH0KfQoKU2V0LUNvbnRlbnQgLVBhdGggJExvY2tGaWxlIC1WYWx1ZSAkUElECgp0cnkgewogICAgJG90aGVyU3VwZXJ2aXNvcnMgPSBAKEdldC1PdGhlclN1cGVydmlzb3JzKQogICAgaWYgKEAoJG90aGVyU3VwZXJ2aXNvcnMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgaWYgKCRTdG9wRXhpc3RpbmdTZXJ2ZXIpIHsKICAgICAgICAgICAgU3RvcC1PdGhlclN1cGVydmlzb3JzIC1TdXBlcnZpc29yUHJvY2Vzc2VzICRvdGhlclN1cGVydmlzb3JzCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHBpZHMgPSAoJG90aGVyU3VwZXJ2aXNvcnMgfCBGb3JFYWNoLU9iamVjdCB7ICRfLlByb2Nlc3NJZCB9KSAtam9pbiAiLCIKICAgICAgICAgICAgdGhyb3cgIkphIGV4aXN0ZSBvdXRybyBzdXBlcnZpc29yIGF0aXZvIChQSUQ9JHBpZHMpLiIKICAgICAgICB9CiAgICB9CgogICAgJGFscmVhZHlSdW5uaW5nID0gR2V0LU1hbmFnZWRKYXZhUHJvY2VzcwogICAgaWYgKCRhbHJlYWR5UnVubmluZykgewogICAgICAgIGlmICgkU3RvcEV4aXN0aW5nU2VydmVyKSB7CiAgICAgICAgICAgIFN0b3AtTWFuYWdlZEphdmFQcm9jZXNzIC1Qcm9jZXNzICRhbHJlYWR5UnVubmluZwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgIHRocm93ICJKYSBleGlzdGUgamF2YSBkbyBzZXJ2aWRvciByb2RhbmRvIChQSUQ9JCgkYWxyZWFkeVJ1bm5pbmcuSWQpKS4gUGFyZSBvIHNlcnZpZG9yIGF0dWFsIGUgZXhlY3V0ZSBvIC5iYXQgbm92YW1lbnRlLiIKICAgICAgICB9CiAgICB9CgogICAgJHNlcnZlciA9IFN0YXJ0LVNlcnZlcgogICAgJG1lbW9yeVNhbXBsZXMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3RbZG91YmxlXQogICAgJGNvbnNlY3V0aXZlQWJvdmVUaHJlc2hvbGQgPSAwCiAgICBXcml0ZS1Mb2cgIlNlcnZpZG9yIGluaWNpYWRvIChQSUQ9JCgkc2VydmVyLlByb2Nlc3MuSWQpKS4gQWd1YXJkYW5kbyAkU3RhcnR1cERlbGF5U2VjIHMgcGFyYSByZXRvbWFkYSBkbyBDaHVua3kuIgogICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgJFN0YXJ0dXBEZWxheVNlYwogICAgZm9yZWFjaCAoJGNtZCBpbiAkcmVzdW1lQ29tbWFuZExpc3QpIHsKICAgICAgICB0cnkgewogICAgICAgICAgICAkc2VydmVyLlByb2Nlc3MuU3RhbmRhcmRJbnB1dC5Xcml0ZUxpbmUoJGNtZCkKICAgICAgICAgICAgV3JpdGUtTG9nICJDb21hbmRvIGVudmlhZG8gYXBvcyBTZXJ2aWRvciBpbmljaWFkbzogJGNtZCIKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgV3JpdGUtTG9nICJGYWxoYSBhbyBlbnZpYXIgY29tYW5kbyBhcG9zIHN0YXJ0OiAkY21kIgogICAgICAgIH0KICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAxCiAgICB9CgogICAgd2hpbGUgKCR0cnVlKSB7CiAgICAgICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgJENoZWNrSW50ZXJ2YWxTZWMKCiAgICAgICAgJHByb2MgPSAkc2VydmVyLlByb2Nlc3MKICAgICAgICBpZiAoJHByb2MuSGFzRXhpdGVkKSB7CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUHJvY2Vzc28gSmF2YSBlbmNlcnJvdSAoY29kZT0kKCRwcm9jLkV4aXRDb2RlKSkuIFJlaW5pY2lhbmRvIGVtIDEwIHMuIgogICAgICAgICAgICBDbGVhbnVwLUV2ZW50cyAtc2VydmVyU3RhdGUgJHNlcnZlcgogICAgICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAxMAogICAgICAgICAgICAkc2VydmVyID0gU3RhcnQtU2VydmVyCiAgICAgICAgICAgICRtZW1vcnlTYW1wbGVzID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W2RvdWJsZV0KICAgICAgICAgICAgJGNvbnNlY3V0aXZlQWJvdmVUaHJlc2hvbGQgPSAwCiAgICAgICAgICAgIFdyaXRlLUxvZyAiU2Vydmlkb3IgcmVpbmljaWFkbyAoUElEPSQoJHNlcnZlci5Qcm9jZXNzLklkKSkuIEFndWFyZGFuZG8gJFN0YXJ0dXBEZWxheVNlYyBzLiIKICAgICAgICAgICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgJFN0YXJ0dXBEZWxheVNlYwogICAgICAgICAgICBmb3JlYWNoICgkY21kIGluICRyZXN1bWVDb21tYW5kTGlzdCkgewogICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICAkc2VydmVyLlByb2Nlc3MuU3RhbmRhcmRJbnB1dC5Xcml0ZUxpbmUoJGNtZCkKICAgICAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIkNvbWFuZG8gZW52aWFkbyBhcG9zIHJlc3RhcnQ6ICRjbWQiCiAgICAgICAgICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIkZhbGhhIGFvIGVudmlhciBjb21hbmRvIGFwb3MgcmVzdGFydDogJGNtZCIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1TZWNvbmRzIDEKICAgICAgICAgICAgfQogICAgICAgICAgICBjb250aW51ZQogICAgICAgIH0KCiAgICAgICAgJHVwdGltZVNlYyA9IFtpbnRdKChHZXQtRGF0ZSkgLSAkc2VydmVyLlN0YXJ0ZWRBdCkuVG90YWxTZWNvbmRzCiAgICAgICAgJG1lbW9yeUdCID0gW21hdGhdOjpSb3VuZCgkcHJvYy5Xb3JraW5nU2V0NjQgLyAxR0IsIDIpCiAgICAgICAgJG1lbW9yeVNhbXBsZXMuQWRkKCRtZW1vcnlHQikKICAgICAgICB3aGlsZSAoJG1lbW9yeVNhbXBsZXMuQ291bnQgLWd0ICRBdmVyYWdlV2luZG93Q2hlY2tzKSB7CiAgICAgICAgICAgICRtZW1vcnlTYW1wbGVzLlJlbW92ZUF0KDApCiAgICAgICAgfQogICAgICAgICRhdmdNZW1vcnlHQiA9IFttYXRoXTo6Um91bmQoKCgkbWVtb3J5U2FtcGxlcyB8IE1lYXN1cmUtT2JqZWN0IC1BdmVyYWdlKS5BdmVyYWdlKSwgMikKICAgICAgICBpZiAoJG1lbW9yeUdCIC1nZSAkTWF4TWVtb3J5R0IpIHsKICAgICAgICAgICAgJGNvbnNlY3V0aXZlQWJvdmVUaHJlc2hvbGQrKwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRjb25zZWN1dGl2ZUFib3ZlVGhyZXNob2xkID0gMAogICAgICAgIH0KICAgICAgICBXcml0ZS1Mb2cgIkhlYWx0aGNoZWNrOiBQSUQ9JCgkcHJvYy5JZCkgUkFNPSRtZW1vcnlHQiBHQiBBVkc9JGF2Z01lbW9yeUdCIEdCIEFib3ZlU29mdFNlcT0kY29uc2VjdXRpdmVBYm92ZVRocmVzaG9sZCBVcHRpbWU9JHt1cHRpbWVTZWN9cyIKCiAgICAgICAgaWYgKCR1cHRpbWVTZWMgLWx0ICRXYXJtdXBTZWMpIHsKICAgICAgICAgICAgY29udGludWUKICAgICAgICB9CgogICAgICAgICRzaG91bGRSZXN0YXJ0QnlIYXJkID0gJG1lbW9yeUdCIC1nZSAkSGFyZE1lbW9yeUdCCiAgICAgICAgJHNob3VsZFJlc3RhcnRCeVNvZnQgPSAoJGF2Z01lbW9yeUdCIC1nZSAkTWF4TWVtb3J5R0IpIC1hbmQgKCRjb25zZWN1dGl2ZUFib3ZlVGhyZXNob2xkIC1nZSAkTWluQ29uc2VjdXRpdmVBYm92ZVRocmVzaG9sZCkKCiAgICAgICAgaWYgKCRzaG91bGRSZXN0YXJ0QnlIYXJkIC1vciAkc2hvdWxkUmVzdGFydEJ5U29mdCkgewogICAgICAgICAgICAkcmVhc29uID0gaWYgKCRzaG91bGRSZXN0YXJ0QnlIYXJkKSB7CiAgICAgICAgICAgICAgICAiUGljbyBkZSBSQU06ICRtZW1vcnlHQiBHQiAoaGFyZD0kSGFyZE1lbW9yeUdCIEdCKSIKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICJSQU0gc3VzdGVudGFkYTogYXR1YWw9JG1lbW9yeUdCIEdCLCBtZWRpYT0kYXZnTWVtb3J5R0IgR0IgKHNvZnQ9JE1heE1lbW9yeUdCIEdCKSIKICAgICAgICAgICAgfQogICAgICAgICAgICBHcmFjZWZ1bC1TdG9wIC1zZXJ2ZXJTdGF0ZSAkc2VydmVyIC1SZWFzb24gJHJlYXNvbgogICAgICAgICAgICBDbGVhbnVwLUV2ZW50cyAtc2VydmVyU3RhdGUgJHNlcnZlcgoKICAgICAgICAgICAgV3JpdGUtTG9nICJSZWluaWNpYW5kbyBzZXJ2aWRvciBlbSAxMCBzLiIKICAgICAgICAgICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgMTAKCiAgICAgICAgICAgICRzZXJ2ZXIgPSBTdGFydC1TZXJ2ZXIKICAgICAgICAgICAgJG1lbW9yeVNhbXBsZXMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3RbZG91YmxlXQogICAgICAgICAgICAkY29uc2VjdXRpdmVBYm92ZVRocmVzaG9sZCA9IDAKICAgICAgICAgICAgV3JpdGUtTG9nICJTZXJ2aWRvciByZWluaWNpYWRvIChQSUQ9JCgkc2VydmVyLlByb2Nlc3MuSWQpKS4gQWd1YXJkYW5kbyAkU3RhcnR1cERlbGF5U2VjIHMuIgogICAgICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAkU3RhcnR1cERlbGF5U2VjCiAgICAgICAgICAgIGZvcmVhY2ggKCRjbWQgaW4gJHJlc3VtZUNvbW1hbmRMaXN0KSB7CiAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICRzZXJ2ZXIuUHJvY2Vzcy5TdGFuZGFyZElucHV0LldyaXRlTGluZSgkY21kKQogICAgICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiQ29tYW5kbyBlbnZpYWRvIGFwb3MgcmVzdGFydDogJGNtZCIKICAgICAgICAgICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiRmFsaGEgYW8gZW52aWFyIGNvbWFuZG8gYXBvcyByZXN0YXJ0OiAkY21kIgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgMQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQp9CmZpbmFsbHkgewogICAgaWYgKFRlc3QtUGF0aCAtUGF0aCAkTG9ja0ZpbGUpIHsKICAgICAgICBSZW1vdmUtSXRlbSAtUGF0aCAkTG9ja0ZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICB9Cn0K'
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
}

function Ensure-CoreScript {
    param([string]$RootPath)
    $corePath = Join-Path $RootPath $coreScriptName
    $content = Get-EmbeddedCoreScript

    if (Test-Path -Path $corePath) {
        $existing = Get-Content -Path $corePath -Raw -ErrorAction SilentlyContinue
        if ($existing -match '(?m)^\s*#\s*CPG_USER_MANAGED\b') {
            return $corePath
        }
        if ($existing -ne $content) {
            try { Copy-Item -Path $corePath -Destination "$corePath.bak" -Force } catch {}
            Set-Content -Path $corePath -Value $content -Encoding UTF8
        }
        return $corePath
    }

    Set-Content -Path $corePath -Value $content -Encoding UTF8
    return $corePath
}

function Resolve-DefaultServerRoot {
    $candidates = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    function Add-Candidate {
        param([string]$PathValue)
        if ([string]::IsNullOrWhiteSpace($PathValue)) { return }
        $normalized = $PathValue.Trim()
        if ([string]::IsNullOrWhiteSpace($normalized)) { return }
        if ($seen.ContainsKey($normalized)) { return }
        $seen[$normalized] = $true
        $candidates.Add($normalized)
    }

    Add-Candidate -PathValue $PSScriptRoot
    Add-Candidate -PathValue $ServerRoot

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        try { Add-Candidate -PathValue ([System.IO.Path]::GetDirectoryName($PSCommandPath)) } catch {}
    }
    try {
        if ($null -ne $MyInvocation -and $null -ne $MyInvocation.MyCommand) {
            Add-Candidate -PathValue ([System.IO.Path]::GetDirectoryName([string]$MyInvocation.MyCommand.Path))
        }
    } catch {}
    try { Add-Candidate -PathValue (Get-Location).Path } catch {}
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        Add-Candidate -PathValue ([System.IO.Path]::GetDirectoryName($exePath))
    } catch {}

    foreach ($base in $candidates) {
        try {
            $directCore = [System.IO.Path]::Combine($base, $coreScriptName)
            $directRunBat = [System.IO.Path]::Combine($base, "run.bat")
            $directProps = [System.IO.Path]::Combine($base, "server.properties")
            if ([System.IO.File]::Exists($directCore) -or [System.IO.File]::Exists($directRunBat) -or [System.IO.File]::Exists($directProps)) {
                return $base
            }

            $parent = [System.IO.Path]::GetDirectoryName($base)
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $parentCore = [System.IO.Path]::Combine($parent, $coreScriptName)
                $parentRunBat = [System.IO.Path]::Combine($parent, "run.bat")
                $parentProps = [System.IO.Path]::Combine($parent, "server.properties")
                if ([System.IO.File]::Exists($parentCore) -or [System.IO.File]::Exists($parentRunBat) -or [System.IO.File]::Exists($parentProps)) {
                    return $parent
                }
            }
        } catch {}
    }

    return ""
}

if ([string]::IsNullOrWhiteSpace($ServerRoot)) {
    $ServerRoot = Resolve-DefaultServerRoot
}

if ([string]::IsNullOrWhiteSpace($ServerRoot)) {
    throw "Nao foi possivel detectar automaticamente a pasta do servidor. Execute o launcher dentro da pasta do server ou use -ServerRoot."
}

$targetScript = Ensure-CoreScript -RootPath $ServerRoot

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$i18n = @{
    "pt-BR" = @{
        form="Chunky Pregen Guard (Teste)"
        head="Preencha as configuracoes abaixo. Se preferir, clique em Aplicar Recomendado e depois em Iniciar Servidor."
        lang="Idioma:"
        tab1="Basico"; tab2="Avancado"; tab3="Java/JVM"
        rec="Aplicar Recomendado"; start="Iniciar Servidor"; save="Gerar .bat com estas Configs"; prev="Atualizar Preview"
        sysram="RAM total detectada: {0} GB"
        cmd="Comando que sera executado:"; jvmp="Conteudo de user_jvm_args.txt que sera aplicado:"; jvmd="(desativado: o arquivo de JVM nao sera alterado)"
        c_gui="Mostrar janela do servidor"; c_brd="Enviar avisos no chat"; c_proj="Usar previsao de memoria"; c_clean="Parar processos antigos no inicio"; c_jvm="Atualizar user_jvm_args.txt antes de iniciar"
        l_soft="Limite Soft de RAM (GB)"; h_soft="Quando a RAM fica acima deste valor por um tempo, o supervisor prepara reinicio."
        l_hard="Limite Hard de RAM (GB)"; h_hard="Limite de emergencia. Se chegar aqui, o reinicio precisa acontecer rapido."
        l_prew="Inicio do Pre-Aviso (RAM_WS em GB)"; h_prew="RAM_WS e a memoria fisica que o Windows mostra para o processo neste instante. Acima deste valor, o aviso aos jogadores pode comecar."
        l_lmin="Pre-aviso minimo (min)"; h_lmin="Menor tempo de antecedencia para avisar antes do reinicio."
        l_lmax="Pre-aviso maximo (min)"; h_lmax="Maior tempo de antecedencia para avisar antes do reinicio."
        l_chk="Intervalo do check (s)"; h_chk="De quantos em quantos segundos o supervisor mede memoria."
        l_warm="Warmup inicial (s)"; h_warm="Tempo inicial em que o supervisor apenas observa e nao reinicia."
        l_st="Espera apos iniciar (s)"; h_st="Tempo de espera antes de enviar os comandos de retomada (ex.: chunky continue)."
        l_fl="Espera apos save-all flush (s)"; h_fl="Tempo para finalizar escrita em disco apos o flush."
        l_gr="Tempo de stop gracioso (s)"; h_gr="Tempo maximo para o stop normal. Se passar disso, o supervisor forcara encerramento."
        l_rc="Comandos de retomada"; h_rc="Comandos enviados apos o servidor subir. Use ';' para separar varios."
        l_gui="GUI do servidor"; h_gui="Se ligado, abre a janela grafica do servidor. Se desligado, roda em modo console."
        l_brd="Avisos para jogadores"; h_brd="Se ligado, o script envia mensagens no chat antes de reiniciar."
        l_proj="Gatilho por previsao (ETA)"; h_proj="Usa a tendencia de crescimento da memoria para agir antes de chegar ao limite."
        l_clean="Limpeza no inicio"; h_clean="Encerra Java/supervisor antigos para evitar duplicidade."
        l_avg="Janela da media (checks)"; h_avg="Quantidade de checks usados para calcular media de memoria."
        l_con="Checks consecutivos"; h_con="Quantos checks acima do limite Soft contam como pressao sustentada."
        l_stop="Timeout legado de stop (s)"; h_stop="Opcao de compatibilidade com fluxo antigo. Normalmente pode manter padrao."
        l_minp="Minimo RAM_PRIVATE (GB)"; h_minp="A previsao por ETA so vale acima deste valor para reduzir alarmes falsos."
        l_low="Sequencia minima de ETA baixo"; h_low="Numero de checks seguidos com ETA baixo antes de abrir pre-aviso."
        l_tr="Fonte da tendencia"; h_tr="Hybrid usa RAM_PRIVATE como base e RAM_WS como protecao para picos."
        l_pref="Prefixo das mensagens"; h_pref="Texto que aparece no inicio dos avisos no chat."
        l_log="Arquivo de log"; h_log="Arquivo onde o supervisor grava todos os eventos."
        l_lock="Arquivo de lock"; h_lock="Arquivo usado para impedir dois supervisores ao mesmo tempo."
        l_xms="RAM minima da JVM (-Xms em GB)"; h_xms="Memoria minima reservada pelo Java ao iniciar."
        l_xmx="RAM maxima da JVM (-Xmx em GB)"; h_xmx="Memoria maxima que o Java pode usar. Nao ultrapasse a RAM fisica do PC."
        l_jpre="Perfil de JVM"; h_jpre="Define o estilo da JVM (balanceado, agressivo ou conservador) e influencia o botao Aplicar Recomendado."
        l_aj="Aplicar configuracao de JVM"; h_aj="Se ligado, o launcher atualiza user_jvm_args.txt antes de iniciar."
        l_ex="Argumentos JVM extras"; h_ex="Adicione um argumento por linha. Use apenas se souber o efeito."
        l_jf="Arquivo de JVM"; h_jf="Arquivo que o Forge le para aplicar os argumentos da JVM."
        tr_h="hybrid (recomendado)"; tr_p="private (mais estavel)"; tr_w="ws (mais sensivel a picos)"
        jp_b="Balanceado (recomendado)"; jp_t="Pregen agressivo"; jp_l="Baixa RAM (conservador)"
        e="Erro"; ok="Sucesso"; w="Validacao"
        m_prev="Nao foi possivel atualizar o preview: {0}"; m_lead="Pre-aviso minimo nao pode ser maior que o maximo."; m_jvm="Xms nao pode ser maior que Xmx."
        m_soft="O limite Soft deve ser menor que o limite Hard."; m_prew="O inicio de pre-aviso (RAM_WS) deve ser menor que o limite Hard."
        m_start="Servidor iniciado em uma nova janela do PowerShell."; m_startj="Servidor iniciado. user_jvm_args.txt atualizado com {0} linhas."
        m_startf="Falha ao iniciar o servidor: {0}"; m_bat=".bat salvo com sucesso."; m_batf="Falha ao salvar o .bat: {0}"
        m_rec="Configuracoes recomendadas aplicadas para {0} GB de RAM total."; m_recf="Falha ao aplicar configuracoes recomendadas: {0}"; m_jvmf="Falha ao atualizar user_jvm_args.txt: {0}"
        m_start_runtime_fail="O supervisor iniciou, mas o servidor nao concluiu a inicializacao."
        m_start_runtime_hint="Verifique os logs do servidor para identificar o erro."
        m_start_uncertain="O supervisor iniciou, mas o startup ainda nao foi confirmado. Verifique os logs do servidor."
    }
    "en-US" = @{
        form="Chunky Pregen Guard (Test)"
        head="Fill the settings below. If you prefer, click Apply Recommended first, then Start Server."
        lang="Language:"
        tab1="Basic"; tab2="Advanced"; tab3="Java/JVM"
        rec="Apply Recommended"; start="Start Server"; save="Generate .bat with These Settings"; prev="Refresh Preview"
        sysram="Detected total RAM: {0} GB"
        cmd="Command that will run:"; jvmp="Content of user_jvm_args.txt that will be applied:"; jvmd="(disabled: JVM file will not be changed)"
        c_gui="Show server window"; c_brd="Send chat warnings"; c_proj="Use memory prediction"; c_clean="Stop old processes at startup"; c_jvm="Update user_jvm_args.txt before start"
        l_soft="Soft RAM limit (GB)"; h_soft="If memory stays above this level for a while, supervisor prepares a restart."
        l_hard="Hard RAM limit (GB)"; h_hard="Emergency limit. If reached, restart must happen quickly."
        l_prew="Pre-warning start (RAM_WS in GB)"; h_prew="RAM_WS is the physical memory currently shown by Windows for this process. Above this level, player warning can start."
        l_lmin="Minimum warning (min)"; h_lmin="Smallest warning time before restart."
        l_lmax="Maximum warning (min)"; h_lmax="Largest warning time before restart."
        l_chk="Check interval (s)"; h_chk="How often the supervisor measures memory."
        l_warm="Initial warmup (s)"; h_warm="Initial period where supervisor only observes and does not restart."
        l_st="Post-start wait (s)"; h_st="Wait time before sending resume commands (for example: chunky continue)."
        l_fl="Wait after save-all flush (s)"; h_fl="Extra time for disk writes to settle after flush."
        l_gr="Graceful stop time (s)"; h_gr="Maximum time for normal stop before forced kill."
        l_rc="Resume commands"; h_rc="Commands sent after startup. Use ';' to separate multiple commands."
        l_gui="Server GUI"; h_gui="If enabled, opens graphical server window. If disabled, runs console-only."
        l_brd="Player warnings"; h_brd="If enabled, sends chat messages before restart."
        l_proj="Prediction trigger (ETA)"; h_proj="Uses memory growth trend to act before hitting limits."
        l_clean="Startup cleanup"; h_clean="Stops old Java/supervisor processes to avoid duplicates."
        l_avg="Average window (checks)"; h_avg="How many checks are used in moving average memory calculation."
        l_con="Consecutive checks"; h_con="How many checks above Soft are treated as sustained pressure."
        l_stop="Legacy stop timeout (s)"; h_stop="Compatibility option from older flow. Usually keep default."
        l_minp="Minimum RAM_PRIVATE (GB)"; h_minp="ETA projection only applies above this value to reduce false positives."
        l_low="Minimum low-ETA streak"; h_low="How many low-ETA checks in a row are required before pre-warning."
        l_tr="Trend source"; h_tr="Hybrid uses RAM_PRIVATE as base and RAM_WS as protection against spikes."
        l_pref="Message prefix"; h_pref="Text shown at the start of chat warnings."
        l_log="Log file"; h_log="File where supervisor stores all events."
        l_lock="Lock file"; h_lock="File used to prevent more than one supervisor at once."
        l_xms="JVM minimum RAM (-Xms in GB)"; h_xms="Minimum memory reserved by Java at startup."
        l_xmx="JVM maximum RAM (-Xmx in GB)"; h_xmx="Maximum memory Java can use. Do not exceed physical RAM."
        l_jpre="JVM profile"; h_jpre="Defines JVM style (balanced, aggressive or conservative) and affects Apply Recommended."
        l_aj="Apply JVM settings"; h_aj="If enabled, launcher updates user_jvm_args.txt before start."
        l_ex="Extra JVM arguments"; h_ex="Add one argument per line. Use only if you understand the impact."
        l_jf="JVM file"; h_jf="File read by Forge to apply JVM arguments."
        tr_h="hybrid (recommended)"; tr_p="private (most stable)"; tr_w="ws (most spike-sensitive)"
        jp_b="Balanced (recommended)"; jp_t="Aggressive pregen"; jp_l="Low RAM (conservative)"
        e="Error"; ok="Success"; w="Validation"
        m_prev="Could not refresh preview: {0}"; m_lead="Minimum warning cannot be greater than maximum warning."; m_jvm="Xms cannot be greater than Xmx."
        m_soft="Soft limit must be lower than Hard limit."; m_prew="Pre-warning RAM_WS must be lower than Hard limit."
        m_start="Server started in a new PowerShell window."; m_startj="Server started. user_jvm_args.txt updated with {0} lines."
        m_startf="Failed to start server: {0}"; m_bat=".bat saved successfully."; m_batf="Failed to save .bat: {0}"
        m_rec="Recommended settings applied for {0} GB of total RAM."; m_recf="Failed to apply recommended settings: {0}"; m_jvmf="Failed to update user_jvm_args.txt: {0}"
        m_start_runtime_fail="Supervisor started, but server startup did not complete."
        m_start_runtime_hint="Please check the server logs to identify the error."
        m_start_uncertain="Supervisor started, but startup was not confirmed yet. Please check server logs."
    }
}

$currentLang = "pt-BR"
function T {
    param([string]$k)
    $langPack = $null
    if ($i18n.ContainsKey($currentLang)) {
        $langPack = $i18n[$currentLang]
    } else {
        $langPack = $i18n["pt-BR"]
    }
    if ($langPack.ContainsKey($k)) { return [string]$langPack[$k] }
    if ($i18n["en-US"].ContainsKey($k)) { return [string]$i18n["en-US"][$k] }
    return $k
}
function Tf { param([string]$k, [object[]]$a) $t = T $k; if ($null -eq $a -or $a.Count -eq 0) { return $t }; return [string]::Format($t, $a) }

function New-TextBox { param([string]$Text, [int]$Width = 280) $tb = New-Object System.Windows.Forms.TextBox; $tb.Width = $Width; $tb.Text = $Text; return $tb }
function New-Numeric {
    param([double]$Value, [double]$Minimum, [double]$Maximum, [int]$DecimalPlaces = 0, [int]$Width = 130)
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Minimum = [decimal]$Minimum; $n.Maximum = [decimal]$Maximum; $n.DecimalPlaces = $DecimalPlaces
    $n.Increment = if ($DecimalPlaces -gt 0) { [decimal]0.1 } else { [decimal]1 }
    $n.Value = [decimal]$Value; $n.Width = $Width; return $n
}
function New-CheckBox { param([bool]$Checked = $true, [int]$Width = 290) $c = New-Object System.Windows.Forms.CheckBox; $c.Checked = $Checked; $c.AutoSize = $false; $c.Width = $Width; $c.Height = 24; return $c }

function Set-ComboOptions {
    param([System.Windows.Forms.ComboBox]$Combo, [array]$Items, [string]$SelectedValue = "")
    $ds = New-Object System.Collections.Generic.List[object]
    foreach ($it in $Items) {
        $display = $null
        $value = $null

        if ($it -is [System.Collections.IDictionary]) {
            $display = [string]$it["Display"]
            $value = [string]$it["Value"]
        } else {
            $display = [string]$it.Display
            $value = [string]$it.Value
        }

        if ([string]::IsNullOrWhiteSpace($display)) { $display = [string]$value }
        if ([string]::IsNullOrWhiteSpace($value)) { $value = [string]$display }
        $ds.Add([pscustomobject]@{ Display = $display; Value = $value })
    }

    $Combo.BeginUpdate()
    try {
        $Combo.DataSource = $null
        $Combo.Items.Clear()
        $Combo.DisplayMember = "Display"
        $Combo.ValueMember = "Value"
        $Combo.DataSource = $ds
        if (-not [string]::IsNullOrWhiteSpace($SelectedValue)) { $Combo.SelectedValue = $SelectedValue }
        if ($Combo.SelectedIndex -lt 0 -and $Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
    } finally {
        $Combo.EndUpdate()
    }
}

function Add-LocalizedRow {
    param([System.Windows.Forms.TableLayoutPanel]$Panel, [System.Windows.Forms.Control]$Control, [string]$LabelKey, [string]$HelpKey, [System.Collections.ArrayList]$Registry)
    $r = $Panel.RowCount; $Panel.RowCount += 1
    [void]$Panel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $lbl = New-Object System.Windows.Forms.Label; $lbl.AutoSize = $true; $lbl.Margin = New-Object System.Windows.Forms.Padding(3, 7, 3, 3); $lbl.MaximumSize = New-Object System.Drawing.Size(245, 0)
    $Control.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 3); $Control.Anchor = ([System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top)
    $help = New-Object System.Windows.Forms.Label; $help.AutoSize = $true; $help.ForeColor = [System.Drawing.Color]::DimGray; $help.Margin = New-Object System.Windows.Forms.Padding(3, 7, 3, 3); $help.MaximumSize = New-Object System.Drawing.Size(640, 0)
    [void]$Panel.Controls.Add($lbl, 0, $r); [void]$Panel.Controls.Add($Control, 1, $r); [void]$Panel.Controls.Add($help, 2, $r)
    [void]$Registry.Add([pscustomobject]@{ LabelControl = $lbl; HelpControl = $help; LabelKey = $LabelKey; HelpKey = $HelpKey })
}

function Quote-ForDisplay { param([string]$Value) if ($Value -match '\s|\"') { return '"' + ($Value -replace '"', '\"') + '"' }; return $Value }
function Escape-BatchEchoText { param([string]$Text) $x = $Text -replace '\^', '^^' -replace '%', '%%' -replace '&', '^&' -replace '\|', '^|' -replace '<', '^<' -replace '>', '^>'; return $x }
function Get-SystemTotalRamGB { try { return [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 1) } catch { return 0.0 } }
function Write-LauncherLog {
    param([string]$Message)
    try {
        $logFile = Join-Path $ServerRoot "logs/chunky-pregen-guard-ui.log"
        $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path $logFile -Value $line -Encoding UTF8
    } catch {
    }
}
function Get-RecentSupervisorLogLines {
    param(
        [string]$LogPath,
        [datetime]$Since,
        [int]$TailLines = 500
    )
    if (-not (Test-Path -Path $LogPath)) {
        return @()
    }
    $tail = @(Get-Content -Path $LogPath -Tail $TailLines -ErrorAction SilentlyContinue)
    if ($tail.Count -eq 0) {
        return @()
    }

    $cutoff = $Since.AddSeconds(-2)
    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($line in $tail) {
        if ($line -match '^\[(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s') {
            try {
                $ts = [datetime]::ParseExact(
                    $Matches["ts"],
                    "yyyy-MM-dd HH:mm:ss",
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeLocal
                )
                if ($ts -ge $cutoff) {
                    $filtered.Add($line)
                }
            } catch {
            }
        } elseif ($filtered.Count -gt 0) {
            $filtered.Add($line)
        }
    }
    return @($filtered)
}
function Wait-StartupDiagnosis {
    param(
        [string]$RootPath,
        [string]$SupervisorLogRel,
        [datetime]$Since,
        [int]$TimeoutSec = 55
    )
    $logPath = Join-Path $RootPath $SupervisorLogRel
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $last = @()

    while ((Get-Date) -lt $deadline) {
        $recent = @(Get-RecentSupervisorLogLines -LogPath $logPath -Since $Since -TailLines 500)
        if ($recent.Count -gt 0) { $last = $recent }
        $text = ($recent -join "`n")

        $hasHealthy = ($text -match "Comando enviado apos Servidor iniciado") -or ($text -match "Healthcheck: PID=")
        if ($hasHealthy) {
            return [pscustomobject]@{ Status = "healthy"; Lines = $recent; LogPath = $logPath }
        }

        $hasRuntimeFailure = ($text -match "Processo Java encerrou") -or
            ($text -match "\[SERVER-ERR\]") -or
            ($text -match "ModLoadingException") -or
            ($text -match "missing") -or
            ($text -match "Failed to load")
        if ($hasRuntimeFailure) {
            return [pscustomobject]@{ Status = "runtime_failure"; Lines = $recent; LogPath = $logPath }
        }

        Start-Sleep -Seconds 2
    }

    return [pscustomobject]@{ Status = "unknown"; Lines = $last; LogPath = $logPath }
}
function Resolve-JvmPreset {
    param([string]$Preset)
    if ([string]::IsNullOrWhiteSpace($Preset)) { return "balanced" }
    switch ($Preset.Trim().ToLowerInvariant()) {
        "throughput" { return "throughput" }
        "lowram" { return "lowram" }
        default { return "balanced" }
    }
}

function Get-ComboSelectedValue {
    param(
        [System.Windows.Forms.ComboBox]$Combo,
        [string]$DefaultValue = ""
    )
    if ($null -eq $Combo) { return $DefaultValue }

    $raw = $null
    try { $raw = $Combo.SelectedValue } catch {}

    if ($null -ne $raw) {
        if ($raw -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($raw)) { return $raw }
        } elseif ($raw -is [System.Collections.IDictionary] -and $raw.Contains("Value")) {
            $v = [string]$raw["Value"]
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        } elseif ($raw.PSObject.Properties.Name -contains "Value") {
            $v = [string]$raw.Value
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        }
    }

    $item = $Combo.SelectedItem
    if ($null -ne $item) {
        if ($item -is [System.Collections.IDictionary] -and $item.Contains("Value")) {
            $v = [string]$item["Value"]
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        } elseif ($item.PSObject.Properties.Name -contains "Value") {
            $v = [string]$item.Value
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        } else {
            $v = [string]$item
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        }
    }

    return $DefaultValue
}

function Get-Recommendation {
    param(
        [double]$TotalRamGB,
        [string]$JvmPreset = "balanced"
    )

    $preset = Resolve-JvmPreset -Preset $JvmPreset
    if ($TotalRamGB -le 0) { $TotalRamGB = 16 }

    $reserveGB = if ($TotalRamGB -le 12) {
        3
    } elseif ($TotalRamGB -le 20) {
        4
    } elseif ($TotalRamGB -le 32) {
        6
    } elseif ($TotalRamGB -le 64) {
        8
    } else {
        10
    }
    $maxPracticalXmx = [int][math]::Max(6, [math]::Floor($TotalRamGB - $reserveGB))

    $tier = if ($TotalRamGB -le 12) {
        @{ lowram = 6; balanced = 7; throughput = 8 }
    } elseif ($TotalRamGB -le 16) {
        @{ lowram = 8; balanced = 10; throughput = 11 }
    } elseif ($TotalRamGB -le 24) {
        @{ lowram = 10; balanced = 13; throughput = 15 }
    } elseif ($TotalRamGB -le 32) {
        @{ lowram = 12; balanced = 16; throughput = 19 }
    } elseif ($TotalRamGB -le 48) {
        @{ lowram = 14; balanced = 20; throughput = 24 }
    } elseif ($TotalRamGB -le 64) {
        @{ lowram = 16; balanced = 24; throughput = 30 }
    } else {
        @{ lowram = 20; balanced = 28; throughput = 36 }
    }

    $xmxTarget = [int]$tier[$preset]
    $xmx = [int][math]::Max(6, [math]::Min($xmxTarget, $maxPracticalXmx))

    $xmsRatio = 0.40
    $xmsMin = 4
    $xmsCap = 10
    $hardPct = 0.92
    $softPct = 0.83
    $prePct = 0.73
    $projPct = 0.58
    $checkInterval = 30
    $warmup = 180
    $startupDelay = 60
    $flushSettle = 15
    $stopGrace = 20
    $avgWindow = 10
    $minConsecutive = 4
    $lowEtaChecks = 3
    $leadMin = 2
    $leadMax = 4
    $trendMode = "hybrid"

    switch ($preset) {
        "throughput" {
            $xmsRatio = 0.50
            $xmsMin = 4
            $xmsCap = 12
            $hardPct = 0.94
            $softPct = 0.86
            $prePct = 0.77
            $projPct = 0.62
            $checkInterval = 20
            $warmup = 120
            $startupDelay = 45
            $flushSettle = 10
            $stopGrace = 15
            $avgWindow = 8
            $minConsecutive = 3
            $lowEtaChecks = 2
            $leadMin = 2
            $leadMax = 3
            $trendMode = "hybrid"
        }
        "lowram" {
            $xmsRatio = 0.33
            $xmsMin = 3
            $xmsCap = 8
            $hardPct = 0.90
            $softPct = 0.78
            $prePct = 0.66
            $projPct = 0.55
            $checkInterval = 30
            $warmup = 180
            $startupDelay = 75
            $flushSettle = 20
            $stopGrace = 25
            $avgWindow = 12
            $minConsecutive = 4
            $lowEtaChecks = 3
            $leadMin = 3
            $leadMax = 5
            $trendMode = "private"
        }
    }

    $xms = [int][math]::Floor($xmx * $xmsRatio)
    if ($xms -lt $xmsMin) { $xms = $xmsMin }
    if ($xms -gt $xmsCap) { $xms = $xmsCap }
    if ($xms -ge $xmx) { $xms = [int][math]::Max(2, $xmx - 2) }

    $hard = [math]::Round($xmx * $hardPct, 1)
    if ($hard -ge $xmx) { $hard = [math]::Round($xmx - 0.3, 1) }

    $soft = [math]::Round($xmx * $softPct, 1)
    if ($soft -ge $hard) { $soft = [math]::Round($hard - 0.8, 1) }

    $pre = [math]::Round($xmx * $prePct, 1)
    if ($pre -ge $soft) { $pre = [math]::Round($soft - 0.8, 1) }
    if ($pre -lt 2.5) { $pre = 2.5 }

    if ($soft -lt ($pre + 0.8)) { $soft = [math]::Round($pre + 0.8, 1) }
    if ($hard -lt ($soft + 0.8)) { $hard = [math]::Round($soft + 0.8, 1) }
    if ($hard -ge $xmx) {
        $hard = [math]::Round($xmx - 0.3, 1)
        if ($soft -ge $hard) { $soft = [math]::Round($hard - 0.8, 1) }
        if ($pre -ge $soft) { $pre = [math]::Round($soft - 0.8, 1) }
    }

    $projectionMinPrivate = [math]::Round([math]::Max(6.0, $xmx * $projPct), 1)
    if ($projectionMinPrivate -ge $hard) {
        $projectionMinPrivate = [math]::Round($hard - 1.0, 1)
    }

    return [pscustomobject]@{
        Xms = $xms
        Xmx = $xmx
        Soft = $soft
        Hard = $hard
        PreWarn = $pre
        ProjectionMinPrivate = $projectionMinPrivate
        CheckIntervalSec = $checkInterval
        WarmupSec = $warmup
        StartupDelaySec = $startupDelay
        FlushSettleSec = $flushSettle
        StopGraceSec = $stopGrace
        AverageWindowChecks = $avgWindow
        MinConsecutiveAboveThreshold = $minConsecutive
        LowEtaConsecutiveChecks = $lowEtaChecks
        AdaptiveLeadMinMinutes = $leadMin
        AdaptiveLeadMaxMinutes = $leadMax
        TrendSourceMode = $trendMode
        JvmPreset = $preset
    }
}

function Get-JvmPresetArgs {
    param([string]$Preset)
    switch ($Preset) {
        "throughput" {
            return @(
                "-XX:+UseG1GC",
                "-XX:MaxGCPauseMillis=240",
                "-XX:+ParallelRefProcEnabled",
                "-XX:+DisableExplicitGC",
                "-XX:+UseStringDeduplication",
                "-XX:G1ReservePercent=15",
                "-XX:InitiatingHeapOccupancyPercent=25"
            )
        }
        "lowram" {
            return @(
                "-XX:+UseG1GC",
                "-XX:MaxGCPauseMillis=300",
                "-XX:+ParallelRefProcEnabled",
                "-XX:+DisableExplicitGC",
                "-XX:+UseStringDeduplication",
                "-XX:G1ReservePercent=25",
                "-XX:InitiatingHeapOccupancyPercent=15"
            )
        }
        default {
            return @(
                "-XX:+UseG1GC",
                "-XX:MaxGCPauseMillis=200",
                "-XX:+ParallelRefProcEnabled",
                "-XX:+DisableExplicitGC",
                "-XX:+UseStringDeduplication",
                "-XX:G1ReservePercent=20",
                "-XX:InitiatingHeapOccupancyPercent=20"
            )
        }
    }
}

function Get-JvmArgLines {
    param($ui)
    $xms = [int]$ui.JvmXmsGB.Value
    $xmx = [int]$ui.JvmXmxGB.Value
    $preset = Resolve-JvmPreset -Preset (Get-ComboSelectedValue -Combo $ui.JvmPreset -DefaultValue "balanced")

    $list = New-Object System.Collections.Generic.List[string]
    $list.Add("-Xms${xms}G")
    $list.Add("-Xmx${xmx}G")
    foreach ($arg in (Get-JvmPresetArgs -Preset $preset)) { $list.Add($arg) }

    foreach ($line in ($ui.ExtraJvmArgs.Text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($t)) { $list.Add($t) }
    }

    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $list) {
        if (-not $seen.ContainsKey($line)) { $seen[$line] = $true; $out.Add($line) }
    }
    return @($out)
}

function Write-JvmArgsFile {
    param($ui, [string]$RootPath)
    $filePath = Join-Path $RootPath "user_jvm_args.txt"
    $backupPath = ""
    $lines = Get-JvmArgLines -ui $ui
    $newContent = ($lines -join "`n")

    if (Test-Path -Path $filePath) {
        $currentLines = Get-Content -Path $filePath -ErrorAction SilentlyContinue
        $currentContent = (($currentLines | ForEach-Object { $_.TrimEnd() }) -join "`n")
        if ($currentContent -eq $newContent) {
            return [pscustomobject]@{ Path = $filePath; BackupPath = ""; LineCount = $lines.Count }
        }

        $backupPath = "$filePath.bak"
        Copy-Item -Path $filePath -Destination $backupPath -Force
    }
    Set-Content -Path $filePath -Value $lines -Encoding ASCII
    return [pscustomobject]@{ Path = $filePath; BackupPath = $backupPath; LineCount = $lines.Count }
}

function Get-ArgumentPairs {
    param($ui)
    $trend = Get-ComboSelectedValue -Combo $ui.TrendSourceMode -DefaultValue "hybrid"
    return @(
        @("MaxMemoryGB", [string][double]$ui.MaxMemoryGB.Value),
        @("HardMemoryGB", [string][double]$ui.HardMemoryGB.Value),
        @("PreWarnMemoryGB", [string][double]$ui.PreWarnMemoryGB.Value),
        @("CheckIntervalSec", [string][int]$ui.CheckIntervalSec.Value),
        @("WarmupSec", [string][int]$ui.WarmupSec.Value),
        @("StartupDelaySec", [string][int]$ui.StartupDelaySec.Value),
        @("AverageWindowChecks", [string][int]$ui.AverageWindowChecks.Value),
        @("MinConsecutiveAboveThreshold", [string][int]$ui.MinConsecutiveAboveThreshold.Value),
        @("StopTimeoutSec", [string][int]$ui.StopTimeoutSec.Value),
        @("FlushSettleSec", [string][int]$ui.FlushSettleSec.Value),
        @("StopGraceSec", [string][int]$ui.StopGraceSec.Value),
        @("ProjectionMinRamPrivateGB", [string][double]$ui.ProjectionMinRamPrivateGB.Value),
        @("LowEtaConsecutiveChecks", [string][int]$ui.LowEtaConsecutiveChecks.Value),
        @("AdaptiveLeadMinMinutes", [string][int]$ui.AdaptiveLeadMinMinutes.Value),
        @("AdaptiveLeadMaxMinutes", [string][int]$ui.AdaptiveLeadMaxMinutes.Value),
        @("TrendSourceMode", $trend),
        @("PreWarnProjectionEnabled", $(if ($ui.PreWarnProjectionEnabled.Checked) { "1" } else { "0" })),
        @("BroadcastEnabled", $(if ($ui.BroadcastEnabled.Checked) { "1" } else { "0" })),
        @("BroadcastPrefix", $ui.BroadcastPrefix.Text),
        @("ResumeCommands", $ui.ResumeCommands.Text),
        @("LogFile", $ui.LogFile.Text),
        @("LockFile", $ui.LockFile.Text),
        @("StopExistingServer", $(if ($ui.StopExistingServer.Checked) { "1" } else { "0" }))
    )
}

function Get-ArgumentData {
    param($ui, [string]$ScriptPath)
    $pairs = Get-ArgumentPairs -ui $ui
    $args = New-Object System.Collections.Generic.List[string]
    $args.Add("-NoProfile"); $args.Add("-ExecutionPolicy"); $args.Add("Bypass"); $args.Add("-File"); $args.Add($ScriptPath)
    foreach ($p in $pairs) { $args.Add("-$($p[0])"); $args.Add([string]$p[1]) }
    if ($ui.GuiMode.Checked) { $args.Add("-GuiMode") }
    return $args
}

function Validate-Inputs {
    param($ui)
    if ([int]$ui.AdaptiveLeadMinMinutes.Value -gt [int]$ui.AdaptiveLeadMaxMinutes.Value) { [System.Windows.Forms.MessageBox]::Show((T "m_lead"), (T "w"), "OK", "Warning") | Out-Null; return $false }
    if ([int]$ui.JvmXmsGB.Value -gt [int]$ui.JvmXmxGB.Value) { [System.Windows.Forms.MessageBox]::Show((T "m_jvm"), (T "w"), "OK", "Warning") | Out-Null; return $false }
    if ([double]$ui.MaxMemoryGB.Value -ge [double]$ui.HardMemoryGB.Value) { [System.Windows.Forms.MessageBox]::Show((T "m_soft"), (T "w"), "OK", "Warning") | Out-Null; return $false }
    if ([double]$ui.PreWarnMemoryGB.Value -ge [double]$ui.HardMemoryGB.Value) { [System.Windows.Forms.MessageBox]::Show((T "m_prew"), (T "w"), "OK", "Warning") | Out-Null; return $false }
    return $true
}

function Register-PreviewTrigger {
    param([System.Windows.Forms.Control]$Control)
    if ($Control -is [System.Windows.Forms.NumericUpDown]) { $Control.Add_ValueChanged({ Update-Preview }) }
    elseif ($Control -is [System.Windows.Forms.TextBox]) { $Control.Add_TextChanged({ Update-Preview }) }
    elseif ($Control -is [System.Windows.Forms.CheckBox]) { $Control.Add_CheckedChanged({ Update-Preview }) }
    elseif ($Control -is [System.Windows.Forms.ComboBox]) { $Control.Add_SelectedIndexChanged({ Update-Preview }) }
}

function Get-TrendModeOptions { return @(@{ Display = (T "tr_h"); Value = "hybrid" }, @{ Display = (T "tr_p"); Value = "private" }, @{ Display = (T "tr_w"); Value = "ws" }) }
function Get-JvmPresetOptions { return @(@{ Display = (T "jp_b"); Value = "balanced" }, @{ Display = (T "jp_t"); Value = "throughput" }, @{ Display = (T "jp_l"); Value = "lowram" }) }
function Update-Preview {
    try {
        $args = Get-ArgumentData -ui $ui -ScriptPath $launcherScriptPath
        $parts = @("powershell"); foreach ($a in $args) { $parts += (Quote-ForDisplay -Value $a) }
        $cmdText = $parts -join " "
        $jvmText = if ($ui.ApplyJvmArgs.Checked) { (Get-JvmArgLines -ui $ui) -join "`r`n" } else { T "jvmd" }
        $preview.Text = ((T "cmd") + "`r`n" + $cmdText + "`r`n`r`n" + (T "jvmp") + "`r`n" + $jvmText)
    } catch {
        [System.Windows.Forms.MessageBox]::Show((Tf "m_prev" @($_.Exception.Message)), (T "e"), "OK", "Error") | Out-Null
    }
}

function Apply-Recommendation {
    param(
        [double]$TotalRamGB,
        [string]$JvmPreset = "balanced"
    )
    $r = Get-Recommendation -TotalRamGB $TotalRamGB -JvmPreset $JvmPreset
    $ui.JvmXmsGB.Value = [decimal]$r.Xms
    $ui.JvmXmxGB.Value = [decimal]$r.Xmx
    $ui.MaxMemoryGB.Value = [decimal]$r.Soft
    $ui.HardMemoryGB.Value = [decimal]$r.Hard
    $ui.PreWarnMemoryGB.Value = [decimal]$r.PreWarn
    $ui.ProjectionMinRamPrivateGB.Value = [decimal]$r.ProjectionMinPrivate
    $ui.CheckIntervalSec.Value = [decimal]$r.CheckIntervalSec
    $ui.WarmupSec.Value = [decimal]$r.WarmupSec
    $ui.StartupDelaySec.Value = [decimal]$r.StartupDelaySec
    $ui.FlushSettleSec.Value = [decimal]$r.FlushSettleSec
    $ui.StopGraceSec.Value = [decimal]$r.StopGraceSec
    $ui.AverageWindowChecks.Value = [decimal]$r.AverageWindowChecks
    $ui.MinConsecutiveAboveThreshold.Value = [decimal]$r.MinConsecutiveAboveThreshold
    $ui.LowEtaConsecutiveChecks.Value = [decimal]$r.LowEtaConsecutiveChecks
    $ui.AdaptiveLeadMinMinutes.Value = [decimal]$r.AdaptiveLeadMinMinutes
    $ui.AdaptiveLeadMaxMinutes.Value = [decimal]$r.AdaptiveLeadMaxMinutes
    $ui.PreWarnProjectionEnabled.Checked = $true
    $ui.BroadcastEnabled.Checked = $true
    $ui.StopExistingServer.Checked = $true
    $ui.ApplyJvmArgs.Checked = $true
    $ui.TrendSourceMode.SelectedValue = $r.TrendSourceMode
    $ui.JvmPreset.SelectedValue = $r.JvmPreset
}

function Apply-Language {
    $form.Text = T "form"
    $header.Text = T "head"
    $tabMain.Text = T "tab1"
    $tabAdv.Text = T "tab2"
    $tabJava.Text = T "tab3"
    $lblLanguage.Text = T "lang"
    $btnRecommended.Text = T "rec"
    $btnStart.Text = T "start"
    $btnSaveBat.Text = T "save"
    $btnRefresh.Text = T "prev"
    $systemRamLabel.Text = Tf "sysram" @($systemRamGB)

    foreach ($row in $rowRegistry) {
        $row.LabelControl.Text = T $row.LabelKey
        $row.HelpControl.Text = T $row.HelpKey
    }

    $ui.GuiMode.Text = T "c_gui"
    $ui.BroadcastEnabled.Text = T "c_brd"
    $ui.PreWarnProjectionEnabled.Text = T "c_proj"
    $ui.StopExistingServer.Text = T "c_clean"
    $ui.ApplyJvmArgs.Text = T "c_jvm"

    $trend = Get-ComboSelectedValue -Combo $ui.TrendSourceMode -DefaultValue "hybrid"
    Set-ComboOptions -Combo $ui.TrendSourceMode -Items (Get-TrendModeOptions) -SelectedValue $trend
    $jp = Resolve-JvmPreset -Preset (Get-ComboSelectedValue -Combo $ui.JvmPreset -DefaultValue "balanced")
    Set-ComboOptions -Combo $ui.JvmPreset -Items (Get-JvmPresetOptions) -SelectedValue $jp

    Update-Preview
}

$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(1320, 920)
$form.MinimumSize = New-Object System.Drawing.Size(1150, 760)
$form.StartPosition = "CenterScreen"

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = "Fill"
$root.AutoScroll = $true
$root.ColumnCount = 1
$root.RowCount = 5
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$form.Controls.Add($root)

$topBar = New-Object System.Windows.Forms.FlowLayoutPanel
$topBar.FlowDirection = "LeftToRight"
$topBar.AutoSize = $true
$topBar.WrapContents = $false
$topBar.Margin = New-Object System.Windows.Forms.Padding(10, 10, 10, 0)

$lblLanguage = New-Object System.Windows.Forms.Label
$lblLanguage.AutoSize = $true
$lblLanguage.Margin = New-Object System.Windows.Forms.Padding(3, 8, 6, 3)

$langCombo = New-Object System.Windows.Forms.ComboBox
$langCombo.Width = 170
$langCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
Set-ComboOptions -Combo $langCombo -Items @(
    @{ Display = "Portuguese (Brazil)"; Value = "pt-BR" },
    @{ Display = "English"; Value = "en-US" }
) -SelectedValue "pt-BR"

$btnRecommended = New-Object System.Windows.Forms.Button
$btnRecommended.AutoSize = $true
$btnRecommended.Margin = New-Object System.Windows.Forms.Padding(18, 3, 3, 3)

$systemRamGB = Get-SystemTotalRamGB
$systemRamLabel = New-Object System.Windows.Forms.Label
$systemRamLabel.AutoSize = $true
$systemRamLabel.Margin = New-Object System.Windows.Forms.Padding(14, 8, 3, 3)
$systemRamLabel.ForeColor = [System.Drawing.Color]::DimGray

[void]$topBar.Controls.Add($lblLanguage)
[void]$topBar.Controls.Add($langCombo)
[void]$topBar.Controls.Add($btnRecommended)
[void]$topBar.Controls.Add($systemRamLabel)
[void]$root.Controls.Add($topBar, 0, 0)

$header = New-Object System.Windows.Forms.Label
$header.AutoSize = $true
$header.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$header.Margin = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)
[void]$root.Controls.Add($header, 0, 1)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Margin = New-Object System.Windows.Forms.Padding(10, 0, 10, 0)
[void]$root.Controls.Add($tabs, 0, 2)

$tabMain = New-Object System.Windows.Forms.TabPage
$tabAdv = New-Object System.Windows.Forms.TabPage
$tabJava = New-Object System.Windows.Forms.TabPage
[void]$tabs.TabPages.Add($tabMain)
[void]$tabs.TabPages.Add($tabAdv)
[void]$tabs.TabPages.Add($tabJava)

$gridMain = New-Object System.Windows.Forms.TableLayoutPanel
$gridMain.Dock = "Fill"; $gridMain.AutoScroll = $true; $gridMain.ColumnCount = 3
[void]$gridMain.RowStyles.Clear(); $gridMain.RowCount = 0; $gridMain.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::AddRows
[void]$gridMain.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 250)))
[void]$gridMain.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 300)))
[void]$gridMain.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$tabMain.Controls.Add($gridMain)

$gridAdv = New-Object System.Windows.Forms.TableLayoutPanel
$gridAdv.Dock = "Fill"; $gridAdv.AutoScroll = $true; $gridAdv.ColumnCount = 3
[void]$gridAdv.RowStyles.Clear(); $gridAdv.RowCount = 0; $gridAdv.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::AddRows
[void]$gridAdv.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 250)))
[void]$gridAdv.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 300)))
[void]$gridAdv.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$tabAdv.Controls.Add($gridAdv)

$gridJava = New-Object System.Windows.Forms.TableLayoutPanel
$gridJava.Dock = "Fill"; $gridJava.AutoScroll = $true; $gridJava.ColumnCount = 3
[void]$gridJava.RowStyles.Clear(); $gridJava.RowCount = 0; $gridJava.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::AddRows
[void]$gridJava.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 250)))
[void]$gridJava.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 300)))
[void]$gridJava.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$tabJava.Controls.Add($gridJava)

$rowRegistry = New-Object System.Collections.ArrayList
$ui = [ordered]@{}
$ui.MaxMemoryGB = New-Numeric -Value 20 -Minimum 4 -Maximum 96 -DecimalPlaces 1; Add-LocalizedRow -Panel $gridMain -Control $ui.MaxMemoryGB -LabelKey "l_soft" -HelpKey "h_soft" -Registry $rowRegistry
$ui.HardMemoryGB = New-Numeric -Value 22 -Minimum 4 -Maximum 96 -DecimalPlaces 1; Add-LocalizedRow -Panel $gridMain -Control $ui.HardMemoryGB -LabelKey "l_hard" -HelpKey "h_hard" -Registry $rowRegistry
$ui.PreWarnMemoryGB = New-Numeric -Value 17.5 -Minimum 4 -Maximum 96 -DecimalPlaces 1; Add-LocalizedRow -Panel $gridMain -Control $ui.PreWarnMemoryGB -LabelKey "l_prew" -HelpKey "h_prew" -Registry $rowRegistry
$ui.AdaptiveLeadMinMinutes = New-Numeric -Value 2 -Minimum 1 -Maximum 20; Add-LocalizedRow -Panel $gridMain -Control $ui.AdaptiveLeadMinMinutes -LabelKey "l_lmin" -HelpKey "h_lmin" -Registry $rowRegistry
$ui.AdaptiveLeadMaxMinutes = New-Numeric -Value 4 -Minimum 1 -Maximum 30; Add-LocalizedRow -Panel $gridMain -Control $ui.AdaptiveLeadMaxMinutes -LabelKey "l_lmax" -HelpKey "h_lmax" -Registry $rowRegistry
$ui.CheckIntervalSec = New-Numeric -Value 30 -Minimum 5 -Maximum 300; Add-LocalizedRow -Panel $gridMain -Control $ui.CheckIntervalSec -LabelKey "l_chk" -HelpKey "h_chk" -Registry $rowRegistry
$ui.WarmupSec = New-Numeric -Value 180 -Minimum 0 -Maximum 1800; Add-LocalizedRow -Panel $gridMain -Control $ui.WarmupSec -LabelKey "l_warm" -HelpKey "h_warm" -Registry $rowRegistry
$ui.StartupDelaySec = New-Numeric -Value 60 -Minimum 0 -Maximum 900; Add-LocalizedRow -Panel $gridMain -Control $ui.StartupDelaySec -LabelKey "l_st" -HelpKey "h_st" -Registry $rowRegistry
$ui.FlushSettleSec = New-Numeric -Value 15 -Minimum 0 -Maximum 180; Add-LocalizedRow -Panel $gridMain -Control $ui.FlushSettleSec -LabelKey "l_fl" -HelpKey "h_fl" -Registry $rowRegistry
$ui.StopGraceSec = New-Numeric -Value 20 -Minimum 1 -Maximum 300; Add-LocalizedRow -Panel $gridMain -Control $ui.StopGraceSec -LabelKey "l_gr" -HelpKey "h_gr" -Registry $rowRegistry
$ui.ResumeCommands = New-TextBox -Text "chunky continue" -Width 280; Add-LocalizedRow -Panel $gridMain -Control $ui.ResumeCommands -LabelKey "l_rc" -HelpKey "h_rc" -Registry $rowRegistry
$ui.GuiMode = New-CheckBox -Checked $true; Add-LocalizedRow -Panel $gridMain -Control $ui.GuiMode -LabelKey "l_gui" -HelpKey "h_gui" -Registry $rowRegistry
$ui.BroadcastEnabled = New-CheckBox -Checked $true; Add-LocalizedRow -Panel $gridMain -Control $ui.BroadcastEnabled -LabelKey "l_brd" -HelpKey "h_brd" -Registry $rowRegistry
$ui.PreWarnProjectionEnabled = New-CheckBox -Checked $true; Add-LocalizedRow -Panel $gridMain -Control $ui.PreWarnProjectionEnabled -LabelKey "l_proj" -HelpKey "h_proj" -Registry $rowRegistry
$ui.StopExistingServer = New-CheckBox -Checked $true; Add-LocalizedRow -Panel $gridMain -Control $ui.StopExistingServer -LabelKey "l_clean" -HelpKey "h_clean" -Registry $rowRegistry

$ui.AverageWindowChecks = New-Numeric -Value 10 -Minimum 2 -Maximum 200; Add-LocalizedRow -Panel $gridAdv -Control $ui.AverageWindowChecks -LabelKey "l_avg" -HelpKey "h_avg" -Registry $rowRegistry
$ui.MinConsecutiveAboveThreshold = New-Numeric -Value 4 -Minimum 1 -Maximum 200; Add-LocalizedRow -Panel $gridAdv -Control $ui.MinConsecutiveAboveThreshold -LabelKey "l_con" -HelpKey "h_con" -Registry $rowRegistry
$ui.StopTimeoutSec = New-Numeric -Value 360 -Minimum 20 -Maximum 7200; Add-LocalizedRow -Panel $gridAdv -Control $ui.StopTimeoutSec -LabelKey "l_stop" -HelpKey "h_stop" -Registry $rowRegistry
$ui.ProjectionMinRamPrivateGB = New-Numeric -Value 14 -Minimum 0 -Maximum 96 -DecimalPlaces 1; Add-LocalizedRow -Panel $gridAdv -Control $ui.ProjectionMinRamPrivateGB -LabelKey "l_minp" -HelpKey "h_minp" -Registry $rowRegistry
$ui.LowEtaConsecutiveChecks = New-Numeric -Value 3 -Minimum 1 -Maximum 20; Add-LocalizedRow -Panel $gridAdv -Control $ui.LowEtaConsecutiveChecks -LabelKey "l_low" -HelpKey "h_low" -Registry $rowRegistry
$ui.TrendSourceMode = New-Object System.Windows.Forms.ComboBox; $ui.TrendSourceMode.Width = 280; $ui.TrendSourceMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
Set-ComboOptions -Combo $ui.TrendSourceMode -Items (Get-TrendModeOptions) -SelectedValue "hybrid"
Add-LocalizedRow -Panel $gridAdv -Control $ui.TrendSourceMode -LabelKey "l_tr" -HelpKey "h_tr" -Registry $rowRegistry
$ui.BroadcastPrefix = New-TextBox -Text "[AutoRestart]" -Width 280; Add-LocalizedRow -Panel $gridAdv -Control $ui.BroadcastPrefix -LabelKey "l_pref" -HelpKey "h_pref" -Registry $rowRegistry
$ui.LogFile = New-TextBox -Text "logs/chunky-autorestart.log" -Width 280; Add-LocalizedRow -Panel $gridAdv -Control $ui.LogFile -LabelKey "l_log" -HelpKey "h_log" -Registry $rowRegistry
$ui.LockFile = New-TextBox -Text "logs/chunky-autorestart.lock" -Width 280; Add-LocalizedRow -Panel $gridAdv -Control $ui.LockFile -LabelKey "l_lock" -HelpKey "h_lock" -Registry $rowRegistry

$ui.JvmXmsGB = New-Numeric -Value 4 -Minimum 1 -Maximum 96; Add-LocalizedRow -Panel $gridJava -Control $ui.JvmXmsGB -LabelKey "l_xms" -HelpKey "h_xms" -Registry $rowRegistry
$ui.JvmXmxGB = New-Numeric -Value 24 -Minimum 2 -Maximum 128; Add-LocalizedRow -Panel $gridJava -Control $ui.JvmXmxGB -LabelKey "l_xmx" -HelpKey "h_xmx" -Registry $rowRegistry
$ui.JvmPreset = New-Object System.Windows.Forms.ComboBox; $ui.JvmPreset.Width = 280; $ui.JvmPreset.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
Set-ComboOptions -Combo $ui.JvmPreset -Items (Get-JvmPresetOptions) -SelectedValue "balanced"
Add-LocalizedRow -Panel $gridJava -Control $ui.JvmPreset -LabelKey "l_jpre" -HelpKey "h_jpre" -Registry $rowRegistry
$ui.ApplyJvmArgs = New-CheckBox -Checked $true; Add-LocalizedRow -Panel $gridJava -Control $ui.ApplyJvmArgs -LabelKey "l_aj" -HelpKey "h_aj" -Registry $rowRegistry
$ui.ExtraJvmArgs = New-Object System.Windows.Forms.TextBox; $ui.ExtraJvmArgs.Multiline = $true; $ui.ExtraJvmArgs.ScrollBars = "Vertical"; $ui.ExtraJvmArgs.Width = 280; $ui.ExtraJvmArgs.Height = 100; $ui.ExtraJvmArgs.Text = ""
Add-LocalizedRow -Panel $gridJava -Control $ui.ExtraJvmArgs -LabelKey "l_ex" -HelpKey "h_ex" -Registry $rowRegistry
$ui.JvmFilePath = New-TextBox -Text "user_jvm_args.txt" -Width 280; $ui.JvmFilePath.ReadOnly = $true
Add-LocalizedRow -Panel $gridJava -Control $ui.JvmFilePath -LabelKey "l_jf" -HelpKey "h_jf" -Registry $rowRegistry

$preview = New-Object System.Windows.Forms.TextBox
$preview.Multiline = $true; $preview.ScrollBars = "Vertical"; $preview.ReadOnly = $true; $preview.Dock = "Fill"; $preview.Height = 145
$preview.Margin = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
[void]$root.Controls.Add($preview, 0, 3)

$btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$btnPanel.FlowDirection = "LeftToRight"; $btnPanel.AutoSize = $true; $btnPanel.WrapContents = $false
$btnPanel.Margin = New-Object System.Windows.Forms.Padding(10, 0, 10, 10)
[void]$root.Controls.Add($btnPanel, 0, 4)

$btnStart = New-Object System.Windows.Forms.Button; $btnStart.AutoSize = $true
$btnSaveBat = New-Object System.Windows.Forms.Button; $btnSaveBat.AutoSize = $true
$btnRefresh = New-Object System.Windows.Forms.Button; $btnRefresh.AutoSize = $true
[void]$btnPanel.Controls.Add($btnStart); [void]$btnPanel.Controls.Add($btnSaveBat); [void]$btnPanel.Controls.Add($btnRefresh)

$launcherScriptPath = $targetScript

$previewControls = @(
    $ui.MaxMemoryGB, $ui.HardMemoryGB, $ui.PreWarnMemoryGB, $ui.AdaptiveLeadMinMinutes, $ui.AdaptiveLeadMaxMinutes,
    $ui.CheckIntervalSec, $ui.WarmupSec, $ui.StartupDelaySec, $ui.FlushSettleSec, $ui.StopGraceSec,
    $ui.ResumeCommands, $ui.GuiMode, $ui.BroadcastEnabled, $ui.PreWarnProjectionEnabled, $ui.StopExistingServer,
    $ui.AverageWindowChecks, $ui.MinConsecutiveAboveThreshold, $ui.StopTimeoutSec, $ui.ProjectionMinRamPrivateGB,
    $ui.LowEtaConsecutiveChecks, $ui.TrendSourceMode, $ui.BroadcastPrefix, $ui.LogFile, $ui.LockFile,
    $ui.JvmXmsGB, $ui.JvmXmxGB, $ui.JvmPreset, $ui.ApplyJvmArgs, $ui.ExtraJvmArgs
)
foreach ($c in $previewControls) { Register-PreviewTrigger -Control $c }

$langCombo.Add_SelectedIndexChanged({
    try {
        $newLang = ""
        if ($null -ne $langCombo.SelectedValue) {
            $newLang = $langCombo.SelectedValue.ToString()
        }
        if ([string]::IsNullOrWhiteSpace($newLang) -and $null -ne $langCombo.SelectedItem) {
            if ($langCombo.SelectedItem.PSObject.Properties.Name -contains "Value") {
                $newLang = [string]$langCombo.SelectedItem.Value
            }
        }
        if ($i18n.ContainsKey($newLang)) {
            $currentLang = $newLang
            Apply-Language
        }
    } catch {
    }
})

$btnRecommended.Add_Click({
    try {
        $selectedPreset = Resolve-JvmPreset -Preset (Get-ComboSelectedValue -Combo $ui.JvmPreset -DefaultValue "balanced")
        Apply-Recommendation -TotalRamGB $systemRamGB -JvmPreset $selectedPreset
        Update-Preview
        [System.Windows.Forms.MessageBox]::Show((Tf "m_rec" @($systemRamGB)), (T "ok"), "OK", "Information") | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show((Tf "m_recf" @($_.Exception.Message)), (T "e"), "OK", "Error") | Out-Null
    }
})

$btnRefresh.Add_Click({ Update-Preview })
$btnStart.Add_Click({
    try {
        if (-not (Validate-Inputs -ui $ui)) { return }
        $launchStart = Get-Date

        $jvmResult = $null
        if ($ui.ApplyJvmArgs.Checked) {
            try {
                $jvmResult = Write-JvmArgsFile -ui $ui -RootPath $ServerRoot
            } catch {
                [System.Windows.Forms.MessageBox]::Show((Tf "m_jvmf" @($_.Exception.Message)), (T "e"), "OK", "Error") | Out-Null
                return
            }
        }

        $args = Get-ArgumentData -ui $ui -ScriptPath $launcherScriptPath
        # Keep the launched shell open so startup errors are visible to the user.
        $startArgs = New-Object System.Collections.Generic.List[string]
        foreach ($a in $args) { $startArgs.Add($a) }
        if (-not ($startArgs -contains "-NoExit")) {
            $insertAt = if ($startArgs.Count -ge 1) { 1 } else { 0 }
            $startArgs.Insert($insertAt, "-NoExit")
        }

        $quotedArgs = @()
        foreach ($a in $startArgs) { $quotedArgs += (Quote-ForDisplay -Value $a) }
        $argLine = $quotedArgs -join " "

        Write-LauncherLog "Start requested. ArgLine=$argLine"
        $startedProc = Start-Process -FilePath "powershell.exe" -ArgumentList $argLine -WorkingDirectory $ServerRoot -PassThru
        Write-LauncherLog "Process started. PID=$($startedProc.Id)"
        Start-Sleep -Seconds 3

        if ($startedProc.HasExited) {
            Write-LauncherLog "Process exited quickly. PID=$($startedProc.Id) ExitCode=$($startedProc.ExitCode)"
            $logPath = Join-Path $ServerRoot $ui.LogFile.Text
            $tail = ""
            if (Test-Path -Path $logPath) {
                $tail = (Get-Content -Path $logPath -Tail 8 -ErrorAction SilentlyContinue) -join "`r`n"
            }
            $msg = "O processo do supervisor fechou logo apos iniciar (PID=$($startedProc.Id), ExitCode=$($startedProc.ExitCode))."
            if (-not [string]::IsNullOrWhiteSpace($tail)) {
                $msg = $msg + "`r`n`r`nUltimas linhas do log:`r`n" + $tail
            } else {
                $msg = $msg + "`r`n`r`nVerifique o console aberto e o arquivo de log configurado."
            }
            [System.Windows.Forms.MessageBox]::Show($msg, (T "e"), "OK", "Error") | Out-Null
            return
        }

        $diagTimeout = [math]::Max(55, [int]$ui.StartupDelaySec.Value + 20)
        $diag = Wait-StartupDiagnosis -RootPath $ServerRoot -SupervisorLogRel $ui.LogFile.Text -Since $launchStart -TimeoutSec $diagTimeout
        if ($diag.Status -eq "runtime_failure") {
            Write-LauncherLog "Runtime failure detected after launch. PID=$($startedProc.Id)"
            $msg = (T "m_start_runtime_fail") + "`r`n" + (T "m_start_runtime_hint")
            [System.Windows.Forms.MessageBox]::Show($msg, (T "e"), "OK", "Error") | Out-Null
            return
        }
        if ($diag.Status -eq "unknown") {
            Write-LauncherLog "Startup status uncertain after timeout. PID=$($startedProc.Id)"
            $msg = (T "m_start_uncertain")
            [System.Windows.Forms.MessageBox]::Show($msg, (T "w"), "OK", "Warning") | Out-Null
            return
        }

        if ($null -ne $jvmResult) {
            [System.Windows.Forms.MessageBox]::Show((Tf "m_startj" @($jvmResult.LineCount)), (T "ok"), "OK", "Information") | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show((T "m_start"), (T "ok"), "OK", "Information") | Out-Null
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show((Tf "m_startf" @($_.Exception.Message)), (T "e"), "OK", "Error") | Out-Null
    }
})

$btnSaveBat.Add_Click({
    try {
        if (-not (Validate-Inputs -ui $ui)) { return }

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "Batch (*.bat)|*.bat"
        $saveDialog.FileName = "start-chunky-autorestart-custom.bat"
        $saveDialog.InitialDirectory = $ServerRoot
        if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $args = Get-ArgumentData -ui $ui -ScriptPath ".\$coreScriptName"
        $parts = @("powershell")
        foreach ($a in $args) { $parts += (Quote-ForDisplay -Value $a) }

        $content = New-Object System.Collections.Generic.List[string]
        $content.Add("@echo off")
        $content.Add("cd /d ""%~dp0""")

        if ($ui.ApplyJvmArgs.Checked) {
            $content.Add("if exist ""user_jvm_args.txt"" copy /Y ""user_jvm_args.txt"" ""user_jvm_args.txt.bak"" >nul")
            $content.Add("(")
            foreach ($line in (Get-JvmArgLines -ui $ui)) {
                $content.Add("echo " + (Escape-BatchEchoText -Text $line))
            }
            $content.Add(") > ""user_jvm_args.txt""")
        }

        $content.Add(($parts -join " "))
        $content.Add("pause")

        Set-Content -Path $saveDialog.FileName -Value $content -Encoding ASCII
        [System.Windows.Forms.MessageBox]::Show((T "m_bat"), (T "ok"), "OK", "Information") | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show((Tf "m_batf" @($_.Exception.Message)), (T "e"), "OK", "Error") | Out-Null
    }
})

try {
    $initialPreset = Resolve-JvmPreset -Preset (Get-ComboSelectedValue -Combo $ui.JvmPreset -DefaultValue "balanced")
    Apply-Recommendation -TotalRamGB $systemRamGB -JvmPreset $initialPreset
} catch {}
Apply-Language
[void]$form.ShowDialog()


