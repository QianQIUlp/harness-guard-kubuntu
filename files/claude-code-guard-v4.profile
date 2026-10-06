# Locally verified incremental policy. See docs/VALIDATION.md in harness-guard-kubuntu.
# Incremental successor to /tmp/claude-code-guard-v3.profile.
# Cross-checked with roddhjav/apparmor.d profiles-a-f/claude at
# f9ee26eb2d44db2a0ae0fd546cdd845f1bb86c2a; retain the tested ix boundary.
# Upstream gh config, broad /tmp, and devrun PUx permissions are intentionally excluded.
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

profile claude-code-guard /home/qiu/.local/share/claude/versions/* flags=(attach_disconnected) {
    include <abstractions/base>
    # Avoid nameservice's extra Kerberos/LDAP/credential interfaces.
    include <abstractions/nameservice-strict>
    # Existing upstream Claude rules: public TLS CA store and runtime introspection.
    include <abstractions/ssl_certs>
    /proc/version r,
    /proc/sys/vm/mmap_min_addr r,
    owner /proc/@{pid}/cgroup r,

    include <abstractions/claude-guard-devtools>

    # Native installer downloads and verifies versions; the host entry is root-owned.
    owner /home/qiu/.local/share/claude/versions/ rw,
    owner /home/qiu/.local/share/claude/versions/** rwkmix,
    owner /home/qiu/.local/state/claude/{,**} rwk,
    owner /home/qiu/.local/bin/ r,
    /usr/local/libexec/claude-code-guard rix,
    /home/qiu/.local/bin/claude rix,
    # Native activation is writable in the private bin view. The root host file
    # is immutable, including against replacement by a user-owned rename source.
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
    owner /proc/@{pid}/{attr/current,stat,statm,comm} r,

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

    # Other session services, including KWallet, remain denied by default.
    include <abstractions/claude-guard-sandbox>
    # Other HOME paths and unrelated sockets remain denied by default.

    /usr/local/libexec/claude-guard-bin/bwrap rix,
}
