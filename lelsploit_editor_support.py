"""Offline editor data and Unicode-safe search/document helpers."""
import re
from difflib import SequenceMatcher
from html import unescape


def find_spans(source, query, case_sensitive=False, whole_word=False):
    if not query:
        return []
    pattern = re.escape(query)
    if whole_word:
        pattern = r'(?<!\w)' + pattern + r'(?!\w)'
    return [(m.start(), m.end()) for m in re.finditer(pattern, source, 0 if case_sensitive else re.IGNORECASE)]


def encoded_spans(source, spans, encoding='utf-8'):
    """Translate Python character offsets to Scintilla bytes / Qt UTF-16 units."""
    wanted = {p for span in spans for p in span}
    offsets, position = {}, 0
    unit = 2 if encoding == 'utf-16-le' else 1
    for index, char in enumerate(source):
        if index in wanted:
            offsets[index] = position
        position += len(char.encode(encoding)) // unit
    offsets[len(source)] = position
    return [(offsets[a], offsets[b]) for a, b in spans]


NONCODE_PATTERN = re.compile(
    r'--\[(=*)\[[\s\S]*?(?:\]\1\]|\Z)|--[^\n]*|'
    r'\[(=*)\[[\s\S]*?(?:\]\2\]|\Z)|'
    r'"(?:\\[\s\S]|[^"\\\n])*(?:"|(?=\n)|\Z)|'
    r"'(?:\\[\s\S]|[^'\\\n])*(?:'|(?=\n)|\Z)|"
    r'`(?:\\[\s\S]|[^`\\])*(?:`|\Z)'
)


def masked_code_bytes(source):
    # Mask bytes, retaining exact Scintilla positions even around non-ASCII text.
    data = bytearray(source.encode('utf-8'))
    spans = encoded_spans(source, [(m.start(), m.end()) for m in NONCODE_PATTERN.finditer(source)])
    for a, b in spans:
        data[a:b] = bytes(10 if c == 10 else 32 for c in data[a:b])
    return bytes(data)


def rank_entries(entries, prefix, limit=300):
    """Prefer local symbols and prefix matches, then camel-case / substring hits."""
    folded = prefix.casefold()
    unique = {}
    priorities = {'local_variable': 0, 'local_function': 0, 'variable': 1,
                  'function': 1, 'method': 1, 'property': 2, 'event': 2,
                  'snippet': 2, 'keyword': 3, 'module': 3, 'type': 3}
    for name, kind in entries:
        name = str(name)
        lower = name.casefold()
        capitals = ''.join(a or b for a, b in re.findall(r'(?:^|_)([A-Za-z])|([A-Z])', name)).casefold()
        score = 0 if lower.startswith(folded) else 1 if folded and capitals.startswith(folded) else 2 if len(folded) >= 2 and folded in lower else 9
        if score == 9 and len(folded) >= 3 and abs(len(lower)-len(folded)) <= max(2,len(folded)//3):
            similarity = SequenceMatcher(None, lower, folded).ratio()
            if similarity >= (0.72 if len(folded) >= 5 else 0.78):
                score = 3 + (1-similarity)
        if score == 9:
            continue
        value = (score, priorities.get(kind, 4), not name.startswith(prefix), len(name), lower)
        if name not in unique or value < unique[name][0]:
            unique[name] = (value, kind)
    return [(name, kind) for name, (_, kind) in sorted(unique.items(), key=lambda item: item[1][0])[:limit]]


# Useful offline members; the existing API-dump loader extends these when available.
OFFLINE_CLASSES = {
    'Instance': ('', {'Archivable':'boolean', 'Changed':'RBXScriptSignal', 'DescendantAdded':'RBXScriptSignal', 'DescendantRemoving':'RBXScriptSignal', 'Destroying':'RBXScriptSignal', 'GetPropertyChangedSignal':'RBXScriptSignal', 'GetAttributeChangedSignal':'RBXScriptSignal', 'GetFullName':'string', 'IsDescendantOf':'boolean', 'IsAncestorOf':'boolean', 'ClearAllChildren':'nil', 'GetDebugId':'string'}),
    'Model': ('Instance', {'PrimaryPart':'BasePart', 'WorldPivot':'CFrame', 'PivotTo':'nil', 'GetPivot':'CFrame', 'GetBoundingBox':'CFrame', 'GetExtentsSize':'Vector3', 'MoveTo':'nil', 'ScaleTo':'nil', 'GetScale':'number', 'Humanoid':'Humanoid', 'HumanoidRootPart':'Part'}),
    'BasePart': ('Instance', {'Position':'Vector3', 'CFrame':'CFrame', 'Size':'Vector3', 'Color':'Color3', 'BrickColor':'BrickColor', 'Material':'Enum.Material', 'Transparency':'number', 'Anchored':'boolean', 'CanCollide':'boolean', 'CanTouch':'boolean', 'CanQuery':'boolean', 'CastShadow':'boolean', 'AssemblyLinearVelocity':'Vector3', 'AssemblyAngularVelocity':'Vector3', 'Touched':'RBXScriptSignal', 'TouchEnded':'RBXScriptSignal', 'ApplyImpulse':'nil', 'ApplyAngularImpulse':'nil', 'GetTouchingParts':'table', 'GetConnectedParts':'table', 'GetMass':'number', 'SetNetworkOwner':'nil'}),
    'Part': ('BasePart', {'Shape':'Enum.PartType'}),
    'MeshPart': ('BasePart', {'MeshId':'string', 'TextureID':'string'}),
    'Humanoid': ('Instance', {'Health':'number', 'MaxHealth':'number', 'WalkSpeed':'number', 'JumpPower':'number', 'JumpHeight':'number', 'UseJumpPower':'boolean', 'MoveDirection':'Vector3', 'RootPart':'BasePart', 'FloorMaterial':'Enum.Material', 'Sit':'boolean', 'Jump':'boolean', 'AutoRotate':'boolean', 'Died':'RBXScriptSignal', 'HealthChanged':'RBXScriptSignal', 'StateChanged':'RBXScriptSignal', 'MoveToFinished':'RBXScriptSignal', 'MoveTo':'nil', 'Move':'nil', 'TakeDamage':'nil', 'GetState':'Enum.HumanoidStateType', 'ChangeState':'nil', 'GetPlayingAnimationTracks':'table', 'LoadAnimation':'AnimationTrack'}),
    'Player': ('Instance', {'PlayerGui':'PlayerGui', 'Backpack':'Backpack', 'Team':'Team', 'TeamColor':'BrickColor', 'AccountAge':'number', 'CharacterRemoving':'RBXScriptSignal', 'Chatted':'RBXScriptSignal', 'GetMouse':'Mouse', 'IsInGroup':'boolean', 'GetRankInGroup':'number', 'GetRoleInGroup':'string', 'WaitForChild':'Instance'}),
    'Camera': ('Instance', {'CFrame':'CFrame', 'Focus':'CFrame', 'FieldOfView':'number', 'ViewportSize':'Vector2', 'CameraType':'Enum.CameraType', 'CameraSubject':'Instance', 'WorldToViewportPoint':'Vector3', 'WorldToScreenPoint':'Vector3', 'ViewportPointToRay':'Ray', 'ScreenPointToRay':'Ray'}),
    'RunService': ('Instance', {'Heartbeat':'RBXScriptSignal', 'RenderStepped':'RBXScriptSignal', 'Stepped':'RBXScriptSignal', 'PreRender':'RBXScriptSignal', 'PreSimulation':'RBXScriptSignal', 'PostSimulation':'RBXScriptSignal', 'BindToRenderStep':'nil', 'UnbindFromRenderStep':'nil', 'IsClient':'boolean', 'IsServer':'boolean', 'IsStudio':'boolean', 'IsRunning':'boolean'}),
    'UserInputService': ('Instance', {'InputBegan':'RBXScriptSignal', 'InputChanged':'RBXScriptSignal', 'InputEnded':'RBXScriptSignal', 'JumpRequest':'RBXScriptSignal', 'TouchEnabled':'boolean', 'KeyboardEnabled':'boolean', 'MouseEnabled':'boolean', 'MouseBehavior':'Enum.MouseBehavior', 'MouseIconEnabled':'boolean', 'GetMouseLocation':'Vector2', 'IsKeyDown':'boolean', 'IsMouseButtonPressed':'boolean', 'GetFocusedTextBox':'TextBox', 'GetKeysPressed':'table'}),
    'TweenService': ('Instance', {'Create':'Tween', 'GetValue':'number'}),
    'Tween': ('Instance', {'Play':'nil', 'Pause':'nil', 'Cancel':'nil', 'Completed':'RBXScriptSignal', 'PlaybackState':'Enum.PlaybackState'}),
    'HttpService': ('Instance', {'JSONEncode':'string', 'JSONDecode':'table', 'GenerateGUID':'string', 'UrlEncode':'string', 'GetAsync':'string', 'PostAsync':'string', 'RequestAsync':'table'}),
    'CollectionService': ('Instance', {'GetTagged':'table', 'HasTag':'boolean', 'AddTag':'nil', 'RemoveTag':'nil', 'GetTags':'table', 'GetInstanceAddedSignal':'RBXScriptSignal', 'GetInstanceRemovedSignal':'RBXScriptSignal'}),
    'Debris': ('Instance', {'AddItem':'nil', 'MaxItems':'number'}),
    'GuiObject': ('Instance', {'Position':'UDim2', 'Size':'UDim2', 'AnchorPoint':'Vector2', 'AbsolutePosition':'Vector2', 'AbsoluteSize':'Vector2', 'BackgroundColor3':'Color3', 'BackgroundTransparency':'number', 'BorderSizePixel':'number', 'Visible':'boolean', 'Rotation':'number', 'ZIndex':'number', 'LayoutOrder':'number', 'MouseEnter':'RBXScriptSignal', 'MouseLeave':'RBXScriptSignal', 'InputBegan':'RBXScriptSignal', 'InputEnded':'RBXScriptSignal'}),
    'Frame': ('GuiObject', {}), 'ScrollingFrame': ('GuiObject', {'CanvasSize':'UDim2', 'CanvasPosition':'Vector2', 'ScrollBarThickness':'number', 'AutomaticCanvasSize':'Enum.AutomaticSize'}),
    'TextLabel': ('GuiObject', {'Text':'string', 'TextColor3':'Color3', 'TextSize':'number', 'TextScaled':'boolean', 'TextWrapped':'boolean', 'RichText':'boolean', 'Font':'Enum.Font', 'TextTransparency':'number'}),
    'TextButton': ('TextLabel', {'Activated':'RBXScriptSignal', 'MouseButton1Click':'RBXScriptSignal', 'MouseButton2Click':'RBXScriptSignal', 'AutoButtonColor':'boolean'}),
    'TextBox': ('TextLabel', {'FocusLost':'RBXScriptSignal', 'Focused':'RBXScriptSignal', 'PlaceholderText':'string', 'ClearTextOnFocus':'boolean', 'CaptureFocus':'nil', 'ReleaseFocus':'nil', 'IsFocused':'boolean'}),
    'ScreenGui': ('Instance', {'Enabled':'boolean', 'ResetOnSpawn':'boolean', 'IgnoreGuiInset':'boolean', 'DisplayOrder':'number'}),
    'RBXScriptSignal': ('', {'Connect':'RBXScriptConnection', 'ConnectParallel':'RBXScriptConnection', 'Once':'RBXScriptConnection', 'Wait':'any'}),
    'RBXScriptConnection': ('', {'Connected':'boolean', 'Disconnect':'nil'}),
    'RemoteEvent': ('Instance', {'FireServer':'nil', 'FireClient':'nil', 'FireAllClients':'nil', 'OnClientEvent':'RBXScriptSignal', 'OnServerEvent':'RBXScriptSignal'}),
    'RemoteFunction': ('Instance', {'InvokeServer':'any', 'InvokeClient':'any', 'OnClientInvoke':'function', 'OnServerInvoke':'function'}),
    'BindableEvent': ('Instance', {'Fire':'nil', 'Event':'RBXScriptSignal'}),
    'BindableFunction': ('Instance', {'Invoke':'any', 'OnInvoke':'function'}),
    'Sound': ('Instance', {'SoundId':'string', 'Volume':'number', 'PlaybackSpeed':'number', 'TimePosition':'number', 'TimeLength':'number', 'Looped':'boolean', 'IsPlaying':'boolean', 'Play':'nil', 'Pause':'nil', 'Resume':'nil', 'Stop':'nil', 'Ended':'RBXScriptSignal', 'Loaded':'RBXScriptSignal'}),
    'Lighting': ('Instance', {'ClockTime':'number', 'Brightness':'number', 'Ambient':'Color3', 'OutdoorAmbient':'Color3', 'FogEnd':'number', 'FogStart':'number', 'FogColor':'Color3'}),
}
METHODS = set('GetPropertyChangedSignal GetAttributeChangedSignal GetFullName IsDescendantOf IsAncestorOf ClearAllChildren GetDebugId PivotTo GetPivot GetBoundingBox GetExtentsSize MoveTo ScaleTo GetScale ApplyImpulse ApplyAngularImpulse GetTouchingParts GetConnectedParts GetMass SetNetworkOwner Move TakeDamage GetState ChangeState GetPlayingAnimationTracks LoadAnimation GetMouse IsInGroup GetRankInGroup GetRoleInGroup WorldToViewportPoint WorldToScreenPoint ViewportPointToRay ScreenPointToRay BindToRenderStep UnbindFromRenderStep IsClient IsServer IsStudio IsRunning GetMouseLocation IsKeyDown IsMouseButtonPressed GetFocusedTextBox GetKeysPressed Create GetValue Play Pause Cancel JSONEncode JSONDecode GenerateGUID UrlEncode GetAsync PostAsync RequestAsync GetTagged HasTag AddTag RemoveTag GetTags GetInstanceAddedSignal GetInstanceRemovedSignal AddItem CaptureFocus ReleaseFocus IsFocused Connect ConnectParallel Once Wait Disconnect FireServer FireClient FireAllClients InvokeServer InvokeClient Fire Invoke Resume Stop WaitForChild'.split())
OFFLINE_ENUMS = {
    'KeyCode': 'Unknown Backspace Tab Return Escape Space LeftShift RightShift LeftControl RightControl LeftAlt RightAlt Up Down Left Right Zero One Two Three Four Five Six Seven Eight Nine ' + ' '.join('ABCDEFGHIJKLMNOPQRSTUVWXYZ') + ' ' + ' '.join('F'+str(i) for i in range(1,13)),
    'UserInputType': 'MouseButton1 MouseButton2 MouseButton3 MouseMovement MouseWheel Keyboard Touch Gamepad1',
    'UserInputState': 'Begin Change End Cancel None',
    'Material': 'Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble Cobblestone Metal CorrodedMetal DiamondPlate Foil Grass LeafyGrass Sand Fabric Snow Ice Glass ForceField Air Water',
    'EasingStyle': 'Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic',
    'EasingDirection': 'In Out InOut', 'RaycastFilterType': 'Exclude Include',
    'CameraType': 'Fixed Attach Watch Track Follow Custom Scriptable Orbital',
    'HumanoidStateType': 'Running Jumping Freefall Landed Swimming Climbing Seated Dead GettingUp Physics',
    'Font': 'Arial ArialBold SourceSans SourceSansBold SourceSansItalic Code Gotham GothamBold',
    'AutomaticSize': 'None X Y XY', 'PlaybackState': 'Begin Delayed Playing Paused Completed Cancelled',
    'SortOrder': 'Name Custom LayoutOrder', 'FillDirection': 'Horizontal Vertical',
    'HorizontalAlignment': 'Center Left Right', 'VerticalAlignment': 'Center Top Bottom',
    'TextXAlignment': 'Left Center Right', 'TextYAlignment': 'Top Center Bottom',
    'PartType': 'Ball Block Cylinder', 'MouseBehavior': 'Default LockCenter LockCurrentPosition',
}


def extend_api_index(index):
    for name, (base, members) in OFFLINE_CLASSES.items():
        index.class_names.add(name)
        if base:
            index.superclasses.setdefault(name, base)
        target = index.classes.setdefault(name, {})
        for member, typ in members.items():
            kind = 'Event' if typ == 'RBXScriptSignal' and member not in METHODS else 'Function' if member in METHODS else 'Property'
            target.setdefault(member, {'kind':kind, 'type':typ, 'signature':f'{member}(...) -> {typ}' if kind == 'Function' else f'{member}: {typ}'})
    for service in index.services:
        index.class_names.add(service)
        index.classes.setdefault(service, {})
        index.superclasses.setdefault(service, 'Instance')
    for name, items in OFFLINE_ENUMS.items():
        index.enums.setdefault(name, items.split())
        index.enum_names.add(name)
    index.creatable.update(set(OFFLINE_CLASSES) - index.services - ABSTRACT_CLASSES)
    index.member_names.update(member for members in index.classes.values() for member in members)


SNIPPETS = {
    'if_block': 'if condition then\n    \nend',
    'if_else': 'if condition then\n    \nelse\n    \nend',
    'for_pairs': 'for key, value in pairs(items) do\n    \nend',
    'for_ipairs': 'for index, value in ipairs(items) do\n    \nend',
    'for_range': 'for index = 1, 10 do\n    \nend',
    'while_loop': 'while condition do\n    task.wait()\nend',
    'repeat_loop': 'repeat\n    task.wait()\nuntil condition',
    'local_function': 'local function name()\n    \nend',
    'function_block': 'function name()\n    \nend',
    'connect_event': 'signal:Connect(function()\n    \nend)',
    'protected_call': 'local success, result = pcall(function()\n    \nend)\nif not success then\n    warn(result)\nend',
    'get_service': 'local Players = game:GetService("Players")',
    'task_spawn': 'task.spawn(function()\n    \nend)',
    'task_delay': 'task.delay(1, function()\n    \nend)',
    'type_alias': 'type Name = {\n    value: string,\n}',
}


def document_sections(markup):
    """Add Qt-compatible named anchors and extract searchable heading sections."""
    sections, parts, last = [], [], 0
    headings = list(re.finditer(r'<h([1-3])\b([^>]*)>([\s\S]*?)</h\1>', markup, re.I))
    def plain(value):
        value = re.sub(r'<style\b[^>]*>[\s\S]*?</style>', '', value, flags=re.I)
        return ' '.join(unescape(re.sub(r'<[^>]*>', ' ', value)).split())
    for i, heading in enumerate(headings):
        anchor = f'doc-section-{i}'
        legacy = re.search(r'\bid=["\']([^"\']+)', heading.group(2))
        parts.append(markup[last:heading.start()])
        parts.append(f'<a name="{anchor}"></a>' + (f'<a name="{legacy.group(1)}"></a>' if legacy else '') + heading.group())
        last = heading.end()
        end = headings[i+1].start() if i+1 < len(headings) else len(markup)
        sections.append({'title':plain(heading.group(3)), 'anchor':anchor,
                         'text':plain(markup[heading.start():end]), 'level':int(heading.group(1))})
    parts.append(markup[last:])
    return ''.join(parts), sections

EXTRA_LIBRARY_MEMBERS = {
    'os': {'clock':'clock(): number', 'time':'time(date: table?): number', 'date':'date(format: string?, time: number?): string | table', 'difftime':'difftime(t2: number, t1: number): number'},
    'debug': {'info':'info(functionOrLevel: function | number, options: string): ...any', 'traceback':'traceback(message: string?, level: number?): string', 'profilebegin':'profilebegin(label: string): ()', 'profileend':'profileend(): ()'},
    'Vector2': {'X':'X: number', 'Y':'Y: number', 'Magnitude':'Magnitude: number', 'Unit':'Unit: Vector2', 'Dot':'Dot(other: Vector2): number', 'Cross':'Cross(other: Vector2): number', 'Lerp':'Lerp(goal: Vector2, alpha: number): Vector2', 'Min':'Min(...Vector2): Vector2', 'Max':'Max(...Vector2): Vector2'},
    'Vector3': {'X':'X: number', 'Y':'Y: number', 'Z':'Z: number', 'Magnitude':'Magnitude: number', 'Unit':'Unit: Vector3', 'Dot':'Dot(other: Vector3): number', 'Cross':'Cross(other: Vector3): Vector3', 'Lerp':'Lerp(goal: Vector3, alpha: number): Vector3', 'FuzzyEq':'FuzzyEq(other: Vector3, epsilon: number): boolean'},
    'CFrame': {'Position':'Position: Vector3', 'Rotation':'Rotation: CFrame', 'LookVector':'LookVector: Vector3', 'RightVector':'RightVector: Vector3', 'UpVector':'UpVector: Vector3', 'X':'X: number', 'Y':'Y: number', 'Z':'Z: number', 'Lerp':'Lerp(goal: CFrame, alpha: number): CFrame', 'Inverse':'Inverse(): CFrame', 'ToWorldSpace':'ToWorldSpace(cf: CFrame): CFrame', 'ToObjectSpace':'ToObjectSpace(cf: CFrame): CFrame', 'PointToWorldSpace':'PointToWorldSpace(point: Vector3): Vector3', 'PointToObjectSpace':'PointToObjectSpace(point: Vector3): Vector3', 'ToOrientation':'ToOrientation(): (number, number, number)', 'ToEulerAnglesXYZ':'ToEulerAnglesXYZ(): (number, number, number)'},
    'Color3': {'R':'R: number', 'G':'G: number', 'B':'B: number', 'Lerp':'Lerp(goal: Color3, alpha: number): Color3', 'ToHSV':'ToHSV(): (number, number, number)', 'ToHex':'ToHex(): string'},
    'Random': {'new':'new(seed: number?): Random', 'NextInteger':'NextInteger(min: number, max: number): number', 'NextNumber':'NextNumber(min: number?, max: number?): number', 'NextUnitVector':'NextUnitVector(): Vector3', 'Shuffle':'Shuffle(array: table): ()', 'Clone':'Clone(): Random'},
    'TweenInfo': {'new':'new(time: number?, easingStyle: Enum.EasingStyle?, easingDirection: Enum.EasingDirection?, repeatCount: number?, reverses: boolean?, delayTime: number?): TweenInfo'},
    'RaycastParams': {'new':'new(): RaycastParams', 'FilterDescendantsInstances':'FilterDescendantsInstances: {Instance}', 'FilterType':'FilterType: Enum.RaycastFilterType', 'IgnoreWater':'IgnoreWater: boolean', 'CollisionGroup':'CollisionGroup: string', 'RespectCanCollide':'RespectCanCollide: boolean'},
    'OverlapParams': {'new':'new(): OverlapParams', 'FilterDescendantsInstances':'FilterDescendantsInstances: {Instance}', 'FilterType':'FilterType: Enum.RaycastFilterType', 'MaxParts':'MaxParts: number', 'CollisionGroup':'CollisionGroup: string'},
    'DateTime': {'now':'now(): DateTime', 'fromUnixTimestamp':'fromUnixTimestamp(unixTimestamp: number): DateTime', 'fromIsoDate':'fromIsoDate(isoDate: string): DateTime?', 'UnixTimestamp':'UnixTimestamp: number', 'UnixTimestampMillis':'UnixTimestampMillis: number', 'ToIsoDate':'ToIsoDate(): string', 'FormatLocalTime':'FormatLocalTime(format: string, locale: string): string'},
    'BrickColor': {'new':'new(color: string | number | Color3): BrickColor', 'Random':'Random(): BrickColor', 'Color':'Color: Color3', 'Name':'Name: string', 'Number':'Number: number'},
}

EXTENSION_START_GUIDE = '''
<h1>Extensions: start here</h1>
<p>An extension adds commands, interface controls, or small workflows to LelSploit. Use this guide first; the detailed operation reference follows below. Search the sidebar for an operation name to jump directly to it.</p>
<h2>Install or import an extension</h2>
<ol><li>Open Extensions from the main toolbar.</li><li>Use Marketplace to browse packages, or Import Extension to select a local <code>.lext</code> package.</li><li>Read its description and requested permissions before installing.</li><li>Return to Installed to manage the package. Use its available enable/disable controls if you want to stop its behavior.</li></ol>
<h2>Create a first extension from a template</h2>
<ol><li>Open Extensions, then Templates.</li><li>Choose a template close to the behavior you want.</li><li>Inspect its manifest and actions. A manifest describes the package; each action contains a list of steps.</li><li>Change one thing, reload the extension, and test that action before adding more steps.</li></ol>
<p>A <code>.lext</code> file is a ZIP package containing <code>manifest.json</code> and optional assets. Templates provide a starting structure so you do not need to write the whole manifest from memory.</p>
<h2>Read the reference without getting lost</h2>
<table><tr><th>Term</th><th>Plain meaning</th></tr><tr><td>Manifest</td><td>The package's name, identity, permissions, and available actions.</td></tr><tr><td>Permission</td><td>A capability the extension needs, such as interacting with the editor or making network requests.</td></tr><tr><td>Action</td><td>A named sequence you can run.</td></tr><tr><td>Step / op</td><td>One operation within that sequence, such as reading editor text.</td></tr><tr><td>save_as</td><td>The name used to store an operation's result for another step.</td></tr><tr><td>Validation</td><td>The conditions checked before an operation can run; the message explains what to correct.</td></tr></table>
<p><b>Workflow:</b> search for a task → choose an operation → check its permission → fill required fields → test the action. The reference lists defaults and validation messages under each operation.</p>
<h2>Troubleshoot an extension</h2>
<ul><li><b>Package will not load:</b> confirm manifest.json is present and valid JSON, and check the format/API requirement in the error.</li><li><b>Action is missing:</b> verify its id matches the toolbar, menu, shortcut, or startup reference that invokes it.</li><li><b>Permission error:</b> compare the operation's required permission with the manifest permissions list.</li><li><b>No visible result:</b> check that the extension is enabled and that its action is actually invoked. Add or inspect a log step while testing.</li></ul>
<h2>Detailed extension reference</h2>
'''

MACRO_START_GUIDE = '''
<h1>Macros: quick guide</h1>
<p>A macro runs a saved sequence of actions. Use the block builder to create it, then read the detailed reference below when you need a specific block or file field.</p>
<h2>Build and test a short sequence</h2>
<ol><li>Open Macros → Installed → New Macro.</li><li>Add a Wait block from Timing and set its delay in Properties.</li><li>Add one keyboard or mouse block and choose its values in Properties.</li><li>Use Run to test. Input actions have a focus delay; activate the intended window.</li><li>Use Stop or the configured stop key (F8 by default) to stop the macro.</li><li>Use Save to keep a file, or Install to make it available under Installed.</li></ol>
<h2>Choose the right block</h2>
<table><tr><th>I want to…</th><th>Use</th></tr><tr><td>Pause before the next action</td><td>Timing → Wait.</td></tr><tr><td>Press and release a key once</td><td>Keyboard → Tap key.</td></tr><tr><td>Hold a key across several steps</td><td>Key down, later followed by Key up.</td></tr><tr><td>Click, move, or scroll</td><td>A block from Mouse.</td></tr><tr><td>Repeat a set number of times</td><td>Control → Repeat; put the repeated steps inside it.</td></tr><tr><td>Keep running until stopped</td><td>Control → Forever; add a Wait inside a rapid loop.</td></tr></table>
<h2>Fix common macro problems</h2>
<ul><li><b>Input goes to the wrong place:</b> activate the intended window after pressing Run.</li><li><b>Actions happen too quickly:</b> add Wait blocks between steps.</li><li><b>A key stays held:</b> check that Key down has a matching Key up.</li><li><b>It keeps looping:</b> use Stop or the stop key, then inspect Repeat/Forever nesting.</li><li><b>Changes are missing next time:</b> Save the file or Apply the updated installed macro.</li></ul>
<h2>Detailed macro reference</h2>
'''


def completion_argument_context(before):
    """Recognize the first argument of common APIs, including an empty () slot.

    Return a token start so insertion can add missing quotes without duplicating
    quotes or parentheses already supplied by the editor.
    """
    pattern = r'(?P<name>[A-Za-z_]\w*)\s*\(\s*(?P<quote>[\'\"]?)(?P<prefix>[A-Za-z0-9_]*)$'
    match = re.search(pattern, before)
    if not match:
        return None
    name = match.group('name')
    canonical = {
        'getservice':('GetService','service'), 'findservice':('FindService','service'),
        'isa':('IsA','class'), 'new':('new','creatable'),
        'findfirstchildofclass':('FindFirstChildOfClass','class'),
        'findfirstchildwhichisa':('FindFirstChildWhichIsA','class'),
        'findfirstancestorofclass':('FindFirstAncestorOfClass','class'),
        'findfirstancestorwhichisa':('FindFirstAncestorWhichIsA','class'),
        'waitforchild':('WaitForChild','child'), 'findfirstchild':('FindFirstChild','child'),
        'findfirstancestor':('FindFirstAncestor','child'),
        'getpropertychangedsignal':('GetPropertyChangedSignal','property'),
        'getattribute':('GetAttribute','attribute'), 'setattribute':('SetAttribute','attribute'),
        'getattributechangedsignal':('GetAttributeChangedSignal','attribute'),
        'addtag':('AddTag','tag'), 'removetag':('RemoveTag','tag'), 'hastag':('HasTag','tag'),
        'gettagged':('GetTagged','tag'), 'getinstanceaddedsignal':('GetInstanceAddedSignal','tag'),
        'getinstanceremovedsignal':('GetInstanceRemovedSignal','tag'),
    }
    known = canonical.get(name.casefold())
    if not known:
        return None
    leading = before[:match.start('name')].rstrip()
    if known[1] == 'creatable' and not re.search(r'\bInstance\s*\.\s*$', leading, re.I):
        return None
    return {'kind':known[1], 'prefix':match.group('prefix'), 'quote':match.group('quote'),
            'start':match.start('prefix'), 'call_start':match.start('name'),
            'call_end':match.end('name'), 'canonical':known[0], 'leading':leading}

# Additional common editing targets, available before the live API index loads.
OFFLINE_CLASSES.update({
    'Folder': ('Instance', {}), 'Configuration': ('Instance', {}),
    'LuaSourceContainer': ('Instance', {}),
    'Script': ('LuaSourceContainer', {'Disabled':'boolean'}),
    'LocalScript': ('Script', {}), 'ModuleScript': ('LuaSourceContainer', {}),
    'PlayerGui': ('Instance', {}), 'PlayerScripts': ('Instance', {}),
    'Backpack': ('Instance', {}), 'Team': ('Instance', {'TeamColor':'BrickColor','AutoAssignable':'boolean'}),
    'Attachment': ('Instance', {'Position':'Vector3','CFrame':'CFrame','WorldPosition':'Vector3','WorldCFrame':'CFrame','Visible':'boolean'}),
    'ImageLabel': ('GuiObject', {'Image':'string','ImageColor3':'Color3','ImageTransparency':'number','ScaleType':'Enum.ScaleType'}),
    'ImageButton': ('ImageLabel', {'Activated':'RBXScriptSignal','MouseButton1Click':'RBXScriptSignal','AutoButtonColor':'boolean'}),
    'UICorner': ('Instance', {'CornerRadius':'UDim'}),
    'UIStroke': ('Instance', {'Color':'Color3','Thickness':'number','Transparency':'number','Enabled':'boolean'}),
    'UIListLayout': ('Instance', {'Padding':'UDim','FillDirection':'Enum.FillDirection','SortOrder':'Enum.SortOrder','AbsoluteContentSize':'Vector2'}),
    'Decal': ('Instance', {'Texture':'string','Color3':'Color3','Transparency':'number','Face':'Enum.NormalId'}),
    'Texture': ('Decal', {'StudsPerTileU':'number','StudsPerTileV':'number'}),
    'Animation': ('Instance', {'AnimationId':'string'}),
    'Animator': ('Instance', {'LoadAnimation':'AnimationTrack','GetPlayingAnimationTracks':'table'}),
    'AnimationTrack': ('Instance', {'Play':'nil','Stop':'nil','AdjustSpeed':'nil','AdjustWeight':'nil','IsPlaying':'boolean','Length':'number','Looped':'boolean','TimePosition':'number','Stopped':'RBXScriptSignal','Ended':'RBXScriptSignal'}),
    'Terrain': ('Instance', {'WaterColor':'Color3','WaterTransparency':'number','WaterWaveSize':'number','WaterWaveSpeed':'number'}),
})
OFFLINE_CLASSES['DataModel'] = ('Instance', {'CreatorId':'number', 'CreatorType':'Enum.CreatorType', 'PrivateServerId':'string','PrivateServerOwnerId':'number','Workspace':'Workspace'})
OFFLINE_CLASSES['Instance'][1].update({
    'FindFirstAncestor':'Instance', 'FindFirstAncestorOfClass':'Instance',
    'FindFirstAncestorWhichIsA':'Instance', 'GetTags':'table', 'HasTag':'boolean',
    'AddTag':'nil', 'RemoveTag':'nil',
})
OFFLINE_CLASSES['Workspace'] = ('Model', {'Terrain':'Terrain'})
METHODS.update('FindFirstAncestor FindFirstAncestorOfClass FindFirstAncestorWhichIsA AdjustSpeed AdjustWeight'.split())
# Abstract classes remain valid IsA arguments, but cannot be constructed.
ABSTRACT_CLASSES = {'DataModel','LuaSourceContainer','Instance','BasePart','GuiObject','RBXScriptSignal','RBXScriptConnection'}
