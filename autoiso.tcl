#!/usr/bin/env tclsh9.0
package require http
package require platform
set platform $tcl_platform(platform)

array set temp_files {
                      extract_dir EXTRACT
                      bootfile etfsboot.com
}


# parser config
namespace eval Config {
    # jeux/programme supplémentaire a installer/télécharger
    variable extra_bin
    # scripts a lancer après installation
    variable extra_script
    # défini si on est dans la partie  extra_script ou extra_bin  de la config
    variable curr_conf ""

    variable parser


    # ajoute une valeur a extra_bin ou extra_script en fonction de ou on se trouve
    proc add_value {name src {dest ""}  } {
        variable extra_bin
        # scripts a lancer après installation
        variable extra_script
        # défini si on est dans la partie  extra_script ou extra_bin  de la config
        variable curr_conf

        # dans le cas d'un script dest = ordre de lancement sinon c'est le
        # chemin de destination du fichier
        if { $curr_conf == "prog_conf" } {
            set extra_bin($name)  "$src,$dest"
        } elseif { $curr_conf == "script_conf" } {
            set extra_script($name)  "$src,$dest"
        }
    }

    proc prog_conf { body } {
        variable parser
        variable curr_conf
        set curr_conf "prog_conf"

        try {
            interp eval $parser $body
        } finally {
            set curr_conf ""
        }
    }

    proc script_conf { body }  {
        variable parser
        variable curr_conf
        set curr_conf "script_conf"
        try {
            interp eval $parser $body
        } finally {
            set curr_conf ""
        }
    }

}


proc create_parser {} {
    set parser [interp create -safe]
    set ::Config::parser $parser
    interp alias $parser extra_bin {} ::Config::prog_conf
    interp alias $parser extra_script {} ::Config::script_conf

    interp alias $parser __add_config {} ::Config::add_value

    interp eval $parser {
        proc unknown {cmd args} {
            __add_config $cmd  {*}$args
        }
    }

    # on restreint les commandes executable
    # dans le parser
    # (onsaitjamais)
    # TODO: si déployé en ligne ajouter une limite au temps d'execution de interp via interp limit
    # https://tcl.lambda.cx/tcl-built-in-commands/interp.html#interp-limit
    foreach cmd [interp eval $parser {info commands}] {
        if {$cmd ni {
            extra_bin
            extra_script
            unknown
            __add_config
        }} {
            interp hide $parser $cmd
        }
    }
    return $parser
}


proc parse_file {filename} {
    set parser [create_parser]
    set text [read [open $filename r]]
    interp eval $parser $text
}

proc download_file {url dest} {
    if { $::platform == "windows" } {
        exec -ignorestderr curl.exe $url -o $dest
    } else {
        exec -ignorestderr curl $url -o $dest
    }
}

proc pshell {cmd} {
    set cmd "-command $cmd"
    foreach chan {stdin stdout stderr} {
        lassign [chan pipe] rd$chan wr$chan
    }
    if {[catch {
        package require twapi_process
        set cmd [string map [list \" \\\"] $cmd]
        twapi::create_process [auto_execok powershell] -cmdline $cmd -showwindow hidden \
            -inherithandles 1 -stdchannels [list $rdstdin $wrstdout $wrstderr]
    } ret]} {
        return [list -1 "" $ret]
    }
    chan close $wrstdin; chan close $rdstdin; chan close $wrstdout; chan close $wrstderr
    foreach chan [list $rdstdout $rdstderr] {
        chan configure $chan -encoding cp850 -blocking true; # -buffering full?; # -enc?
    }
    set out [read $rdstdout]; set err [read $rdstderr]
    chan close $rdstdout; chan close $rdstderr
    return [list [string compare $err ""] $out $err]
}


proc mount_iso { src { dest ""} } {
    if { $::platform == "windows" } {
        exec 7z.exe x $src -oEXTRACT
    } else {
        return [exec -ignorestderr mount $src $dest]
    }
}


proc copy_to_iso {filelist dest} {
    if { ! [array exist $filelist]} {
        return
    }
    array for {key val} $filelist {
        lassign [ split  $val "," ] src oem_dest
        if { [string range $src 0 3 ] == "http" } {
            download_file $src "$dest/$oem_dest"
        } else {
            file copy $src "$dest/$oem_dest"
        }
    }
}



proc main {} {

    array for {id path} ::temp_files {
        if  [file exists $path]  {
            file delete -force $path
        }
    }


    array set cli_opts {--iso-path 0 --iso-url "https://dl.malwarewatch.org/windows/Windows-XP.iso" --config-path 0  }
    array set cli_opts $::argv
    set iso $cli_opts(--iso-path)
    set config $cli_opts(--config-path)
	
    set dest "/tmp/media"
    if { $config  == 0 } {
        exit "Need at least option --config-path <path_to_config> to work"
    }

    if { $iso == 0 } {
        download_file $cli_opts(--iso-url) windowsxp.iso
        set $iso "windowsxp.iso"
    }


    parse_file $cli_opts(--config-path)

    if { $::platform == "windows" } {
        lassign "EXTRACT" copy dest
        mount_iso $iso $dest

    } else {
        mount_iso $iso $dest
        set copy "iso-modified"

        file copy  $dest $copy
    }
    file mkdir "$copy/\$OEM\$/\$\$/IMAGES"


    copy_to_iso ::Config::extra_bin $copy
    copy_to_iso ::Config::extra_script $copy


    after 1000
    if { $::platform == "windows" } {
      file copy "./winnt.sif" "./$copy/I386/WINNT.SIF"
      file copy "./$copy/\[BOOT\]/Boot-NoEmul.img" "./etfsboot.com"
        exec -ignorestderr oscdimg.exe -lWXPVOL_FR -betfsboot.com -n -m "EXTRACT" "ISO-BDJEUX.iso"
    } else {
            file copy "./winnt.sif" "$copy/i386/WINNT.SIF"
        exec -ignorestderr xorriso   -indev $iso   -outdev ./xp_mod.iso   -map '$copy/\$OEM\$' '\$OEM\$'   -boot_image any replay   -commit
    }
    after 3000
    if { $::platform != "windows" } {
        exec umount $dest

    }

}

main
