# build.tcl -- create the Radiant project and run synth -> map -> par -> bitgen.
# Invoked by scripts/build.sh, which runs it from the build/ directory so that
# every generated file (blink.rdf, impl1/, logs, ...) lands under build/.
# Sources are located by absolute path relative to this script, so the current
# working directory only controls where output goes -- not where inputs are found.

set script_dir [file dirname [file normalize [info script]]]
set root       [file dirname $script_dir]   ;# project root (parent of scripts/)

prj_create -name "blink" -impl "impl1" -dev LIFCL-33U-9CTG104I -synthesis "lse"

prj_add_source "$root/source/blink.v"
prj_add_source "$root/source/blink.pdc"
prj_add_source "$root/source/blink.sdc"

prj_set_impl_opt -impl "impl1" "top" "blink"

# LIFCL-33U in this Radiant needs IP-Evaluation-mode bitstream enabled.
prj_set_strategy_value -strategy Strategy1 bit_ip_eval=True

prj_save
prj_run Synthesis -impl impl1
prj_run Map        -impl impl1
prj_run PAR        -impl impl1
prj_run Export     -impl impl1
prj_save
puts "BUILD-DONE"
