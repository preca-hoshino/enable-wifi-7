#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future

{
    # Wait 10 seconds
    until [[ "$(getprop sys.boot_completed)" == "1" ]]; do
        sleep 10
    done

    cmd wifi force-country-code enabled AU
}&