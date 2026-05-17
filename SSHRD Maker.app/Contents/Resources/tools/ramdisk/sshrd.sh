#!/usr/bin/env sh
{

echo "[*] Cleaning up work directory"
rm -rf work

$(rm *.log 2> /dev/null)
set -e
oscheck=$(uname)

version="$1"
major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)
major=${major:-0}
minor=${minor:-0}
patch=${patch:-0}

#MODIFIED FOR BLACKRA1N / T2 SUPPORT
cd "$(dirname "$0")"

ERR_HANDLER () {
    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"
    rm -rf work

}

trap ERR_HANDLER EXIT


if [ -e sshtars/ssh.tar.gz ]; then
    if [ "$oscheck" = 'Linux' ]; then
        gzip -d sshtars/ssh.tar.gz
        gzip -d sshtars/t2ssh.tar.gz
        gzip -d sshtars/atvssh.tar.gz
    fi
fi

if [ ! -e "$oscheck"/gaster ]; then
    gaster="gaster-$oscheck"
    curl -sLO https://nightly.link/verygenericname/gaster/workflows/makefile/main/"$gaster".zip
    unzip "$gaster".zip
    mv gaster "$oscheck"/
    rm -rf gaster "$gaster".zip
fi

chmod +x "$oscheck"/*

if [ "$1" = 'clean' ]; then
    rm -rf sshramdisk work
    echo "[*] Removed the current created SSH ramdisk"
    exit
elif [ "$1" = 'dump-blobs' ]; then
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/rdisk1" | dd of=dump.raw bs=256 count=$((0x4000))
    username=$USER
    date=$(date '+%Y-%m-%d-%H:%M:%S')
    fullStr='SSHMaker-'$date'-Blobs'
    mkdir /Users/$USER/Desktop/$fullStr/
    "$oscheck"/img4tool --convert -s dumped.shsh dump.raw
    killall iproxy
    cp /Applications/SSHRD\ Maker.app/Contents/Resources/tools/ramdisk/dumped.shsh /Users/$USER/Desktop/'SSHMaker-'$(date '+%Y-%m-%d-%H:%M:%S')'-Blobs'/dumped.shsh
    echo "[*] Onboard blobs should have dumped to the dumped.shsh file"
    exit
elif [ "$1" = 'reboot' ]; then
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
    echo "[*] Device should now reboot"
    exit
elif [ "$1" = 'ssh' ]; then
    killall iproxy 2>/dev/null | true
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost
    killall iproxy
    exit
elif [ "$oscheck" = 'Darwin' ]; then
    if ! (system_profiler SPUSBDataType SPUSBHostDataType 2> /dev/null | grep -E 'Apple Mobile Device \(DFU Mode\)|Apple T2 DFU' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi

    while ! (system_profiler SPUSBDataType SPUSBHostDataType 2> /dev/null | grep -E 'Apple Mobile Device \(DFU Mode\)|Apple T2 DFU' >> /dev/null); do
        sleep 1
    done
else
    if ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi

    while ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
fi

echo "[*] Getting device info... this may take a second"
check=$("$oscheck"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$oscheck"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$oscheck"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')

if [ "$1" != 'boot' ] && [ "$1" != 'reset' ]; then
    if echo "$deviceid" | grep -q "iBridge"; then
        ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
    else
        ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
    fi

    if [ -z "$ipswurl" ] || [ "$ipswurl" = "null" ]; then
        echo "[-] Could not find firmware version $1 for device $deviceid"
        echo "[-] For bridgeOS, use the exact version string (e.g. 10.5.1 not 10.5)"
        exit 1
    fi
fi

if [ "$1" != 'boot' ] && [ "$1" != 'reset' ]; then
    if [ "$check" = "0x8012" ]; then
        darwin_major="$(expr $major '+' 15)"
    elif [ "$major" -ge "26" ]; then
        darwin_major="$(expr $major '-' 1)"
    else
        darwin_major="$(expr $major '+' 6)"
    fi
fi

if [ -e work ]; then
    rm -rf work
fi

if [ ! -e sshramdisk ]; then
    mkdir sshramdisk
fi

if [ "$1" = 'reset' ]; then
    if [ ! -e sshramdisk/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    "$oscheck"/gaster pwn > /dev/null
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f sshramdisk/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi

    sleep 2
    "$oscheck"/irecovery -c "setenv oblit-inprogress 5"
    "$oscheck"/irecovery -c saveenv
    "$oscheck"/irecovery -c reset

    echo "[*] Device should now show a progress bar and erase all data"
    exit
fi

if [ "$2" = 'TrollStore' ]; then
    if [ -z "$3" ]; then
        echo "[-] Please pass an uninstallable system app to use (Tips is a great choice)"
        exit
    fi
fi

if [ "$1" = 'boot' ]; then
    if [ ! -e sshramdisk/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    if [ -e sshramdisk/version.txt ]; then
        saved=$(cat sshramdisk/version.txt)
        s_major=$(echo "$saved" | cut -d. -f1)
        s_minor=$(echo "$saved" | cut -d. -f2)
        s_patch=$(echo "$saved" | cut -d. -f3)
        s_major=${s_major:-0}
        s_minor=${s_minor:-0}
        s_patch=${s_patch:-0}
        if [ "$check" = "0x8012" ]; then
            boot_darwin_major="$(expr $s_major '+' 15)"
        elif [ "$s_major" -ge "26" ]; then
            boot_darwin_major="$(expr $s_major '-' 1)"
        else
            boot_darwin_major="$(expr $s_major '+' 6)"
        fi
    else
        echo "[-] sshramdisk/version.txt not found — please re-create the ramdisk before booting"
        exit 1
    fi

    "$oscheck"/gaster pwn > /dev/null
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f sshramdisk/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/logo.img4
    "$oscheck"/irecovery -c "setpicture 0x1"
    "$oscheck"/irecovery -f sshramdisk/ramdisk.img4
    "$oscheck"/irecovery -c ramdisk
    "$oscheck"/irecovery -f sshramdisk/devicetree.img4
    "$oscheck"/irecovery -c devicetree
    if [ "$boot_darwin_major" -ge 17 ] && ! ([ "$boot_darwin_major" -eq 17 ] && ([ "$s_minor" -lt 4 ] || ([ "$s_minor" -eq 4 ] && [ "$s_patch" -le 1 ])) && [ "$check" != '0x8012' ]); then
        "$oscheck"/irecovery -f sshramdisk/trustcache.img4
        "$oscheck"/irecovery -c firmware
    fi
    "$oscheck"/irecovery -f sshramdisk/kernelcache.img4
    "$oscheck"/irecovery -c bootx

    echo "[*] Device should now show text on screen"
    exit
fi

if [ -z "$1" ]; then
    printf "1st argument: iOS/bridgeOS version for the ramdisk\nExtra arguments:\nreset: wipes the device, without losing version.\n"
    exit
fi

if [ ! -e work ]; then
    mkdir work
fi

"$oscheck"/gaster pwn > /dev/null
# A10X / T2 workaround — warms up the exploit state before img4tool
"$oscheck"/gaster decrypt_kbag 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 > /dev/null || true
"$oscheck"/img4tool -e -s other/shsh/"${check}".shsh -m work/IM4M

cd work
../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$darwin_major" -ge 17 ] && ! ([ "$darwin_major" -eq 17 ] && ([ "$minor" -lt 4 ] || ([ "$minor" -eq 4 ] && [ "$patch" -le 1 ])) && [ "$check" != '0x8012' ]); then
        ../"$oscheck"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
    fi
else
    if [ "$darwin_major" -ge 17 ] && ! ([ "$darwin_major" -eq 17 ] && ([ "$minor" -lt 4 ] || ([ "$minor" -eq 4 ] && [ "$patch" -le 1 ])) && [ "$check" != '0x8012' ]); then
        ../"$oscheck"/pzb -g Firmware/"$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache "$ipswurl"
    fi
fi

../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
else
    ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl"
fi

cd ..

if [ "$darwin_major" -ge 24 ]; then
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBSS.dec
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBEC.dec
else
    "$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBSS.dec
    "$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBEC.dec
fi

"$oscheck"/iBoot64Patcher work/iBSS.dec work/iBSS.patched
"$oscheck"/img4 -i work/iBSS.patched -o sshramdisk/iBSS.img4 -M work/IM4M -A -T ibss
"$oscheck"/iBoot64Patcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
"$oscheck"/img4 -i work/iBEC.patched -o sshramdisk/iBEC.img4 -M work/IM4M -A -T ibec

"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
"$oscheck"/KPlooshFinder work/kcache.raw work/kcache.patched
"$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o sshramdisk/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o sshramdisk/devicetree.img4 -M work/IM4M -T rdtr

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$darwin_major" -ge 17 ] && ! ([ "$darwin_major" -eq 17 ] && ([ "$minor" -lt 4 ] || ([ "$minor" -eq 4 ] && [ "$patch" -le 1 ])) && [ "$check" != '0x8012' ]); then
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg
else
    if [ "$darwin_major" -ge 17 ] && ! ([ "$darwin_major" -eq 17 ] && ([ "$minor" -lt 4 ] || ([ "$minor" -eq 4 ] && [ "$patch" -le 1 ])) && [ "$check" != '0x8012' ]); then
        "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg
fi

if [ "$oscheck" = 'Darwin' ]; then
    hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk.dmg -owners off

    if [ "$darwin_major" -gt 22 ] || ([ "$darwin_major" -eq 22 ] && [ "$minor" -ge 1 ]); then
        if [ "$check" = "0x8012" ]; then
            hdiutil create -size 127m -imagekey diskimage-class=CRawDiskImage -format UDZO -fs HFS+ -layout NONE -srcfolder /tmp/SSHRD -copyuid root work/ramdisk1.dmg
        else
            hdiutil create -size 210m -imagekey diskimage-class=CRawDiskImage -format UDZO -fs HFS+ -layout NONE -srcfolder /tmp/SSHRD -copyuid root work/ramdisk1.dmg
        fi
        hdiutil detach -force /tmp/SSHRD
        hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk1.dmg -owners off
    else
        if [ "$check" = "0x8012" ]; then
            hdiutil resize -size 127MB work/ramdisk.dmg
        else
            hdiutil resize -size 210MB work/ramdisk.dmg
        fi
    fi

    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/atvssh.tar.gz -C /tmp/SSHRD/
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/t2ssh.tar.gz -C /tmp/SSHRD/
        echo "[!] T2 ramdisk — device may hang briefly when booting, this is normal."
    else
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/ssh.tar.gz -C /tmp/SSHRD/
    fi

    hdiutil detach -force /tmp/SSHRD

    if [ "$darwin_major" -gt 22 ] || ([ "$darwin_major" -eq 22 ] && [ "$minor" -ge 1 ]); then
        hdiutil resize -sectors min work/ramdisk1.dmg
    else
        hdiutil resize -sectors min work/ramdisk.dmg
    fi
else
    if [ "$check" = "0x8012" ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg grow 133169152 > /dev/null
    else
        "$oscheck"/hfsplus work/ramdisk.dmg grow 210000000 > /dev/null
    fi

    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/atvssh.tar > /dev/null
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/t2ssh.tar > /dev/null
    else
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/ssh.tar > /dev/null
    fi
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$darwin_major" -gt 22 ] || ([ "$darwin_major" -eq 22 ] && [ "$minor" -ge 1 ]); then
        "$oscheck"/img4 -i work/ramdisk1.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
    else
        "$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
    fi
else
    "$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
fi

"$oscheck"/img4 -i other/bootlogo.im4p -o sshramdisk/logo.img4 -M work/IM4M -A -T rlgo
echo ""
echo "[*] Cleaning up work directory"
rm -rf work

echo ""
echo "[*] Finished! Please use ./sshrd.sh boot to boot your device"
echo $1 > sshramdisk/version.txt

} | tee "$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
