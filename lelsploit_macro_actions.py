"""Declarative macro actions and adapters for the existing application controls.

No Python eval, shell, or dynamically imported commands are accepted by macros.
Script blocks intentionally execute Luau through the app's existing script runner.
"""
from __future__ import annotations

import re
from pathlib import PurePosixPath

# label, control attribute, type, allowed values/range
CONFIG = {
    'enabled': ('FastFlags enabled', 'manager_check', 'bool', None),
    'renderer': ('Rendering mode', 'render_combo', 'enum', ['Default', 'D3D11', 'Vulkan', 'OpenGL']),
    'msaa': ('MSAA', 'msaa_combo', 'enum', ['Default', '1', '2', '4']),
    'texture_quality': ('Texture quality', 'texture_combo', 'enum', ['Default', '0', '1', '2', '3']),
    'display_scaling': ('Disable display scaling', 'scaling_check', 'bool', None),
    'manual_fullscreen': ('Manual fullscreen', 'fullscreen_check', 'bool', None),
    'mesh_quality': ('Mesh quality (0 = default)', 'mesh_slider', 'int', [0, 4]),
    'render_quality': ('Render quality (0 = default)', 'frm_slider', 'int', [0, 21]),
    'grey_sky': ('Grey sky', 'grey_sky_check', 'bool', None),
    'pause_voxelizer': ('Pause voxelizer', 'pause_voxelizer_check', 'bool', None),
    'grass_max': ('Grass maximum distance', 'grass_max', 'int', [0, 10000]),
    'grass_min': ('Grass minimum distance', 'grass_min', 'int', [0, 10000]),
    'grass_motion': ('Grass motion', 'grass_motion', 'int', [0, 10000]),
    'fps_cap': ('Frame rate cap (0 = default)', 'fps_cap', 'int', [0, 1000]),
}

def field(label, kind='text', default='', limit=1024, choices=None):
    return dict(label=label, type=kind, default=default, limit=limit, choices=choices)

SCHEMA = {
    'script_execute': dict(label='Execute script', category='Scripts', description='Run embedded Luau using the app script runner, then wait for its response.', fields={
        'source': field('Luau script', 'script', 'print("Macro started")', 200000)}),
    'fastflags_config': dict(label='Configure FastFlags', category='FastFlags', description='Change a normal FastFlags setting. Some changes require restarting Roblox.', fields={
        'setting': field('Setting', 'enum', 'enabled', choices=list(CONFIG)), 'value': field('Value', 'config', True)}),
    'fastflag_set': dict(label='Set FastFlag', category='FastFlags', description='Add or update a normal or custom FastFlag value.', fields={
        'scope': field('Storage', 'enum', 'custom', choices=['custom', 'normal']),
        'name': field('Flag name', 'flag', 'FFlagExample', 160), 'value': field('Value', 'text', 'True', 4096)}),
    'fastflag_remove': dict(label='Remove FastFlag', category='FastFlags', description='Remove a saved flag from the selected storage.', fields={
        'scope': field('Storage', 'enum', 'custom', choices=['custom', 'normal']), 'name': field('Flag name', 'flag', 'FFlagExample', 160)}),
    'custom_flag_enabled': dict(label='Custom flag enabled', category='FastFlags', description='Enable or disable an existing custom FastFlag.', fields={
        'name': field('Flag name', 'flag', 'FFlagExample', 160), 'enabled': field('Enabled', 'bool', True)}),
    'username_spoofer': dict(label='Username spoofer', category='Username', description='Configure your name or other players’ names using the existing spoofer.', fields={
        'target': field('Players', 'enum', 'your', choices=['your', 'others']),
        'username': field('Display name', 'text', '', 80), 'enabled': field('Apply in game', 'bool', True),
        'verified': field('Verified badge', 'bool', False)}),
    'creator_set': dict(label='Set creator appearance', category='Username', description='Set the existing local game-creator appearance option.', fields={
        'enabled': field('Make creator', 'bool', True)}),
    'asset_set': dict(label='Set asset / font', category='Assets', description='Replace a built-in sound, sky face, texture, mesh, or font.', fields={
        'target': field('Asset', 'asset', 'content/sounds/oof.ogg', 512), 'source': field('File / URL / asset ID', 'source', '', 2048)}),
    'asset_remove': dict(label='Restore asset / font', category='Assets', description='Remove the override and restore the backed-up original.', fields={
        'target': field('Asset', 'asset', 'content/sounds/oof.ogg', 512)}),
    'skybox_set': dict(label='Set all skybox faces', category='Assets', description='Apply one source to the six outdoor skybox faces.', fields={
        'source': field('File / URL / asset ID', 'source', '', 2048)}),
    'skybox_remove': dict(label='Restore all skybox faces', category='Assets', description='Restore the six outdoor skybox faces.', fields={}),
    'custom_set': dict(label='Set custom modification', category='Customs', description='Replace a Roblox resource file under content, PlatformContent, or ExtraContent.', fields={
        'name': field('Display name', 'text', 'Custom resource', 80),
        'target': field('Relative resource path', 'target', 'content/textures/example.png', 512),
        'source': field('File / URL / asset ID', 'source', '', 2048)}),
    'custom_remove': dict(label='Restore custom modification', category='Customs', description='Remove a custom resource override and restore its backup.', fields={
        'target': field('Relative resource path', 'target', 'content/textures/example.png', 512)}),
}
RESOURCE_SUFFIXES = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp', '.dds', '.tex', '.mesh', '.obj', '.mtl', '.rbxm', '.rbxmx', '.mp3', '.ogg', '.wav', '.flac', '.ttf', '.otf', '.json', '.xml', '.material', '.ktx', '.ktx2'}

def resource_target(value, font=False):
    if font and value == '__font__':
        return value
    target = value.replace('\\', '/')
    parts = target.split('/')
    if (len(parts) < 2 or parts[0].lower() not in {'content', 'platformcontent', 'extracontent'}
            or any(not p or p in {'.', '..'} or p.endswith((' ', '.')) or ':' in p
                   or re.search(r'[\x00-\x1f<>"|?*]', p)
                   or re.fullmatch(r'(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?', p, re.I) for p in parts)
            or PurePosixPath(target).suffix.lower() not in RESOURCE_SUFFIXES):
        raise ValueError('Choose a relative Roblox resource path under content, PlatformContent, or ExtraContent.')
    return target


def validate_action(raw):
    op = str(raw.get('op') or '').strip().lower()
    if op not in SCHEMA:
        raise ValueError('Unsupported application action.')
    clean = {'op': op}
    for key, spec in SCHEMA[op]['fields'].items():
        value = raw.get(key, spec['default'])
        kind = spec['type']
        if kind == 'bool':
            if type(value) is not bool:
                raise ValueError(f'{key} must be true or false.')
        elif kind == 'config':
            config = CONFIG[clean['setting']]
            if config[2] == 'bool' and type(value) is not bool:
                raise ValueError('This setting requires true or false.')
            if config[2] == 'int' and (type(value) is not int or not config[3][0] <= value <= config[3][1]):
                raise ValueError(f'This setting must be {config[3][0]}–{config[3][1]}.')
            if config[2] == 'enum' and value not in config[3]:
                raise ValueError('Unsupported setting value.')
        else:
            if not isinstance(value, str) or len(value) > spec['limit'] or '\0' in value:
                raise ValueError(f"{spec['label']} must be text (maximum {spec['limit']} characters).")
            if kind not in {'script', 'text'}:
                value = value.strip()
            if kind == 'enum' and value not in spec['choices']:
                raise ValueError(f'Unsupported {key}.')
            if kind == 'flag' and not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,159}', value):
                raise ValueError('Flag names may contain letters, digits, and underscores.')
            if kind in {'script', 'source'} and not value.strip():
                raise ValueError(f"{spec['label']} is required.")
            if kind in {'target', 'asset'}:
                value = resource_target(value, font=kind == 'asset')
        clean[key] = value
    return clean


def block_definitions():
    return {op: dict(label=s['label'], category=s['category'], description=s['description'],
                     template={'op': op, **{k: f['default'] for k, f in s['fields'].items()}})
            for op, s in SCHEMA.items()}


def asset_choices(host):
    return [(f'{group} — {label}', str(target).replace('\\', '/'))
            for group, entries in host.get('ASSET_TARGETS', {}).items() for label, target in entries.items()] + [('Custom font', '__font__')]


def apply_resource_action(step, host):
    """Run in the macro worker: downloads/file copies must not block Qt."""
    step = validate_action(step)
    op = step['op']
    if op.startswith('skybox_'):
        targets = [(label, str(target).replace('\\', '/'))
                   for label, target in host['ASSET_TARGETS']['Skyboxes'].items() if label.startswith('Sky —')]
    elif op.startswith('asset_'):
        names = {target: label for label, target in asset_choices(host)}
        if step['target'] not in names:
            raise ValueError('This asset is not in the application asset catalog.')
        targets = [(names[step['target']], step['target'])]
    else:
        targets = [(step.get('name') or step['target'], step['target'])]
    for label, target in targets:
        if op.endswith('_remove'):
            host['remove_modification'](target)
        else:
            kind = 'font' if target == '__font__' else ('custom' if op == 'custom_set' else 'asset')
            host['set_modification'](label, target, step['source'], kind)


class HostActions:
    """All methods on this adapter are called on the GUI thread."""
    def __init__(self, owner, host):
        self.owner = owner
        self.host = host
        self.script_pending = False
        self.script_source = None
        self.script_cancel = None

    def window(self):
        from lelsploit_fastflags import FastFlagsWindow
        window = getattr(self.owner, 'fastflags_window', None)
        if window is None:
            window = FastFlagsWindow(self.owner)
            self.owner.fastflags_window = window
        # Commit pending edits before reloading controls from disk.
        window.auto_save_timer.stop()
        window.username_save_timer.stop()
        window.save_changes(quiet=True)
        window.persist_username_spoofer()
        window.reload()
        return window

    def run(self, step):
        owner = self.owner
        op = step['op']
        if op == '_script_status':
            if getattr(owner, '_pending_api_after_restart', None):
                return False
            if getattr(owner, 'busy', False):
                self.script_cancel = getattr(owner, 'api_cancel', None)
                return False
            self.script_pending = False
            if not getattr(owner, '_macro_script_succeeded', False):
                raise RuntimeError('The script runner did not finish successfully. Check the application log.')
            return True
        if op == '_script_cancel':
            if self.script_pending:
                pending = getattr(owner, '_pending_api_after_restart', None)
                if pending and pending == ('execute', self.script_source):
                    owner._pending_api_after_restart = None
                cancel = getattr(owner, 'api_cancel', None)
                if cancel is not None and (cancel is self.script_cancel or getattr(owner, 'api_action', None) == 'execute'):
                    cancel.set()
                self.script_pending = False
            return
        if op == '_resources_changed':
            owner.set_fastflags_restart_required(owner.roblox_running is True)
            window = getattr(owner, 'fastflags_window', None)
            if window is not None and window.isVisible():
                for row in window.asset_rows:
                    row.refresh()
                window.refresh_custom_mods()
            return
        step = validate_action(step)
        if op == 'script_execute':
            owner._macro_script_succeeded = False
            if not owner.execute_source_text(step['source'], label='Macro script'):
                raise RuntimeError('Script execution was not started. Finish the current action or check the application log.')
            self.script_source = step['source']
            self.script_cancel = getattr(owner, 'api_cancel', None)
            self.script_pending = True
            return
        window = self.window()
        if op == 'fastflags_config':
            setting, value = step['setting'], step['value']
            _, attr, kind, _ = CONFIG[setting]
            control = getattr(window, attr)
            if kind == 'bool':
                control.setChecked(value)
            elif kind == 'enum':
                index = control.findData(None if value == 'Default' else value)
                if index < 0:
                    raise ValueError('The selected setting is not supported by this application version.')
                control.setCurrentIndex(index)
            else:
                control.setValue(value)
                if setting in {'mesh_quality', 'render_quality'}:
                    getattr(window, 'mesh_check' if setting == 'mesh_quality' else 'frm_check').setChecked(value > 0)
            window.auto_save_timer.stop()
            window.save_changes(quiet=True)
        elif op in {'fastflag_set', 'fastflag_remove'}:
            custom = step['scope'] == 'custom'
            flags = dict(owner.load_custom_fastflags() if custom else owner.load_fastflags())
            if op == 'fastflag_set':
                flags[step['name']] = step['value']
            else:
                flags.pop(step['name'], None)
            if custom:
                window._persist_custom_flag_mapping(flags)
            else:
                owner.save_fastflags(flags)
                owner.request_fastflag_sync(force=True)
                self.host['prime_windows_fastflag_cache'](owner.load_effective_fastflags())
                owner.refresh_proxy_for_active_session()
                owner.set_fastflags_restart_required(owner.roblox_running is True)
            window.reload()
        elif op == 'custom_flag_enabled':
            if step['name'] not in owner.load_custom_fastflags():
                raise ValueError(f"Custom flag does not exist: {step['name']}")
            window._set_custom_flag_enabled(step['name'], step['enabled'])
            window.reload()
        elif op in {'username_spoofer', 'creator_set'}:
            if op == 'creator_set':
                window.spoof_creator.setChecked(step['enabled'])
            else:
                prefix = 'spoof_yours' if step['target'] == 'your' else 'spoof_others'
                getattr(window, prefix).setText(step['username'])
                getattr(window, prefix + '_apply').setChecked(step['enabled'])
                getattr(window, prefix + '_verified').setChecked(step['verified'])
            window.username_save_timer.stop()
            window.persist_username_spoofer()
