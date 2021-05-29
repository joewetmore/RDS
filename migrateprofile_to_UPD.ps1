# Script to migrate user profile data from a roaming profile to a UPD
#
# Usage:
#
# Modify the $UPDpath variable for the location of your UPDs
# Modify the $Profilepath variable for the location of your user profiles
# Create a list of user names to process in c:\scripts\userlist.txt
#
# This script uses Expand-archive and Mount-VHD PS commands, so it must be run on a Windows 2016 (or higher) system with RDS or Hyper-V modules installed
# This script will expand the userprofile.zip into c:\users, so the user's profile folder should not already exist at this location
#


# Check to see if a PS feature is installed
if (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell) {
    Write-Host "The Microsoft-Hyper-V-Management-PowerShell is installed"
} 
else {
    Write-Host "The Microsoft-Hyper-V-Management-PowerShell is not installed";exit
}

# Loop through the user list
foreach($user in Get-Content c:\scripts\userlist.txt) {
    if($user -match $regex){

        $UserSID = (New-Object System.Security.Principal.NTAccount($User)).Translate([System.Security.Principal.SecurityIdentifier]).value
        $UserUPD = "UVHD-$UserSID.vhdx"
        $UPDpath = "c:\temp\$UserUPD"
        $Profilepath = "c:\flex\archives"


        # Note: check here for existance of profile archive and UPD, else exit
        Write-Host "The username"$User" should have a profile archive at "$Profilepath\$User".zip and a UPD at "$UPDpath
        if (test-path -Path $Profilepath\$User.zip) {
            Write-Host "User profile $Profilepath\$User.zip found"
        }
        else {
            Write-Host "User profile $Profilepath\$User.zip not found";exit
        }
        if (test-path -Path $UPDpath) {
            Write-Host "User profile $UPDpath found"
        }
        else {
            Write-Host "User profile $UPDpath not found";exit
        }


        # Expand archive .ZIP
        # Note: check here for the existance of the profile already in c:\users and prompt to delete or quit
        if (test-path -Path c:\users\$User) {
            Write-Host "User profile already exists at c:\users.";exit
        }
        expand-archive -path $Profilepath\$User.zip -destinationpath c:\users\$User

        # Check for and delete a file
        $WantFile = "c:\users\$User\Registry\Flex Profiles.reg"
        $FileExists = Test-Path $WantFile
        If ($FileExists -eq $True) {remove-item $WantFile}

        # Mount the users UPD disk and get the drive letter
        $DriveLetter = (Mount-VHD -Path "$UPDpath" -PassThru | Get-Disk | Get-Partition | Get-Volume | Where-Object {$_.FileSystemLabel -like ""}).DriveLetter

        # Copy the user's profile data to the user's UPD
        Robocopy c:\users\$User $DriveLetter /copy:datso
        Robocopy C:\users\$User\AppData $DriveLetter\AppData /e /copy:datso
        Robocopy c:\users\$User\Favorites $DriveLetter\Favorites /e /copy:datso

        # Cleanup
        Remove-Item -Recurse c:\users\$user
        dismount-vhd -Path "$UPDpath"

    }
}



# Notes:

# New-VHD -Path c:\temp\testjoe.vhdx -SizeBytes 1GB
# Or use diskmgmt.msc to create a VHD

# CCA servername
#    STLPVFS01

# Get-ADUser -Identity testjoe | select SID
# UPD filename format
#    UVHD-S-1-5-21-1270786115-213448717-1826233855-2612.vhdx
