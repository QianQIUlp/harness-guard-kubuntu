#!/usr/bin/python3 -I
"""Decode public window icons under the guard; no Claude process or account."""
import os
import runpy
import subprocess
import sys

profile = sys.argv[1] if len(sys.argv) == 2 else 'claude-desktop-guard'
code = '''
import gi, os, sys
from pathlib import Path
gi.require_version('GdkPixbuf', '2.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GdkPixbuf, Gtk
profile = sys.argv[1]
assert Path('/proc/self/attr/current').read_text().strip() == profile + ' (enforce)'
Gtk.init([])
assert {'minimize','maximize','close'} <= set(Gtk.Settings.get_default().get_property('gtk-decoration-layout').split(':')[-1].split(','))
for name in ('close', 'maximize', 'minimize'):
    icon = GdkPixbuf.Pixbuf.new_from_file('/usr/share/icons/Adwaita/symbolic/ui/window-' + name + '-symbolic.svg')
    assert icon.get_width() > 0 and icon.get_height() > 0
helpers = []
for p in Path('/proc').iterdir():
    if not p.name.isdecimal() or p.stat().st_uid != os.getuid(): continue
    try:
        if (p/'comm').read_text().strip() != 'glycin-svg': continue
        parent = int((p/'stat').read_text().rsplit(')', 1)[1].split()[1])
        if parent != os.getpid(): continue
        label = (p/'attr/current').read_text().strip()
        assert label == profile + ' (enforce)', label
        helpers.append(int(p.name))
    except (OSError, ValueError): continue
assert helpers, 'No enforcing SVG helper observed'
print('PASS: all three buttons configured and icons decoded; actual SVG helper inherits enforce')
'''
env = runpy.run_path('/usr/lib/claude-desktop/claude-desktop')['environment'](os.environ)
subprocess.run(['setpriv', '--no-new-privs', '--', 'aa-exec', '-p', profile, '--',
                '/usr/bin/python3', '-I', '-c', code, profile], env=env, check=True, timeout=20)
