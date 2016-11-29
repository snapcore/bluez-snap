#!/bin/bash

if [ $SPREAD_REBOOT -ge 1 ] ; then
	# Give system a moment to settle
	sleep 2

	# For debugging dump all snaps and connected slots/plugs
	snap list
	snap interfaces

	exit 0
fi

echo "Wait for firstboot change to be ready"
while ! snap changes | grep -q "Done"; do
	snap changes || true
	snap change 1 || true
	sleep 1
done

echo "Ensure fundamental snaps are still present"
. $TESTSLIB/snap-names.sh
for name in $gadget_name $kernel_name $core_name; do
	if ! snap list | grep -q $name ; then
		echo "Not all fundamental snaps are available, all-snap image not valid"
		echo "Currently installed snaps:"
		snap list
		exit 1
	fi
done

echo "Kernel has a store revision"
snap list | grep ^${kernel_name} | grep -E " [0-9]+\s+canonical"

if [ -n "$SNAP_CHANNEL" ] ; then
	# Don't reinstall if we have it installed already
	if ! snap list | grep bluez ; then
		snap install --$SNAP_CHANNEL bluez
	fi
else
	# Install prebuilt bluez snap but first install from the store
	# to work around the fact that we are not allowed anymore to
	# connect bluez slot to a snap installed with --dangerous
	snap install bluez
	snap install --dangerous /home/bluez/bluez_*_amd64.snap
	# As we have a snap which we build locally its unasserted and therefor
	# we don't have any snap-declarations in place and need to manually
	# connect all plugs.
	snap connect bluez:client bluez:service
fi

# Snapshot of the current snapd state for a later restore
if [ ! -f $SPREAD_PATH/snapd-state.tar.gz ] ; then
	systemctl stop snapd.service snapd.socket
	tar czf $SPREAD_PATH/snapd-state.tar.gz /var/lib/snapd
	systemctl start snapd.socket
fi
