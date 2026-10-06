# Native Desktop confinement. The package binary is diverted to .real;
# its original entry is a root-owned, fail-closed launcher.
# Portions adapted from roddhjav/apparmor.d f9ee26eb2d44db2a0ae0fd546cdd845f1bb86c2a
# Copyright (C) 2024-2026 Alexandre Pujol <alexandre@pujol.io>
# SPDX-License-Identifier: GPL-2.0-only
abi <abi/5.0>,
include <tunables/global>

# Match the same authorized paths during bubblewrap's temporary root setup.
alias /usr/ -> /oldroot/usr/,
alias /usr/ -> /newroot/usr/,
alias /etc/ -> /oldroot/etc/,
alias /etc/ -> /newroot/etc/,
alias /home/qiu/ -> /oldroot/home/qiu/,
alias /home/qiu/ -> /newroot/home/qiu/,
alias /tmp/claude-1000/ -> /oldroot/tmp/claude-1000/,
alias /tmp/claude-1000/ -> /newroot/tmp/claude-1000/,
alias /tmp/claude-desktop-guard-1000/ -> /oldroot/tmp/claude-desktop-guard-1000/,
alias /tmp/claude-desktop-guard-1000/ -> /newroot/tmp/claude-desktop-guard-1000/,
alias /var/cache/fontconfig/ -> /oldroot/var/cache/fontconfig/,
alias /var/cache/fontconfig/ -> /newroot/var/cache/fontconfig/,

@{CLAUDE_NODE} = /home/qiu/.nvm/versions/node/v22.23.2

profile claude-desktop-guard /usr/lib/claude-desktop/claude-desktop.real flags=(attach_disconnected) {
    include <abstractions/base>
    # Avoid nameservice's extra Kerberos/LDAP/credential interfaces.
    include <abstractions/nameservice-strict>
    # Existing upstream Claude rules: public TLS CA store and runtime introspection.
    include <abstractions/ssl_certs>
    /proc/version r,
    /proc/sys/vm/mmap_min_addr r,
    owner /proc/@{pid}/cgroup r,

    include <abstractions/claude-guard-devtools>
    # GTK symbolic icons use Glycin image helpers on this Ubuntu release.
    /usr/libexec/glycin-loaders/2+/glycin-* rix,
    / r,
    /proc/sys/kernel/overflow{u,g}id r,

    # Native installer downloads and verifies versions; the host entry is root-owned.
    owner /home/qiu/.local/share/claude/versions/ rw,
    owner /home/qiu/.local/share/claude/versions/** rwkmix,
    owner /home/qiu/.local/state/claude/{,**} rwk,
    owner /home/qiu/.local/bin/ r,
    /usr/local/libexec/claude-code-guard rix,
    /home/qiu/.local/bin/claude rix,
    owner /home/qiu/.local/bin/claude{,.tmp.*} rw,
    # User-authorized development tree; all descendants inherit this profile.
    owner /home/qiu/src/ r,
    owner /home/qiu/src/** rwkmix,
    # Shared skills stay read-only; helpers execute with inherited confinement.
    owner /home/qiu/.agents/skills/ r,
    owner /home/qiu/.agents/skills/** rmix,

    owner /home/qiu/.claude/ rw,
    owner /home/qiu/.claude/** rwkmix,
    owner /home/qiu/.claude.json{,.*} rwk,
    owner /home/qiu/.claude.json.lock/{,**} rwk,

    /etc/claude-code-guard/gitconfig r,
    /etc/claude-code-guard/npmrc r,
    owner /home/qiu/.cache/claude-code-guard/ rw,
    owner /home/qiu/.cache/claude-code-guard/** rwkmix,
    owner /tmp/claude-1000/ rw,
    owner /tmp/claude-1000/** rwkmix,
    owner /dev/pts/[0-9]* rw,
    /dev/tty rw,
    owner /proc/@{pid}/{attr/current,stat,statm,comm,cmdline} r,

    network inet stream,
    network inet6 stream,
    network inet dgram,
    network inet6 dgram,

    # base includes legacy encrypted-HOME allowances; remove those grants.
    audit deny /home/qiu/.Private{,/**} rwklmx,
    audit deny /home/.ecryptfs/** rwklmx,
    audit deny /home/qiu/.gitconfig rwklmx,
    audit deny /home/qiu/.config/git/** rwklmx,
    audit deny /home/qiu/.npmrc wklmx,
    audit deny /home/qiu/.ssh/** rwklmx,
    audit deny /home/qiu/.aws/** rwklmx,
    audit deny /home/qiu/.azure/** rwklmx,
    audit deny /home/qiu/.config/{gcloud,clash*,Clash*,mihomo*,Mihomo*,clash-verge*,google-chrome,chromium,BraveSoftware,kwalletd}/** rwklmx,
    audit deny /home/qiu/.mozilla/** rwklmx,

    audit deny /run/{docker,containerd}.sock rw,
    audit deny /usr/bin/{sudo,su,pkexec,newgrp,sg} x,
    audit deny capability mac_admin,
    audit deny capability mac_override,



    # Adapted from upstream claude-desktop/common/electron/common/chromium.
    # Allow the trusted local Codex operator to terminate its own probes.
    signal receive peer=chatgpt,
    capability sys_chroot,
    ptrace (read, trace) peer=claude-desktop-guard,
    /usr/lib/claude-desktop/{claude-desktop,claude-desktop.real,chrome_crashpad_handler,chrome-sandbox} rmix,
    /usr/lib/claude-desktop/resources/app.asar.unpacked/**.node mr,
    owner /home/qiu/.config/Claude/ rw,
    owner /home/qiu/.config/Claude/** rwkmix,
    owner /home/qiu/.cache/claude-desktop-guard/ rw,
    owner /home/qiu/.cache/claude-desktop-guard/** rwklmix,
    owner /tmp/claude-desktop-guard-1000/ rw,
    owner /tmp/claude-desktop-guard-1000/** rwkmix,

    # Sound servers own device access; do not grant direct microphone devices.
    /etc/pulse/client.conf r,
    /etc/pulse/client.conf.d/{,*.conf} r,
    /dev/shm/ r,
    owner /dev/shm/pulse-shm-* rwk,
    owner /run/user/1000/pulse/{,native} rw,
    owner /run/user/1000/pipewire-0 rw,
    # Package-provided helpers inherit the same guard.
    /usr/lib/claude-desktop/resources/{cowork-linux-helper,virtiofsd,chrome-native-host} rmix,
    /usr/lib/claude-desktop/resources/app.asar.unpacked/resources/github-mcp/github-mcp-server rmix,
    /usr/lib/claude-desktop/resources/smol-bin.*.img rk,
    /usr/libexec/virtiofsd rix,
    /home/qiu/.config/autostart/ r,
    /home/qiu/.config/autostart/claude-desktop.real.desktop r,
    owner /home/qiu/.config/autostart/{claude-desktop.real.desktop,.claude-desktop.real.desktop.*.tmp} rwk,
    owner /run/user/1000/claude-cowork-vm.sock rw,
    owner /run/user/1000/cowork-vm-*/{,**} rwk,
    /dev/{kvm,vhost-vsock} rw,
    /sys/module/{kvm_*,vhost}/parameters/* r,
    /sys/devices/system/node/{,node[0-9]*/meminfo} r,
    /proc/sys/vm/max_map_count r,
    network vsock stream,

    # Public application associations, not browser data.
    owner /home/qiu/.config/mimeapps.list r,
    owner /home/qiu/.local/share/applications/ r,
    owner /home/qiu/.local/share/applications/{mimeapps.list,mimeinfo.cache,*.desktop} r,

    include <abstractions/fonts>
    include <abstractions/dri-common>
    include <abstractions/dri-enumerate>
    /usr/share/libdrm/amdgpu.ids r,
    /sys/devices/@{pci_bus}/**/{revision,config,class} r,
    /sys/devices/system/cpu/cpu[0-9]*/cpu_capacity r,
    /proc/sys/dev/i915/perf_stream_paranoid r,
    /sys/bus/pci/devices/ r,
    # Kernel device notifications; no CAP_NET_ADMIN or host route changes.
    network netlink raw,
    # Fonts may use the dedicated XDG cache; do not write shared app caches.
    audit deny /home/qiu/.{,cache/}fontconfig/{,**} wkl,
    audit deny /dev/dri/card* rw,
    /etc/glvnd/egl_vendor.d/{,*.json} r,
    owner /run/user/1000/wayland-[0-9]* rw,
    owner /run/user/1000/{mesa,wayland-cursor}-shared-* rw,
    owner /home/qiu/.config/gtk-3.0/{settings.ini,*.css} r,
    owner /proc/@{pid}/task/ r,
    owner /proc/@{pid}/task/@{tid}/{stat,status,comm} rw,
    owner /proc/@{pid}/{fd/,mountinfo,smaps_rollup,oom_adj,oom_score_adj} r,
    # Chromium enumerates its namespace children, some owned by namespace root.
    /proc/ r,
    /proc/version_signature r,
    /proc/uptime r,
    /proc/@{pid}/stat r,
    /sys/devices/system/cpu/{present,kernel_max} r,
    /sys/devices/system/cpu/cpufreq/policy[0-9]*/cpuinfo_max_freq r,
    /proc/sys/fs/inotify/max_user_watches r,
    /proc/sys/kernel/yama/ptrace_scope r,
    owner /proc/@{pid}/{setgroups,gid_map,uid_map} w,
    owner /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/**/memory.* r,
    /sys/fs/cgroup/user.slice/{cpu.max,user-1000.slice/{cpu.max,user@1000.service/cpu.max}} r,
    owner /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/{,*/}cpu.max r,
    /etc/gtk-3.0/settings.ini r,
    /etc/claude-desktop-guard/gtk-schemas/gschemas.compiled r,
    unix bind type=stream addr=@*/bus/busctl/busctl,

    # Session-bus handshake and approved desktop interfaces, no generic calls.
    owner /run/user/1000/bus rw,
    /etc/machine-id r,
    /run/dbus/system_bus_socket rw,
    dbus send bus=session path=/org/freedesktop/DBus
         interface=org.freedesktop.DBus
         member={Hello,AddMatch,RemoveMatch,GetNameOwner,NameHasOwner,ListNames,StartServiceByName}
         peer=(name=org.freedesktop.DBus),
    dbus receive bus=session peer=(name=org.freedesktop.DBus),
    dbus send bus=system path=/org/freedesktop/DBus
         interface=org.freedesktop.DBus
         member={Hello,AddMatch,RemoveMatch,GetNameOwner,NameHasOwner,StartServiceByName}
         peer=(name=org.freedesktop.DBus),
    dbus receive bus=system peer=(name=org.freedesktop.DBus),
    dbus send bus=session path=/org/freedesktop/Notifications
         interface=org.freedesktop.Notifications
         member={Notify,CloseNotification,GetCapabilities,GetServerInformation}
         peer=(name=org.freedesktop.Notifications),
    dbus receive bus=session peer=(name=org.freedesktop.Notifications),
    dbus receive bus=session path=/org/freedesktop/Notifications
         interface=org.freedesktop.Notifications
         member={ActivationToken,ActionInvoked,NotificationClosed}
         peer=(label="{unconfined,plasmashell}"),

    # KDE StatusNotifierItem protocol: registration, icon updates and own menu.
    dbus bind bus=session name=org.{freedesktop,kde}.StatusNotifierItem-*,
    dbus send bus=session path=/org/freedesktop/DBus
         interface=org.freedesktop.DBus member={RequestName,ReleaseName}
         peer=(name=org.freedesktop.DBus),
    dbus send bus=session path=/StatusNotifierWatcher
         interface=org.freedesktop.DBus.Properties member={Get,GetAll}
         peer=(name=org.kde.StatusNotifierWatcher),
    dbus send bus=session path=/StatusNotifierWatcher
         interface=org.kde.StatusNotifierWatcher member=RegisterStatusNotifierItem
         peer=(name=org.kde.StatusNotifierWatcher),
    dbus receive bus=session path=/StatusNotifierWatcher
         interface=org.kde.StatusNotifierWatcher
         member={StatusNotifierHostRegistered,StatusNotifierHostUnregistered}
         peer=(label="{unconfined,plasmashell}"),
    dbus receive bus=session path={/StatusNotifierItem,/org/chromium/DbusMenu}
         interface=org.freedesktop.DBus.Properties member={Get,GetAll}
         peer=(label="{unconfined,plasmashell}"),
    dbus receive bus=session path={/StatusNotifierItem,/org/chromium/DbusMenu}
         interface=org.freedesktop.DBus.Introspectable member=Introspect
         peer=(label="{unconfined,plasmashell}"),
    dbus receive bus=session path=/StatusNotifierItem
         interface=org.{freedesktop,kde}.StatusNotifierItem
         member={Activate,SecondaryActivate,ContextMenu,Scroll,ProvideXdgActivationToken}
         peer=(label="{unconfined,plasmashell}"),
    dbus receive bus=session path=/org/chromium/DbusMenu interface=com.canonical.dbusmenu
         member={GetLayout,GetGroupProperties,GetProperty,AboutToShow,AboutToShowGroup,Event,EventGroup}
         peer=(label="{unconfined,plasmashell}"),
    dbus send bus=session path=/StatusNotifierItem
         interface=org.{freedesktop,kde}.StatusNotifierItem
         member={NewTitle,NewIcon,NewAttentionIcon,NewOverlayIcon,NewToolTip,NewStatus}
         peer=(label="{unconfined,plasmashell}"),
    dbus send bus=session path=/org/chromium/DbusMenu interface=com.canonical.dbusmenu
         member={LayoutUpdated,ItemsPropertiesUpdated} peer=(label="{unconfined,plasmashell}"),

    audit deny dbus send bus=session peer=(name=org.freedesktop.secrets),
    # User accepted shared-wallet readPassword access on 2026-10-06.
    dbus send bus=session path=/modules/kwalletd6
         interface=org.kde.KWallet
         member={isEnabled,wallets,localWallet,networkWallet,open,openAsync,isOpen,hasFolder,hasEntry,entryType,readPassword}
         peer=(name=org.kde.kwalletd6),
    dbus receive bus=session peer=(name=org.kde.kwalletd6),
    # KWallet broadcasts completion with its unique bus name, not the service name.
    dbus receive bus=session path=/modules/kwalletd6
         interface=org.kde.KWallet member={walletAsyncOpened,walletOpened}
         peer=(label=unconfined),
    # Wallet modification and other read interfaces remain denied.
    audit deny dbus send bus=session path=/modules/kwalletd6
         interface=org.kde.KWallet
         member={readEntry,readEntryList,readMap,readMapList,readPasswordList,writeEntry,writeMap,writePassword,removeEntry,removeFolder,renameEntry,changePassword,closeAllWallets}
         peer=(name=org.kde.kwalletd6),
    audit deny dbus send bus=session peer=(name=org.freedesktop.systemd1),

    # Native URI dispatch, not access to the browser's profile or credentials.
    /usr/local/libexec/claude-guard-bin/xdg-open rix,
    owner /run/user/1000/bus rw,
    /etc/machine-id r,
    dbus send bus=session path=/org/freedesktop/DBus
         interface=org.freedesktop.DBus
         member={Hello,AddMatch,RemoveMatch,GetNameOwner,NameHasOwner,StartServiceByName}
         peer=(name=org.freedesktop.DBus),
    dbus receive bus=session peer=(name=org.freedesktop.DBus),
    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.OpenURI member={OpenURI,OpenFile,OpenDirectory}
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.DBus.Properties member={Get,GetAll}
         peer=(label=unconfined),
    dbus receive bus=session path=/org/freedesktop/portal/desktop/request/**
         interface=org.freedesktop.portal.Request member=Response
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop/request/**
         interface=org.freedesktop.portal.Request member=Close
         peer=(label=unconfined),

    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.Settings member={Read,ReadOne,ReadAll}
         peer=(label=unconfined),
    dbus receive bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.Settings member=SettingChanged
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.FileChooser member={OpenFile,SaveFile,SaveFiles}
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.GlobalShortcuts member={CreateSession,BindShortcuts,ListShortcuts}
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.host.portal.Registry member=Register
         peer=(label=unconfined),
    dbus receive bus=session path=/org/freedesktop/portal/desktop
         interface=org.freedesktop.portal.GlobalShortcuts member={Activated,Deactivated,ShortcutsChanged}
         peer=(label=unconfined),
    dbus send bus=session path=/org/freedesktop/portal/desktop/session/**
         interface=org.freedesktop.portal.Session member=Close
         peer=(label=unconfined),
    dbus receive bus=session path=/org/freedesktop/portal/desktop/session/**
         interface=org.freedesktop.portal.Session member=Closed
         peer=(label=unconfined),

    # No unconfined execution or policy-write grants.
    include <abstractions/claude-guard-sandbox>
    mount options in (rw,bind,rbind,silent) /oldroot/home/qiu/{.cache/claude-desktop-guard,.cache/claude-desktop-guard/**,.config/Claude,.config/Claude/**} -> /newroot/{,**},
    mount options in (rw,bind,silent) /home/qiu/.config/Claude/guard-autostart/ -> /home/qiu/.config/autostart/,
    mount options in (rw,bind,rbind,silent) /oldroot/tmp/{claude-desktop-guard-1000,claude-desktop-guard-1000/**} -> /newroot/{,**},
    # Other HOME paths and unrelated sockets remain denied by default.


    /usr/local/libexec/claude-guard-bin/bwrap rix,
}
