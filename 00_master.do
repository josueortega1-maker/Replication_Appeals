version 18
clear all
set more off
set seed 20260721
set graphics on

* Set ROOT to the Experiment directory on your machine.
*global ROOT "C:/Users/3055040/Dropbox/Papers/17. Appeals/Experiment"
global ROOT "/Users/claudia/Library/CloudStorage/Dropbox/Appeals/Experiment"

global DATA "$ROOT/Data"
global CODE "$ROOT/Replication/code"
global OUT  "$ROOT/Replication/output"
global DER  "$OUT/data"
global FIG  "$OUT/figures"
global TAB  "$OUT/tables"

capture mkdir "$OUT"
capture mkdir "$DER"
capture mkdir "$FIG"
capture mkdir "$TAB"

confirm file "$DATA/sessions_long.dta"
confirm file "$CODE/01_prepare_data.do"
confirm file "$CODE/02_main_results.do"
confirm file "$CODE/03_appendix_results.do"
confirm file "$CODE/05_full_takeup.do"

do "$CODE/01_prepare_data.do"
do "$CODE/02_main_results.do"
do "$CODE/03_appendix_results.do"
do "$CODE/05_full_takeup.do"

display as result "Finished."
display as result "Main figures saved in: $FIG"
display as result "Full-take-up outputs saved in: $OUT/full_takeup"