# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

## Check for submodule tagging
if { [SubmoduleCheck {ruckus} {1.4.0} ] < 0 } {exit -1}
if { [SubmoduleCheck {surf}   {1.3.7} ] < 0 } {exit -1}

## Check for version 2016.4 of Vivado
if { [VersionCheck 2016.4] < 0 } {exit -1}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/evr"
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/pci"
loadRuckusTcl "$::DIR_PATH/pgp"
