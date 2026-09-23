import ast
import base64
import math
import random
import statistics
import codecs
import ctypes
from ctypes import wintypes
import csv
import hashlib
import html
import ipaddress
import json
import os
import queue
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import traceback
import xml.etree.ElementTree as ET
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime
from pathlib import Path

RUNTIME_DIR = Path(__file__).resolve().parent
_APPDATA_ROOT = os.environ.get("APPDATA")
APPDATA_DIR = (
    Path(_APPDATA_ROOT).expanduser().resolve() / "LelSploit"
    if _APPDATA_ROOT
    else (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()
)
APPDATA_DIR.mkdir(parents=True, exist_ok=True)



BASE_DIR = APPDATA_DIR

from api_bridge import (
    CombinedStop,
    attach_api,
    run_script,
    reattach_api,
    detach_api,
)
APP_ICON_PATH = RUNTIME_DIR / "icon.ico"
APP_USER_MODEL_ID = "LelSploit"
READ_CHUNK = 64 * 1024
UNDO_LIMIT = 8 * 1024 * 1024
COLOR_LIMIT = 200 * 1024 * 1024
LONG_LINE_LIMIT = 1024 * 1024
ICON_DIR = RUNTIME_DIR / "icons"
IMAGES_DIR = RUNTIME_DIR / "images"
EXTENSIONS_DIR = BASE_DIR / "extensions"
EXTENSION_DATA_DIR = BASE_DIR / "extension_data"
EXTENSION_STATE_PATH = BASE_DIR / "extensions_state.json"
EXTENSION_FORMAT_VERSION = 1
EXTENSION_MANIFEST_LIMIT = 256 * 1024
EXTENSION_ICON_LIMIT = 2 * 1024 * 1024
EXTENSION_PACKAGE_LIMIT = 32 * 1024 * 1024
EXTENSION_TEXT_LIMIT = 8 * 1024 * 1024
EXTENSION_NETWORK_LIMIT = 2 * 1024 * 1024
SCRIPTBLOX_API = "https://scriptblox.com/api/script"
SCRIPTBLOX_RESPONSE_LIMIT = 8 * 1024 * 1024
TOOL_FETCH_LIMIT = 256 * 1024 * 1024
ROBLOX_PLAYER_IMAGES = {
    "robloxplayerbeta.exe",
    "windows10universal.exe",
    "roblox.exe",
}
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
SETTINGS_PATH = BASE_DIR / "settings.json"
CAPTURE_AFFINITY_NONE = 0x00000000
CAPTURE_AFFINITY_EXCLUDE = 0x00000011


def set_window_capture_exclusion(hwnd, enabled):
    if sys.platform != "win32" or not hwnd:
        return False
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.SetWindowDisplayAffinity.argtypes = [wintypes.HWND, wintypes.DWORD]
    user32.SetWindowDisplayAffinity.restype = wintypes.BOOL
    affinity = CAPTURE_AFFINITY_EXCLUDE if enabled else CAPTURE_AFFINITY_NONE
    ctypes.set_last_error(0)
    return bool(user32.SetWindowDisplayAffinity(int(hwnd), affinity))


def get_window_exstyle(hwnd):
    if sys.platform != "win32" or not hwnd:
        return None
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    getter = getattr(user32, "GetWindowLongPtrW", None)
    if getter is None:
        getter = user32.GetWindowLongW
        getter.restype = ctypes.c_long
    else:
        getter.restype = ctypes.c_ssize_t
    getter.argtypes = [wintypes.HWND, ctypes.c_int]
    ctypes.set_last_error(0)
    value = getter(int(hwnd), -20)
    if value == 0 and ctypes.get_last_error():
        return None
    return int(value)


def set_window_taskbar_hidden(hwnd, hidden, restore_style=None):
    if sys.platform != "win32" or not hwnd:
        return False
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    setter = getattr(user32, "SetWindowLongPtrW", None)
    if setter is None:
        setter = user32.SetWindowLongW
        setter.restype = ctypes.c_long
    else:
        setter.restype = ctypes.c_ssize_t
    setter.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_ssize_t]
    user32.SetWindowPos.argtypes = [
        wintypes.HWND,
        wintypes.HWND,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        wintypes.UINT,
    ]
    user32.SetWindowPos.restype = wintypes.BOOL
    current = get_window_exstyle(hwnd)
    if current is None:
        return False
    if hidden:
        target = (current | 0x00000080) & ~0x00040000
    else:
        target = current if restore_style is None else int(restore_style)
    ctypes.set_last_error(0)
    setter(int(hwnd), -20, target)
    if ctypes.get_last_error():
        return False
    flags = 0x0001 | 0x0002 | 0x0004 | 0x0010 | 0x0020
    user32.SetWindowPos(int(hwnd), 0, 0, 0, 0, 0, flags)
    return True
FASTFLAGS_PATH = BASE_DIR / "fastflags.json"
CUSTOM_FASTFLAGS_PATH = BASE_DIR / "custom_fastflags.json"
CUSTOM_FASTFLAG_STATE_PATH = BASE_DIR / "custom_fastflag_state.json"
FASTFLAG_CATALOG_CACHE_PATH = BASE_DIR / "fastflag_catalog_cache.json"
FASTFLAG_MODULES_PATH = BASE_DIR / "fastflag_modules.json"
FASTFLAG_CATALOG_ENDPOINT = "https://clientsettingscdn.roblox.com/v2/settings/application/PCDesktopClient"
LEGACY_FASTFLAG_CATALOG = {'DFFlagDebugDisableTimeoutDisconnect': {'value': 'True', 'category': 'network', 'presets': ['No Internet Disconnect']}, 'DFFlagDebugDrawBroadPhaseAABBs': {'value': 'True', 'category': 'abusive', 'presets': ['ESP 1']}, 'DFFlagDebugDrawBvhNodes': {'value': 'True', 'category': 'abusive', 'presets': ['ESP 2']}, 'DFFlagDisableDPIScale': {'value': 'False', 'category': 'rendering', 'presets': ['High Res Becomes Lower Resolution']}, 'DFFlagOrder66': {'value': 'True', 'category': 'privacy', 'presets': ['Disable In-Game Purchases']}, 'DFFlagSimHumanoidTimestepModelUpdate': {'value': 'True', 'category': 'abusive', 'presets': ['Drunk']}, 'DFFlagTextureQualityOverrideEnabled': {'value': 'True', 'category': 'performance', 'presets': ['Low Quality Graphics', 'vRCO 3 [LQ] (Advanced Fps Booster)']}, 'DFIntAssetPreloading': {'value': '9999999', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Increased Asset Preloading Count']}, 'DFIntConnectionMTUSize': {'value': '900', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntCSGLevelOfDetailSwitchingDistance': {'value': '0', 'category': 'performance', 'presets': ['Low Polygons', 'Boost FPS']}, 'DFIntCSGLevelOfDetailSwitchingDistanceL12': {'value': '0', 'category': 'performance', 'presets': ['Low Polygons', 'Boost FPS']}, 'DFIntCSGLevelOfDetailSwitchingDistanceL23': {'value': '0', 'category': 'performance', 'presets': ['Low Polygons', 'Boost FPS']}, 'DFIntCSGLevelOfDetailSwitchingDistanceL34': {'value': '0', 'category': 'performance', 'presets': ['Low Polygons', 'Boost FPS']}, 'DFIntDebugFRMQualityLevelOverride': {'value': '1', 'category': 'abusive, performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Fullbright']}, 'DFIntGameNetLocalSpaceMaxSendIndex': {'value': '100000', 'category': 'abusive', 'presets': ['No Knockback']}, 'DFIntMaxFrameBufferSize': {'value': '4', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'DFIntMaximumUnstickForceInGs': {'value': '-10', 'category': 'abusive', 'presets': ['WallGlide']}, 'DFIntMinimalNetworkPrediction': {'value': '0.1', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntNetworkLatencyTolerance': {'value': '1', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntNetworkPrediction': {'value': '120', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntNumAssetsMaxToPreload': {'value': '9999999', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Increased Asset Preloading Count']}, 'DFIntOptimizePingThreshold': {'value': '50', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntPhysicsImprovedCyclicExecutiveThrottleThresholdTenth': {'value': '0', 'category': 'abusive', 'presets': ['No Knockback']}, 'DFIntPlayerNetworkUpdateQueueSize': {'value': '20', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntPlayerNetworkUpdateRate': {'value': '60', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntRaknetBandwidthPingSendEveryXSeconds': {'value': '1', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntRakNetResendRttMultiple': {'value': '1', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntRaycastMaxDistance': {'value': '3', 'category': 'abusive', 'presets': ['Noclip Cam']}, 'DFIntRenderClampRoughnessMax': {'value': '-640000000', 'category': 'abusive', 'presets': ['Fullbright']}, 'DFIntServerPhysicsUpdateRate': {'value': '60', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntServerTickRate': {'value': '60', 'category': 'network', 'presets': ['Lower Ping']}, 'DFIntSimAdaptiveHumanoidPDControllerSubstepMultiplier': {'value': '-999999', 'category': 'abusive', 'presets': ['Drunk']}, 'DFIntSmoothTerrainPhysicsRayAabbSlop': {'value': '-9999', 'category': 'abusive', 'presets': ['Slide on Terrain/Meshes']}, 'DFIntTaskSchedulerTargetFps': {'value': '9999', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'DFIntTextureQualityOverride': {'value': '0', 'category': 'performance', 'presets': ['Low Quality Graphics', 'Boost FPS', 'vRCO 3 [LQ] (Advanced Fps Booster)']}, 'DFIntVideoMaxNumberOfVideosPlaying': {'value': '0', 'category': 'interface', 'presets': ['Remove Videos']}, 'FFlagAdServiceEnabled': {'value': 'False', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable In-game Advertisements']}, 'FFlagBetaBadgeLearnMoreLinkFormview': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagControlBetaBadgeWithGuac': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagDebugCheckRenderThreading': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagDebugDisableTelemetryEphemeralCounter': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryEphemeralStat': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryEventIngest': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryPoint': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryV2Counter': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryV2Event': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugDisableTelemetryV2Stat': {'value': 'True', 'category': 'performance, privacy', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)', 'Disable Telemetry']}, 'FFlagDebugGraphicsDisableDirect3D11': {'value': 'False', 'category': 'performance, rendering', 'presets': ['Force Direct3D11', 'Render With Vulkan (May glitch out!)', 'Render With OpenGL']}, 'FFlagDebugGraphicsPreferD3D11': {'value': 'True', 'category': 'performance', 'presets': ['Force Direct3D11']}, 'FFlagDebugGraphicsPreferD3D11FL10': {'value': 'True', 'category': 'performance', 'presets': ['Direct X 10']}, 'FFlagDebugGraphicsPreferOpenGL': {'value': 'True', 'category': 'rendering', 'presets': ['Prefer OpenGL', 'Render With OpenGL']}, 'FFlagDebugGraphicsPreferVulkan': {'value': 'True', 'category': 'rendering', 'presets': ['Prefer Vulcan', 'Render With Vulkan (May glitch out!)']}, 'FFlagDisablePostFx': {'value': 'True', 'category': 'performance', 'presets': ['Disable Unnecessary Effects', 'Boost FPS', 'vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagEnableQuickGameLaunch': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagFastGPULightCulling3': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagFixSensitivityTextPrecision': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagHandleAltEnterFullscreenManually': {'value': 'False', 'category': 'rendering', 'presets': ['Alt Enter Fullscreen']}, 'FFlagMovePrerender': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagOptimizeNetwork': {'value': 'True', 'category': 'network', 'presets': ['Lower Ping']}, 'FFlagOptimizeNetworkRouting': {'value': 'True', 'category': 'network', 'presets': ['Lower Ping']}, 'FFlagOptimizeNetworkTransport': {'value': 'True', 'category': 'network', 'presets': ['Lower Ping']}, 'FFlagOptimizeServerTickRate': {'value': 'True', 'category': 'network', 'presets': ['Lower Ping']}, 'FFlagRenderDebugCheckThreading2': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagRenderDynamicResolutionScale9': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagRenderNoLowFrmBloom': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagRenderVulkanFixMinimizeWindow': {'value': 'True', 'category': 'rendering', 'presets': ['Render With Vulkan (May glitch out!)']}, 'FFlagSimAdaptiveTimesteppingDefault2': {'value': 'True', 'category': 'abusive', 'presets': ['Drunk']}, 'FFlagTaskSchedulerLimitTargetFpsTo2402': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagTopBarUseNewBadge': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagUserClickToMoveSupportAgentCanClimb2': {'value': 'False', 'category': 'environment', 'presets': ['Click To Move Supports Climbing']}, 'FFlagUserShowGuiHideToggles': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FFlagVoiceBetaBadge': {'value': 'False', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntDebugForceMSAASamples': {'value': '0', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntFRMMaxGrassDistance': {'value': '0', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntFRMMinGrassDistance': {'value': '0', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntFullscreenTitleBarTriggerDelayMillis': {'value': '3600000', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntGrassMovementReducedMotionFactor': {'value': '0', 'category': 'interface, performance', 'presets': ['Reduced Motion', 'vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntRakNetResendBufferArrayLength': {'value': '128', 'category': 'network', 'presets': ['Lower Ping']}, 'FIntRenderGrassDetailStrands': {'value': '0', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntRenderLocalLightUpdatesMax': {'value': '8', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntRenderLocalLightUpdatesMin': {'value': '6', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FIntRenderShadowIntensity': {'value': '0', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'FStringTencentAuthPath': {'value': 'null', 'category': 'privacy', 'presets': ['Prevent Roblox Monitoring']}, 'FStringVoiceBetaBadgeLearnMoreLink': {'value': 'null', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}, 'GuiHidingApiSupport2': {'value': 'True', 'category': 'performance', 'presets': ['vRCO 3 [LQ] (Advanced Fps Booster)']}}
SAVED_SCRIPTS_PATH = BASE_DIR / "saved_scripts.json"
MODIFICATIONS_PATH = BASE_DIR / "modifications.json"
MOD_BACKUP_DIR = BASE_DIR / "mod_backups"
MOD_CACHE_DIR = BASE_DIR / "mod_cache"
FASTFLAG_BACKUP_DIR = BASE_DIR / "fastflag_backups"
CLIENT_SETTINGS_NAME = "ClientAppSettings.json"
PROXY_PORT = 58443
PROXY_RUNTIME_PATH = BASE_DIR / "proxy_runtime.json"
PROXY_USERNAME_ACTIVE_PATH = BASE_DIR / "proxy_username_active.json"
PROXY_STATE_PATH = BASE_DIR / "proxy_state.json"
PROXY_HELPER_PATH = RUNTIME_DIR / "lelsploit_local_proxy.py"
PROXY_READY_PATH = BASE_DIR / "proxy_ready.json"
PROXY_DIR = BASE_DIR / ".lelsploit_proxy"
PROXY_CA_MARKER = b"\n# LelSploit local interception CA\n"

ASSET_TARGETS = {
    "Sounds": {
        "Footsteps (Plastic)": r"content\sounds\action_footsteps_plastic.mp3",
        "Falling": r"content\sounds\action_falling.ogg",
        "Get Up": r"content\sounds\action_get_up.mp3",
        "Jump": r"content\sounds\action_jump.mp3",
        "Jump Land": r"content\sounds\action_jump_land.mp3",
        "Swim": r"content\sounds\action_swim.mp3",
        "Explosion": r"content\sounds\impact_explosion_03.mp3",
        "Water Impact": r"content\sounds\impact_water.mp3",
        "Oof": r"content\sounds\oof.ogg",
        "Ouch": r"content\sounds\ouch.ogg",
        "Volume Slider": r"content\sounds\volume_slider.ogg",
    },
    "Skyboxes": {
        "Sky — Back": r"PlatformContent\pc\textures\sky\sky512_bk.tex",
        "Sky — Down": r"PlatformContent\pc\textures\sky\sky512_dn.tex",
        "Sky — Front": r"PlatformContent\pc\textures\sky\sky512_ft.tex",
        "Sky — Left": r"PlatformContent\pc\textures\sky\sky512_lf.tex",
        "Sky — Right": r"PlatformContent\pc\textures\sky\sky512_rt.tex",
        "Sky — Up": r"PlatformContent\pc\textures\sky\sky512_up.tex",
        "Indoor — Back": r"PlatformContent\pc\textures\sky\indoor512_bk.tex",
        "Indoor — Down": r"PlatformContent\pc\textures\sky\indoor512_dn.tex",
        "Indoor — Front": r"PlatformContent\pc\textures\sky\indoor512_ft.tex",
        "Indoor — Left": r"PlatformContent\pc\textures\sky\indoor512_lf.tex",
        "Indoor — Right": r"PlatformContent\pc\textures\sky\indoor512_rt.tex",
        "Indoor — Up": r"PlatformContent\pc\textures\sky\indoor512_up.tex",
    },
    "Textures": {
        "High Quality Studs — Diffuse": r"PlatformContent\pc\textures\plastic\diffuse.dds",
        "High Quality Studs — Normal": r"PlatformContent\pc\textures\plastic\normal.dds",
        "High Quality Studs — Detail": r"PlatformContent\pc\textures\plastic\normaldetail.dds",
        "Low Quality Studs": r"PlatformContent\pc\textures\studs.dds",
        "Shiftlock Cursor": r"content\textures\MouseLockedCursor.png",
        "Cursor — Pointing": r"content\textures\Cursors\KeyboardMouse\ArrowCursor.png",
        "Cursor — Arrow": r"content\textures\Cursors\KeyboardMouse\ArrowFarCursor.png",
        "Cursor — IBeam": r"content\textures\Cursors\KeyboardMouse\IBeamCursor.png",
        "Moon": r"content\sky\moon.jpg",
        "Sun": r"content\sky\sun.jpg",
    },
    "R6 Default Avatar Meshes": {
        "Left Arm": r"content\avatar\meshes\leftarm.mesh",
        "Left Leg": r"content\avatar\meshes\leftleg.mesh",
        "Right Arm": r"content\avatar\meshes\rightarm.mesh",
        "Right Leg": r"content\avatar\meshes\rightleg.mesh",
        "Torso": r"content\avatar\meshes\torso.mesh",
        "Head": r"content\avatar\heads\head.mesh",
    },
}

FASTFLAG_KEYS = {
    "manual_fullscreen": "FFlagHandleAltEnterFullscreenManually",
    "display_scaling": "DFFlagDisableDPIScale",
    "msaa": "FIntDebugForceMSAASamples",
    "frm_quality": "DFIntDebugFRMQualityLevelOverride",
    "render_disable_d3d11": "FFlagDebugGraphicsDisableDirect3D11",
    "render_d3d11": "FFlagDebugGraphicsPreferD3D11",
    "render_vulkan": "FFlagDebugGraphicsPreferVulkan",
    "render_opengl": "FFlagDebugGraphicsPreferOpenGL",
    "lod_static": "DFIntCSGLevelOfDetailSwitchingDistanceStatic",
    "lod_l0": "DFIntCSGLevelOfDetailSwitchingDistance",
    "lod_l12": "DFIntCSGLevelOfDetailSwitchingDistanceL12",
    "lod_l23": "DFIntCSGLevelOfDetailSwitchingDistanceL23",
    "lod_l34": "DFIntCSGLevelOfDetailSwitchingDistanceL34",
    "texture_enabled": "DFFlagTextureQualityOverrideEnabled",
    "texture_level": "DFIntTextureQualityOverride",
    "grey_sky": "FFlagDebugSkyGray",
    "pause_voxelizer": "DFFlagDebugPauseVoxelizer",
    "grass_max": "FIntFRMMaxGrassDistance",
    "grass_min": "FIntFRMMinGrassDistance",
    "grass_motion": "FIntGrassMovementReducedMotionFactor",
}
DEFAULT_FASTFLAGS = {}


ROBLOX_API_DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
ROBLOX_API_DUMP_LIMIT = 12 * 1024 * 1024
AUTOCOMPLETE_ANALYSIS_LIMIT = 4 * 1024 * 1024

LUAU_KEYWORDS = (
    "and break continue do else elseif end export false for function if in local nil not or "
    "repeat return then true type until while"
)
LUAU_KEYWORD_SET = frozenset(LUAU_KEYWORDS.split())
LUAU_GLOBALS = (
    "assert collectgarbage error getfenv getmetatable ipairs loadstring newproxy next pairs pcall "
    "print rawequal rawget rawlen rawset select setfenv setmetatable tonumber tostring type typeof "
    "unpack xpcall warn require gcinfo tick time elapsedTime spawn delay wait settings UserSettings version ypcall"
)
LUAU_LIBRARIES = "bit32 buffer coroutine debug math os string table task utf8"
ROBLOX_GLOBALS = "game workspace script shared _G Enum Instance"
LUAU_TYPES = "any boolean number string thread unknown never vector nil"
ROBLOX_VALUE_TYPES = (
    "Axes BrickColor CFrame Color3 ColorSequence ColorSequenceKeypoint DateTime Faces Font NumberRange "
    "NumberSequence NumberSequenceKeypoint OverlapParams PathWaypoint PhysicalProperties Random Ray "
    "RaycastParams RaycastResult Rect Region3 Region3int16 RotationCurveKey SharedTable TweenInfo UDim "
    "UDim2 Vector2 Vector2int16 Vector3 Vector3int16"
)
ROBLOX_COMMON_SERVICES = (
    "Players Workspace ReplicatedStorage ReplicatedFirst RunService TweenService UserInputService "
    "ContextActionService HttpService MarketplaceService TeleportService CollectionService Debris Lighting "
    "SoundService StarterGui StarterPack StarterPlayer ServerStorage ServerScriptService Teams TextChatService "
    "Chat PathfindingService PhysicsService ProximityPromptService BadgeService DataStoreService MemoryStoreService "
    "MessagingService LocalizationService GuiService ContentProvider InsertService LogService PolicyService "
    "GroupService AvatarEditorService VoiceChatService VirtualInputManager Stats TestService"
)
ROBLOX_COMMON_ENUMS = (
    "KeyCode UserInputType UserInputState Material EasingStyle EasingDirection Font CameraType CameraMode "
    "HumanoidStateType RaycastFilterType ActuatorRelativeTo AutomaticSize ButtonStyle ContextActionResult "
    "CoreGuiType FillDirection HorizontalAlignment VerticalAlignment SortOrder ScaleType ResamplerMode "
    "TextXAlignment TextYAlignment ZIndexBehavior PlaybackState PathStatus PathWaypointAction NormalId Axis"
)

STATIC_MEMBER_FALLBACKS = {
    "task": {
        "wait": "wait(duration: number?): number",
        "spawn": "spawn(functionOrThread: function | thread, ...any): thread",
        "defer": "defer(functionOrThread: function | thread, ...any): thread",
        "delay": "delay(duration: number, functionOrThread: function | thread, ...any): thread",
        "cancel": "cancel(thread: thread): ()",
        "synchronize": "synchronize(): ()",
        "desynchronize": "desynchronize(): ()",
    },
    "math": {name: f"{name}(...)" for name in (
        "abs acos asin atan atan2 ceil clamp cos cosh deg exp floor fmod frexp ldexp log log10 max min modf "
        "noise pow rad random randomseed round sign sin sinh sqrt tan tanh".split()
    )},
    "string": {name: f"{name}(...)" for name in (
        "byte char find format gmatch gsub len lower match pack packsize rep reverse split sub unpack upper".split()
    )},
    "table": {name: f"{name}(...)" for name in "clear clone concat create find freeze insert isfrozen maxn move pack remove sort unpack".split()},
    "coroutine": {name: f"{name}(...)" for name in "close create isyieldable resume running status wrap yield".split()},
    "utf8": {name: f"{name}(...)" for name in "char codes codepoint graphemes len nfcnormalize nfdnormalize offset".split()},
    "bit32": {name: f"{name}(...)" for name in "arshift band bnot bor btest bxor countlz countrz extract lrotate lshift replace rrotate rshift".split()},
    "buffer": {name: f"{name}(...)" for name in (
        "copy create fill fromstring len readf32 readf64 readi8 readi16 readi32 readstring readu8 readu16 readu32 "
        "tostring writef32 writef64 writei8 writei16 writei32 writestring writeu8 writeu16 writeu32".split()
    )},
    "Instance": {
        "new": "new(className: string, parent: Instance?): Instance",
    },
    "Vector2": {"new": "new(x: number?, y: number?): Vector2", "zero": "zero: Vector2", "one": "one: Vector2"},
    "Vector3": {"new": "new(x: number?, y: number?, z: number?): Vector3", "zero": "zero: Vector3", "one": "one: Vector3"},
    "Color3": {"new": "new(r: number?, g: number?, b: number?): Color3", "fromRGB": "fromRGB(r: number, g: number, b: number): Color3", "fromHSV": "fromHSV(h: number, s: number, v: number): Color3", "fromHex": "fromHex(hex: string): Color3"},
    "CFrame": {"new": "new(...): CFrame", "Angles": "Angles(rx: number, ry: number, rz: number): CFrame", "lookAt": "lookAt(at: Vector3, lookAt: Vector3, up: Vector3?): CFrame", "identity": "identity: CFrame"},
    "UDim2": {"new": "new(xScale: number, xOffset: number, yScale: number, yOffset: number): UDim2", "fromScale": "fromScale(xScale: number, yScale: number): UDim2", "fromOffset": "fromOffset(xOffset: number, yOffset: number): UDim2"},
    "UDim": {"new": "new(scale: number, offset: number): UDim"},
}

GLOBAL_SIGNATURES = {
    "print": "print(...any): ()",
    "warn": "warn(...any): ()",
    "typeof": "typeof(value: any): string",
    "type": "type(value: any): string",
    "tostring": "tostring(value: any): string",
    "tonumber": "tonumber(value: any, radix: number?): number?",
    "require": "require(module: ModuleScript | number | string): any",
    "pcall": "pcall(function: function, ...any): (boolean, ...any)",
    "xpcall": "xpcall(function: function, errorHandler: function, ...any): (boolean, ...any)",
    "assert": "assert<T>(value: T, message: string?): T",
    "error": "error(message: any, level: number?): never",
}


class RobloxApiIndex:
    def __init__(self):
        self._lock = threading.RLock()
        self.classes = {}
        self.superclasses = {}
        self.enums = {}
        self.services = set(ROBLOX_COMMON_SERVICES.split())
        self.creatable = set()
        self.class_names = set(ROBLOX_VALUE_TYPES.split()) | {"Instance", "DataModel", "Workspace", "Player", "Model", "Part", "BasePart", "Humanoid"}
        self.enum_names = set(ROBLOX_COMMON_ENUMS.split())
        self.member_names = set()
        self._seed_fallbacks()
        self.member_names.update(name for members in self.classes.values() for name in members)

    def _seed_fallbacks(self):
        instance_members = {
            "Name": {"kind": "Property", "signature": "Name: string", "type": "string"},
            "Parent": {"kind": "Property", "signature": "Parent: Instance?", "type": "Instance"},
            "ClassName": {"kind": "Property", "signature": "ClassName: string", "type": "string"},
            "Clone": {"kind": "Function", "signature": "Clone(): Instance", "type": "Instance"},
            "Destroy": {"kind": "Function", "signature": "Destroy(): ()", "type": "nil"},
            "FindFirstChild": {"kind": "Function", "signature": "FindFirstChild(name: string, recursive: boolean?): Instance?", "type": "Instance"},
            "FindFirstChildOfClass": {"kind": "Function", "signature": "FindFirstChildOfClass(className: string): Instance?", "type": "Instance"},
            "FindFirstChildWhichIsA": {"kind": "Function", "signature": "FindFirstChildWhichIsA(className: string, recursive: boolean?): Instance?", "type": "Instance"},
            "WaitForChild": {"kind": "Function", "signature": "WaitForChild(childName: string, timeOut: number?): Instance", "type": "Instance"},
            "GetChildren": {"kind": "Function", "signature": "GetChildren(): {Instance}", "type": "table"},
            "GetDescendants": {"kind": "Function", "signature": "GetDescendants(): {Instance}", "type": "table"},
            "IsA": {"kind": "Function", "signature": "IsA(className: string): boolean", "type": "boolean"},
            "GetAttribute": {"kind": "Function", "signature": "GetAttribute(attribute: string): Variant", "type": "any"},
            "SetAttribute": {"kind": "Function", "signature": "SetAttribute(attribute: string, value: Variant): ()", "type": "nil"},
            "GetAttributes": {"kind": "Function", "signature": "GetAttributes(): {[string]: Variant}", "type": "table"},
            "AncestryChanged": {"kind": "Event", "signature": "AncestryChanged(child: Instance, parent: Instance): RBXScriptSignal", "type": "RBXScriptSignal"},
            "ChildAdded": {"kind": "Event", "signature": "ChildAdded(child: Instance): RBXScriptSignal", "type": "RBXScriptSignal"},
            "ChildRemoved": {"kind": "Event", "signature": "ChildRemoved(child: Instance): RBXScriptSignal", "type": "RBXScriptSignal"},
        }
        self.classes["Instance"] = instance_members
        self.classes["DataModel"] = {
            "GetService": {"kind": "Function", "signature": "GetService(className: string): Instance", "type": "Instance"},
            "FindService": {"kind": "Function", "signature": "FindService(className: string): Instance?", "type": "Instance"},
            "PlaceId": {"kind": "Property", "signature": "PlaceId: number", "type": "number"},
            "GameId": {"kind": "Property", "signature": "GameId: number", "type": "number"},
            "JobId": {"kind": "Property", "signature": "JobId: string", "type": "string"},
            "Loaded": {"kind": "Event", "signature": "Loaded(): RBXScriptSignal", "type": "RBXScriptSignal"},
            "IsLoaded": {"kind": "Function", "signature": "IsLoaded(): boolean", "type": "boolean"},
        }
        self.superclasses["DataModel"] = "Instance"
        self.classes["Workspace"] = {
            "CurrentCamera": {"kind": "Property", "signature": "CurrentCamera: Camera?", "type": "Camera"},
            "Gravity": {"kind": "Property", "signature": "Gravity: number", "type": "number"},
            "Raycast": {"kind": "Function", "signature": "Raycast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams?): RaycastResult?", "type": "RaycastResult"},
        }
        self.superclasses["Workspace"] = "Model"
        self.classes["Players"] = {
            "LocalPlayer": {"kind": "Property", "signature": "LocalPlayer: Player", "type": "Player"},
            "PlayerAdded": {"kind": "Event", "signature": "PlayerAdded(player: Player): RBXScriptSignal", "type": "RBXScriptSignal"},
            "PlayerRemoving": {"kind": "Event", "signature": "PlayerRemoving(player: Player): RBXScriptSignal", "type": "RBXScriptSignal"},
            "GetPlayers": {"kind": "Function", "signature": "GetPlayers(): {Player}", "type": "table"},
        }
        self.superclasses["Players"] = "Instance"
        self.classes["Player"] = {
            "Character": {"kind": "Property", "signature": "Character: Model?", "type": "Model"},
            "UserId": {"kind": "Property", "signature": "UserId: number", "type": "number"},
            "DisplayName": {"kind": "Property", "signature": "DisplayName: string", "type": "string"},
            "CharacterAdded": {"kind": "Event", "signature": "CharacterAdded(character: Model): RBXScriptSignal", "type": "RBXScriptSignal"},
        }
        self.superclasses["Player"] = "Instance"
        for class_name in self.classes:
            self.class_names.add(class_name)

    @staticmethod
    def _type_name(value):
        if isinstance(value, dict):
            name = value.get("Name")
            if name:
                return str(name)
        if isinstance(value, str):
            return value
        return "any"

    @classmethod
    def _format_parameters(cls, parameters):
        out = []
        for item in parameters or []:
            if not isinstance(item, dict):
                continue
            name = str(item.get("Name") or "value")
            typ = cls._type_name(item.get("Type"))
            if item.get("Default") is not None:
                name += "?"
            out.append(f"{name}: {typ}")
        return ", ".join(out)

    def load_dump(self, payload):
        if not isinstance(payload, dict):
            return False
        new_classes = {}
        supers = {}
        services = set()
        creatable = set()
        class_names = set()
        member_names = set()
        for cls in payload.get("Classes", []):
            if not isinstance(cls, dict) or not cls.get("Name"):
                continue
            name = str(cls["Name"])
            class_names.add(name)
            tags = {str(tag) for tag in (cls.get("Tags") or []) if isinstance(tag, str)}
            if "Service" in tags:
                services.add(name)
            if "NotCreatable" not in tags and "Service" not in tags:
                creatable.add(name)
            superclass = cls.get("Superclass")
            if superclass and superclass != "<<<ROOT>>>":
                supers[name] = str(superclass)
            members = {}
            for member in cls.get("Members", []):
                if not isinstance(member, dict) or not member.get("Name"):
                    continue
                member_name = str(member["Name"])
                kind = str(member.get("MemberType") or "Member")
                result_type = "any"
                if kind == "Property":
                    result_type = self._type_name(member.get("ValueType"))
                    signature = f"{member_name}: {result_type}"
                elif kind in {"Function", "YieldFunction"}:
                    result_type = self._type_name(member.get("ReturnType"))
                    params = self._format_parameters(member.get("Parameters"))
                    signature = f"{member_name}({params}): {result_type}"
                elif kind in {"Event", "Callback"}:
                    params = self._format_parameters(member.get("Parameters"))
                    signature = f"{member_name}({params})"
                    result_type = "RBXScriptSignal" if kind == "Event" else self._type_name(member.get("ReturnType"))
                else:
                    signature = member_name
                members[member_name] = {"kind": kind, "signature": signature, "type": result_type}
                member_names.add(member_name)
            new_classes[name] = members
        new_enums = {}
        for enum in payload.get("Enums", []):
            if not isinstance(enum, dict) or not enum.get("Name"):
                continue
            name = str(enum["Name"])
            items = []
            for item in enum.get("Items", []):
                if isinstance(item, dict) and item.get("Name"):
                    items.append(str(item["Name"]))
            new_enums[name] = items
        if not new_classes:
            return False
        with self._lock:
            
            for name, members in self.classes.items():
                if name not in new_classes:
                    new_classes[name] = members
                else:
                    for member_name, meta in members.items():
                        new_classes[name].setdefault(member_name, meta)
            self.classes = new_classes
            self.superclasses = {**self.superclasses, **supers}
            self.enums = new_enums
            self.services = services or self.services
            self.creatable = creatable
            self.class_names = class_names | set(ROBLOX_VALUE_TYPES.split()) | set(new_classes)
            self.enum_names = set(new_enums) | set(ROBLOX_COMMON_ENUMS.split())
            self.member_names = member_names | {name for members in new_classes.values() for name in members}
        return True

    def refresh_remote(self):
        try:
            request = urllib.request.Request(
                ROBLOX_API_DUMP_URL,
                headers={"Accept": "application/json", "User-Agent": "LelSploit/1.0"},
            )
            with urllib.request.urlopen(request, timeout=12) as response:
                raw = response.read(ROBLOX_API_DUMP_LIMIT + 1)
            if len(raw) > ROBLOX_API_DUMP_LIMIT:
                return
            self.load_dump(json.loads(raw.decode("utf-8")))
        except Exception:
            return

    def class_members(self, class_name, method_only=False):
        class_name = str(class_name or "")
        merged = {}
        seen = set()
        with self._lock:
            while class_name and class_name not in seen:
                seen.add(class_name)
                merged.update(self.classes.get(class_name, {}))
                class_name = self.superclasses.get(class_name, "")
        if method_only:
            return {name: meta for name, meta in merged.items() if meta.get("kind") in {"Function", "YieldFunction"}}
        return merged

    def member_type(self, class_name, member_name):
        meta = self.class_members(class_name).get(str(member_name))
        return str(meta.get("type") or "") if meta else ""

    def member_signature(self, class_name, member_name):
        meta = self.class_members(class_name).get(str(member_name))
        return str(meta.get("signature") or "") if meta else ""

    def member_meta(self, class_name, member_name):
        meta = self.class_members(class_name).get(str(member_name))
        return dict(meta) if isinstance(meta, dict) else {}

    def snapshot(self):
        with self._lock:
            return (
                set(self.class_names), set(self.enum_names), set(self.services),
                set(self.creatable), set(self.member_names),
            )

    def enum_items(self, name):
        with self._lock:
            return tuple(self.enums.get(str(name), ()))


ROBLOX_API_INDEX = RobloxApiIndex()
threading.Thread(target=ROBLOX_API_INDEX.refresh_remote, daemon=True).start()


def read_json_object(path, default=None):
    fallback = dict(default or {})
    try:
        with Path(path).open("r", encoding="utf-8") as handle:
            value = json.load(handle)
        return value if isinstance(value, dict) else fallback
    except (OSError, ValueError, TypeError):
        return fallback


def write_json_object(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    with temp.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp, path)


def scriptblox_script_key(script):
    if not isinstance(script, dict):
        return ""
    game_data = script.get("game") if isinstance(script.get("game"), dict) else {}
    return str(script.get("_id") or script.get("slug") or (
        str(script.get("title")) + "\0" + str(game_data.get("name"))
    ))


def load_saved_scripts():
    value = read_json_object(SAVED_SCRIPTS_PATH, {})
    return {
        str(key): item for key, item in value.items()
        if isinstance(key, str) and isinstance(item, dict)
    }


def save_saved_scripts(value):
    clean = {
        str(key): item for key, item in value.items()
        if isinstance(key, str) and isinstance(item, dict)
    }
    write_json_object(SAVED_SCRIPTS_PATH, clean)


def clear_directory_contents(path):
    path = Path(path)
    if not path.exists():
        return
    if path.is_symlink() or not path.is_dir():
        raise OSError(f"Refusing to clear non-directory path: {path}")
    for child in path.iterdir():
        if child.is_symlink() or child.is_file():
            child.unlink()
        elif child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink(missing_ok=True)


class JsonSettings:
    def __init__(self, path):
        self.path = Path(path)
        self.lock = threading.RLock()
        self.data = read_json_object(self.path)
        if not self.path.is_file():
            self.sync()

    def value(self, key, default=None):
        with self.lock:
            node = self.data
            for part in str(key).split("/"):
                if not isinstance(node, dict) or part not in node:
                    return default
                node = node[part]
            return node

    def setValue(self, key, value):
        with self.lock:
            node = self.data
            parts = [part for part in str(key).split("/") if part]
            if not parts:
                return
            for part in parts[:-1]:
                child = node.get(part)
                if not isinstance(child, dict):
                    child = {}
                    node[part] = child
                node = child
            node[parts[-1]] = value

    def sync(self):
        with self.lock:
            write_json_object(self.path, self.data)


def normalize_fastflags(value):
    if not isinstance(value, dict):
        value = {}
    flags = {}
    for key, item in value.items():
        if not isinstance(key, str) or not key.strip() or item is None:
            continue
        if isinstance(item, bool):
            item = "True" if item else "False"
        else:
            item = str(item)
        flags[key.strip()] = item
    return flags


def fastflag_family(name):
    value = str(name or "")
    for prefix in ("DFFlag", "FFlag", "DFInt", "FInt", "DFString", "FString", "DFLog", "FLog"):
        if value.startswith(prefix):
            return prefix
    return "Other"


def _catalog_entry(value="", source="Current", category="", presets=None):
    if isinstance(value, bool):
        value = "True" if value else "False"
    elif value is None:
        value = ""
    else:
        value = str(value)
    return {
        "value": value,
        "family": "",
        "source": str(source or ""),
        "category": str(category or ""),
        "presets": list(presets or ()),
    }


def load_cached_fastflag_catalog():
    raw = read_json_object(FASTFLAG_CATALOG_CACHE_PATH, {})
    source = raw.get("flags", {}) if isinstance(raw, dict) else {}
    result = {}
    if isinstance(source, dict):
        for name, meta in source.items():
            if not isinstance(name, str) or not name.strip():
                continue
            if isinstance(meta, dict):
                entry = _catalog_entry(
                    meta.get("value", ""), meta.get("source", "Current"),
                    meta.get("category", "current"), meta.get("presets", ()),
                )
            else:
                entry = _catalog_entry(meta, "Current", "current")
            entry["family"] = fastflag_family(name)
            result[name.strip()] = entry
    return result


def combined_fastflag_catalog():
    result = {}
    for name, meta in LEGACY_FASTFLAG_CATALOG.items():
        entry = _catalog_entry(meta.get("value", ""), "Legacy", meta.get("category", "legacy"), meta.get("presets", ()))
        entry["family"] = fastflag_family(name)
        result[name] = entry
    for name, current in load_cached_fastflag_catalog().items():
        if name in result:
            previous = result[name]
            current["source"] = "Current + Legacy"
            if not current.get("category"):
                current["category"] = previous.get("category", "")
            if not current.get("presets"):
                current["presets"] = previous.get("presets", [])
        result[name] = current
    return result



def useful_fastflag_catalog():
    
    
    
    if FASTFLAG_MODULES_PATH.is_file():
        try:
            payload = read_json_object(FASTFLAG_MODULES_PATH, {})
            modules = payload.get("modules", []) if isinstance(payload, dict) else []
            if isinstance(modules, list):
                dynamic = {}
                for module in modules:
                    if not isinstance(module, dict):
                        continue
                    preset = str(module.get("name", "")).strip()
                    category = str(module.get("categoryId", "")).strip()
                    flags = module.get("flags", {})
                    if not isinstance(flags, dict) or not preset:
                        continue
                    cleaned = [
                        (str(name or "").strip(), value)
                        for name, value in flags.items()
                        if str(name or "").strip()
                    ]
                    if len(cleaned) != 1:
                        continue
                    name, value = cleaned[0]
                    if name not in dynamic:
                        dynamic[name] = _catalog_entry(value, "Curated", category, [preset])
                        dynamic[name]["family"] = fastflag_family(name)
                    else:
                        entry = dynamic[name]
                        if category:
                            categories = {part.strip() for part in str(entry.get("category", "")).split(",") if part.strip()}
                            categories.add(category)
                            entry["category"] = ", ".join(sorted(categories))
                        if preset not in entry["presets"]:
                            entry["presets"].append(preset)
                if dynamic:
                    return dynamic
        except Exception:
            pass

    
    
    
    preset_flags = {}
    for flag_name, meta in LEGACY_FASTFLAG_CATALOG.items():
        for preset in meta.get("presets", ()):
            preset = str(preset or "").strip()
            if preset:
                preset_flags.setdefault(preset, set()).add(flag_name)
    single_flag_presets = {preset for preset, names in preset_flags.items() if len(names) == 1}

    result = {}
    for name, meta in LEGACY_FASTFLAG_CATALOG.items():
        presets = [
            str(preset).strip()
            for preset in meta.get("presets", ())
            if str(preset or "").strip() in single_flag_presets
        ]
        if not presets:
            continue
        entry = _catalog_entry(
            meta.get("value", ""),
            "Curated",
            meta.get("category", ""),
            presets,
        )
        entry["family"] = fastflag_family(name)
        result[name] = entry
    return result

def fetch_current_fastflag_catalog(timeout=14):
    request = urllib.request.Request(
        FASTFLAG_CATALOG_ENDPOINT,
        headers={"Accept": "application/json", "User-Agent": "LelSploit/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = response.read(64 * 1024 * 1024 + 1)
    if len(data) > 64 * 1024 * 1024:
        raise ValueError("The FastFlag catalog response was too large.")
    payload = json.loads(data.decode("utf-8-sig"))
    settings = payload.get("applicationSettings") if isinstance(payload, dict) else None
    if not isinstance(settings, dict):
        raise ValueError("Roblox returned an invalid FastFlag catalog.")
    flags = {}
    for name, value in settings.items():
        if not isinstance(name, str) or not name.strip():
            continue
        entry = _catalog_entry(value, "Current", "current")
        entry["family"] = fastflag_family(name)
        flags[name.strip()] = entry
    write_json_object(FASTFLAG_CATALOG_CACHE_PATH, {"fetched_at": time.time(), "flags": flags})
    return flags


def refresh_fastflag_catalog_cache_in_background(max_age=21600):
    try:
        fresh = FASTFLAG_CATALOG_CACHE_PATH.is_file() and time.time() - FASTFLAG_CATALOG_CACHE_PATH.stat().st_mtime <= max_age
    except OSError:
        fresh = False
    if fresh:
        return
    def worker():
        try:
            fetch_current_fastflag_catalog()
        except Exception:
            pass
    threading.Thread(target=worker, daemon=True).start()


def load_saved_fastflags():
    flags = normalize_fastflags(read_json_object(FASTFLAGS_PATH, DEFAULT_FASTFLAGS))
    if not FASTFLAGS_PATH.is_file():
        write_json_object(FASTFLAGS_PATH, flags)
    return flags


def save_saved_fastflags(flags):
    flags = normalize_fastflags(flags)
    write_json_object(FASTFLAGS_PATH, flags)
    return flags


def load_custom_fastflags():
    flags = normalize_fastflags(read_json_object(CUSTOM_FASTFLAGS_PATH, {}))
    if not CUSTOM_FASTFLAGS_PATH.is_file():
        write_json_object(CUSTOM_FASTFLAGS_PATH, flags)
    return flags


def save_custom_fastflags(flags):
    flags = normalize_fastflags(flags)
    write_json_object(CUSTOM_FASTFLAGS_PATH, flags)
    return flags


def load_custom_fastflag_state():
    raw = read_json_object(CUSTOM_FASTFLAG_STATE_PATH, {})
    if not isinstance(raw, dict):
        raw = {}
    disabled = sorted({str(name).strip() for name in raw.get("disabled", []) if str(name).strip()})
    bindings = {}
    source = raw.get("keybinds", {})
    if isinstance(source, dict):
        for name, spec in source.items():
            if not isinstance(name, str) or not name.strip() or not isinstance(spec, dict):
                continue
            try:
                vk = int(spec.get("virtual_key", 0) or 0)
                modifiers = int(spec.get("modifiers", 0) or 0)
                scan_code = int(spec.get("scan_code", 0) or 0)
            except (TypeError, ValueError):
                continue
            if 0 < vk <= 0xFF:
                bindings[name.strip()] = {
                    "virtual_key": vk,
                    "modifiers": modifiers & 0x0F,
                    "scan_code": max(0, scan_code),
                    "extended": bool(spec.get("extended", False)),
                }
    return {"disabled": disabled, "keybinds": bindings}


def save_custom_fastflag_state(state):
    state = state if isinstance(state, dict) else {}
    flags = load_custom_fastflags()
    names = set(flags)
    disabled = sorted({str(name).strip() for name in state.get("disabled", []) if str(name).strip() in names})
    bindings = {}
    source = state.get("keybinds", {})
    if isinstance(source, dict):
        for name, spec in source.items():
            if name not in names or not isinstance(spec, dict):
                continue
            try:
                vk = int(spec.get("virtual_key", 0) or 0)
                modifiers = int(spec.get("modifiers", 0) or 0)
                scan_code = int(spec.get("scan_code", 0) or 0)
            except (TypeError, ValueError):
                continue
            if 0 < vk <= 0xFF:
                bindings[name] = {
                    "virtual_key": vk,
                    "modifiers": modifiers & 0x0F,
                    "scan_code": max(0, scan_code),
                    "extended": bool(spec.get("extended", False)),
                }
    clean = {"disabled": disabled, "keybinds": bindings}
    write_json_object(CUSTOM_FASTFLAG_STATE_PATH, clean)
    return clean


def active_custom_fastflags(flags=None):
    flags = normalize_fastflags(load_custom_fastflags() if flags is None else flags)
    disabled = set(load_custom_fastflag_state().get("disabled", []))
    return {name: value for name, value in flags.items() if name not in disabled}


def merge_fastflags(managed=None, custom=None, managed_enabled=True, custom_enabled=True):
    merged = {}
    if managed_enabled:
        merged.update(normalize_fastflags(managed if managed is not None else load_saved_fastflags()))
    if custom_enabled:
        custom_flags = normalize_fastflags(custom if custom is not None else load_custom_fastflags())
        merged.update(active_custom_fastflags(custom_flags))
    return merged


def roblox_client_settings_file():
    roots = roblox_player_version_dirs()
    return roots[0] / "ClientSettings" / CLIENT_SETTINGS_NAME if roots else None


def sync_saved_fastflags_to_roblox(flags=None, enabled=True):
    if sys.platform != "win32" or not enabled:
        return None
    desired = normalize_fastflags(flags if flags is not None else load_saved_fastflags())
    changed = []
    for root in roblox_player_version_dirs():
        target = root / "ClientSettings" / CLIENT_SETTINGS_NAME
        backup = FASTFLAG_BACKUP_DIR / root.name / "ClientSettings" / CLIENT_SETTINGS_NAME
        current = read_json_object(target, default={})
        current = {str(k): str(v) for k, v in current.items()} if isinstance(current, dict) else {}
        if current == desired:
            continue
        try:
            if target.is_file() and not backup.exists():
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                try:
                    target.chmod(target.stat().st_mode | 0o200)
                except OSError:
                    pass
            write_json_object(target, desired)
            changed.append(target)
        except OSError:
            continue
    prime_windows_fastflag_cache(desired)
    return changed[0] if changed else None


def remove_matching_fastflags_from_roblox(flags=None):
    if sys.platform != "win32":
        return False
    desired = normalize_fastflags(flags if flags is not None else load_saved_fastflags())
    restored = False
    for root in roblox_player_version_dirs():
        target = root / "ClientSettings" / CLIENT_SETTINGS_NAME
        backup = FASTFLAG_BACKUP_DIR / root.name / "ClientSettings" / CLIENT_SETTINGS_NAME
        try:
            if backup.is_file():
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    try:
                        target.chmod(target.stat().st_mode | 0o200)
                    except OSError:
                        pass
                shutil.copy2(backup, target)
                backup.unlink(missing_ok=True)
                restored = True
                continue
            if not target.is_file():
                continue
            current = read_json_object(target, default={})
            current = {str(k): str(v) for k, v in current.items()} if isinstance(current, dict) else {}
            if current != desired:
                continue
            try:
                target.chmod(target.stat().st_mode | 0o200)
            except OSError:
                pass
            target.unlink()
            try:
                target.parent.rmdir()
            except OSError:
                pass
            restored = True
        except OSError:
            continue
    return restored


def roblox_resource_dir():
    player = latest_roblox_player()
    return player.parent if player is not None else None


def _normalise_target_path(value):
    text = str(value or "").strip().replace("\\", "/")
    if not text:
        raise ValueError("Target path is empty.")
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise ValueError("Target path must be relative to the Roblox directory.")
    parts = [part for part in text.split("/") if part and part != "."]
    if not parts or any(part == ".." for part in parts):
        raise ValueError("Target path contains an invalid segment.")
    return Path(*parts)


def _read_modifications_data():
    data = read_json_object(MODIFICATIONS_PATH, default={})
    if not isinstance(data, dict):
        data = {}
    entries = data.get("entries")
    if not isinstance(entries, list):
        entries = []
    data["entries"] = [entry for entry in entries if isinstance(entry, dict)]
    username = data.get("username_spoofer")
    if not isinstance(username, dict):
        username = {}
    data["username_spoofer"] = username
    return data


def _write_modifications_data(data):
    write_json_object(MODIFICATIONS_PATH, data)


def _mod_entry_key(target):
    return str(target or "").replace("\\", "/").casefold()


def find_modification(target):
    key = _mod_entry_key(target)
    for entry in _read_modifications_data().get("entries", []):
        if _mod_entry_key(entry.get("target")) == key:
            return dict(entry)
    return None


def _download_mod_source(url, limit=128 * 1024 * 1024):
    MOD_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    import hashlib
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:24]
    ext = Path(urllib.parse.urlsplit(url).path).suffix[:12]
    cache = MOD_CACHE_DIR / f"url_{digest}{ext}"
    if cache.is_file():
        return cache.read_bytes()
    request = urllib.request.Request(url, headers={"User-Agent": "LelSploit/1.0"})
    with urllib.request.urlopen(request, timeout=25) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Modification source is larger than 128 MiB.")
    cache.write_bytes(data)
    return data


def _resolve_mod_source(source):
    value = str(source or "").strip()
    if not value:
        raise ValueError("Choose a source first.")
    if value.casefold() in {"none", "remove"}:
        return b""
    if value.casefold().startswith(("http://", "https://")):
        return _download_mod_source(value)
    if value.isdecimal():
        return _download_mod_source(f"https://assetdelivery.roblox.com/v1/asset/?id={value}")
    path = Path(value).expanduser()
    if not path.is_file():
        raise FileNotFoundError(f"Source file was not found: {value}")
    return path.read_bytes()


def _backup_target(root, rel):
    rel = _normalise_target_path(rel)
    target = root / rel
    backup = MOD_BACKUP_DIR / root.name / rel
    marker = backup.with_name(backup.name + ".new")
    if target.exists() and not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup)
        marker.unlink(missing_ok=True)
    elif not target.exists() and not backup.exists() and not marker.exists():
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.touch()
    return target, backup, marker


def _write_target_bytes(root, rel, data):
    target, _backup, _marker = _backup_target(root, rel)
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        if target.exists():
            target.chmod(target.stat().st_mode | 0o200)
    except OSError:
        pass
    target.write_bytes(data)
    return target


def _restore_target(root, rel):
    rel = _normalise_target_path(rel)
    target = root / rel
    backup = MOD_BACKUP_DIR / root.name / rel
    marker = backup.with_name(backup.name + ".new")
    if backup.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            if target.exists():
                target.chmod(target.stat().st_mode | 0o200)
        except OSError:
            pass
        shutil.copy2(backup, target)
        backup.unlink(missing_ok=True)
        marker.unlink(missing_ok=True)
        return True
    if marker.exists():
        marker.unlink(missing_ok=True)
        try:
            target.unlink(missing_ok=True)
        except OSError:
            pass
        return True
    return False


def _patch_font_family_value(value):
    if isinstance(value, dict):
        return {key: _patch_font_family_value(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_patch_font_family_value(item) for item in value]
    if isinstance(value, str):
        lowered = value.casefold().replace("\\", "/")
        if ("fonts/" in lowered or "rbxasset://fonts/" in lowered) and lowered.endswith((".ttf", ".otf")):
            return "rbxasset://fonts/CustomFont.ttf"
    return value


def _apply_custom_font(root, source):
    data = _resolve_mod_source(source)
    if len(data) < 4 or data[:4] not in (b"\x00\x01\x00\x00", b"OTTO", b"ttcf", b"true"):
        raise ValueError("Choose a valid TTF/OTF font file.")
    font_rel = Path("content") / "fonts" / "CustomFont.ttf"
    _write_target_bytes(root, font_rel, data)
    families = root / "content" / "fonts" / "families"
    if not families.is_dir():
        return
    for json_path in families.glob("*.json"):
        try:
            payload = json.loads(json_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, UnicodeError):
            continue
        rel = json_path.relative_to(root)
        _backup_target(root, rel)
        try:
            json_path.write_text(json.dumps(_patch_font_family_value(payload), indent=2), encoding="utf-8")
        except OSError:
            pass


def _restore_custom_font(root):
    restored = _restore_target(root, Path("content") / "fonts" / "CustomFont.ttf")
    backup_family_dir = MOD_BACKUP_DIR / root.name / "content" / "fonts" / "families"
    if backup_family_dir.is_dir():
        for backup in backup_family_dir.glob("*.json"):
            restored = _restore_target(root, Path("content") / "fonts" / "families" / backup.name) or restored
    return restored


def apply_modification_entry(entry, root=None):
    root = root or roblox_resource_dir()
    if root is None:
        raise FileNotFoundError("Roblox Player installation was not found.")
    if entry.get("kind") == "font" or entry.get("target") == "__font__":
        _apply_custom_font(root, entry.get("source"))
        return root / "content" / "fonts" / "CustomFont.ttf"
    rel = _normalise_target_path(entry.get("target"))
    data = _resolve_mod_source(entry.get("source"))
    return _write_target_bytes(root, rel, data)


def set_modification(display_name, target, source, kind="asset"):
    data = _read_modifications_data()
    key = _mod_entry_key(target)
    entry = {
        "display_name": str(display_name or target),
        "target": str(target),
        "source": str(source),
        "kind": str(kind or "asset"),
    }
    for index, old in enumerate(data["entries"]):
        if _mod_entry_key(old.get("target")) == key:
            data["entries"][index] = entry
            break
    else:
        data["entries"].append(entry)
    _write_modifications_data(data)
    return apply_modification_entry(entry)


def remove_modification(target):
    data = _read_modifications_data()
    key = _mod_entry_key(target)
    data["entries"] = [entry for entry in data["entries"] if _mod_entry_key(entry.get("target")) != key]
    _write_modifications_data(data)
    root = roblox_resource_dir()
    if root is not None:
        if key == "__font__":
            _restore_custom_font(root)
        else:
            _restore_target(root, target)


def sync_saved_modifications_to_roblox():
    if sys.platform != "win32":
        return []
    root = roblox_resource_dir()
    if root is None:
        return []
    applied = []
    for entry in _read_modifications_data().get("entries", []):
        try:
            apply_modification_entry(entry, root)
            applied.append(entry.get("target"))
        except Exception:
            continue
    return applied


def restore_all_modifications():
    root = roblox_resource_dir()
    if root is None:
        return
    for entry in list(_read_modifications_data().get("entries", [])):
        target = entry.get("target")
        try:
            if _mod_entry_key(target) == "__font__":
                _restore_custom_font(root)
            else:
                _restore_target(root, target)
        except Exception:
            pass


def _roblox_global_settings_files():
    if sys.platform != "win32":
        return []
    paths = []
    users = Path("C:/Users")
    if users.is_dir():
        try:
            for user in users.iterdir():
                path = user / "AppData" / "Local" / "Roblox" / "GlobalBasicSettings_13.xml"
                if path.is_file():
                    paths.append(path)
        except OSError:
            pass
    local = os.environ.get("LOCALAPPDATA")
    if local:
        path = Path(local) / "Roblox" / "GlobalBasicSettings_13.xml"
        if path.is_file() and path not in paths:
            paths.append(path)
    return paths


def read_roblox_framerate_cap():
    for path in _roblox_global_settings_files():
        try:
            root = ET.parse(path).getroot()
            for item in root.findall("Item"):
                if item.get("class") != "UserGameSettings":
                    continue
                for props in item.findall("Properties"):
                    for node in props.findall("int"):
                        if node.get("name") == "FramerateCap":
                            return int(node.text or 0)
        except Exception:
            continue
    return None


def write_roblox_framerate_cap(value):
    value = int(value)
    changed = 0
    for path in _roblox_global_settings_files():
        try:
            tree = ET.parse(path)
            root = tree.getroot()
            found = False
            for item in root.findall("Item"):
                if item.get("class") != "UserGameSettings":
                    continue
                for props in item.findall("Properties"):
                    for node in props.findall("int"):
                        if node.get("name") == "FramerateCap":
                            node.text = str(value)
                            found = True
                            break
            if found:
                tree.write(path, encoding="utf-8", xml_declaration=True)
                changed += 1
        except Exception:
            continue
    return changed


def load_username_spoofer_settings():
    return dict(_read_modifications_data().get("username_spoofer", {}))


def save_username_spoofer_settings(settings):
    data = _read_modifications_data()
    value = dict(settings or {})
    value["save"] = True
    data["username_spoofer"] = value
    _write_modifications_data(data)


def _normalized_username_proxy_state(settings):
    settings = dict(settings or {})
    return {
        "save_settings": True,
        "suspended": bool(settings.get("suspended", False)),
        "others_name": str(settings.get("others_username", settings.get("others_name", ""))),
        "others_apply_ingame": bool(settings.get("others_apply", settings.get("others_apply_ingame", False))),
        "others_verified": bool(settings.get("others_verified", False)),
        "self_name": str(settings.get("your_username", settings.get("self_name", ""))),
        "self_apply_ingame": bool(settings.get("your_apply", settings.get("self_apply_ingame", False))),
        "self_verified": bool(settings.get("your_verified", settings.get("self_verified", False))),
        "self_game_creator": bool(settings.get("make_creator", settings.get("self_game_creator", False))),
    }


def save_username_proxy_runtime(settings):
    current = read_json_object(PROXY_RUNTIME_PATH, default={})
    state = _normalized_username_proxy_state(settings)
    if isinstance(current, dict):
        state["suspended"] = bool(current.get("suspended", state.get("suspended", False)))
    write_json_object(PROXY_RUNTIME_PATH, state)
    return state


def username_proxy_runtime():
    state = read_json_object(PROXY_RUNTIME_PATH, default={})
    if isinstance(state, dict) and state:
        return _normalized_username_proxy_state(state)
    saved = load_username_spoofer_settings()
    if saved:
        return _normalized_username_proxy_state(saved)
    return _normalized_username_proxy_state({})


def activate_username_proxy_runtime():
    state = username_proxy_runtime()
    active = dict(state)
    active.pop("suspended", None)
    write_json_object(PROXY_USERNAME_ACTIVE_PATH, active)
    return active


def username_proxy_enabled(state=None):
    state = state or username_proxy_runtime()
    return any(bool(state.get(key)) for key in (
        "others_apply_ingame", "others_verified", "self_apply_ingame",
        "self_verified", "self_game_creator",
    ))


def fastflags_enabled_on_disk():
    data = read_json_object(SETTINGS_PATH, default={})
    node = data.get("fastflags", {}) if isinstance(data, dict) else {}
    value = node.get("enabled", False) if isinstance(node, dict) else False
    if isinstance(value, str):
        return value.strip().casefold() not in {"0", "false", "no", "off", ""}
    return bool(value)


def roblox_player_version_dirs():
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return []
    root = Path(local_app_data) / "Roblox" / "Versions"
    result = []
    try:
        for player in root.glob("version-*/RobloxPlayerBeta.exe"):
            if player.is_file():
                result.append(player.parent)
    except OSError:
        return []
    result.sort(key=lambda path: path.stat().st_mtime_ns if path.exists() else 0, reverse=True)
    return result


def prime_windows_fastflag_cache(flags=None):
    if sys.platform != "win32":
        return False
    flags = normalize_fastflags(flags if flags is not None else load_saved_fastflags())
    if not flags:
        return False
    cache_path = Path(os.environ.get("LOCALAPPDATA", "")) / "Temp" / "Roblox" / "cache" / "flag_cache.dat"
    try:
        raw = cache_path.read_bytes()
        if len(raw) < 5:
            return False
        signature_length = int.from_bytes(raw[:4], "little")
        compression_offset = 4 + signature_length
        payload_offset = compression_offset + 1
        if payload_offset >= len(raw) or raw[compression_offset] != 0:
            return False
        payload = json.loads(raw[payload_offset:])
        app_settings = payload.get("applicationSettings")
        if not isinstance(app_settings, dict):
            return False
        app_settings.update(flags)
        app_settings["DFIntSecondsBetweenDynamicVariableReloading"] = "1"
        updated = raw[:payload_offset] + json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        temp = cache_path.with_name(f".{cache_path.name}.{os.getpid()}.tmp")
        temp.write_bytes(updated)
        temp.replace(cache_path)
        return True
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError):
        return False



def choose_proxy_port(preferred=PROXY_PORT):
    for requested in (int(preferred), 0):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(("127.0.0.1", requested))
            return int(sock.getsockname()[1])
        except OSError:
            pass
        finally:
            sock.close()
    raise OSError("No free loopback port is available for the local Roblox proxy.")


def proxy_dependencies_available():
    try:
        import cryptography  
        import zstandard  
        return True
    except Exception:
        return False


def python_console_executable():
    executable = Path(sys.executable)
    if executable.name.casefold() == "pythonw.exe":
        candidate = executable.with_name("python.exe")
        if candidate.is_file():
            return str(candidate)
    return str(executable)

def patch_roblox_proxy_ca(ca_path):
    if sys.platform != "win32":
        return []
    ca_path = Path(ca_path)
    try:
        ca = ca_path.read_bytes().strip()
    except OSError:
        return []
    patched = []
    for root in roblox_player_version_dirs():
        target = root / "ssl" / "cacert.pem"
        if not target.is_file():
            continue
        try:
            raw = target.read_bytes()
            if ca in raw:
                continue
            backup = PROXY_DIR / "backups" / root.name / "cacert.pem"
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(target, backup)
            try:
                target.chmod(target.stat().st_mode | 0o200)
            except OSError:
                pass
            target.write_bytes(raw.rstrip() + PROXY_CA_MARKER + ca + b"\n")
            patched.append(target)
        except OSError:
            continue
    return patched


def restore_roblox_proxy_ca():
    backup_root = PROXY_DIR / "backups"
    if not backup_root.is_dir():
        return
    versions = {path.name: path for path in roblox_player_version_dirs()}
    for backup in backup_root.glob("*/cacert.pem"):
        root = versions.get(backup.parent.name)
        if root is None:
            continue
        target = root / "ssl" / "cacert.pem"
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup, target)
        except OSError:
            pass



def app_icon(name):
    path = ICON_DIR / f"{name}.png"
    if not path.is_file():
        return QIcon()
    settings = globals().get("VISUAL_ICON_THEME", {"hue": 0, "saturation": 100, "brightness": 100})
    try:
        hue = int(settings.get("hue", 0) or 0); saturation = int(settings.get("saturation", 100) or 100); brightness = int(settings.get("brightness", 100) or 100)
    except Exception:
        hue, saturation, brightness = 0, 100, 100
    if hue == 0 and saturation == 100 and brightness == 100:
        return QIcon(str(path))
    cache = globals().setdefault("VISUAL_ICON_CACHE", {})
    key = (str(path), hue, saturation, brightness)
    if key in cache: return cache[key]
    pixmap = QPixmap(str(path))
    if pixmap.isNull(): return QIcon()
    image = pixmap.toImage()
    for y in range(image.height()):
        for x in range(image.width()):
            color = image.pixelColor(x, y)
            if color.alpha() == 0: continue
            h, sat, val, alpha = color.getHsv()
            if h < 0:
                if hue: h = hue % 360; sat = max(sat, 155)
                else: h = 0
            else: h = (h + hue) % 360
            sat = max(0, min(255, int(sat * saturation / 100.0))); val = max(0, min(255, int(val * brightness / 100.0)))
            color.setHsv(h, sat, val, alpha); image.setPixelColor(x, y, color)
    icon = QIcon(QPixmap.fromImage(image)); cache[key] = icon; return icon


def lelsploit_icon():
    return QIcon(str(APP_ICON_PATH)) if APP_ICON_PATH.is_file() else QIcon()


def apply_window_icon(window):
    icon = lelsploit_icon()
    if not icon.isNull():
        window.setWindowIcon(icon)


def configure_windows_identity():
    if sys.platform != "win32":
        return
    try:
        ctypes.windll.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
    except Exception:
        pass
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID)
    except (AttributeError, OSError):
        pass


def read_limited(response, limit=SCRIPTBLOX_RESPONSE_LIMIT):
    data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("ScriptBlox response was too large.")
    return data


def extract_loadstring_url(source):
    if not isinstance(source, str):
        return None
    lowered = source.casefold()
    load_at = lowered.find("loadstring")
    if load_at < 0:
        return None


    fragment = source[load_at:load_at + 16384]
    http_at = fragment.casefold().find("httpget")
    if http_at < 0:
        return None
    tail = fragment[http_at:]
    match = re.search(
        r'''(?is)(?:["'](?P<quoted>https?://[^"']+)["']|\[\[(?P<bracket>https?://.*?)\]\])''',
        tail,
    )
    if not match:
        return None
    return (match.group("quoted") or match.group("bracket") or "").strip()


def normalize_http_url(url):
    value = (url or "").strip()
    if not value or any(char.isspace() for char in value):
        raise ValueError("Enter a valid URL.")
    if value.startswith("//"):
        value = "https:" + value
    parsed = urllib.parse.urlsplit(value)
    if not parsed.scheme:
        value = "https://" + value.lstrip("/")
        parsed = urllib.parse.urlsplit(value)
    if parsed.scheme.casefold() not in ("http", "https") or not parsed.netloc:
        raise ValueError("Enter a valid HTTP or HTTPS URL.")
    return urllib.parse.urlunsplit((
        parsed.scheme.casefold(), parsed.netloc, parsed.path, parsed.query, parsed.fragment
    ))


def make_loadstring_url(url):
    value = normalize_http_url(url)
    return f"loadstring(game:HttpGet({json.dumps(value, ensure_ascii=False)}))()"


def github_raw_url(url):
    value = normalize_http_url(url)
    parsed = urllib.parse.urlsplit(value)
    if parsed.netloc.casefold() not in ("github.com", "www.github.com"):
        raise ValueError("Enter a github.com URL.")
    path = parsed.path
    if "/blob/" not in path:
        raise ValueError("GitHub URL must contain /blob/.")
    before, after = path.split("/blob/", 1)
    if before.count("/") < 2 or not after:
        raise ValueError("GitHub blob URL is incomplete.")
    return urllib.parse.urlunsplit((
        "https", "raw.githubusercontent.com", f"{before}/{after}", "", ""
    ))


def stream_remote_text(output, request_id, url, cancelled, limit=TOOL_FETCH_LIMIT):
    def send(kind, payload=None):
        while not cancelled.is_set():
            try:
                output.put((kind, request_id, payload), timeout=0.1)
                return True
            except queue.Full:
                pass
        return False

    try:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            raise ValueError("Only http:// and https:// URLs are supported.")
        request = urllib.request.Request(
            url,
            headers={"Accept": "text/plain,*/*;q=0.8", "User-Agent": "LelSploit/1.0"},
        )
        total = 0
        with urllib.request.urlopen(request, timeout=15) as response:
            while not cancelled.is_set():
                chunk = response.read(READ_CHUNK)
                if not chunk:
                    send("done", total)
                    return
                total += len(chunk)
                if total > limit:
                    raise ValueError(
                        f"Response exceeded the {limit // (1024 * 1024)} MiB display limit."
                    )
                if not send("chunk", chunk):
                    return
    except Exception as exc:
        send("error", str(exc))


SCRIPTBLOX_USER_AGENT = "LelSploit ScriptBloxApi/1.0"


def scriptblox_curl_bytes(url, accept, timeout=12):
    curl = shutil.which("curl.exe") or shutil.which("curl")
    if not curl:
        raise OSError("curl is not available")
    result = subprocess.run(
        [
            curl, "-fLsS", "--compressed",
            "--connect-timeout", str(max(1, min(int(timeout), 10))),
            "--max-time", str(max(1, int(timeout))),
            "--retry", "2", "--retry-all-errors", "--retry-delay", "1",
            "-A", SCRIPTBLOX_USER_AGENT,
            "-H", f"Accept: {accept}",
            "-H", "Cache-Control: no-cache",
            "-H", "Referer: https://scriptblox.com/",
            url,
        ],
        capture_output=True,
        timeout=max(3, int(timeout) + 4),
        creationflags=NO_WINDOW,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ConnectionError(detail or f"curl failed with exit code {result.returncode}.")
    if len(result.stdout) > SCRIPTBLOX_RESPONSE_LIMIT:
        raise ValueError("ScriptBlox response was too large.")
    return result.stdout


def scriptblox_request_bytes(url, accept, timeout=20):
    request = urllib.request.Request(
        url,
        headers={
            "Accept": accept,
            "User-Agent": SCRIPTBLOX_USER_AGENT,
        },
    )
    retry_statuses = {429, 502, 503, 504}
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return read_limited(response)
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code in retry_statuses and attempt < 2:
                retry_after = 0.0
                if exc.code == 429:
                    try:
                        retry_after = float(exc.headers.get("Retry-After", 0) or 0)
                    except (TypeError, ValueError):
                        retry_after = 0.0
                time.sleep(min(4.0, max(retry_after, 0.45 * (2 ** attempt))))
                continue
            break
        except urllib.error.URLError as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(0.45 * (2 ** attempt))
                continue
            break

    if isinstance(last_error, urllib.error.HTTPError):
        detail = ""
        try:
            body = last_error.read(4096).decode("utf-8", errors="replace")
            payload = json.loads(body)
            if isinstance(payload, dict):
                detail = str(payload.get("message", "") or "").strip()
        except Exception:
            pass
        raise ConnectionError(
            detail or f"ScriptBlox request failed (HTTP {last_error.code})."
        ) from last_error

    try:
        return scriptblox_curl_bytes(url, accept, timeout)
    except Exception as curl_exc:
        if isinstance(last_error, urllib.error.URLError):
            reason = getattr(last_error, "reason", last_error)
            raise ConnectionError(f"Could not reach ScriptBlox: {reason}") from last_error
        raise ConnectionError(f"Could not reach ScriptBlox: {curl_exc}") from curl_exc


def scriptblox_catalog_request(endpoint, parameter_sets):
    errors = []
    seen = set()
    for params in parameter_sets:
        query = urllib.parse.urlencode(params)
        url = f"{SCRIPTBLOX_API}/{endpoint}" + (f"?{query}" if query else "")
        if url in seen:
            continue
        seen.add(url)
        try:
            raw = scriptblox_request_bytes(url, "application/json")
            payload = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(payload, dict):
                raise ValueError("ScriptBlox returned an invalid response.")
            if payload.get("message"):
                raise ValueError(str(payload["message"]))
            result = payload.get("result")
            if not isinstance(result, dict) or not isinstance(result.get("scripts"), list):
                raise ValueError("ScriptBlox returned an invalid result.")
            return result
        except Exception as exc:
            errors.append(str(exc))
    if errors:
        raise ConnectionError(errors[-1])
    raise ConnectionError("ScriptBlox did not return a usable response.")



SCRIPTBLOX_SITE = "https://scriptblox.com"
SCRIPTBLOX_RAW_SITE = "https://rawscripts.net/raw"


def _scriptblox_title_from_slug(slug):
    text = urllib.parse.unquote(str(slug or "")).strip("/")
    text = re.sub(r"-\d+$", "", text)
    text = text.replace("-", " ").replace("_", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text or "Untitled script"


def _scriptblox_parse_site_scripts(document, keyless=False):
    
    
    pattern = re.compile(
        r'<a\b[^>]*href\s*=\s*(?P<q>["\'])'
        r'(?:(?:https?:)?//(?:www\.)?scriptblox\.com)?'
        r'(?P<href>/script/[^"\']+)(?P=q)[^>]*>(?P<body>.*?)</a>',
        re.IGNORECASE | re.DOTALL,
    )
    scripts = []
    seen = set()
    for match in pattern.finditer(document):
        href = html.unescape(match.group("href"))
        slug = href.split("/script/", 1)[-1].split("?", 1)[0].split("#", 1)[0].strip("/")
        if not slug or slug in seen:
            continue
        body = re.sub(r"<[^>]+>", " ", match.group("body"))
        body = html.unescape(re.sub(r"\s+", " ", body)).strip()
        lowered = body.casefold()
        has_key = "key system" in lowered
        if keyless and has_key:
            continue
        paid = bool(re.search(r"\bpaid\b", lowered))
        universal = "universal script" in lowered
        patched = "patched" in lowered and "unpatched" not in lowered and "not patched" not in lowered
        seen.add(slug)
        scripts.append({
            "_id": slug,
            "slug": slug,
            "title": _scriptblox_title_from_slug(slug),
            "game": {"name": "Universal" if universal else "ScriptBlox"},
            "verified": "verified" in lowered,
            "key": has_key,
            "views": None,
            "scriptType": "paid" if paid else "free",
            "isUniversal": universal,
            "isPatched": patched,
            "_lelsploit_raw_url": f"{SCRIPTBLOX_RAW_SITE}/{urllib.parse.quote(slug, safe='')}",
        })
        if len(scripts) >= 20:
            break
    return scripts


def scriptblox_web_catalog(script_query, game_query, keyless, page):
    
    
    if int(page or 1) != 1:
        return {"scripts": [], "totalPages": 1, "nextPage": None, "_lelsploit_web": True}

    script_query = str(script_query or "").strip()
    game_query = str(game_query or "").strip()
    numeric_place = game_query.isdecimal()
    text_terms = [script_query]
    if game_query and not numeric_place:
        text_terms.append(game_query)
    query = " ".join(term for term in text_terms if term).strip()

    urls = []
    if numeric_place:
        
        
        urls.append(f"{SCRIPTBLOX_SITE}/game/{urllib.parse.quote(game_query, safe='')}")
    if query:
        urls.append(f"{SCRIPTBLOX_SITE}/?{urllib.parse.urlencode({'q': query})}")
    else:
        
        
        urls.append(f"{SCRIPTBLOX_SITE}/trending")

    last_error = None
    for url in urls:
        try:
            raw = scriptblox_request_bytes(url, "text/html,application/xhtml+xml")
            document = raw.decode("utf-8", errors="replace")
            scripts = _scriptblox_parse_site_scripts(document, keyless=keyless)
            if scripts:
                return {
                    "scripts": scripts,
                    "totalPages": 1,
                    "nextPage": None,
                    "_lelsploit_web": True,
                }
        except Exception as exc:
            last_error = exc

    if numeric_place and not query:
        
        
        try:
            raw = scriptblox_request_bytes(
                f"{SCRIPTBLOX_SITE}/trending", "text/html,application/xhtml+xml"
            )
            scripts = _scriptblox_parse_site_scripts(raw.decode("utf-8", errors="replace"), keyless=keyless)
            if scripts:
                return {
                    "scripts": scripts,
                    "totalPages": 1,
                    "nextPage": None,
                    "_lelsploit_web": True,
                }
        except Exception as exc:
            last_error = exc

    if last_error is not None:
        raise ConnectionError(str(last_error)) from last_error
    raise ConnectionError("ScriptBlox website did not return script cards.")


def scriptblox_raw_source(script_id, slug=None):
    script_id = str(script_id or "").strip()
    slug = str(slug or "").strip()
    candidates = []
    if script_id:
        candidates.append(f"{SCRIPTBLOX_API}/raw/{urllib.parse.quote(script_id, safe='')}")
    if slug and slug != script_id:
        candidates.append(f"{SCRIPTBLOX_API}/raw/{urllib.parse.quote(slug, safe='')}")
    raw_slug = slug or script_id
    if raw_slug:
        
        candidates.append(f"{SCRIPTBLOX_RAW_SITE}/{urllib.parse.quote(raw_slug, safe='')}")

    last_error = None
    for url in candidates:
        try:
            code = scriptblox_request_bytes(url, "text/plain,*/*;q=0.8").decode("utf-8-sig")
            if code.strip():
                return code
        except Exception as exc:
            last_error = exc
    if last_error is not None:
        raise last_error
    raise ValueError("ScriptBlox returned an empty script.")


def fetch_scriptblox(output, request_id, script_query, game_query,
                     sort_by, keyless, page, append):
    script_query = script_query.strip()
    game_query = game_query.strip()
    numeric_place = game_query.isdecimal()
    terms = [script_query]
    if game_query and not numeric_place:
        terms.append(game_query)
    query = " ".join(term for term in terms if term)
    endpoint = "search" if query else "fetch"

    full = {
        "max": 12,
        "page": page,
        "sortBy": sort_by,
        "order": "desc",
        "mode": "free",
        "patched": 0,
    }
    if query:
        full["q"] = query
        full["strict"] = "false"
    if numeric_place:
        full["placeId"] = game_query
    if keyless:
        full["key"] = 0

    
    
    
    stable = {
        "page": page,
        "max": 20,
        "sortBy": sort_by,
        "order": "desc",
    }
    if query:
        stable["q"] = query
        stable["strict"] = "false"
    if numeric_place:
        stable["placeId"] = game_query

    baseline = {"page": page, "max": 20}
    if query:
        baseline["q"] = query

    try:
        try:
            result = scriptblox_catalog_request(endpoint, (full, stable, baseline))
        except Exception:
            result = scriptblox_web_catalog(script_query, game_query, keyless, page)
        web_fallback = bool(result.get("_lelsploit_web"))
        scripts = [item for item in result.get("scripts", []) if isinstance(item, dict)]

        if keyless:
            scripts = [item for item in scripts if not bool(item.get("key"))]
        scripts = [
            item for item in scripts
            if str(item.get("scriptType", "free")).casefold() != "paid"
            and not bool(item.get("isPatched"))
        ]

        if game_query and not numeric_place and not web_fallback:
            wanted = game_query.casefold()
            scripts = [
                item for item in scripts
                if wanted in str(
                    item.get("game", {}).get("name", "")
                    if isinstance(item.get("game"), dict) else ""
                ).casefold()
            ]
        elif numeric_place:
            wanted = str(game_query)
            matching = []
            for item in scripts:
                game_data = item.get("game") if isinstance(item.get("game"), dict) else {}
                identifiers = {
                    str(game_data.get("gameId", "")),
                    str(game_data.get("placeId", "")),
                    str(game_data.get("_id", "")),
                }
                if wanted in identifiers:
                    matching.append(item)
            
            
            if matching:
                scripts = matching

        if sort_by in {"views", "likeCount"}:
            scripts.sort(
                key=lambda item: float(item.get(sort_by, 0) or 0),
                reverse=True,
            )
        elif sort_by in {"createdAt", "updatedAt"}:
            scripts.sort(key=lambda item: str(item.get(sort_by, "")), reverse=True)

        scripts = scripts[:12]
        total_pages = result.get("totalPages", page)
        try:
            total_pages = max(page, int(total_pages))
        except (TypeError, ValueError):
            total_pages = page
        next_page = result.get("nextPage")
        try:
            next_page = int(next_page) if next_page is not None else None
        except (TypeError, ValueError):
            next_page = page + 1 if page < total_pages else None
        if next_page is None and page < total_pages:
            next_page = page + 1
        if next_page is not None and next_page <= page:
            next_page = None
        output.put(("catalog", request_id, {
            "scripts": scripts,
            "page": page,
            "total_pages": total_pages,
            "next_page": next_page,
            "append": append,
        }))
    except Exception as exc:
        output.put(("catalog_error", request_id, str(exc)))


def roblox_processes():
    if sys.platform != "win32":
        return []
    result = subprocess.run(
        ["tasklist", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
        errors="replace",
        timeout=5,
        creationflags=NO_WINDOW,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.strip() or "tasklist failed"
        raise OSError(detail)
    found = []
    for row in csv.reader(result.stdout.splitlines()):
        if row and row[0].casefold() in ROBLOX_PLAYER_IMAGES:
            found.append(row[0])
    return list(dict.fromkeys(found))


def roblox_is_running():
    return bool(roblox_processes())


def current_roblox_join_context(require_running=True):
    if sys.platform != "win32":
        return None
    if require_running and not roblox_is_running():
        return None
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return None
    log_dir = Path(local_app_data) / "Roblox" / "logs"
    try:
        logs = [path for path in log_dir.glob("*.log") if "player" in path.name.casefold()]
        if not logs:
            logs = list(log_dir.glob("*.log"))
        log = max(logs, key=lambda path: path.stat().st_mtime_ns)
        log_mtime_ns = log.stat().st_mtime_ns
        with log.open("rb") as handle:
            handle.seek(0, 2)
            size = handle.tell()
            tail_start = max(0, size - 4_000_000)
            handle.seek(tail_start)
            data = handle.read()
    except (OSError, ValueError):
        return None
    matches = list(re.finditer(
        rb"! Joining game '([^']*)' place (\d+) at ",
        data,
    ))
    if not matches:
        return None
    match = matches[-1]
    try:
        job_id = match.group(1).decode("ascii", errors="ignore").strip()
        place_id = match.group(2).decode("ascii")
    except (UnicodeError, AttributeError):
        return None
    return {
        "place_id": place_id,
        "job_id": job_id,
        "log": str(log),
        "join_offset": int(tail_start + match.start()),
        "log_mtime_ns": int(log_mtime_ns),
    }


def roblox_join_signature(context):
    if not isinstance(context, dict):
        return None
    return (
        str(context.get("log", "")),
        int(context.get("join_offset", -1) or -1),
        str(context.get("place_id", "")),
        str(context.get("job_id", "")),
    )


def current_roblox_place_id():
    context = current_roblox_join_context(require_running=True)
    return context.get("place_id") if context else None



def roblox_process_ids():
    if sys.platform != "win32":
        return set()
    try:
        result = subprocess.run(
            ["tasklist", "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=5,
            creationflags=NO_WINDOW,
            check=False,
        )
    except Exception:
        return set()
    if result.returncode:
        return set()
    pids = set()
    for row in csv.reader(result.stdout.splitlines()):
        if len(row) < 2 or row[0].casefold() not in ROBLOX_PLAYER_IMAGES:
            continue
        try:
            pids.add(int(str(row[1]).replace(",", "")))
        except (TypeError, ValueError):
            pass
    return pids


def roblox_primary_window():
    if sys.platform != "win32":
        return None
    pids = roblox_process_ids()
    if not pids:
        return None
    try:
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        handles = []
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        def callback(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd):
                return True
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if int(pid.value) not in pids:
                return True
            rect = wintypes.RECT()
            if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
                return True
            width = max(0, rect.right - rect.left)
            height = max(0, rect.bottom - rect.top)
            if width >= 300 and height >= 200:
                handles.append((width * height, int(hwnd)))
            return True

        cb = callback_type(callback)
        user32.EnumWindows(cb, 0)
        return max(handles)[1] if handles else None
    except Exception:
        return None


def roblox_window_is_fullscreen(hwnd=None):
    if sys.platform != "win32":
        return False
    hwnd = int(hwnd or roblox_primary_window() or 0)
    if not hwnd:
        return False
    try:
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        rect = wintypes.RECT()
        if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
            return False
        monitor = user32.MonitorFromWindow(hwnd, 2)
        if not monitor:
            return False

        class MONITORINFO(ctypes.Structure):
            _fields_ = [
                ("cbSize", wintypes.DWORD),
                ("rcMonitor", wintypes.RECT),
                ("rcWork", wintypes.RECT),
                ("dwFlags", wintypes.DWORD),
            ]

        info = MONITORINFO()
        info.cbSize = ctypes.sizeof(info)
        if not user32.GetMonitorInfoW(monitor, ctypes.byref(info)):
            return False
        m = info.rcMonitor
        tolerance = 3
        return (
            abs(rect.left - m.left) <= tolerance
            and abs(rect.top - m.top) <= tolerance
            and abs(rect.right - m.right) <= tolerance
            and abs(rect.bottom - m.bottom) <= tolerance
        )
    except Exception:
        return False


def exit_roblox_fullscreen_for_attach():
    hwnd = roblox_primary_window()
    if not hwnd or not roblox_window_is_fullscreen(hwnd):
        return False
    try:
        user32 = ctypes.windll.user32
        WM_KEYDOWN = 0x0100
        WM_KEYUP = 0x0101
        WM_SYSKEYDOWN = 0x0104
        WM_SYSKEYUP = 0x0105
        VK_F11 = 0x7A
        VK_RETURN = 0x0D

        user32.PostMessageW(hwnd, WM_KEYDOWN, VK_F11, 0)
        user32.PostMessageW(hwnd, WM_KEYUP, VK_F11, 0)
        time.sleep(0.35)
        if roblox_window_is_fullscreen(hwnd):
            alt_context = 1 << 29
            user32.PostMessageW(hwnd, WM_SYSKEYDOWN, VK_RETURN, alt_context)
            user32.PostMessageW(hwnd, WM_SYSKEYUP, VK_RETURN, alt_context)
            time.sleep(0.35)
        return not roblox_window_is_fullscreen(hwnd)
    except Exception:
        return False

def roblox_join_deeplink(place_id, game_instance_id=None):
    place_id = str(place_id or "").strip()
    if not place_id.isdecimal():
        raise ValueError("A valid Roblox place ID is required.")
    params = {"placeId": place_id}
    game_instance_id = str(game_instance_id or "").strip()
    if game_instance_id:
        params["gameInstanceId"] = game_instance_id
    return "roblox://experiences/start?" + urllib.parse.urlencode(params)


def latest_roblox_player():
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return None
    candidates = list(
        (Path(local_app_data) / "Roblox" / "Versions").glob(
            "version-*/RobloxPlayerBeta.exe"
        )
    )
    candidates = [path for path in candidates if path.is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime_ns)


def wait_for_roblox(expected, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if roblox_is_running() is expected:
            return True
        time.sleep(0.35)
    return roblox_is_running() is expected


def start_roblox(env=None, deeplink=None):
    if sys.platform != "win32":
        raise OSError("Roblox controls are available on Windows.")
    player = latest_roblox_player()
    launch_uri = str(deeplink or "").strip()
    if player is not None:
        command = [str(player)]
        if launch_uri:
            command.append(launch_uri)
        subprocess.Popen(
            command,
            cwd=str(player.parent),
            close_fds=True,
            creationflags=NO_WINDOW,
            env=env,
        )
    else:
        if env:
            raise OSError("The Roblox web player was not found, so LelSploit cannot launch it through the local proxy.")
        os.startfile(launch_uri or "roblox://")
    if not wait_for_roblox(True):
        raise TimeoutError("Roblox did not start within 12 seconds.")


def end_roblox():
    if sys.platform != "win32":
        raise OSError("Roblox controls are available on Windows.")
    for image_name in roblox_processes():
        subprocess.run(
            ["taskkill", "/F", "/T", "/IM", image_name],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=8,
            creationflags=NO_WINDOW,
            check=False,
        )
    if not wait_for_roblox(False, timeout=6):
        raise TimeoutError("Roblox is still running.")


def fetch_scriptblox_raw(output, script_id, title, slug=None):
    try:
        code = scriptblox_raw_source(script_id, slug)
        output.put(("install", title, code))
    except Exception as exc:
        output.put(("install_error", title, str(exc)))


def fetch_scriptblox_saved_raw(output, key, script_id, slug=None):
    try:
        code = scriptblox_raw_source(script_id, slug)
        output.put(("save", key, code))
    except Exception as exc:
        output.put(("save_error", key, str(exc)))


def stream_file(path, output, cancelled):
    def send(kind, payload=None):
        while not cancelled.is_set():
            try:
                output.put((kind, payload), timeout=0.1)
                return True
            except queue.Full:
                pass
        return False

    try:
        with Path(path).open("rb") as handle:

            decoder = codecs.getincrementaldecoder("utf-8-sig")("strict")
            first = decoder.decode(handle.read(READ_CHUNK)).encode("utf-8")
            if not send("start", first):
                return
            while not cancelled.is_set():
                raw = handle.read(READ_CHUNK)
                if not raw:
                    tail = decoder.decode(b"", final=True).encode("utf-8")
                    if tail and not send("chunk", tail):
                        return
                    send("end")
                    return
                chunk = decoder.decode(raw).encode("utf-8")
                if chunk and not send("chunk", chunk):
                    return
    except (OSError, UnicodeError, MemoryError) as exc:
        send("error", str(exc))


try:
    from PyQt6.QtCore import Qt, QTimer, QSize, QEvent, QRectF, QPoint, QObject, pyqtSignal, QPropertyAnimation, QEasingCurve
    from PyQt6.QtGui import (
        QAction, QColor, QFont, QIcon, QPixmap, QKeySequence, QShortcut, QTextCharFormat, QTextCursor, QTextDocument, QPainter, QPainterPath, QRegion, QSyntaxHighlighter,
    )
    from PyQt6.QtWidgets import (
        QApplication, QCheckBox, QColorDialog, QComboBox, QDialog, QFileDialog, QFrame, QInputDialog,
        QGridLayout, QHBoxLayout, QLabel, QLineEdit, QMainWindow, QMenu, QMessageBox, QPlainTextEdit,
        QPushButton, QScrollArea, QStackedWidget, QTabWidget, QTabBar, QTextBrowser, QVBoxLayout, QWidget, QGraphicsOpacityEffect, QButtonGroup,
        QListWidget, QListWidgetItem, QAbstractItemView, QAbstractScrollArea, QSystemTrayIcon, QSpinBox, QSlider, QHeaderView, QTableWidget, QTableWidgetItem,
    )
    from PyQt6.Qsci import QsciScintilla, QsciLexerLua
except ImportError as exc:
    message = (
        "LelSploit could not load its editor dependencies.\n\n"
        "Install them with: python -m pip install PyQt6-QScintilla\n\n"
        f"Details: {exc}"
    )
    try:
        (BASE_DIR / "startup_error.log").write_text(message, encoding="utf-8")
    except Exception:
        pass
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(None, message, "LelSploit", 0x10)
        except Exception:
            pass
    raise SystemExit(message) from exc


class CaptureExclusionService(QObject):
    def __init__(self, owner):
        super().__init__(owner)
        self.owner = owner
        self._applied_hwnds = set()
        self._taskbar_styles = {}
        app = QApplication.instance()
        if app is not None:
            app.installEventFilter(self)

    @staticmethod
    def _eligible(widget):
        if not isinstance(widget, QWidget) or not widget.isWindow():
            return False
        window_type = widget.windowType()
        return window_type not in {
            Qt.WindowType.Popup,
            Qt.WindowType.ToolTip,
            Qt.WindowType.SplashScreen,
            Qt.WindowType.Desktop,
        }

    def apply_widget(self, widget, enabled=None):
        if sys.platform != "win32" or not self._eligible(widget):
            return
        if enabled is None:
            enabled = self.owner.screen_capture_hidden()
        try:
            hwnd = int(widget.winId())
        except (RuntimeError, TypeError, ValueError):
            return
        if not hwnd:
            return
        if enabled and hwnd not in self._taskbar_styles:
            original_style = get_window_exstyle(hwnd)
            if original_style is not None:
                self._taskbar_styles[hwnd] = original_style
        restore_style = self._taskbar_styles.get(hwnd)
        capture_ok = set_window_capture_exclusion(hwnd, bool(enabled))
        taskbar_ok = set_window_taskbar_hidden(hwnd, bool(enabled), restore_style)
        if capture_ok:
            if enabled:
                self._applied_hwnds.add(hwnd)
            else:
                self._applied_hwnds.discard(hwnd)
        if not enabled and taskbar_ok:
            self._taskbar_styles.pop(hwnd, None)

    def apply_all(self, enabled=None):
        if sys.platform != "win32":
            return
        if enabled is None:
            enabled = self.owner.screen_capture_hidden()
        app = QApplication.instance()
        if enabled:
            if app is None:
                return
            for widget in app.topLevelWidgets():
                if isinstance(widget, QWidget) and widget.isVisible():
                    self.apply_widget(widget, True)
            return
        for hwnd in tuple(self._applied_hwnds):
            set_window_capture_exclusion(hwnd, False)
        self._applied_hwnds.clear()
        for hwnd, original_style in tuple(self._taskbar_styles.items()):
            set_window_taskbar_hidden(hwnd, False, original_style)
        self._taskbar_styles.clear()
        if app is not None:
            for widget in app.topLevelWidgets():
                if isinstance(widget, QWidget) and widget.isVisible():
                    self.apply_widget(widget, False)

    def eventFilter(self, watched, event):
        try:
            if (
                event.type() == QEvent.Type.Show
                and self.owner.screen_capture_hidden()
                and self._eligible(watched)
            ):
                QTimer.singleShot(0, lambda widget=watched: self.apply_widget(widget, True))
        except RuntimeError:
            pass
        return False


class SmoothScrollService(QObject):
    """Global wheel/trackpad smoothing. Extensions may tune it, but it is built in by default."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self._claims = {}
        self._default = (165, 1.0)
        self._installed = False
        self._animations = {}
        self._targets = {}
        QTimer.singleShot(0, self._apply_state)

    @staticmethod
    def _clamp(value, low, high):
        return max(low, min(high, value))

    def set_extension(self, ext_id, enabled=True, duration=165, strength=1.0):
        ext_id = str(ext_id or '').strip()
        if not ext_id:
            return
        if enabled:
            try:
                duration = int(duration)
            except (TypeError, ValueError):
                duration = 165
            try:
                strength = float(strength)
            except (TypeError, ValueError):
                strength = 1.0
            self._claims[ext_id] = (
                self._clamp(duration, 70, 450),
                self._clamp(strength, 0.35, 3.0),
            )
        else:
            self._claims.pop(ext_id, None)
        self._apply_state()

    def retain_extensions(self, enabled_ids):
        enabled_ids = set(enabled_ids or ())
        for ext_id in list(self._claims):
            if ext_id not in enabled_ids:
                self._claims.pop(ext_id, None)
        self._apply_state()

    def _apply_state(self):
        app = QApplication.instance()
        
        should_install = app is not None
        if should_install and not self._installed:
            app.installEventFilter(self)
            self._installed = True
        elif not should_install and self._installed:
            try:
                app.removeEventFilter(self)
            except Exception:
                pass
            self._installed = False
            self._stop_all()

    def _stop_all(self):
        for animation in list(self._animations.values()):
            try:
                animation.stop()
            except Exception:
                pass
        self._targets.clear()

    def _forget_bar(self, key):
        self._targets.pop(key, None)
        animation = self._animations.pop(key, None)
        if animation is not None:
            try:
                animation.stop()
                animation.deleteLater()
            except Exception:
                pass

    def _config(self):
        if not self._claims:
            return self._default
        
        return next(reversed(self._claims.values()))

    @staticmethod
    def _scroll_area_for(watched):
        node = watched
        for _ in range(10):
            if isinstance(node, QAbstractScrollArea):
                return node
            try:
                node = node.parentWidget() if isinstance(node, QWidget) else node.parent()
            except Exception:
                return None
            if node is None:
                return None
        return None

    def _animate(self, bar, movement, duration, strength):
        if bar is None or bar.maximum() <= bar.minimum():
            return False
        key = id(bar)
        current = int(bar.value())
        base = int(self._targets.get(key, current))
        if base < bar.minimum() or base > bar.maximum():
            base = current
        target = int(round(base - (float(movement) * float(strength))))
        target = int(self._clamp(target, int(bar.minimum()), int(bar.maximum())))
        if target == current and target == base:
            return False

        animation = self._animations.get(key)
        if animation is None:
            animation = QPropertyAnimation(bar, b"value", self)
            self._animations[key] = animation
            try:
                bar.destroyed.connect(lambda *_, k=key: self._forget_bar(k))
            except Exception:
                pass
        else:
            animation.stop()

        self._targets[key] = target
        animation.setStartValue(current)
        animation.setEndValue(target)
        animation.setDuration(int(duration))
        animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        animation.start()
        return True

    def eventFilter(self, watched, event):
        if event.type() != QEvent.Type.Wheel:
            return False

        
        try:
            modifiers = event.modifiers()
            if modifiers & Qt.KeyboardModifier.ControlModifier:
                return False
        except Exception:
            modifiers = Qt.KeyboardModifier.NoModifier

        area = self._scroll_area_for(watched)
        if area is None:
            return False

        try:
            pixel = event.pixelDelta()
            angle = event.angleDelta()
        except Exception:
            return False

        shift = bool(modifiers & Qt.KeyboardModifier.ShiftModifier)
        horizontal = shift or abs(angle.x()) > abs(angle.y()) or abs(pixel.x()) > abs(pixel.y())
        bar = area.horizontalScrollBar() if horizontal else area.verticalScrollBar()
        if bar is None or bar.maximum() <= bar.minimum():
            
            bar = area.verticalScrollBar() if horizontal else area.horizontalScrollBar()
            horizontal = not horizontal
            if bar is None or bar.maximum() <= bar.minimum():
                return False

        component_pixel = pixel.x() if horizontal and pixel.x() else pixel.y()
        component_angle = angle.x() if horizontal and angle.x() else angle.y()
        if horizontal and shift and not component_pixel and not component_angle:
            component_pixel = pixel.y()
            component_angle = angle.y()

        if component_pixel:
            
            step = max(1, int(bar.singleStep()))
            movement = (float(component_pixel) / 40.0) * (3.0 * step)
            duration_scale = 0.72
        elif component_angle:
            notches = float(component_angle) / 120.0
            movement = notches * (3.0 * max(1, int(bar.singleStep())))
            duration_scale = 1.0
        else:
            return False

        try:
            if event.inverted():
                movement = -movement
        except Exception:
            pass

        duration, strength = self._config()
        if self._animate(bar, movement, max(55, int(duration * duration_scale)), strength):
            event.accept()
            return True
        return False


BLUR_STYLESHEET = r"""
    QMainWindow, QDialog {
        background: #08090a;
        color: #e8e9ea;
    }
    QWidget#blurWindowBody {
        background: #0b0c0d;
        border: none;
    }
    QFrame#blurTitleBar {
        background: #0c0d0e;
        border: none;
        border-bottom: 1px solid #232629;
    }
    QLabel#blurWindowIcon {
        background: transparent;
        border: none;
    }
    QLabel#blurWindowTitle {
        background: transparent;
        color: #e1e3e4;
        font-weight: 800;
        padding-left: 2px;
    }
    QLabel, QCheckBox {
        background: transparent;
    }
    QLabel { color: #b7bbbd; }
    QPushButton {
        background: #101214;
        color: #e8e9ea;
        border: 1px solid #2d3235;
        border-radius: 8px;
        padding: 7px 12px;
    }
    QPushButton:hover {
        background: #1b1e20;
        border-color: #3a4044;
    }
    QPushButton:pressed { background: #0f1113; }
    QPushButton:disabled {
        background: #0e1011;
        color: #72787b;
        border-color: #252a2d;
    }
    QPushButton:checked {
        background: #131517;
        border-color: #3a4044;
    }
    QPushButton#blurWindowControl, QPushButton#blurPinButton, QPushButton#blurCloseButton {
        background: transparent;
        border: 1px solid transparent;
        border-radius: 7px;
        padding: 0;
        color: #d7dbd8;
        font-size: 16px;
        font-weight: 500;
    }
    QPushButton#blurWindowControl:hover, QPushButton#blurPinButton:hover {
        background: #131614;
        border-color: #272d29;
    }
    QPushButton#blurPinButton:checked {
        background: #141715;
        border-color: #464e49;
    }
    QPushButton#blurCloseButton:hover {
        background: #b83a3a;
        border-color: #c94a4a;
        color: #ffffff;
    }
    QLineEdit, QPlainTextEdit, QComboBox, QsciScintilla {
        background: #111315;
        color: #eceeef;
        border: 1px solid #2b3033;
        border-radius: 8px;
        selection-background-color: #30363a;
        selection-color: #ffffff;
    }
    QLineEdit, QComboBox {
        padding: 7px 9px;
        min-height: 20px;
    }
    QComboBox {
        padding-right: 34px;
        background: #141719;
        border: 1px solid #30363a;
        border-radius: 8px;
    }
    QComboBox:hover {
        background: #1b1f21;
        border-color: #42494d;
    }
    QComboBox:focus, QComboBox:on {
        background: #1b1f21;
        border-color: #50585d;
    }
    QComboBox::drop-down {
        subcontrol-origin: padding;
        subcontrol-position: top right;
        width: 30px;
        background: transparent;
        border: none;
    }
    QComboBox::drop-down:hover {
        background: transparent;
        border: none;
    }
    QComboBox::down-arrow {
        width: 9px;
        height: 9px;
    }
    QLineEdit:focus, QPlainTextEdit:focus {
        border-color: #4b5358;
    }
    QSlider {
        background: transparent;
        border: none;
        padding: 0;
    }
    QSlider::groove:horizontal {
        height: 4px;
        background: #303538;
        border: none;
        border-radius: 2px;
    }
    QSlider::sub-page:horizontal {
        background: #646b6f;
        border-radius: 2px;
    }
    QSlider::add-page:horizontal {
        background: #272c2f;
        border-radius: 2px;
    }
    QSlider::handle:horizontal {
        width: 12px;
        margin: -4px 0;
        background: #92989b;
        border: 1px solid #adb2b5;
        border-radius: 6px;
    }
    QSlider::handle:horizontal:hover {
        background: #b1b6b9;
        border-color: #c8ccce;
    }
    QComboBox QAbstractItemView {
        background: #101214;
        color: #e5e7e8;
        border: 1px solid #343a3e;
        border-radius: 9px;
        padding: 5px;
        selection-background-color: transparent;
        selection-color: #ffffff;
        outline: none;
    }
    QComboBox QAbstractItemView::item {
        min-height: 28px;
        padding: 5px 9px;
        margin: 1px 0;
        border: none;
        border-radius: 6px;
    }
    QComboBox QAbstractItemView::item:hover {
        background: #1b1f21;
        color: #ffffff;
    }
    QComboBox QAbstractItemView::item:selected {
        background: #22272a;
        color: #ffffff;
    }
    QTabWidget::pane {
        background: #0b0c0d;
        border: 1px solid #2b3033;
        border-radius: 9px;
        top: -1px;
    }
    QTabWidget#editorTabs {
        background: #0b0c0d;
        border: none;
        border-radius: 10px;
        margin: 0;
        padding: 0;
    }
    QTabWidget#editorTabs::pane {
        background: #0b0c0d;
        border: 0px;
        border-radius: 10px;
        margin: 0;
        padding: 0;
        top: 0;
    }
    QTabWidget#editorTabs QTabBar {
        background: #0a0b0c;
        border: 0px;
        margin: 0;
        padding: 0;
    }
    QTabWidget#editorTabs QTabBar::tab {
        min-width: 82px;
        max-width: 190px;
        min-height: 27px;
        padding: 2px 7px 2px 10px;
        margin: 0px 3px 2px 0;
        background: #131517;
        color: #ffffff;
        border: none;
        border-radius: 3px;
    }
    QTabWidget#editorTabs QTabBar::tab:hover {
        background: #131517;
        color: #ffffff;
    }
    QTabWidget#editorTabs QTabBar::tab:selected {
        background: #1e2225;
        color: #ffffff;
    }
    QPushButton#tabAddButton, QPushButton#tabHoverClose {
        background: transparent;
        border: none;
        border-radius: 4px;
        padding: 0;
    }
    QPushButton#tabAddButton:hover, QPushButton#tabHoverClose:hover {
        background: #1e2225;
    }
    QLineEdit#tabRenameEdit {
        background: #15181a;
        color: #f0f2f3;
        border: 1px solid #4a5257;
        border-radius: 4px;
        padding: 1px 5px;
        min-height: 18px;
    }
    QTabBar::tab {
        background: #0f1113;
        color: #b6bbbe;
        border: 1px solid #292e31;
        padding: 8px 14px;
        margin-right: 4px;
        border-radius: 7px;
    }
    QTabBar::tab:hover { color: #eeeeee; background: #131517; }
    QTabBar::tab:selected {
        background: #1b1f21;
        color: #ffffff;
        border-color: #38413c;
    }
    QFrame#scriptCard, QFrame#fastFlagCard {
        background: #0d0f0e;
        border: 1px solid #272727;
        border-radius: 9px;
    }
    QFrame#fastFlagManagerCard {
        background: #0b0c0b;
        border: 1px solid #303030;
        border-radius: 9px;
    }
    QPushButton#keylessButton {
        background: #0c0d0e;
        color: #bdbdbd;
        border: 1px solid #2b302d;
        border-radius: 8px;
        font-weight: 600;
    }
    QPushButton#keylessButton:hover {
        background: #131614;
        color: #e6e9e7;
        border-color: #3a423d;
    }
    QPushButton#keylessButton:checked {
        background: #12351e;
        color: #82eca0;
        border-color: #397f4b;
    }
    QPushButton#keylessButton:checked:hover {
        background: #184527;
        color: #9af4b2;
        border-color: #4d9a61;
    }
    QFrame#restartBar {
        background: #0b0d0c;
        border: 1px solid #272d29;
        border-radius: 8px;
    }
    QPushButton#iconButton {
        background: #0d0f0e;
        border: 1px solid #292929;
        border-radius: 8px;
        padding: 0;
    }
    QPushButton#iconButton:hover { background: #151816; border-color: #3a423d; }
    QPushButton#fastFlagCheck {
        background: #08090a;
        color: #ffffff;
        border: 1px solid #49534d;
        border-radius: 5px;
        padding: 0;
        font-size: 15px;
        font-weight: 700;
    }
    QPushButton#fastFlagCheck:hover { background: #101211; border-color: #777777; }
    QPushButton#fastFlagCheck:checked { background: #356846; border-color: #6da17d; }
    QPushButton#resetLink {
        background: transparent;
        border: none;
        color: #aaaaaa;
        padding: 6px 2px;
        text-align: left;
    }
    QPushButton#resetLink:hover { background: transparent; color: #e6e9e7; }
    QPushButton#dangerButton {
        background: #4b2020;
        color: #ffffff;
        border: 1px solid #7f3838;
        font-weight: 600;
    }
    QPushButton#dangerButton:hover { background: #672828; border-color: #a14747; }
    QScrollArea, QScrollArea > QWidget > QWidget {
        background: #0b0c0d;
        border: none;
    }
    QMenu {
        background: #131517;
        color: #e6e9e7;
        border: 1px solid #2b302d;
        border-radius: 7px;
        padding: 4px;
    }
    QMenu::item { padding: 7px 20px 7px 10px; border-radius: 5px; }
    QMenu::item:selected { background: #262b28; }
    QToolTip {
        background: #0c0d0e;
        color: #e6e9e7;
        border: 1px solid #2b302d;
        padding: 5px;
    }
    QScrollBar { background: #08090a; border: none; }
    QScrollBar:vertical { width: 10px; }
    QScrollBar:horizontal { height: 10px; }
    QScrollBar::handle {
        background: #303733;
        border-radius: 4px;
        min-width: 24px;
        min-height: 24px;
    }
    QScrollBar::handle:hover { background: #555555; }
    QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
"""


def apply_blur_style(widget):
    widget.setStyleSheet(widget.styleSheet() + "\n" + BLUR_STYLESHEET)



class LelComboBox(QComboBox):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMaxVisibleItems(10)
        self._popup_menu = None
        self._pressed_inside = False

    def _clear_popup_menu(self):
        menu = self._popup_menu
        if menu is not None and not menu.isVisible():
            self._popup_menu = None

    def _select_popup_item(self, index):
        if 0 <= index < self.count():
            self.setCurrentIndex(index)
        self.hidePopup()

    def _build_popup_menu(self):
        menu = QMenu(self.window())
        menu.setObjectName("lelComboMenu")
        menu.setMinimumWidth(max(self.width(), 180))
        menu.setStyleSheet("""
            QMenu#lelComboMenu {
                background: #151517;
                color: #eeeeee;
                border: 1px solid #343438;
                border-radius: 8px;
                padding: 5px;
            }
            QMenu#lelComboMenu::item {
                min-height: 25px;
                padding: 6px 12px;
                margin: 1px;
                border-radius: 6px;
            }
            QMenu#lelComboMenu::item:selected {
                background: #252529;
                color: #ffffff;
            }
        """)
        current = self.currentIndex()
        for index in range(self.count()):
            label = self.itemText(index).replace("&", "&&")
            action = QAction(("✓  " if index == current else "   ") + label, menu)
            model_index = self.model().index(index, 0)
            action.setEnabled(bool(self.model().flags(model_index) & Qt.ItemFlag.ItemIsEnabled))
            action.triggered.connect(lambda checked=False, i=index: self._select_popup_item(i))
            menu.addAction(action)
        menu.aboutToHide.connect(lambda: QTimer.singleShot(0, self._clear_popup_menu))
        return menu

    def showPopup(self):
        if self._popup_menu is not None and self._popup_menu.isVisible():
            return
        self._popup_menu = self._build_popup_menu()
        self._popup_menu.popup(self.mapToGlobal(QPoint(0, self.height() + 3)))

    def hidePopup(self):
        if self._popup_menu is not None:
            self._popup_menu.close()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._pressed_inside = self.rect().contains(event.position().toPoint())
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            inside = self._pressed_inside and self.rect().contains(event.position().toPoint())
            self._pressed_inside = False
            if inside:
                if self._popup_menu is not None and self._popup_menu.isVisible():
                    self.hidePopup()
                else:
                    self.showPopup()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key.Key_Space, Qt.Key.Key_Return, Qt.Key.Key_Enter, Qt.Key.Key_Down) and event.modifiers() in (Qt.KeyboardModifier.NoModifier, Qt.KeyboardModifier.AltModifier):
            if self._popup_menu is not None and self._popup_menu.isVisible():
                self.hidePopup()
            else:
                self.showPopup()
            event.accept()
            return
        if event.key() == Qt.Key.Key_Escape and self._popup_menu is not None and self._popup_menu.isVisible():
            self.hidePopup()
            event.accept()
            return
        super().keyPressEvent(event)


class JumpSlider(QSlider):
    def __init__(self, orientation=Qt.Orientation.Horizontal, parent=None):
        super().__init__(orientation, parent)
        self._jump_dragging = False
        self.setCursor(Qt.CursorShape.PointingHandCursor)

    def _set_from_position(self, point):
        if self.orientation() == Qt.Orientation.Horizontal:
            handle = 6.0
            span = max(1.0, self.width() - handle * 2.0)
            position = max(0.0, min(span, float(point.x()) - handle))
            ratio = position / span
        else:
            handle = 6.0
            span = max(1.0, self.height() - handle * 2.0)
            position = max(0.0, min(span, float(point.y()) - handle))
            ratio = 1.0 - (position / span)
        value = self.minimum() + round(ratio * (self.maximum() - self.minimum()))
        self.setValue(max(self.minimum(), min(self.maximum(), value)))

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._jump_dragging = True
            self._set_from_position(event.position())
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._jump_dragging:
            self._set_from_position(event.position())
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self._jump_dragging:
            self._set_from_position(event.position())
            self._jump_dragging = False
            event.accept()
            return
        super().mouseReleaseEvent(event)


class TabCloseButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._opacity = QGraphicsOpacityEffect(self)
        self._opacity.setOpacity(0.62)
        self.setGraphicsEffect(self._opacity)

    def enterEvent(self, event):
        self._opacity.setOpacity(1.0)
        self.setIconSize(QSize(11, 11))
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._opacity.setOpacity(0.62)
        self.setIconSize(QSize(10, 10))
        super().leaveEvent(event)


class EditorTabBar(QTabBar):
    closeRequested = pyqtSignal(int)
    newRequested = pyqtSignal()
    renameRequested = pyqtSignal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMouseTracking(True)
        self.setDrawBase(False)
        self.setExpanding(False)
        self.setUsesScrollButtons(False)
        self.setElideMode(Qt.TextElideMode.ElideRight)
        self.setIconSize(QSize(13, 13))
        self.setMovable(True)
        self.setMinimumHeight(30)
        self.setMinimumWidth(30)
        self._hover_index = -1
        self.new_button = QPushButton(parent if parent is not None else self)
        self.new_button.setObjectName("tabAddButton")
        self.new_button.setFixedSize(24, 24)
        icon = app_icon("new")
        if not icon.isNull():
            self.new_button.setIcon(icon)
            self.new_button.setIconSize(QSize(12, 12))
        self.new_button.clicked.connect(self.newRequested.emit)
        self.new_button.show()

    def sizeHint(self):
        size = super().sizeHint()
        return QSize(max(30, size.width() + 30), max(30, size.height()))

    def minimumSizeHint(self):
        size = super().minimumSizeHint()
        return QSize(max(30, size.width() + 30), max(30, size.height()))

    def install_close_button(self, index):
        button = TabCloseButton(self)
        button.setObjectName("tabHoverClose")
        button.setFixedSize(22, 18)
        button.setStyleSheet("padding: 0 4px 3px 0; background: transparent; border: none;")
        icon = app_icon("close")
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(10, 10))
        button.hide()
        button.clicked.connect(lambda checked=False, b=button: self._close_button_clicked(b))
        self.setTabButton(index, QTabBar.ButtonPosition.RightSide, button)
        QTimer.singleShot(0, self._place_new_button)

    def _close_button_clicked(self, button):
        for index in range(self.count()):
            if self.tabButton(index, QTabBar.ButtonPosition.RightSide) is button:
                self.closeRequested.emit(index)
                return

    def _set_hover_index(self, index):
        if index == self._hover_index:
            return
        for i in range(self.count()):
            button = self.tabButton(i, QTabBar.ButtonPosition.RightSide)
            if button is not None:
                button.setVisible(i == index)
        self._hover_index = index

    def _place_new_button(self):
        host = self.new_button.parentWidget()
        if host is None:
            return
        origin = self.mapTo(host, QPoint(0, 0))
        if self.count():
            rect = self.tabRect(self.count() - 1)
            desired_x = origin.x() + rect.x() + rect.width() + 5
        else:
            desired_x = origin.x() + 2
        max_x = max(2, host.width() - self.new_button.width() - 2)
        x = max(2, min(desired_x, max_x))
        y = origin.y() + max(2, (self.height() - self.new_button.height()) // 2)
        self.new_button.move(x, y)
        self.new_button.raise_()

    def mouseMoveEvent(self, event):
        self._set_hover_index(self.tabAt(event.position().toPoint()))
        super().mouseMoveEvent(event)
        self._place_new_button()

    def leaveEvent(self, event):
        self._set_hover_index(-1)
        super().leaveEvent(event)

    def mousePressEvent(self, event):
        index = self.tabAt(event.position().toPoint())
        if event.button() == Qt.MouseButton.RightButton and index >= 0:
            self.closeRequested.emit(index)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseDoubleClickEvent(self, event):
        index = self.tabAt(event.position().toPoint())
        if event.button() == Qt.MouseButton.LeftButton and index >= 0:
            self.renameRequested.emit(index)
            event.accept()
            return
        super().mouseDoubleClickEvent(event)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._place_new_button()

    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        QTimer.singleShot(0, self._place_new_button)

    def wheelEvent(self, event):
        if self.count() < 2:
            event.ignore()
            return
        delta = event.angleDelta().y() or event.angleDelta().x()
        if not delta:
            event.ignore()
            return
        step = -1 if delta > 0 else 1
        current = self.currentIndex()
        if current < 0:
            current = 0
        target = max(0, min(self.count() - 1, current + step))
        if target != current:
            self.setCurrentIndex(target)
            QTimer.singleShot(0, self._place_new_button)
        event.accept()

    def tabInserted(self, index):
        super().tabInserted(index)
        QTimer.singleShot(0, self._place_new_button)

    def tabRemoved(self, index):
        super().tabRemoved(index)
        self._hover_index = -1
        QTimer.singleShot(0, self._place_new_button)


class EditorTabs(QTabWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._editor_bar = EditorTabBar(self)
        self.setTabBar(self._editor_bar)


class EditorPage(QWidget):
    def __init__(self, editor, parent=None):
        super().__init__(parent)
        self._lel_editor = editor
        self.setObjectName("editorPage")
        self.setContentsMargins(0, 0, 0, 0)
        padding = max(0, int(ui_config("editor", "inner_padding", 1)))
        radius = max(0, int(ui_config("editor", "corner_radius", 4)))
        background = str(getattr(editor, "_lel_background", ui_config("editor", "background", "#121416")))
        self.setStyleSheet(f"QWidget#editorPage {{ background: {background}; border: none; border-radius: {radius}px; }}")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(padding, padding, padding, padding)
        layout.setSpacing(0)
        layout.addWidget(editor)


class BlurTitleBar(QFrame):
    ROUND_RADIUS = 12

    def __init__(self, window, title):
        super().__init__(window)
        self.owner_window = window
        self._drag_global = None
        self._drag_window = None
        self._pinned = False
        self.setObjectName("blurTitleBar")
        self.setFixedHeight(39)

        row = QHBoxLayout(self)
        row.setContentsMargins(8, 5, 6, 5)
        row.setSpacing(5)

        if title != "LelSploit":
            title_icon = QLabel()
            title_icon.setObjectName("blurWindowIcon")
            title_icon.setFixedSize(20, 20)
            icon = lelsploit_icon()
            if not icon.isNull():
                title_icon.setPixmap(icon.pixmap(16, 16))
            row.addWidget(title_icon)

        title_label = QLabel(title)
        title_label.setObjectName("blurWindowTitle")
        if title == "LelSploit":
            title_label.setStyleSheet(
                f"background:transparent;color:{ui_config('title','color','#e3e5e6')};"
                f"font-size:{int(ui_config('title','font_size',14))}px;"
                f"font-weight:{int(ui_config('title','font_weight',800))};"
                f"font-style:{ui_config('title','font_style','oblique')};"
            )
        row.addWidget(title_label)
        row.addStretch(1)

        self.pin_button = QPushButton()
        self.pin_button.setObjectName("blurPinButton")
        self.pin_button.setCheckable(True)
        self.pin_button.setToolTip("Always on top")
        self.pin_button.setFixedSize(30, 28)
        self.pin_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.pin_button.setAutoDefault(False)
        self.pin_button.setDefault(False)
        pin_icon = app_icon("pin")
        if not pin_icon.isNull():
            self.pin_button.setIcon(pin_icon)
            self.pin_button.setIconSize(QSize(15, 15))
        self.pin_button.toggled.connect(self.set_pinned)
        row.addWidget(self.pin_button)

        self.min_button = QPushButton("−")
        self.min_button.setObjectName("blurWindowControl")
        self.min_button.setToolTip("Minimize")
        self.min_button.setFixedSize(30, 28)
        self.min_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.min_button.setAutoDefault(False)
        self.min_button.setDefault(False)
        self._rolled_up = False
        self._restore_size = None
        self._restore_minimum = None
        self._restore_maximum = None
        self.min_button.clicked.connect(self.toggle_rollup)
        row.addWidget(self.min_button)

        self.close_button = QPushButton("×")
        self.close_button.setObjectName("blurCloseButton")
        self.close_button.setToolTip("Close")
        self.close_button.setFixedSize(30, 28)
        self.close_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.close_button.setAutoDefault(False)
        self.close_button.setDefault(False)
        self.close_button.clicked.connect(window.close)
        row.addWidget(self.close_button)


        self._topmost_timer = QTimer(self)
        self._topmost_timer.setInterval(700)
        self._topmost_timer.timeout.connect(self._refresh_topmost)
        window.installEventFilter(self)
        QTimer.singleShot(0, self._sync_native_window)

    def toggle_rollup(self):
        body = getattr(self.owner_window, "_blur_body", None)
        if body is None:
            return
        window = self.owner_window
        if not self._rolled_up:
            self._restore_size = window.size()
            self._restore_minimum = window.minimumSize()
            self._restore_maximum = window.maximumSize()
            self._rolled_up = True
            body.hide()
            title_height = self.height()
            window.setMinimumHeight(title_height)
            window.setMaximumHeight(title_height)
            window.resize(max(window.width(), 260), title_height)
            self.min_button.setToolTip("Restore")
        else:
            self._rolled_up = False
            if self._restore_minimum is not None:
                window.setMinimumSize(self._restore_minimum)
            else:
                window.setMinimumHeight(0)
            if self._restore_maximum is not None:
                window.setMaximumSize(self._restore_maximum)
            else:
                window.setMaximumHeight(16777215)
            body.show()
            if self._restore_size is not None:
                window.resize(self._restore_size)
            self.min_button.setToolTip("Minimize")
        window.raise_()
        if self._pinned:
            QTimer.singleShot(0, self._refresh_topmost)
        QTimer.singleShot(0, self._sync_native_window)

    @staticmethod
    def _set_native_topmost(window, pinned):
        if sys.platform != "win32":
            return False
        try:
            import ctypes
            from ctypes import wintypes

            user32 = ctypes.WinDLL("user32", use_last_error=True)
            hwnd = wintypes.HWND(int(window.winId()))
            HWND_TOPMOST = wintypes.HWND(-1)
            HWND_NOTOPMOST = wintypes.HWND(-2)
            SWP_NOSIZE = 0x0001
            SWP_NOMOVE = 0x0002
            SWP_NOACTIVATE = 0x0010
            SWP_FRAMECHANGED = 0x0020
            SWP_SHOWWINDOW = 0x0040

            user32.SetWindowPos.argtypes = (
                wintypes.HWND, wintypes.HWND,
                ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                wintypes.UINT,
            )
            user32.SetWindowPos.restype = wintypes.BOOL
            ok = user32.SetWindowPos(
                hwnd,
                HWND_TOPMOST if pinned else HWND_NOTOPMOST,
                0, 0, 0, 0,
                SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                SWP_FRAMECHANGED | SWP_SHOWWINDOW,
            )
            return bool(ok)
        except Exception:
            return False

    def _refresh_topmost(self):
        if self._pinned and self.owner_window.isVisible():
            if not self._set_native_topmost(self.owner_window, True):
                self.owner_window.raise_()

    def set_pinned(self, pinned):
        self._pinned = bool(pinned)
        self.owner_window._blur_pinned = self._pinned

        if sys.platform == "win32":


            self._set_native_topmost(self.owner_window, self._pinned)
            if self._pinned:
                self._topmost_timer.start()
                self.owner_window.raise_()
            else:
                self._topmost_timer.stop()
            return


        was_visible = self.owner_window.isVisible()
        self.owner_window.setWindowFlag(
            Qt.WindowType.WindowStaysOnTopHint, self._pinned
        )
        if was_visible:
            self.owner_window.show()
            self.owner_window.raise_()

    def _apply_rounded_corners(self):
        window = self.owner_window
        if sys.platform == "win32":
            if not window.mask().isEmpty():
                window.clearMask()
            try:
                DWMWA_WINDOW_CORNER_PREFERENCE = 33
                DWMWCP_ROUND = 2
                preference = ctypes.c_int(DWMWCP_ROUND)
                ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    int(window.winId()),
                    DWMWA_WINDOW_CORNER_PREFERENCE,
                    ctypes.byref(preference),
                    ctypes.sizeof(preference),
                )
            except Exception:
                pass
            return
        if window.isMaximized() or window.isFullScreen():
            window.clearMask()
            return
        rect = QRectF(window.rect())
        if rect.width() <= 1 or rect.height() <= 1:
            return
        path = QPainterPath()
        path.addRoundedRect(rect, self.ROUND_RADIUS, self.ROUND_RADIUS)
        window.setMask(QRegion(path.toFillPolygon().toPolygon()))

    def _sync_native_window(self):
        self._apply_rounded_corners()
        if self._pinned:
            self._refresh_topmost()

    def eventFilter(self, watched, event):
        if watched is self.owner_window:
            if event.type() == QEvent.Type.Close and self._rolled_up:
                body = getattr(self.owner_window, "_blur_body", None)
                self._rolled_up = False
                if self._restore_minimum is not None:
                    self.owner_window.setMinimumSize(self._restore_minimum)
                if self._restore_maximum is not None:
                    self.owner_window.setMaximumSize(self._restore_maximum)
                if body is not None:
                    body.show()
                if self._restore_size is not None:
                    self.owner_window.resize(self._restore_size)
                self.min_button.setToolTip("Minimize")
            if event.type() in (
                QEvent.Type.Show,
                QEvent.Type.Resize,
                QEvent.Type.WindowStateChange,
            ):
                QTimer.singleShot(0, self._sync_native_window)
        return super().eventFilter(watched, event)

    def mouseDoubleClickEvent(self, event):
        event.accept()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self.owner_window.isMaximized():
            handle = self.owner_window.windowHandle()
            try:
                if handle is not None and handle.startSystemMove():
                    self._drag_global = None
                    self._drag_window = None
                    event.accept()
                    return
            except Exception:
                pass
            self._drag_global = event.globalPosition().toPoint()
            self._drag_window = self.owner_window.pos()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if (
            self._drag_global is not None
            and self._drag_window is not None
            and event.buttons() & Qt.MouseButton.LeftButton
            and not self.owner_window.isMaximized()
        ):
            delta = event.globalPosition().toPoint() - self._drag_global
            self.owner_window.move(self._drag_window + delta)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._drag_global = None
        self._drag_window = None
        super().mouseReleaseEvent(event)


def blur_content_layout(window, host, title, margins=(16, 16, 16, 16), spacing=10):
    window.setWindowFlag(Qt.WindowType.FramelessWindowHint, True)
    outer = QVBoxLayout(host)
    outer.setContentsMargins(0, 0, 0, 0)
    outer.setSpacing(0)
    title_bar = BlurTitleBar(window, title)
    outer.addWidget(title_bar)
    body = QWidget(host)
    body.setObjectName("blurWindowBody")
    content = QVBoxLayout(body)
    content.setContentsMargins(*margins)
    content.setSpacing(spacing)
    outer.addWidget(body, 1)
    window._blur_title_bar = title_bar
    window._blur_body = body
    return content


MOD_CTRL = 0x01
MOD_ALT = 0x02
MOD_SHIFT = 0x04
MOD_WIN = 0x08


def _modifier_bit_for_vk(vk):
    if vk in (0x11, 0xA2, 0xA3):
        return MOD_CTRL
    if vk in (0x12, 0xA4, 0xA5):
        return MOD_ALT
    if vk in (0x10, 0xA0, 0xA1):
        return MOD_SHIFT
    if vk in (0x5B, 0x5C):
        return MOD_WIN
    return 0


def _qt_modifier_mask(modifiers):
    mask = 0
    if modifiers & Qt.KeyboardModifier.ControlModifier:
        mask |= MOD_CTRL
    if modifiers & Qt.KeyboardModifier.AltModifier:
        mask |= MOD_ALT
    if modifiers & Qt.KeyboardModifier.ShiftModifier:
        mask |= MOD_SHIFT
    if modifiers & Qt.KeyboardModifier.MetaModifier:
        mask |= MOD_WIN
    return mask


def _vk_is_down(vk):
    if sys.platform != "win32":
        return False
    try:
        return bool(ctypes.windll.user32.GetAsyncKeyState(int(vk)) & 0x8000)
    except Exception:
        return False


def _current_modifier_mask():
    mask = 0
    if _vk_is_down(0x11) or _vk_is_down(0xA2) or _vk_is_down(0xA3):
        mask |= MOD_CTRL
    if _vk_is_down(0x12) or _vk_is_down(0xA4) or _vk_is_down(0xA5):
        mask |= MOD_ALT
    if _vk_is_down(0x10) or _vk_is_down(0xA0) or _vk_is_down(0xA1):
        mask |= MOD_SHIFT
    if _vk_is_down(0x5B) or _vk_is_down(0x5C):
        mask |= MOD_WIN
    return mask


def hotkey_text(spec):
    if not isinstance(spec, dict):
        return "Set hotkey"
    try:
        vk = int(spec.get("virtual_key", 0) or 0)
        modifiers = int(spec.get("modifiers", 0) or 0)
    except (TypeError, ValueError):
        return "Set hotkey"
    labels = []
    for bit, label in ((MOD_CTRL, "Ctrl"), (MOD_ALT, "Alt"), (MOD_SHIFT, "Shift"), (MOD_WIN, "Win")):
        if modifiers & bit:
            labels.append(label)
    names = {
        0x08: "Backspace", 0x09: "Tab", 0x0D: "Enter", 0x10: "Shift", 0x11: "Ctrl",
        0x12: "Alt", 0x13: "Pause", 0x14: "Caps Lock", 0x1B: "Esc", 0x20: "Space",
        0x21: "Page Up", 0x22: "Page Down", 0x23: "End", 0x24: "Home",
        0x25: "Left", 0x26: "Up", 0x27: "Right", 0x28: "Down", 0x2C: "Print Screen",
        0x2D: "Insert", 0x2E: "Delete", 0x5B: "Left Win", 0x5C: "Right Win",
        0x60: "Num 0", 0x61: "Num 1", 0x62: "Num 2", 0x63: "Num 3", 0x64: "Num 4",
        0x65: "Num 5", 0x66: "Num 6", 0x67: "Num 7", 0x68: "Num 8", 0x69: "Num 9",
        0x6A: "Num *", 0x6B: "Num +", 0x6D: "Num -", 0x6E: "Num .", 0x6F: "Num /",
        0x90: "Num Lock", 0x91: "Scroll Lock",
        0xA0: "Left Shift", 0xA1: "Right Shift", 0xA2: "Left Ctrl", 0xA3: "Right Ctrl",
        0xA4: "Left Alt", 0xA5: "Right Alt",
        0xBA: ";", 0xBB: "=", 0xBC: ",", 0xBD: "-", 0xBE: ".", 0xBF: "/",
        0xC0: "`", 0xDB: "[", 0xDC: "\\", 0xDD: "]", 0xDE: "'",
    }
    if 0x41 <= vk <= 0x5A or 0x30 <= vk <= 0x39:
        key_name = chr(vk)
    elif 0x70 <= vk <= 0x87:
        key_name = f"F{vk - 0x6F}"
    else:
        key_name = names.get(vk, f"VK {vk:02X}")
    own_modifier = _modifier_bit_for_vk(vk)
    if own_modifier and modifiers & own_modifier:
        labels = [label for bit, label in ((MOD_CTRL, "Ctrl"), (MOD_ALT, "Alt"), (MOD_SHIFT, "Shift"), (MOD_WIN, "Win")) if modifiers & bit and bit != own_modifier]
    labels.append(key_name)
    return "+".join(labels)


class FastFlagHotkeyService(QObject):
    activated = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._bindings = {}
        self._down = {}
        self._timer = QTimer(self)
        self._timer.setInterval(15)
        self._timer.timeout.connect(self._poll)
        if sys.platform == "win32":
            self._timer.start()

    def set_bindings(self, bindings):
        clean = {}
        if isinstance(bindings, dict):
            for name, spec in bindings.items():
                if not isinstance(name, str) or not isinstance(spec, dict):
                    continue
                try:
                    vk = int(spec.get("virtual_key", 0) or 0)
                    modifiers = int(spec.get("modifiers", 0) or 0) & 0x0F
                except (TypeError, ValueError):
                    continue
                if 0 < vk <= 0xFF:
                    clean[name] = {**spec, "virtual_key": vk, "modifiers": modifiers}
        self._bindings = clean
        current_modifiers = _current_modifier_mask()
        down = {}
        for name, spec in clean.items():
            vk = int(spec.get("virtual_key", 0) or 0)
            required = int(spec.get("modifiers", 0) or 0) & 0x0F
            own_modifier = _modifier_bit_for_vk(vk)
            comparison = current_modifiers & ~own_modifier
            required_comparison = required & ~own_modifier
            down[name] = bool(_vk_is_down(vk) and comparison == required_comparison)
        self._down = down

    def _poll(self):
        if not self._bindings or sys.platform != "win32":
            return
        current_modifiers = _current_modifier_mask()
        for name, spec in tuple(self._bindings.items()):
            vk = int(spec.get("virtual_key", 0) or 0)
            required = int(spec.get("modifiers", 0) or 0) & 0x0F
            own_modifier = _modifier_bit_for_vk(vk)
            comparison = current_modifiers & ~own_modifier
            required_comparison = required & ~own_modifier
            active = _vk_is_down(vk) and comparison == required_comparison
            was_down = self._down.get(name, False)
            if active and not was_down:
                self.activated.emit(name)
            self._down[name] = active


class FastFlagHotkeyCaptureDialog(QDialog):
    _MODIFIER_QT_KEYS = {
        int(Qt.Key.Key_Control), int(Qt.Key.Key_Alt), int(Qt.Key.Key_Shift), int(Qt.Key.Key_Meta),
    }

    def __init__(self, flag_name, parent=None):
        super().__init__(parent)
        self.binding = None
        self.clear_requested = False
        self._pending_binding = None
        self._pending_key = None
        self.setWindowTitle("Set FastFlag Hotkey")
        self.setMinimumSize(430, 170)
        apply_window_icon(self)
        root = blur_content_layout(self, self, "Set FastFlag Hotkey", (16, 12, 16, 16), 10)
        label = QLabel(f'Press a global hotkey for <b>{flag_name}</b>.<br><span style="color:#888">Esc, Backspace, or Delete clears it.</span>')
        label.setTextFormat(Qt.TextFormat.RichText)
        label.setWordWrap(True)
        root.addWidget(label)
        self.preview = QLabel("Waiting for a key combination…")
        self.preview.setStyleSheet("color:#a9a9a9;background:transparent;padding:10px 0;font-size:12px;")
        root.addWidget(self.preview)
        row = QHBoxLayout()
        clear = QPushButton("Clear hotkey")
        cancel = QPushButton("Cancel")
        clear.clicked.connect(self._clear)
        cancel.clicked.connect(self.reject)
        row.addWidget(clear)
        row.addStretch(1)
        row.addWidget(cancel)
        root.addLayout(row)
        apply_blur_style(self)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        QTimer.singleShot(0, self.setFocus)

    def _clear(self):
        self.clear_requested = True
        self.accept()

    def _event_binding(self, event):
        if sys.platform != "win32":
            return None
        try:
            vk = int(event.nativeVirtualKey())
            scan = int(event.nativeScanCode())
        except Exception:
            return None
        if not 0 < vk <= 0xFF:
            return None
        modifiers = _qt_modifier_mask(event.modifiers())
        modifiers &= ~_modifier_bit_for_vk(vk)
        return {
            "virtual_key": vk,
            "scan_code": max(0, scan),
            "extended": vk in {0xA3, 0xA5, 0x2D, 0x2E, 0x24, 0x23, 0x21, 0x22, 0x25, 0x26, 0x27, 0x28, 0x5B, 0x5C},
            "modifiers": modifiers,
        }

    def keyPressEvent(self, event):
        if event.isAutoRepeat():
            event.accept()
            return
        if event.key() in (Qt.Key.Key_Escape, Qt.Key.Key_Backspace, Qt.Key.Key_Delete):
            self.clear_requested = True
            self.binding = None
            self.accept()
            return
        binding = self._event_binding(event)
        if binding is None:
            self.preview.setText("That key could not be captured.")
            event.accept()
            return
        self._pending_binding = binding
        self._pending_key = int(event.key())
        if self._pending_key in self._MODIFIER_QT_KEYS:
            preview = dict(binding)
            preview["modifiers"] = _qt_modifier_mask(event.modifiers()) | _modifier_bit_for_vk(binding["virtual_key"])
            self.preview.setText(hotkey_text(preview))
        else:
            self.preview.setText(hotkey_text(binding))
        event.accept()

    def keyReleaseEvent(self, event):
        if event.isAutoRepeat():
            event.accept()
            return
        if self._pending_binding is not None and int(event.key()) == self._pending_key:
            self.binding = dict(self._pending_binding)
            self._pending_binding = None
            self._pending_key = None
            self.accept()
            return
        event.accept()




class FastFlagListDialog(QDialog):
    MAX_ROWS = 1000

    def __init__(self, fastflags_window):
        super().__init__(fastflags_window)
        self.fastflags_window = fastflags_window
        self.setObjectName("fastFlagListDialog")
        self.catalog = useful_fastflag_catalog()
        self.setWindowTitle("FastFlags List")
        self.resize(860, 600)
        self.setMinimumSize(700, 460)
        apply_window_icon(self)
        root = blur_content_layout(self, self, "FastFlags List", (14, 12, 14, 14), 9)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Search for useful FastFlags")
        root.addWidget(self.search)

        self.table = QTableWidget(0, 3)
        self.table.setObjectName("catalogTable")
        self.table.setAutoFillBackground(False)
        self.table.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.table.viewport().setAutoFillBackground(False)
        self.table.viewport().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.table.viewport().setStyleSheet("background:transparent;border:0;")
        self.table.setHorizontalHeaderLabels(("Name", "Value", "Does"))
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.setAlternatingRowColors(False)
        self.table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.table.setColumnWidth(1, 145)
        self.table.verticalHeader().setDefaultSectionSize(31)
        root.addWidget(self.table, 1)

        actions = QHBoxLayout()
        self.add_selected = QPushButton("Add selected")
        self.add_selected.setEnabled(False)
        actions.addStretch(1)
        actions.addWidget(self.add_selected)
        root.addLayout(actions)

        self.search.textChanged.connect(self._populate)
        self.table.itemSelectionChanged.connect(
            lambda: self.add_selected.setEnabled(bool(self.table.selectionModel().selectedRows()))
        )
        self.table.itemDoubleClicked.connect(lambda _item: self._add_selection())
        self.add_selected.clicked.connect(self._add_selection)

        self.setStyleSheet(r'''
            QDialog#fastFlagListDialog { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QLineEdit { background:#0d0d0e; color:#ededed; border:1px solid #2a2a2d; border-radius:6px; min-height:32px; padding:0 9px; }
            QLineEdit:focus { background:#101012; border-color:#45454a; }
            QPushButton { background:#111113; color:#e9e9e9; border:1px solid #2a2a2d; border-radius:6px; padding:6px 11px; }
            QPushButton:hover { background:#19191c; border-color:#414146; }
            QTableWidget#catalogTable { background:transparent; alternate-background-color:transparent; border:1px solid #252528; border-radius:7px; selection-background-color:#1a1b1d; selection-color:#fff; gridline-color:transparent; }
            QTableWidget#catalogTable::item { padding:5px 7px; border-bottom:1px solid #151517; }
            QHeaderView::section { background:#0d0d0f; color:#bcbcbc; border:0; border-bottom:1px solid #252528; padding:7px; font-weight:600; }
        ''')
        apply_blur_style(self)
        self._populate()

    def _matching_entries(self):
        query = self.search.text().strip().casefold()
        rows = []
        for name, meta in self.catalog.items():
            
            haystack = " ".join((
                name,
                str(meta.get("category", "")),
                " ".join(meta.get("presets", ())),
            )).casefold()
            if query and query not in haystack:
                continue
            rows.append((name, meta))
        rows.sort(key=lambda item: item[0].casefold())
        return rows

    def _populate(self, *_):
        rows = self._matching_entries()
        visible = rows[:self.MAX_ROWS]
        self.table.setUpdatesEnabled(False)
        self.table.setRowCount(len(visible))
        try:
            for row, (name, meta) in enumerate(visible):
                presets = ", ".join(meta.get("presets", ()))
                values = (
                    name,
                    str(meta.get("value", "")),
                    presets,
                )
                for column, value in enumerate(values):
                    item = QTableWidgetItem(value)
                    item.setData(Qt.ItemDataRole.UserRole, name)
                    if presets:
                        item.setToolTip(presets)
                    self.table.setItem(row, column, item)
        finally:
            self.table.setUpdatesEnabled(True)
        self.add_selected.setEnabled(bool(self.table.selectionModel().selectedRows()))

    def _add_selection(self):
        selected = []
        for index in self.table.selectionModel().selectedRows():
            item = self.table.item(index.row(), 0)
            if not item:
                continue
            name = str(item.data(Qt.ItemDataRole.UserRole) or item.text()).strip()
            if name:
                selected.append(name)
        if not selected:
            return
        additions = {}
        for name in selected:
            meta = self.catalog.get(name, {})
            additions[name] = str(meta.get("value", ""))
        self.fastflags_window.add_catalog_fastflags(additions)
        self.accept()


class LuauLexer(QsciLexerLua):
    def keywords(self, number):
        class_names, enum_names, services, _, member_names = ROBLOX_API_INDEX.snapshot()
        if number == 1:
            return LUAU_KEYWORDS
        if number == 2:
            return f"{LUAU_GLOBALS} {ROBLOX_GLOBALS}"
        if number == 3:
            return LUAU_LIBRARIES
        if number == 4:
            return " ".join(sorted(set("task math string table coroutine utf8 bit32 buffer".split()) | member_names))
        if number == 5:
            return f"{LUAU_TYPES} {ROBLOX_VALUE_TYPES}"
        if number == 6:
            return " ".join(sorted(class_names))
        if number == 7:
            return " ".join(sorted(services))
        if number == 8:
            return " ".join(sorted(enum_names))
        return super().keywords(number) or ""


class FindOverlay(QFrame):
    def __init__(self, target):
        super().__init__(target)
        self.target = target
        self.setObjectName("findOverlay")
        self.setFixedSize(330, 36)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        row = QHBoxLayout(self)
        row.setContentsMargins(5, 4, 5, 4)
        row.setSpacing(4)
        self.query = QLineEdit()
        self.query.setPlaceholderText("Find")
        self.query.setClearButtonEnabled(True)
        self.query.textChanged.connect(self._live_search)
        self.query.returnPressed.connect(lambda: self.search(True))
        row.addWidget(self.query, 1)
        self.status = QLabel("")
        self.status.setFixedWidth(58)
        self.status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        row.addWidget(self.status)
        previous = QPushButton("↑")
        previous.setToolTip("Previous match")
        previous.clicked.connect(lambda: self.search(False))
        row.addWidget(previous)
        following = QPushButton("↓")
        following.setToolTip("Next match")
        following.clicked.connect(lambda: self.search(True))
        row.addWidget(following)
        close = QPushButton("×")
        close.setToolTip("Close")
        close.clicked.connect(self.hide_find)
        row.addWidget(close)
        for button in (previous, following, close):
            button.setFixedSize(25, 26)
            button.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("""
            QFrame#findOverlay {
                background: #101011;
                border: 1px solid #303033;
                border-radius: 6px;
            }
            QLineEdit {
                min-height: 26px;
                padding: 0 7px;
                background: #080809;
                color: #f0f0f0;
                border: 1px solid #2b2b2d;
                border-radius: 4px;
            }
            QLabel { color: #8e8e92; background: transparent; font-size: 10px; }
            QPushButton {
                padding: 0;
                background: transparent;
                color: #cfcfd2;
                border: none;
                border-radius: 3px;
            }
            QPushButton:hover { background: #242427; color: #ffffff; }
        """)
        self.hide()
        target.installEventFilter(self)

    def eventFilter(self, watched, event):
        if watched is self.target and event.type() == QEvent.Type.Resize:
            self._place()
        return super().eventFilter(watched, event)

    def _place(self):
        x = max(6, self.target.width() - self.width() - 10)
        self.move(x, 8)
        self.raise_()

    def show_find(self):
        selected = ""
        if isinstance(self.target, QsciScintilla):
            selected = self.target.selectedText() if self.target.hasSelectedText() else ""
        elif isinstance(self.target, QPlainTextEdit):
            cursor = self.target.textCursor()
            selected = cursor.selectedText() if cursor.hasSelection() else ""
        if selected and "\n" not in selected and len(selected) <= 120:
            self.query.setText(selected)
        self._place()
        self.show()
        self.raise_()
        self.query.setFocus()
        self.query.selectAll()

    def hide_find(self):
        self.hide()
        self.status.clear()
        self.target.setFocus()

    def _live_search(self, text):
        if text:
            self.search(True, wrap=True)
        else:
            self.status.clear()

    def search(self, forward=True, wrap=True):
        term = self.query.text()
        if not term:
            self.status.clear()
            return False
        found = False
        if isinstance(self.target, QsciScintilla):
            data = term.encode("utf-8")
            send = self.target.SendScintilla
            send(self.target.SCI_SEARCHANCHOR)
            pos = send(self.target.SCI_SEARCHNEXT if forward else self.target.SCI_SEARCHPREV, 0, data)
            if pos < 0 and wrap:
                send(self.target.SCI_GOTOPOS, 0 if forward else send(self.target.SCI_GETLENGTH))
                send(self.target.SCI_SEARCHANCHOR)
                pos = send(self.target.SCI_SEARCHNEXT if forward else self.target.SCI_SEARCHPREV, 0, data)
            found = pos >= 0
            if found:
                self.target.ensureCursorVisible()
        elif isinstance(self.target, QPlainTextEdit):
            flags = QTextDocument.FindFlag(0)
            if not forward:
                flags |= QTextDocument.FindFlag.FindBackward
            found = self.target.find(term, flags)
            if not found and wrap:
                cursor = self.target.textCursor()
                cursor.movePosition(QTextCursor.MoveOperation.Start if forward else QTextCursor.MoveOperation.End)
                self.target.setTextCursor(cursor)
                found = self.target.find(term, flags)
        self.status.setText("" if found else "No match")
        return found


class CompletionPopup(QFrame):
    chosen = pyqtSignal(str)

    def __init__(self, editor):
        super().__init__(editor.window())
        self.editor = editor
        self.prefix = ""
        self.setObjectName("completionPopup")
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(1, 1, 1, 1)
        layout.setSpacing(0)
        self.items = QListWidget(self)
        self.items.setObjectName("completionList")
        self.items.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.items.setMouseTracking(True)
        self.items.setIconSize(QSize(16, 16))
        self.items.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.items.setVerticalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        self.items.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.items.itemClicked.connect(self._choose_item)
        layout.addWidget(self.items)

        self.setStyleSheet("""
            QFrame#completionPopup {
                background: #0b0b0c;
                border: 1px solid #29292d;
                border-radius: 5px;
            }
            QListWidget#completionList {
                background: transparent;
                border: none;
                outline: 0;
                padding: 2px;
                color: #dedee2;
            }
            QListWidget#completionList::item {
                min-height: 24px;
                padding: 2px 8px 2px 5px;
                border-radius: 3px;
            }
            QListWidget#completionList::item:hover {
                background: #151517;
                color: #f4f4f5;
            }
            QListWidget#completionList::item:selected {
                background: #1c2620;
                color: #f5f7f5;
            }
            QScrollBar:vertical {
                width: 8px;
                background: transparent;
                margin: 2px;
            }
            QScrollBar::handle:vertical {
                background: #343438;
                min-height: 24px;
                border-radius: 4px;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0;
            }
        """)
        self.hide()

    def _choose_item(self, item):
        name = item.data(Qt.ItemDataRole.UserRole)
        if name:
            self.chosen.emit(str(name))

    def set_candidates(self, prefix, candidates, icons):
        self.prefix = prefix
        self.items.clear()
        widest = 0
        metrics = self.items.fontMetrics()
        for name, kind in candidates:
            item = QListWidgetItem(name)
            item.setData(Qt.ItemDataRole.UserRole, name)
            icon = icons.get(kind)
            if icon is None and kind in {"method", "callback", "local_function"}:
                icon = icons.get("function")
            elif icon is None and kind == "local_variable":
                icon = icons.get("variable")
            elif icon is None and kind == "service":
                icon = icons.get("class")
            elif icon is None and kind == "struct":
                icon = icons.get("type")
            if icon is not None and not icon.isNull():
                item.setIcon(icon)
            self.items.addItem(item)
            widest = max(widest, metrics.horizontalAdvance(name))
        if not self.items.count():
            self.hide()
            return
        self.items.setCurrentRow(0)
        row_height = max(25, self.items.sizeHintForRow(0))
        visible_rows = min(13, self.items.count())
        width = max(245, min(480, widest + 64))
        height = visible_rows * row_height + 6
        self.resize(width, height)
        self.reposition()
        self.show()
        self.raise_()

    def reposition(self):
        if not self.items.count():
            return
        parent = self.parentWidget()
        if parent is None:
            return
        try:
            position = self.editor.SendScintilla(self.editor.SCI_GETCURRENTPOS)
            line = self.editor.SendScintilla(self.editor.SCI_LINEFROMPOSITION, position)
            x = int(self.editor.SendScintilla(self.editor.SCI_POINTXFROMPOSITION, 0, position))
            y = int(self.editor.SendScintilla(self.editor.SCI_POINTYFROMPOSITION, 0, position))
            line_height = int(self.editor.SendScintilla(self.editor.SCI_TEXTHEIGHT, line))
        except Exception:
            line, index = self.editor.getCursorPosition()
            x = max(0, index * self.editor.fontMetrics().horizontalAdvance("M"))
            y = max(0, line * self.editor.fontMetrics().height())
            line_height = self.editor.fontMetrics().height()
        point = self.editor.mapTo(parent, QPoint(x, y + line_height + 3))
        px, py = point.x(), point.y()
        margin = 8
        if px + self.width() > parent.width() - margin:
            px = max(margin, parent.width() - self.width() - margin)
        if py + self.height() > parent.height() - margin:
            above = self.editor.mapTo(parent, QPoint(x, y - self.height() - 3))
            py = max(margin, above.y())
        self.move(px, py)

    def move_selection(self, delta):
        count = self.items.count()
        if not count:
            return
        row = self.items.currentRow()
        if row < 0:
            row = 0
        row = max(0, min(count - 1, row + delta))
        self.items.setCurrentRow(row)
        self.items.scrollToItem(self.items.currentItem(), QAbstractItemView.ScrollHint.EnsureVisible)

    def current_name(self):
        item = self.items.currentItem()
        if item is None:
            return ""
        return str(item.data(Qt.ItemDataRole.UserRole) or "")


class CodeEditor(QsciScintilla):
    _PAIR_OPEN = {"(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"}
    _PAIR_CLOSE = {value: key for key, value in _PAIR_OPEN.items()}
    _FUNCTION_INDICATOR = 20
    _ERROR_INDICATOR = 21
    _INDENT = "    "
    _AUTOFILL_ICON_FILES = {
        "variable": "Variable.png",
        "local_variable": "Variable.png",
        "function": "Function.png",
        "local_function": "Function.png",
        "method": "Method.png",
        "property": "Property.png",
        "event": "Event.png",
        "callback": "Function.png",
        "keyword": "Keyword.png",
        "class": "Class.png",
        "service": "Service.png",
        "enum": "Enum.png",
        "enum_member": "EnumMember.png",
        "module": "Module.png",
        "type": "TypeParameter.png",
        "struct": "Struct.png",
        "field": "Field.png",
        "snippet": "Snippet.png",
    }

    def __init__(self, parent):
        super().__init__(parent)
        self.paste_handler = None
        self._find_overlay = None
        self._local_symbols = set()
        self._local_symbol_kinds = {}
        self._symbol_types = {}
        self._semantic_enabled = True
        self._autocomplete_icons = {}
        self._completion_popup = CompletionPopup(self)
        self._completion_popup.chosen.connect(self._accept_completion_name)
        self._analysis_timer = QTimer(self)
        self._analysis_timer.setSingleShot(True)
        self._analysis_timer.setInterval(90)
        self._analysis_timer.timeout.connect(self._reanalyze_document)
        self._completion_timer = QTimer(self)
        self._completion_timer.setSingleShot(True)
        self._completion_timer.setInterval(12)
        self._completion_timer.timeout.connect(self.show_autocomplete)
        try:
            self.textChanged.connect(self._schedule_analysis)
        except Exception:
            pass
        self._round_radius = 13
        self._configure_completion_popup()
        self._configure_indicators()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if not self.mask().isEmpty():
            self.clearMask()

    def _configure_completion_popup(self):
        send = self.SendScintilla
        for constant_name, color in (
            ("SCI_CALLTIPSETBACK", QColor("#111113")),
            ("SCI_CALLTIPSETFORE", QColor("#e6e6e8")),
            ("SCI_CALLTIPSETFOREHLT", QColor("#72d98a")),
        ):
            constant = getattr(self, constant_name, None)
            if constant is not None:
                try:
                    send(constant, color)
                except Exception:
                    pass
        self._load_autocomplete_icons()

    def _load_autocomplete_icons(self):
        self._autocomplete_icons.clear()
        icon_dir = ICON_DIR / "autofill"
        if not icon_dir.is_dir():
            return

        
        
        
        by_name = {}
        by_stem = {}
        try:
            for candidate in icon_dir.iterdir():
                if not candidate.is_file():
                    continue
                by_name.setdefault(candidate.name.casefold(), candidate)
                by_stem.setdefault(candidate.stem.casefold(), candidate)
        except OSError:
            return

        for kind, filename in self._AUTOFILL_ICON_FILES.items():
            configured = Path(filename)
            path = icon_dir / configured
            if not path.is_file():
                path = by_name.get(configured.name.casefold()) or by_stem.get(configured.stem.casefold())
            if path is None or not path.is_file():
                continue
            icon = QIcon(str(path))
            if not icon.isNull():
                self._autocomplete_icons[kind] = icon

    def _configure_indicators(self):
        send = self.SendScintilla
        try:
            text_fore = getattr(self, "INDIC_TEXTFORE", 17)
            send(self.SCI_INDICSETSTYLE, self._FUNCTION_INDICATOR, text_fore)
            send(self.SCI_INDICSETFORE, self._FUNCTION_INDICATOR, QColor("#7daee0"))
            send(self.SCI_INDICSETUNDER, self._FUNCTION_INDICATOR, 1)
        except Exception:
            pass
        try:
            squiggle = getattr(self, "INDIC_SQUIGGLE", 1)
            send(self.SCI_INDICSETSTYLE, self._ERROR_INDICATOR, squiggle)
            send(self.SCI_INDICSETFORE, self._ERROR_INDICATOR, QColor("#ff5f57"))
            send(self.SCI_INDICSETUNDER, self._ERROR_INDICATOR, 1)
        except Exception:
            pass

    def set_semantic_highlighting_enabled(self, enabled):
        self._semantic_enabled = bool(enabled)
        if not self._semantic_enabled:
            self._clear_indicator(self._FUNCTION_INDICATOR)
        else:
            self._schedule_analysis()

    def _clear_indicator(self, indicator):
        try:
            length = self.SendScintilla(self.SCI_GETLENGTH)
            self.SendScintilla(self.SCI_SETINDICATORCURRENT, indicator)
            self.SendScintilla(self.SCI_INDICATORCLEARRANGE, 0, length)
        except Exception:
            pass

    def _fill_indicator(self, indicator, start, length):
        if length <= 0:
            return
        try:
            self.SendScintilla(self.SCI_SETINDICATORCURRENT, indicator)
            self.SendScintilla(self.SCI_INDICATORFILLRANGE, int(start), int(length))
        except Exception:
            pass

    def _schedule_analysis(self):
        if self.SendScintilla(self.SCI_GETLENGTH) <= AUTOCOMPLETE_ANALYSIS_LIMIT:
            self._analysis_timer.start()

    def _queue_autocomplete(self, force=False):
        if force:
            self._completion_timer.stop()
            self.show_autocomplete(force=True)
        else:
            self._completion_timer.start()

    def _recent_source(self, max_chars=262144, max_lines=2500):
        line, index = self.getCursorPosition()
        chunks = [self.text(line)[:index]]
        total = len(chunks[0])
        rows = 1
        for row in range(line - 1, -1, -1):
            if total >= max_chars or rows >= max_lines:
                break
            text = self.text(row)
            chunks.append(text)
            total += len(text)
            rows += 1
        chunks.reverse()
        return "".join(chunks)[-max_chars:]

    @staticmethod
    def _extract_symbols(source):
        symbols = set()
        kinds = {}
        types = {}

        def add_symbol(name, kind="variable", type_name=""):
            if not name or name in LUAU_KEYWORD_SET:
                return
            previous = kinds.get(name)
            if previous in {"local_variable", "local_function"} and kind in {"variable", "function"}:
                kind = previous
            symbols.add(name)
            kinds[name] = kind
            if type_name:
                types[name] = type_name.rstrip("?")

        for match in re.finditer(r"\blocal\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)", source):
            for name in re.findall(r"[A-Za-z_]\w*", match.group(1)):
                add_symbol(name, "local_variable")

        for match in re.finditer(r"(?m)^[ \t]*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*=(?!=)", source):
            for name in re.findall(r"[A-Za-z_]\w*", match.group(1)):
                add_symbol(name)

        for match in re.finditer(r"\b(?:export\s+)?type\s+([A-Za-z_]\w*)", source):
            add_symbol(match.group(1), "type")

        for match in re.finditer(r"\b(local\s+)?function\s+([A-Za-z_]\w*)", source):
            add_symbol(match.group(2), "local_function" if match.group(1) else "function")

        for match in re.finditer(r"\bfor\s+([^\n]+?)\s+(?:in|=)", source):
            for name in re.findall(r"[A-Za-z_]\w*", match.group(1)):
                if name not in {"for", "in"}:
                    add_symbol(name, "local_variable")

        function_pattern = r"\bfunction(?:\s+[A-Za-z_]\w*(?:(?:\.|:)[A-Za-z_]\w*)*)?(?:\s*<[^>]*>)?\s*\(([^)]*)\)"
        for function_match in re.finditer(function_pattern, source):
            params = function_match.group(1)
            for name in re.findall(r"(?:^|,)\s*([A-Za-z_]\w*)", params):
                add_symbol(name, "local_variable")
            for match in re.finditer(r"([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)\??", params):
                name, type_name = match.groups()
                add_symbol(name, "local_variable", type_name)

        for match in re.finditer(r"\blocal\s+([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)\??", source):
            name, type_name = match.groups()
            add_symbol(name, "local_variable", type_name)

        for match in re.finditer(r'\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*game\s*:\s*GetService\s*\(\s*[\'"]([A-Za-z_]\w*)[\'"]\s*\)', source):
            add_symbol(match.group(1), "variable", match.group(2))

        for match in re.finditer(r'\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*Instance\s*\.\s*new\s*\(\s*[\'"]([A-Za-z_]\w*)[\'"]', source):
            add_symbol(match.group(1), "variable", match.group(2))

        value_types = "|".join(re.escape(item) for item in ROBLOX_VALUE_TYPES.split())
        value_pattern = rf"\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*({value_types})\s*\.\s*(?:new|fromRGB|fromHSV|fromHex|fromScale|fromOffset|Angles|lookAt)\b"
        for match in re.finditer(value_pattern, source):
            add_symbol(match.group(1), "variable", match.group(2))

        child_pattern = r'\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*([A-Za-z_]\w*)\s*:\s*(?:FindFirstChildOfClass|FindFirstChildWhichIsA)\s*\(\s*[\'"]([A-Za-z_]\w*)[\'"]'
        for match in re.finditer(child_pattern, source):
            add_symbol(match.group(1), "variable", match.group(3))

        for _ in range(3):
            changed = False
            for match in re.finditer(r"\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)\b", source):
                target, base, member = match.groups()
                base_type = types.get(base)
                if not base_type:
                    continue
                result_type = ROBLOX_API_INDEX.member_type(base_type, member)
                if result_type and result_type not in {"any", "nil", "Variant"} and types.get(target) != result_type:
                    add_symbol(target, "variable", result_type)
                    changed = True
            if not changed:
                break
        return symbols, kinds, types

    def _refresh_recent_symbols(self):
        try:
            source = self._recent_source()
            symbols, kinds, types = self._extract_symbols(source)
        except (MemoryError, RuntimeError):
            return
        self._local_symbols.update(symbols)
        self._local_symbol_kinds.update(kinds)
        self._symbol_types.update(types)

    def _reanalyze_document(self):
        if self.SendScintilla(self.SCI_GETLENGTH) > AUTOCOMPLETE_ANALYSIS_LIMIT:
            self._local_symbols = set()
            self._local_symbol_kinds = {}
            self._symbol_types = {}
            self._clear_indicator(self._FUNCTION_INDICATOR)
            self._clear_indicator(self._ERROR_INDICATOR)
            return
        try:
            source = self.text()
        except (MemoryError, RuntimeError):
            return
        symbols, kinds, types = self._extract_symbols(source)
        self._local_symbols = symbols
        self._local_symbol_kinds = kinds
        self._symbol_types = types
        self._apply_semantic_highlighting(source)
        self._apply_diagnostics(source)

    def _apply_semantic_highlighting(self, source):
        self._clear_indicator(self._FUNCTION_INDICATOR)
        if not self._semantic_enabled:
            return
        try:
            data = source.encode("utf-8")
        except UnicodeError:
            return
        ranges = set()
        declaration = re.compile(rb"\b(?:local\s+)?function\s+(?:[A-Za-z_]\w*(?:\.|:))*([A-Za-z_]\w*)")
        calls = re.compile(rb"\b([A-Za-z_]\w*)\s*(?=\()")
        for match in declaration.finditer(data):
            ranges.add((match.start(1), match.end(1) - match.start(1)))
        excluded = set(LUAU_KEYWORDS.encode("ascii").split()) | {b"function"}
        for match in calls.finditer(data):
            name = match.group(1)
            if name in excluded:
                continue
            start = match.start(1)
            prefix = data[max(0, start - 12):start]
            if re.search(rb"\bfunction\s*$", prefix):
                continue
            ranges.add((start, match.end(1) - start))
        for start, length in sorted(ranges):
            self._fill_indicator(self._FUNCTION_INDICATOR, start, length)

    @staticmethod
    def _delimiter_diagnostics(data):
        pairs = {ord("("): ord(")"), ord("["): ord("]"), ord("{"): ord("}")}
        reverse = {value: key for key, value in pairs.items()}
        stack = []
        errors = []
        i = 0
        n = len(data)
        quote = None
        quote_start = -1
        while i < n:
            ch = data[i]
            if quote is not None:
                if ch == ord("\\") and quote != ord("`"):
                    i += 2
                    continue
                if ch == quote:
                    quote = None
                    quote_start = -1
                i += 1
                continue
            if data.startswith(b"--[[", i):
                close = data.find(b"]]", i + 4)
                if close < 0:
                    break
                i = close + 2
                continue
            if data.startswith(b"--", i):
                newline = data.find(b"\n", i + 2)
                if newline < 0:
                    break
                i = newline + 1
                continue
            if data.startswith(b"[[", i):
                close = data.find(b"]]", i + 2)
                if close < 0:
                    errors.append((i, 2))
                    break
                i = close + 2
                continue
            if ch in (ord("\""), ord("'"), ord("`")):
                quote = ch
                quote_start = i
                i += 1
                continue
            if ch in pairs:
                stack.append((ch, i))
            elif ch in reverse:
                if stack and stack[-1][0] == reverse[ch]:
                    stack.pop()
                else:
                    errors.append((i, 1))
            i += 1
        if quote is not None and quote_start >= 0:
            errors.append((quote_start, 1))
        errors.extend((position, 1) for _, position in stack)
        return errors

    @staticmethod
    def _strip_inline_comment(line):
        quote = None
        escaped = False
        i = 0
        while i < len(line) - 1:
            ch = line[i]
            if quote:
                if escaped:
                    escaped = False
                elif ch == "\\" and quote != "`":
                    escaped = True
                elif ch == quote:
                    quote = None
                i += 1
                continue
            if ch in "\"'`":
                quote = ch
                i += 1
                continue
            if line[i:i + 2] == "--":
                return line[:i]
            i += 1
        return line

    @classmethod
    def _block_diagnostics(cls, source):
        errors = []
        stack = []
        byte_offset = 0
        for raw_line in source.splitlines(keepends=True):
            line = raw_line.rstrip("\r\n")
            code = cls._strip_inline_comment(line)
            stripped = code.lstrip(" \t")
            leading = code[:len(code) - len(stripped)]
            line_prefix_bytes = len(leading.encode("utf-8"))

            def pos_of(word):
                index = code.find(word, len(leading))
                if index < 0:
                    return byte_offset + line_prefix_bytes
                return byte_offset + len(code[:index].encode("utf-8"))

            if not stripped:
                byte_offset += len(raw_line.encode("utf-8"))
                continue

            if re.match(r"^end\b", stripped):
                if stack and stack[-1][0] == "end":
                    stack.pop()
                else:
                    errors.append((pos_of("end"), 3))
                byte_offset += len(raw_line.encode("utf-8"))
                continue
            if re.match(r"^until\b", stripped):
                if stack and stack[-1][0] == "until":
                    stack.pop()
                else:
                    errors.append((pos_of("until"), 5))
                byte_offset += len(raw_line.encode("utf-8"))
                continue
            if re.match(r"^(?:else\b|elseif\b)", stripped):
                if not stack or stack[-1][1] != "if":
                    word = "elseif" if stripped.startswith("elseif") else "else"
                    errors.append((pos_of(word), len(word)))
                if stripped.startswith("elseif") and not re.search(r"\bthen\b", stripped):
                    errors.append((pos_of("elseif"), 6))
                byte_offset += len(raw_line.encode("utf-8"))
                continue

            opener = None
            kind = None
            word = None
            if re.match(r"^if\b", stripped):
                word = "if"
                if not re.search(r"\bthen\b", stripped):
                    errors.append((pos_of(word), len(word)))
                elif not re.search(r"\bend\b", stripped[2:]):
                    opener, kind = "end", "if"
            elif re.match(r"^for\b", stripped):
                word = "for"
                if not re.search(r"\bdo\b", stripped):
                    errors.append((pos_of(word), len(word)))
                elif not re.search(r"\bend\b", stripped[3:]):
                    opener, kind = "end", "for"
            elif re.match(r"^while\b", stripped):
                word = "while"
                if not re.search(r"\bdo\b", stripped):
                    errors.append((pos_of(word), len(word)))
                elif not re.search(r"\bend\b", stripped[5:]):
                    opener, kind = "end", "while"
            elif re.match(r"^(?:local\s+)?function\b", stripped) or re.search(r"\bfunction\s*\([^)]*\)\s*$", stripped):
                word = "function"
                if "(" not in stripped:
                    errors.append((pos_of(word), len(word)))
                elif not re.search(r"\bend\b", stripped[stripped.find("function") + 8:]):
                    opener, kind = "end", "function"
            elif re.match(r"^repeat\b", stripped):
                word = "repeat"
                if not re.search(r"\buntil\b", stripped[6:]):
                    opener, kind = "until", "repeat"
            elif re.match(r"^do\b", stripped) and not re.search(r"\bend\b", stripped[2:]):
                word = "do"
                opener, kind = "end", "do"
            if opener:
                stack.append((opener, kind, pos_of(word), len(word)))
            byte_offset += len(raw_line.encode("utf-8"))
        errors.extend((position, length) for _, _, position, length in stack)
        return errors

    def _apply_diagnostics(self, source):
        self._clear_indicator(self._ERROR_INDICATOR)
        try:
            data = source.encode("utf-8")
        except UnicodeError:
            return
        errors = set(self._delimiter_diagnostics(data))
        errors.update(self._block_diagnostics(source))
        for start, length in sorted(errors):
            self._fill_indicator(self._ERROR_INDICATOR, start, length)

    def show_find(self):
        if self._find_overlay is None:
            self._find_overlay = FindOverlay(self)
        self._find_overlay.show_find()

    def _autocomplete_active(self):
        return self._completion_popup.isVisible()

    def _hide_autocomplete(self):
        self._completion_timer.stop()
        self._completion_popup.hide()

    def _accept_completion_name(self, name):
        if not name:
            return
        prefix = self._completion_popup.prefix
        line, index = self.getCursorPosition()
        start = max(0, index - len(prefix))
        self.setSelection(line, start, line, index)
        self.replaceSelectedText(name)
        self.setCursorPosition(line, start + len(name))
        self._hide_autocomplete()
        self._schedule_analysis()

    def _accept_selected_completion(self):
        name = self._completion_popup.current_name()
        if name:
            self._accept_completion_name(name)
            return True
        return False

    def _paired_backspace(self):
        if self.hasSelectedText():
            return False
        line, index = self.getCursorPosition()
        if index <= 0:
            return False
        text = self.text(line)
        before = text[index - 1:index]
        after = text[index:index + 1]
        if self._PAIR_OPEN.get(before) != after:
            return False
        self.setSelection(line, index - 1, line, index + 1)
        self.removeSelectedText()
        return True

    def _skip_existing_closer(self, char):
        if self.hasSelectedText() or char not in self._PAIR_CLOSE:
            return False
        line, index = self.getCursorPosition()
        if self.text(line)[index:index + 1] != char:
            return False
        self.setCursorPosition(line, index + 1)
        return True

    def _insert_pair_after(self, char):
        closing = self._PAIR_OPEN.get(char)
        if not closing:
            return
        line, index = self.getCursorPosition()
        text = self.text(line)
        if char in {"\"", "'", "`"}:
            if index >= 2 and text[index - 2:index - 1] == "\\":
                return
            if text[index:index + 1] == closing:
                return
        try:
            self.insertAt(closing, line, index)
            self.setCursorPosition(line, index)
        except Exception:
            return

    @staticmethod
    def _identifier_prefix(before):
        match = re.search(r"([A-Za-z_]\w*)$", before)
        return match.group(1) if match else ""

    @staticmethod
    def _member_context(before):
        prefix = CodeEditor._identifier_prefix(before)
        cursor = len(before) - len(prefix)
        while cursor > 0 and before[cursor - 1].isspace():
            cursor -= 1
        if cursor <= 0 or before[cursor - 1] not in ".:":
            return None
        separator = before[cursor - 1]
        end = cursor - 1
        i = end - 1
        depth = 0
        quote = None
        while i >= 0:
            ch = before[i]
            if quote:
                if ch == quote and (i == 0 or before[i - 1] != "\\"):
                    quote = None
                i -= 1
                continue
            if ch in "\"'":
                quote = ch
                i -= 1
                continue
            if ch == ")":
                depth += 1
            elif ch == "(":
                depth = max(0, depth - 1)
            elif depth == 0 and (ch.isspace() or ch in "=,+-*/%^{}[];"):
                break
            i -= 1
        expression = before[i + 1:end].strip()
        return expression, separator, prefix

    def _infer_expression_type(self, expression):
        expression = expression.strip()
        if not expression:
            return ""
        if expression == "game":
            return "DataModel"
        if expression == "workspace":
            return "Workspace"
        if expression == "script":
            return "Instance"
        if expression in self._symbol_types:
            return self._symbol_types[expression]
        direct = re.fullmatch(r"game\s*:\s*GetService\s*\(\s*['\"]([A-Za-z_]\w*)['\"]\s*\)", expression)
        if direct:
            return direct.group(1)
        direct = re.fullmatch(r"Instance\s*\.\s*new\s*\(\s*['\"]([A-Za-z_]\w*)['\"](?:\s*,[^)]*)?\)", expression)
        if direct:
            return direct.group(1)
        if expression in ROBLOX_VALUE_TYPES.split():
            return expression
        if re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+", expression):
            parts = expression.split(".")
            current = self._infer_expression_type(parts[0])
            if not current:
                return ""
            for member in parts[1:]:
                current = ROBLOX_API_INDEX.member_type(current, member).rstrip("?")
                if not current:
                    return ""
            return current
        return ""

    def _string_completion_context(self, before):
        patterns = (
            (r"game\s*:\s*GetService\s*\(\s*['\"]([^'\"]*)$", "service"),
            (r"Instance\s*\.\s*new\s*\(\s*['\"]([^'\"]*)$", "class"),
            (r"(?:IsA|FindFirstChildOfClass|FindFirstChildWhichIsA)\s*\(\s*['\"]([^'\"]*)$", "class"),
        )
        for pattern, kind in patterns:
            match = re.search(pattern, before)
            if match:
                return kind, match.group(1)
        return None

    @staticmethod
    def _kind_from_member_meta(meta):
        kind = str((meta or {}).get("kind") or "").casefold()
        if kind in {"function", "yieldfunction"}:
            return "method"
        if kind == "property":
            return "property"
        if kind == "event":
            return "event"
        if kind == "callback":
            return "callback"
        return "field"

    @staticmethod
    def _filter_entries(entries, prefix, limit=220):
        folded = prefix.casefold()
        unique = {}
        for name, kind in entries:
            name = str(name)
            if not name.casefold().startswith(folded):
                continue
            unique.setdefault(name, kind)
        kind_priority = {
            "local_variable": 0, "local_function": 0,
            "variable": 1, "function": 1, "method": 1,
            "property": 2, "event": 2, "callback": 2,
            "enum_member": 2, "field": 2,
            "keyword": 3, "module": 3, "struct": 3, "type": 3,
            "service": 4, "class": 4, "enum": 4,
        }
        ordered = sorted(
            unique.items(),
            key=lambda item: (
                not item[0].startswith(prefix),
                kind_priority.get(item[1], 6),
                len(item[0]),
                item[0].casefold(),
            ),
        )
        return ordered[:limit]

    def _completion_candidates(self, before, allow_empty=False):
        class_names, enum_names, services, creatable, _ = ROBLOX_API_INDEX.snapshot()
        string_context = self._string_completion_context(before)
        if string_context:
            kind, prefix = string_context
            pool = services if kind == "service" else (creatable or class_names)
            icon_kind = "service" if kind == "service" else "class"
            return prefix, self._filter_entries(((name, icon_kind) for name in pool), prefix)
        member_context = self._member_context(before)
        if member_context:
            expression, separator, prefix = member_context
            if expression == "Enum":
                return prefix, self._filter_entries(((name, "enum") for name in enum_names), prefix)
            if expression.startswith("Enum."):
                enum_name = expression.split(".", 1)[1]
                return prefix, self._filter_entries(((name, "enum_member") for name in ROBLOX_API_INDEX.enum_items(enum_name)), prefix)
            if expression in STATIC_MEMBER_FALLBACKS:
                entries = []
                for name, signature in STATIC_MEMBER_FALLBACKS[expression].items():
                    entries.append((name, "function" if "(" in str(signature) else "property"))
                return prefix, self._filter_entries(entries, prefix)
            expression_type = self._infer_expression_type(expression)
            if expression_type:
                members = ROBLOX_API_INDEX.class_members(expression_type, method_only=separator == ":")
                entries = [(name, self._kind_from_member_meta(meta)) for name, meta in members.items()]
                for name, signature in STATIC_MEMBER_FALLBACKS.get(expression_type, {}).items():
                    entries.append((name, "function" if "(" in str(signature) else "property"))
                return prefix, self._filter_entries(entries, prefix)
            return prefix, []
        prefix = self._identifier_prefix(before)
        if not prefix and not allow_empty:
            return "", []
        entries = []
        entries.extend((name, "keyword") for name in LUAU_KEYWORDS.split())
        entries.extend((name, "function" if name in GLOBAL_SIGNATURES else "variable") for name in LUAU_GLOBALS.split())
        entries.extend((name, "module") for name in LUAU_LIBRARIES.split())
        for name in ROBLOX_GLOBALS.split():
            if name == "Enum":
                kind = "enum"
            elif name == "Instance":
                kind = "class"
            else:
                kind = "variable"
            entries.append((name, kind))
        entries.extend((name, "struct") for name in ROBLOX_VALUE_TYPES.split())
        entries.extend((name, self._local_symbol_kinds.get(name, "variable")) for name in self._local_symbols)
        entries.extend((name, "service" if name in services else "class") for name in class_names)
        return prefix, self._filter_entries(entries, prefix)

    def show_autocomplete(self, force=False):
        if self.hasSelectedText() or not self.hasFocus():
            self._hide_autocomplete()
            return
        self._refresh_recent_symbols()
        line, index = self.getCursorPosition()
        before = self.text(line)[:index]
        prefix, candidates = self._completion_candidates(before, allow_empty=force)
        contextual = self._member_context(before) is not None or self._string_completion_context(before) is not None
        if not candidates or (not force and not prefix and not contextual):
            self._hide_autocomplete()
            return
        if len(candidates) == 1 and candidates[0][0] == prefix:
            self._hide_autocomplete()
            return
        self._completion_popup.set_candidates(prefix, candidates, self._autocomplete_icons)

    def _calltip_for_expression(self, expression):
        expression = expression.strip()
        if not expression:
            return ""
        if expression in GLOBAL_SIGNATURES:
            return GLOBAL_SIGNATURES[expression]
        if ":" in expression:
            object_expression, member = expression.rsplit(":", 1)
            expression_type = self._infer_expression_type(object_expression)
            if expression_type:
                return ROBLOX_API_INDEX.member_signature(expression_type, member)
        if "." in expression:
            object_expression, member = expression.rsplit(".", 1)
            fallback = STATIC_MEMBER_FALLBACKS.get(object_expression, {}).get(member)
            if fallback:
                return fallback
            expression_type = self._infer_expression_type(object_expression)
            if expression_type:
                return ROBLOX_API_INDEX.member_signature(expression_type, member)
        return ""

    def show_calltip(self):
        line, index = self.getCursorPosition()
        before = self.text(line)[:index]
        match = re.search(r"([A-Za-z_]\w*(?:(?:\.|:)[A-Za-z_]\w*)*)\s*\($", before)
        if not match:
            return
        signature = self._calltip_for_expression(match.group(1))
        if not signature:
            return
        try:
            position = self.SendScintilla(self.SCI_GETCURRENTPOS)
            self.SendScintilla(self.SCI_CALLTIPSHOW, position, signature.encode("utf-8"))
        except Exception:
            return

    @classmethod
    def _block_opener(cls, text):
        code = cls._strip_inline_comment(text).strip()
        if not code:
            return None
        if re.match(r"^if\b.*\bthen\s*$", code):
            return "end"
        if re.match(r"^(?:for|while)\b.*\bdo\s*$", code):
            return "end"
        if re.match(r"^do\s*$", code):
            return "end"
        if re.match(r"^repeat\s*$", code):
            return "until "
        if re.match(r"^(?:local\s+)?function\b.*\)\s*(?::\s*[^=]+)?\s*$", code):
            return "end"
        if re.search(r"(?:^|[=,(]\s*)function\s*\([^)]*\)\s*$", code):
            return "end"
        return None

    @staticmethod
    def _continuation_indent(text):
        code = CodeEditor._strip_inline_comment(text).strip()
        return bool(re.match(r"^(?:else\b|elseif\b.*\bthen\s*$)", code))

    def _next_nonempty_line(self, line):
        for row in range(line + 1, self.lines()):
            value = self.text(row).strip()
            if value:
                return value
        return ""

    def _smart_newline(self):
        if self.hasSelectedText():
            return False
        line, index = self.getCursorPosition()
        raw = self.text(line).rstrip("\r\n")
        before = raw[:index]
        after = raw[index:]
        indent_match = re.match(r"[ \t]*", before)
        base_indent = indent_match.group(0) if indent_match else ""
        inner_indent = base_indent + self._INDENT

        if before.rstrip().endswith("{") and after.lstrip().startswith("}"):
            self.insert("\n" + inner_indent + "\n" + base_indent)
            self.setCursorPosition(line + 1, len(inner_indent))
            return True

        closer = self._block_opener(before)
        if closer:
            after_only_closers = not after.strip() or bool(re.fullmatch(r"[)\]}\s,;]*", after))
            if after_only_closers:
                next_line = self._next_nonempty_line(line)
                closer_word = closer.strip().split()[0]
                already_there = bool(re.match(rf"^{re.escape(closer_word)}\b", next_line))
                insertion = "\n" + inner_indent
                if not already_there:
                    insertion += "\n" + base_indent + closer
                self.insert(insertion)
                self.setCursorPosition(line + 1, len(inner_indent))
                self._schedule_analysis()
                return True

        next_indent = base_indent + (self._INDENT if self._continuation_indent(before) else "")
        self.insert("\n" + next_indent)
        self.setCursorPosition(line + 1, len(next_indent))
        self._schedule_analysis()
        return True

    def keyPressEvent(self, event):
        if event.matches(QKeySequence.StandardKey.Find):
            self.show_find()
            event.accept()
            return
        if event.matches(QKeySequence.StandardKey.Paste) and self.paste_handler:
            self.paste_handler()
            event.accept()
            return
        if event.modifiers() == Qt.KeyboardModifier.ControlModifier and event.key() == Qt.Key.Key_Space:
            self._queue_autocomplete(force=True)
            event.accept()
            return
        if event.key() == Qt.Key.Key_Tab and self._completion_timer.isActive():
            
            
            self._completion_timer.stop()
            self.show_autocomplete()
        if self._autocomplete_active() and event.key() in (Qt.Key.Key_Up, Qt.Key.Key_Down, Qt.Key.Key_PageUp, Qt.Key.Key_PageDown):
            step = -1 if event.key() == Qt.Key.Key_Up else 1
            if event.key() == Qt.Key.Key_PageUp:
                step = -8
            elif event.key() == Qt.Key.Key_PageDown:
                step = 8
            self._completion_popup.move_selection(step)
            event.accept()
            return
        if self._autocomplete_active() and event.key() in (Qt.Key.Key_Tab, Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if self._accept_selected_completion():
                event.accept()
                return
        if event.key() == Qt.Key.Key_Escape and self._autocomplete_active():
            self._hide_autocomplete()
            event.accept()
            return
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) and event.modifiers() in (
            Qt.KeyboardModifier.NoModifier, Qt.KeyboardModifier.KeypadModifier,
        ):
            if self._smart_newline():
                event.accept()
                return
        if event.key() == Qt.Key.Key_Backspace and self._paired_backspace():
            event.accept()
            self._queue_autocomplete()
            return
        text = event.text()
        if text and self._skip_existing_closer(text):
            event.accept()
            self._queue_autocomplete()
            return
        super().keyPressEvent(event)
        if text in self._PAIR_OPEN:
            self._insert_pair_after(text)
        if text and (text[-1:].isalnum() or text in "_.:\"'"):
            self._queue_autocomplete()
        elif event.key() == Qt.Key.Key_Backspace:
            self._queue_autocomplete()
        elif text == " ":
            line, index = self.getCursorPosition()
            before = self.text(line)[:index].rstrip()
            if re.search(r"(?:\blocal|\breturn|\bthen|\bdo|=)$", before):
                self._queue_autocomplete(force=True)

    def mousePressEvent(self, event):
        self._hide_autocomplete()
        super().mousePressEvent(event)

    def wheelEvent(self, event):
        self._hide_autocomplete()
        super().wheelEvent(event)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self._autocomplete_active():
            self._completion_popup.reposition()

    def focusOutEvent(self, event):
        super().focusOutEvent(event)
        QTimer.singleShot(0, self._hide_if_focus_left)

    def _hide_if_focus_left(self):
        if not self.hasFocus():
            self._hide_autocomplete()

    def hideEvent(self, event):
        self._hide_autocomplete()
        super().hideEvent(event)

    def contextMenuEvent(self, event):
        menu = QMenu(self)
        for label, action in (("Undo", self.undo), ("Redo", self.redo),
                              ("Cut", self.cut), ("Copy", self.copy),
                              ("Paste", self.paste_handler),
                              ("Find", self.show_find),
                              ("Select All", self.selectAll)):
            menu.addAction(label, action)
        menu.exec(event.globalPos())


class ScriptBloxInstallDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.behavior = None
        self.setWindowTitle("ScriptBlox install")
        self.setModal(True)
        self.resize(470, 315)
        self.setMinimumWidth(430)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "ScriptBlox install", (18, 18, 18, 18), 12)

        heading = QLabel("Choose how ScriptBlox should install scripts")
        heading.setObjectName("installHeading")
        layout.addWidget(heading)

        choices = QVBoxLayout()
        choices.setSpacing(8)
        options = (
            ("Put in current code window", "current", False),
            ("Put in current code window & run", "current_execute", False),
            ("Put in new code window", "new", False),
            ("Put in new code window & run    Recommended", "new_execute", True),
        )
        for label, behavior, recommended in options:
            button = QPushButton(label.replace("&", "&&"))
            button.setObjectName("installRecommended" if recommended else "installChoice")
            button.setMinimumHeight(42)
            button.setCursor(Qt.CursorShape.PointingHandCursor)
            button.clicked.connect(lambda checked=False, value=behavior: self.choose(value))
            choices.addWidget(button)
        layout.addLayout(choices)

        bottom = QHBoxLayout()
        bottom.addStretch(1)
        cancel = QPushButton("Cancel")
        cancel.setObjectName("installCancel")
        cancel.setFixedWidth(90)
        cancel.clicked.connect(self.reject)
        bottom.addWidget(cancel)
        layout.addLayout(bottom)

        self.setStyleSheet(r'''            QLabel#installHeading {
                color: #f1f1f1;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton#installChoice, QPushButton#installRecommended {
                text-align: left;
                padding: 9px 12px;
                border-radius: 8px;
            }
            QPushButton#installChoice {
                background: #0b0c0b;
                border: 1px solid #292929;
                color: #e4e4e4;
            }
            QPushButton#installChoice:hover {
                background: #181818;
                border-color: #3c3c3c;
            }
            QPushButton#installRecommended {
                background: #102b19;
                border: 1px solid #2e6c3d;
                color: #8febaa;
                font-weight: 600;
            }
            QPushButton#installRecommended:hover {
                background: #163922;
                border-color: #438a55;
                color: #a4f4b9;
            }
            QPushButton#installCancel {
                background: transparent;
                border: 1px solid #292929;
            }
            QPushButton#installCancel:hover {
                background: #151515;
                border-color: #3a3a3a;
            }
        ''')
        apply_blur_style(self)

    def choose(self, behavior):
        self.behavior = behavior
        self.accept()


class ScriptBloxWindow(QDialog):
    SORTS = (
        ("Popular", "views"),
        ("Most liked", "likeCount"),
        ("Newest", "createdAt"),
        ("Recently updated", "updatedAt"),
    )

    def __init__(self, parent, install_callback):
        super().__init__(parent)
        self.install_callback = install_callback
        self.events = queue.Queue()
        self.request_id = 0
        self.next_page = None
        self.loaded_keys = set()
        self.saved_scripts = load_saved_scripts()
        self.saved_only = False
        self.browse_state = None
        self.auto_place_id = None
        self.setWindowTitle("ScriptBlox")
        self.resize(720, 560)
        self.setMinimumSize(560, 400)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "ScriptBlox", (16, 16, 16, 16), 10)
        back_row = QHBoxLayout()
        self.back_button = QPushButton()
        self.back_button.setFixedSize(34, 34)
        back_icon = app_icon("back")
        if not back_icon.isNull():
            self.back_button.setIcon(back_icon)
            self.back_button.setIconSize(QSize(18, 18))
        self.back_button.clicked.connect(lambda: self.saved_button.setChecked(False))
        self.back_button.hide()
        back_row.addWidget(self.back_button)
        back_row.addStretch(1)
        layout.addLayout(back_row)
        searches = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search scripts...")
        self.search.setClearButtonEnabled(True)
        self.search.returnPressed.connect(self.refresh)
        searches.addWidget(self.search, 1)

        self.game_search = QLineEdit()
        self.game_search.setPlaceholderText("Search games or place ID...")
        self.game_search.setClearButtonEnabled(True)
        self.game_search.returnPressed.connect(self.refresh)
        searches.addWidget(self.game_search, 1)
        layout.addLayout(searches)

        filters = QHBoxLayout()

        self.sort = LelComboBox()
        sort_icon = app_icon("sort")
        for label, value in self.SORTS:
            self.sort.addItem(sort_icon, label, value)
        self.sort.currentIndexChanged.connect(self.refresh)
        filters.addWidget(self.sort)

        self.keyless = QPushButton("Keyless")
        self.keyless.setObjectName("keylessButton")
        self.keyless.setCheckable(True)
        self.keyless.setChecked(True)
        keyless_icon = app_icon("keyless")
        if not keyless_icon.isNull():
            self.keyless.setIcon(keyless_icon)
            self.keyless.setIconSize(QSize(18, 18))
        self.keyless.toggled.connect(self.refresh)
        filters.addWidget(self.keyless)
        filters.addStretch(1)

        self.saved_button = QPushButton("Saved Scripts")
        self.saved_button.setObjectName("savedScriptsButton")
        self.saved_button.setCheckable(True)
        saved_icon = app_icon("stared")
        if saved_icon.isNull():
            saved_icon = app_icon("star")
        if not saved_icon.isNull():
            self.saved_button.setIcon(saved_icon)
            self.saved_button.setIconSize(QSize(17, 17))
        self.saved_button.toggled.connect(self.set_saved_only)
        filters.addWidget(self.saved_button)
        layout.addLayout(filters)

        self.status = QLabel("Loading scripts...")
        self.status.setTextFormat(Qt.TextFormat.PlainText)
        layout.addWidget(self.status)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.results = QWidget()
        self.results_layout = QVBoxLayout(self.results)
        self.results_layout.setContentsMargins(0, 0, 0, 0)
        self.results_layout.setSpacing(8)
        self.load_more_button = QPushButton("Load More")
        self.load_more_button.clicked.connect(self.load_more)
        self.load_more_button.hide()
        self.results_layout.addStretch(1)
        self.results_layout.addWidget(self.load_more_button)
        self.scroll.setWidget(self.results)
        layout.addWidget(self.scroll, 1)

        self.search_timer = QTimer(self)
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(650)
        self.search_timer.timeout.connect(self.refresh)
        self.search.textChanged.connect(lambda: self.search_timer.start())
        self.game_search.textChanged.connect(lambda: self.search_timer.start())
        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(50)
        self.poll_timer.timeout.connect(self.poll_events)
        self.poll_timer.start()
        self.setStyleSheet("""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel, QCheckBox { background: transparent; }
            QLabel { color: #b7bbbd; }
            QLineEdit { background: #0d0d0d; border: 1px solid #2b2b2b;
                border-radius: 7px; padding: 7px; }
            QPushButton { background: #101214; border: 1px solid #2d3235;
                border-radius: 4px; padding: 5px 10px; }
            QPushButton:hover { background: #1e2225; }
            QPushButton#starButton { background: #0d0d0d; border: 1px solid #262626;
                border-radius: 6px; padding: 0; }
            QPushButton#starButton:hover { background: #181818; border-color: #3a3a3a; }
            QPushButton#savedScriptsButton:checked { background: #27220f; color: #f0d56a;
                border-color: #66582a; }
            QPushButton#savedScriptsButton:checked:hover { background: #322b12; border-color: #806f32; }
            QFrame#scriptCard { background: #090909; border: 1px solid #121212;
                border-radius: 4px; }
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)
        apply_blur_style(self)
        self.prefill_current_game(refresh_on_change=False)
        QTimer.singleShot(0, self.refresh)

    def prefill_current_game(self, refresh_on_change=True):
        if self.saved_only:
            return False
        current = self.game_search.text().strip()
        if current and current != (self.auto_place_id or ""):
            return False
        try:
            place_id = current_roblox_place_id()
        except Exception:
            return False
        if not place_id:
            return False
        place_id = str(place_id)
        changed = current != place_id
        self.auto_place_id = place_id
        if changed:
            self.game_search.blockSignals(True)
            self.game_search.setText(place_id)
            self.game_search.blockSignals(False)
            if refresh_on_change:
                QTimer.singleShot(0, self.refresh)
        return changed

    def refresh(self, *_):
        self.search_timer.stop()
        self.next_page = None
        self.loaded_keys.clear()
        self.clear_results()
        if self.saved_only:
            self.refresh_saved()
            return
        self.request_page(1, append=False)

    def set_saved_only(self, enabled):
        enabled = bool(enabled)
        if enabled == self.saved_only:
            return

        self.search_timer.stop()
        if enabled:
            self.browse_state = {
                "search": self.search.text(),
                "game_search": self.game_search.text(),
                "keyless": self.keyless.isChecked(),
                "sort": self.sort.currentIndex(),
            }
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(True)
            self.search.clear()
            self.game_search.clear()
            self.keyless.setChecked(False)
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(False)
                widget.hide()
        else:
            state = self.browse_state or {}
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.show()
                widget.blockSignals(True)
            self.search.setText(str(state.get("search", "")))
            self.game_search.setText(str(state.get("game_search", "")))
            self.keyless.setChecked(bool(state.get("keyless", True)))
            sort_index = state.get("sort", 0)
            if isinstance(sort_index, int) and 0 <= sort_index < self.sort.count():
                self.sort.setCurrentIndex(sort_index)
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(False)
            self.browse_state = None

        self.saved_only = enabled
        self.back_button.setVisible(enabled)
        self.request_id += 1
        self.next_page = None
        self.load_more_button.hide()
        self.load_more_button.setEnabled(False)
        self.refresh()

    def refresh_saved(self):
        scripts = list(self.saved_scripts.values())
        scripts.sort(
            key=lambda item: float(item.get("_lelsploit_saved_at", 0) or 0),
            reverse=True,
        )
        self.show_scripts(scripts, append=False)
        if not scripts:
            self.status.setText("No saved scripts.")

    def request_page(self, page, append):
        self.request_id += 1
        request_id = self.request_id
        self.status.setText("Loading more..." if append else "Loading scripts...")
        self.set_filters_enabled(False)
        self.load_more_button.setVisible(False)
        self.load_more_button.setEnabled(False)
        threading.Thread(
            target=fetch_scriptblox,
            args=(self.events, request_id, self.search.text(),
                  self.game_search.text(), self.sort.currentData(),
                  self.keyless.isChecked(), page, append),
            daemon=True,
        ).start()

    def load_more(self):
        if self.next_page is not None and self.load_more_button.isEnabled():
            self.request_page(self.next_page, append=True)

    def set_filters_enabled(self, enabled):
        active = bool(enabled) and not self.saved_only
        self.sort.setEnabled(active)
        self.keyless.setEnabled(active)

    def clear_results(self):
        while self.results_layout.count() > 2:
            item = self.results_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
        self.load_more_button.hide()

    def show_scripts(self, scripts, append=False):
        if not append:
            self.clear_results()
            self.loaded_keys.clear()
        if not scripts and not self.loaded_keys:
            self.status.setText("No saved scripts." if self.saved_only else "No scripts found.")
            return
        install_icon = app_icon("install")
        for script in scripts:
            game_data = script.get("game") if isinstance(script.get("game"), dict) else {}
            key = scriptblox_script_key(script)
            if key in self.loaded_keys:
                continue
            self.loaded_keys.add(key)
            card = QFrame()
            card.setObjectName("scriptCard")
            card_layout = QHBoxLayout(card)
            card_layout.setContentsMargins(12, 10, 12, 10)
            details = QVBoxLayout()
            title = QLabel(str(script.get("title") or "Untitled script"))
            title.setTextFormat(Qt.TextFormat.PlainText)
            title.setStyleSheet("color: #eeeeee; font-weight: 600;")
            details.addWidget(title)
            game = str(game_data.get("name") or "Universal")
            views = script.get("views")
            meta = game if not isinstance(views, (int, float)) else f"{game}  •  {int(views):,} views"
            meta_label = QLabel(meta)
            meta_label.setTextFormat(Qt.TextFormat.PlainText)
            details.addWidget(meta_label)
            card_layout.addLayout(details, 1)
            install = QPushButton("Install")
            if not install_icon.isNull():
                install.setIcon(install_icon)
                install.setIconSize(QSize(18, 18))
            install.clicked.connect(lambda checked=False, item=script: self.install(item))
            card_layout.addWidget(install)

            star = QPushButton()
            star.setObjectName("starButton")
            star.setFixedSize(34, 34)
            self.update_star_button(star, key in self.saved_scripts)
            star.clicked.connect(
                lambda checked=False, item=script, button=star: self.toggle_saved(item, button)
            )
            card_layout.addWidget(star)
            self.results_layout.insertWidget(self.results_layout.count() - 2, card)
        label = "saved scripts" if self.saved_only else "scripts"
        self.status.setText(f"{len(self.loaded_keys)} {label}")

    def update_star_button(self, button, starred):
        icon = app_icon("stared" if starred else "star")
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(17, 17))
        button.setToolTip("Remove from saved scripts" if starred else "Save script")

    def toggle_saved(self, script, button=None):
        key = scriptblox_script_key(script)
        if not key:
            return
        if key in self.saved_scripts:
            del self.saved_scripts[key]
            starred = False
        else:
            try:
                saved = json.loads(json.dumps(script, ensure_ascii=False))
            except (TypeError, ValueError):
                saved = dict(script)
            saved["_lelsploit_saved_at"] = time.time()
            self.saved_scripts[key] = saved
            starred = True
        try:
            save_saved_scripts(self.saved_scripts)
        except OSError as exc:
            self.status.setText(f"Could not save scripts: {exc}")
            return
        if button is not None:
            self.update_star_button(button, starred)
        if starred:
            saved_item = self.saved_scripts.get(key, {})
            script_id = saved_item.get("_id") or saved_item.get("slug")
            code = saved_item.get("script")
            if script_id and not (isinstance(code, str) and code.strip()):
                self.status.setText("Saving script source...")
                threading.Thread(
                    target=fetch_scriptblox_saved_raw,
                    args=(self.events, key, script_id, saved_item.get("slug")),
                    daemon=True,
                ).start()
            else:
                self.status.setText("Script saved.")
        else:
            self.status.setText("Removed from saved scripts.")
        if self.saved_only and not starred:
            self.refresh_saved()

    def install(self, script):
        title = str(script.get("title") or "script")
        code = script.get("script")
        if isinstance(code, str) and code.strip():
            installed = self.install_callback(code, title)
            self.status.setText(f"Installed {title}." if installed else "Install cancelled.")
            return
        script_id = script.get("_id") or script.get("slug")
        if not script_id:
            self.status.setText("This script has no downloadable source.")
            return
        self.status.setText(f"Installing {title}...")
        threading.Thread(
            target=fetch_scriptblox_raw,
            args=(self.events, script_id, title, script.get("slug")),
            daemon=True,
        ).start()

    def poll_events(self):
        for _ in range(20):
            try:
                kind, first, second = self.events.get_nowait()
            except queue.Empty:
                break
            if kind == "catalog":
                if first == self.request_id:
                    self.set_filters_enabled(True)
                    self.next_page = second["next_page"]
                    self.show_scripts(second["scripts"], second["append"])
                    self.load_more_button.setVisible(self.next_page is not None)
                    self.load_more_button.setEnabled(self.next_page is not None)
            elif kind == "catalog_error":
                if first == self.request_id:
                    self.set_filters_enabled(True)
                    self.load_more_button.hide()
                    self.load_more_button.setEnabled(False)
                    if not self.loaded_keys:
                        self.clear_results()
                    self.status.setText("Could not load scripts.")
            elif kind == "install":
                installed = self.install_callback(second, first)
                self.status.setText(f"Installed {first}." if installed else "Install cancelled.")
            elif kind == "save":
                if first in self.saved_scripts:
                    self.saved_scripts[first]["script"] = second
                    try:
                        save_saved_scripts(self.saved_scripts)
                        self.status.setText("Script saved.")
                    except OSError as exc:
                        self.status.setText(f"Could not save scripts: {exc}")
            elif kind == "save_error":
                if first in self.saved_scripts:
                    self.status.setText(f"Saved script, but source could not be cached: {second}")
            else:
                self.status.setText(f"Could not install {first}: {second}")


class HoverCopyButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._opacity = QGraphicsOpacityEffect(self)
        self._opacity.setOpacity(0.72)
        self.setGraphicsEffect(self._opacity)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setFixedSize(26, 26)
        self.setIcon(app_icon("copy"))
        self.setIconSize(QSize(14, 14))
        self.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: 0;
                border-radius: 5px;
                padding: 0;
            }
            QPushButton:hover { background: #1b1b1b; }
            QPushButton:pressed { background: #121212; }
        """)

    def enterEvent(self, event):
        self._opacity.setOpacity(1.0)
        self.setIconSize(QSize(16, 16))
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._opacity.setOpacity(0.72)
        self.setIconSize(QSize(14, 14))
        super().leaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._opacity.setOpacity(0.55)
            self.setIconSize(QSize(12, 12))
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self._opacity.setOpacity(1.0 if self.underMouse() else 0.72)
            self.setIconSize(QSize(13, 13))
            QTimer.singleShot(
                85,
                lambda: self.setIconSize(QSize(16, 16) if self.underMouse() else QSize(14, 14)),
            )


class HoverCopyLineEdit(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._copy_button = HoverCopyButton(self)
        self._copy_button.hide()
        self._copy_button.clicked.connect(self.copy_result)
        self.textChanged.connect(self._sync_copy_button)
        self.setMouseTracking(True)
        self.setTextMargins(0, 0, 30, 0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        x = max(2, self.width() - self._copy_button.width() - 5)
        y = max(0, (self.height() - self._copy_button.height()) // 2)
        self._copy_button.move(x, y)
        self._copy_button.raise_()

    def enterEvent(self, event):
        self._sync_copy_button()
        super().enterEvent(event)

    def leaveEvent(self, event):
        super().leaveEvent(event)
        QTimer.singleShot(0, self._sync_copy_button)

    def _sync_copy_button(self, *_):
        visible = bool(self.text()) and (self.underMouse() or self._copy_button.underMouse())
        self._copy_button.setVisible(visible)
        if visible:
            self._copy_button.raise_()

    def copy_result(self):
        value = self.text()
        if value:
            QApplication.clipboard().setText(value)


class ToolsWindow(QDialog):
    TOOL_NAMES = ("Loadstring Reverser", "Loadstring Creator", "GitHub Rawifier", "Deobfuscate")

    def __init__(self, parent):
        super().__init__(parent)
        self.setWindowTitle("Tools")
        self.resize(760, 560)
        self.setMinimumSize(600, 420)
        apply_window_icon(self)

        self.owner = parent
        self.events = queue.Queue(maxsize=16)
        self.fetch_cancel = None
        self.request_id = 0
        self.fetch_url = ""

        layout = blur_content_layout(self, self, "Tools", (16, 16, 16, 16), 10)

        nav = QHBoxLayout()
        nav.setContentsMargins(0, 0, 0, 0)
        nav.setSpacing(6)
        self.tool_group = QButtonGroup(self)
        self.tool_group.setExclusive(True)
        self.tool_buttons = []
        for index, name in enumerate(self.TOOL_NAMES):
            button = QPushButton(name)
            button.setObjectName("toolNavButton")
            button.setCheckable(True)
            button.clicked.connect(lambda checked=False, i=index: self.select_tool(i))
            self.tool_group.addButton(button, index)
            self.tool_buttons.append(button)
            nav.addWidget(button)
        nav.addStretch(1)
        layout.addLayout(nav)

        self.tool_stack = QStackedWidget()
        self.tool_stack.setObjectName("toolStack")
        layout.addWidget(self.tool_stack, 1)

        self._build_reverser_page()
        self._build_creator_page()
        self._build_github_page()
        self._build_deobfuscate_page()
        self.select_tool(0)

        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(30)
        self.poll_timer.timeout.connect(self.poll_fetch)
        self.poll_timer.start()

        self.deob_timer = QTimer(self)
        self.deob_timer.setInterval(40)
        self.deob_timer.timeout.connect(self.poll_deobfuscate)
        self.deob_timer.start()

        self.setStyleSheet(r"""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel { background: transparent; color: #a8a8a8; }
            QStackedWidget#toolStack { background: transparent; border: none; }
            QPushButton#toolNavButton {
                min-height: 30px; padding: 0 12px;
                background: #0d0d0e; color: #bcbcbc;
                border: 1px solid #242424; border-radius: 5px;
            }
            QPushButton#toolNavButton:hover { background: #151516; color: #eeeeee; }
            QPushButton#toolNavButton:checked {
                background: #1a1a1c; color: #ffffff; border-color: #383838;
            }
            QPlainTextEdit, QLineEdit {
                background: #09090a; color: #eeeeee;
                border: 1px solid #272727; border-radius: 5px;
                padding: 7px;
            }
            QLineEdit:read-only { color: #bfc0c2; background: #070708; }
            QFrame#toolOutputFrame {
                background: #070708; border: 1px solid #252525; border-radius: 6px;
            }
            QsciScintilla#toolOutput {
                background: #070708; color: #eeeeee; border: none;
            }
            QPushButton {
                background: #111112; color: #eeeeee;
                border: 1px solid #2b2b2b; border-radius: 5px;
                padding: 7px 11px;
            }
            QPushButton:hover { background: #1a1a1b; border-color: #383838; }
            QPushButton:disabled { color: #666666; }
            QScrollBar { background: #070708; }
            QScrollBar:horizontal { height: 9px; }
            QScrollBar:vertical { width: 9px; }
            QScrollBar::handle { background: #38383b; border-radius: 4px; min-width: 24px; min-height: 24px; }
            QScrollBar::handle:hover { background: #4a4a4e; }
            QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
        """)
        apply_blur_style(self)

    @staticmethod
    def _page_layout(page):
        layout = QVBoxLayout(page)
        layout.setContentsMargins(0, 2, 0, 0)
        layout.setSpacing(8)
        return layout

    def _build_reverser_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.loadstring_input = QPlainTextEdit()
        self.loadstring_input.setPlaceholderText(
            'loadstring(game:HttpGet("https://example.com/script.lua"))()'
        )
        self.loadstring_input.setFixedHeight(92)
        self.loadstring_input.setFont(QFont("Consolas", 10))
        layout.addWidget(self.loadstring_input)
        self.loadstring_find = FindOverlay(self.loadstring_input)
        self.loadstring_find_shortcut = QShortcut(QKeySequence("Ctrl+F"), self.loadstring_input)
        self.loadstring_find_shortcut.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
        self.loadstring_find_shortcut.activated.connect(self.loadstring_find.show_find)

        fetch_actions = QHBoxLayout()
        fetch_actions.setContentsMargins(0, 0, 0, 0)
        fetch_actions.setSpacing(7)
        self.fetch_button = QPushButton("Reverse / Fetch")
        self.fetch_button.clicked.connect(self.fetch_loadstring)
        fetch_actions.addWidget(self.fetch_button, 1)
        self.fetch_to_script_button = QPushButton("Open as New Script")
        self.fetch_to_script_button.setEnabled(False)
        new_icon = app_icon("new")
        if not new_icon.isNull():
            self.fetch_to_script_button.setIcon(new_icon)
            self.fetch_to_script_button.setIconSize(QSize(16, 16))
        self.fetch_to_script_button.clicked.connect(self.open_fetch_as_script)
        fetch_actions.addWidget(self.fetch_to_script_button)
        layout.addLayout(fetch_actions)

        self.fetch_status = QLabel("")
        self.fetch_status.setTextFormat(Qt.TextFormat.PlainText)
        self.fetch_status.hide()
        layout.addWidget(self.fetch_status)

        frame = QFrame()
        frame.setObjectName("toolOutputFrame")
        frame_layout = QVBoxLayout(frame)
        frame_layout.setContentsMargins(1, 1, 1, 1)
        frame_layout.setSpacing(0)

        self.fetch_output = QsciScintilla(frame)
        self.fetch_output.setObjectName("toolOutput")
        self.fetch_output.setUtf8(True)
        self.fetch_output.setFont(QFont("Consolas", 10))
        self.fetch_output.setColor(QColor("#eeeeee"))
        self.fetch_output.setPaper(QColor("#070708"))
        self.fetch_output.setMargins(0)
        self.fetch_output.setWrapMode(QsciScintilla.WrapMode.WrapNone)
        self.fetch_output.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.fetch_output.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.fetch_output.setReadOnly(True)
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETUNDOCOLLECTION, 0)
        self.fetch_output.SendScintilla(
            self.fetch_output.SCI_SETLAYOUTCACHE, self.fetch_output.SC_CACHE_PAGE
        )
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETSCROLLWIDTH, 1)
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETSCROLLWIDTHTRACKING, 1)
        self._configure_fetch_syntax()
        frame_layout.addWidget(self.fetch_output)
        layout.addWidget(frame, 1)
        self.tool_stack.addWidget(page)

    def _configure_fetch_syntax(self, editor=None, lexer_attr="fetch_lexer"):
        editor = self.fetch_output if editor is None else editor
        lexer = LuauLexer(editor)
        setattr(self, lexer_attr, lexer)
        editor.SendScintilla(editor.SCI_SETLEXER, editor.SCLEX_NULL)
        editor.SendScintilla(editor.SCI_STYLESETFORE, editor.STYLE_DEFAULT, QColor("#eeeeee"))
        editor.SendScintilla(editor.SCI_STYLESETBACK, editor.STYLE_DEFAULT, QColor("#070708"))
        editor.SendScintilla(editor.SCI_STYLESETFONT, editor.STYLE_DEFAULT, b"Consolas")
        editor.SendScintilla(editor.SCI_STYLESETSIZE, editor.STYLE_DEFAULT, 10)
        editor.SendScintilla(editor.SCI_STYLECLEARALL)
        styles = {
            "#7f936f": (lexer.Comment, lexer.LineComment),
            "#86a8e7": (lexer.Keyword,),
            "#a8c77a": (lexer.String, lexer.Character, lexer.LiteralString, lexer.UnclosedString),
            "#c9a56f": (lexer.Number,),
            "#d7dadd": (lexer.Operator,),
            "#7db0d5": (lexer.BasicFunctions, lexer.KeywordSet5, lexer.KeywordSet6, lexer.KeywordSet7),
            "#7daee0": (lexer.StringTableMathsFunctions, lexer.CoroutinesIOSystemFacilities),
            "#b5a0d2": (lexer.KeywordSet8,),
        }
        for style in range(32):
            editor.SendScintilla(editor.SCI_STYLESETFORE, style, QColor("#eeeeee"))
            editor.SendScintilla(editor.SCI_STYLESETBACK, style, QColor("#070708"))
        for color, style_numbers in styles.items():
            for style in style_numbers:
                editor.SendScintilla(editor.SCI_STYLESETFORE, style, QColor(color))
        editor.SendScintilla(editor.SCI_SETLEXER, editor.SCLEX_LUA)
        for number in range(1, 9):
            words = (lexer.keywords(number) or "").encode("utf-8")
            editor.SendScintilla(editor.SCI_SETKEYWORDS, number - 1, words)
        editor.SendScintilla(editor.SCI_SETPROPERTY, b"fold", b"0")
        editor.SendScintilla(editor.SCI_SETIDLESTYLING, editor.SC_IDLESTYLING_ALL)

    def open_fetch_as_script(self):
        if self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) <= 0:
            return
        try:
            source = self.fetch_output.text()
        except MemoryError:
            self.show_fetch_status("Not enough memory to copy this response into a script tab.")
            return
        if not source:
            return
        name = "reversed.luau"
        if self.fetch_url:
            try:
                candidate = Path(urllib.parse.urlsplit(self.fetch_url).path).name.strip()
            except Exception:
                candidate = ""
            if candidate:
                candidate = re.sub(r'[^A-Za-z0-9._ -]+', '_', candidate).strip(' ._') or "reversed"
                name = candidate if candidate.casefold().endswith((".lua", ".luau")) else f"{candidate}.luau"
        try:
            self.owner.add_editor_tab(name, source, select=True)
            self.owner.update_editor_action_state()
            self.owner.raise_()
            self.owner.activateWindow()
            self.show_fetch_status("")
        except Exception as exc:
            self.show_fetch_status(f"Could not open script: {exc}")

    def _build_creator_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.creator_input = QLineEdit()
        self.creator_input.setPlaceholderText("pastebin.com/raw/... or raw.githubusercontent.com/...")
        self.creator_input.textChanged.connect(self.update_loadstring_creator)
        layout.addWidget(self.creator_input)

        self.creator_output = HoverCopyLineEdit()
        self.creator_output.setPlaceholderText('loadstring(game:HttpGet("..."))()')
        self.creator_output.setReadOnly(True)
        layout.addWidget(self.creator_output)

        self.creator_status = QLabel("")
        self.creator_status.setTextFormat(Qt.TextFormat.PlainText)
        self.creator_status.hide()
        layout.addWidget(self.creator_status)
        layout.addStretch(1)
        self.tool_stack.addWidget(page)

    def _build_github_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.github_input = QLineEdit()
        self.github_input.setPlaceholderText(
            "github.com/owner/repo/blob/branch/path/to/file.lua"
        )
        self.github_input.textChanged.connect(self.update_raw_url)
        layout.addWidget(self.github_input)

        self.github_output = HoverCopyLineEdit()
        self.github_output.setPlaceholderText("Raw URL")
        self.github_output.setReadOnly(True)
        layout.addWidget(self.github_output)

        self.github_status = QLabel("")
        self.github_status.setTextFormat(Qt.TextFormat.PlainText)
        self.github_status.hide()
        layout.addWidget(self.github_status)
        layout.addStretch(1)
        self.tool_stack.addWidget(page)

    def _build_deobfuscate_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.deob_input = QPlainTextEdit()
        self.deob_input.setPlaceholderText("Paste obfuscated Lua/Luau here.")
        self.deob_input.setFont(QFont("Consolas", 10))
        self.deob_input.setFixedHeight(130)
        layout.addWidget(self.deob_input)

        input_actions = QHBoxLayout()
        input_actions.setContentsMargins(0, 0, 0, 0)
        input_actions.setSpacing(7)
        self.deob_button = QPushButton("Deobfuscate")
        self.deob_button.clicked.connect(self.start_deobfuscate)
        input_actions.addWidget(self.deob_button, 1)
        self.deob_new_tab_button = QPushButton("Open as New Script")
        self.deob_new_tab_button.setEnabled(False)
        new_icon = app_icon("new")
        if not new_icon.isNull():
            self.deob_new_tab_button.setIcon(new_icon)
            self.deob_new_tab_button.setIconSize(QSize(16, 16))
        self.deob_new_tab_button.clicked.connect(self.open_deobfuscated_as_script)
        input_actions.addWidget(self.deob_new_tab_button)
        layout.addLayout(input_actions)

        self.deob_status = QLabel("")
        self.deob_status.setTextFormat(Qt.TextFormat.PlainText)
        self.deob_status.setWordWrap(True)
        self.deob_status.hide()
        layout.addWidget(self.deob_status)

        frame = QFrame()
        frame.setObjectName("toolOutputFrame")
        frame_layout = QVBoxLayout(frame)
        frame_layout.setContentsMargins(1, 1, 1, 1)
        frame_layout.setSpacing(0)

        self.deob_output = QsciScintilla(frame)
        self.deob_output.setObjectName("toolOutput")
        self.deob_output.setUtf8(True)
        self.deob_output.setFont(QFont("Consolas", 10))
        self.deob_output.setColor(QColor("#eeeeee"))
        self.deob_output.setPaper(QColor("#070708"))
        self.deob_output.setMargins(0)
        self.deob_output.setWrapMode(QsciScintilla.WrapMode.WrapNone)
        self.deob_output.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.deob_output.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.deob_output.setReadOnly(True)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETUNDOCOLLECTION, 0)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETLAYOUTCACHE, self.deob_output.SC_CACHE_PAGE)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETSCROLLWIDTH, 1)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETSCROLLWIDTHTRACKING, 1)
        self._configure_fetch_syntax(self.deob_output, "deob_lexer")
        frame_layout.addWidget(self.deob_output)
        layout.addWidget(frame, 1)

        self.deob_events = queue.Queue(maxsize=8)
        self.deob_request_id = 0
        self.deob_running = False
        self.deob_result_text = ""
        self.tool_stack.addWidget(page)

    def show_deob_status(self, text):
        self.deob_status.setText(str(text or ""))
        self.deob_status.setVisible(bool(text))

    @staticmethod
    def _supported_deobfuscation_source(source):
        try:
            module = __import__("lelsploit_deobfuscate")
            checker = getattr(module, "is_supported_obfuscated_format", None)
            if checker is None:
                checker = getattr(module, "is_supported_obfuscation", None)
            if checker is None:
                return False
            return bool(checker(source))
        except Exception:
            return False

    def prefill_deobfuscate(self, source):
        source = str(source or "")
        if source and self._supported_deobfuscation_source(source):
            self.deob_input.setPlainText(source)
            self.show_deob_status("")
            return True
        return False

    def load_current_script_for_deobfuscate(self):
        editor = getattr(self.owner, "editor", None)
        if editor is None:
            self.show_deob_status("No script tab is open.")
            return False
        try:
            source = editor.text()
        except MemoryError:
            self.show_deob_status("Not enough memory to copy the current script.")
            return False
        if not source.strip():
            return False
        if self.prefill_deobfuscate(source):
            return True
        self.show_deob_status("")
        return False

    @staticmethod
    def _run_deobfuscator(events, request_id, source):
        try:
            module = __import__("lelsploit_deobfuscate")
            if hasattr(module, "deobfuscate"):
                result, report = module.deobfuscate(source, return_report=True)
            else:
                engine = module.Deobfuscator()
                result, report = engine.deobfuscate(source, return_report=True)
            if isinstance(result, (bytes, bytearray)):
                result = bytes(result).decode("latin-1")
            result = str(result)
            family = str(getattr(report, "best_family", "Unknown") or "Unknown")
            passes = list(getattr(report, "passes", ()) or ())
            warnings = list(getattr(report, "warnings", ()) or ())
            status = f"LelSploit recognized {family}. Applied {len(passes)} pass{'es' if len(passes) != 1 else ''}."
            if passes:
                status += " " + "; ".join(str(item) for item in passes[:5])
                if len(passes) > 5:
                    status += f"; +{len(passes) - 5} more"
            if warnings:
                status += " Warning: " + str(warnings[0])
            events.put(("done", request_id, result, status))
        except Exception as exc:
            events.put(("error", request_id, "", f"Deobfuscation failed: {exc}"))

    def start_deobfuscate(self):
        if self.deob_running:
            return
        source = self.deob_input.toPlainText()
        if not source.strip():
            self.show_deob_status("Paste an obfuscated script first.")
            return
        if not self._supported_deobfuscation_source(source):
            self.show_deob_status("This is not a supported obfuscated format.")
            return
        self.deob_request_id += 1
        request_id = self.deob_request_id
        self.deob_running = True
        self.deob_result_text = ""
        self.deob_button.setEnabled(False)
        self.deob_new_tab_button.setEnabled(False)
        self.show_deob_status("Deobfuscating...")
        self.deob_output.setReadOnly(False)
        try:
            self.deob_output.clear()
        finally:
            self.deob_output.setReadOnly(True)
        threading.Thread(
            target=self._run_deobfuscator,
            args=(self.deob_events, request_id, source),
            daemon=True,
        ).start()

    def poll_deobfuscate(self):
        terminal = None
        for _ in range(4):
            try:
                item = self.deob_events.get_nowait()
            except queue.Empty:
                break
            kind, request_id, result, status = item
            if request_id == self.deob_request_id:
                terminal = (kind, result, status)
        if terminal is None:
            return
        kind, result, status = terminal
        self.deob_running = False
        self.deob_button.setEnabled(True)
        if kind == "done":
            self.deob_result_text = result
            data = result.encode("utf-8", errors="replace")
            self.deob_output.setReadOnly(False)
            try:
                self.deob_output.setText(result)
                self.deob_output.SendScintilla(self.deob_output.SCI_EMPTYUNDOBUFFER)
                self.deob_output.SendScintilla(self.deob_output.SCI_COLOURISE, 0, -1)
            finally:
                self.deob_output.setReadOnly(True)
            has_result = bool(data)
            self.deob_new_tab_button.setEnabled(has_result)
        else:
            self.deob_result_text = ""
            self.deob_new_tab_button.setEnabled(False)
        self.show_deob_status(status)

    def open_deobfuscated_as_script(self):
        if not self.deob_result_text:
            return
        current_name = "script.luau"
        try:
            current_name = self.owner.current_tab_name() or current_name
        except Exception:
            pass
        path = Path(current_name)
        suffix = path.suffix if path.suffix.casefold() in {".lua", ".luau"} else ".luau"
        name = f"{path.stem or 'script'}.deobfuscated{suffix}"
        try:
            self.owner.add_editor_tab(name, self.deob_result_text, select=True)
            self.owner.update_editor_action_state()
            self.owner.raise_()
            self.owner.activateWindow()
            self.show_deob_status("")
        except Exception as exc:
            self.show_deob_status(f"Could not open the deobfuscated script: {exc}")

    def select_tool(self, index):
        if index < 0 or index >= self.tool_stack.count():
            return
        self.tool_stack.setCurrentIndex(index)
        for button_index, button in enumerate(self.tool_buttons):
            button.setChecked(button_index == index)
        if index == 3:
            self.load_current_script_for_deobfuscate()

    def prefill_loadstring(self, source):
        if extract_loadstring_url(source):
            self.loadstring_input.setPlainText(source)
            self.select_tool(0)

    def clear_fetch_output(self):
        self.fetch_output.setReadOnly(False)
        try:
            self.fetch_output.clear()
            self.fetch_output.SendScintilla(self.fetch_output.SCI_EMPTYUNDOBUFFER)
        finally:
            self.fetch_output.setReadOnly(True)

    def show_fetch_status(self, text):
        self.fetch_status.setText(text)
        self.fetch_status.setVisible(bool(text))

    def show_github_status(self, text):
        self.github_status.setText(text)
        self.github_status.setVisible(bool(text))

    def fetch_loadstring(self):
        source = self.loadstring_input.toPlainText().strip()
        url = extract_loadstring_url(source)
        if url is None and source.startswith(("http://", "https://")):
            url = source
        if not url:
            self.show_fetch_status("No HttpGet URL found.")
            return
        if self.fetch_cancel is not None:
            self.fetch_cancel.set()
        self.request_id += 1
        request_id = self.request_id
        self.fetch_cancel = threading.Event()
        self.fetch_url = url
        self.clear_fetch_output()
        self.fetch_to_script_button.setEnabled(False)
        self.fetch_button.setEnabled(False)
        self.show_fetch_status("Fetching...")
        threading.Thread(
            target=stream_remote_text,
            args=(self.events, request_id, url, self.fetch_cancel),
            daemon=True,
        ).start()

    def append_fetch_bytes(self, data):
        if not data:
            return
        self.fetch_output.setReadOnly(False)
        try:
            self.fetch_output.SendScintilla(
                self.fetch_output.SCI_APPENDTEXT, len(data), data
            )
        finally:
            self.fetch_output.setReadOnly(True)

    def poll_fetch(self):
        chunks = []
        terminal = None
        for _ in range(32):
            try:
                kind, request_id, payload = self.events.get_nowait()
            except queue.Empty:
                break
            if request_id != self.request_id:
                continue
            if kind == "chunk":
                chunks.append(payload)
            else:
                terminal = (kind, payload)
                break
        if chunks:
            self.append_fetch_bytes(b"".join(chunks))
        if terminal is None:
            return
        kind, payload = terminal
        self.fetch_button.setEnabled(True)
        if kind == "done":
            self.fetch_output.SendScintilla(self.fetch_output.SCI_COLOURISE, 0, -1)
            self.fetch_to_script_button.setEnabled(
                self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) > 0
            )
            self.show_fetch_status("")
        else:
            self.fetch_to_script_button.setEnabled(False)
            self.show_fetch_status(f"Fetch failed: {payload}")

    def show_creator_status(self, text):
        self.creator_status.setText(text)
        self.creator_status.setVisible(bool(text))

    def update_loadstring_creator(self, *_):
        value = self.creator_input.text().strip()
        if not value:
            self.creator_output.clear()
            self.show_creator_status("")
            return
        try:
            result = make_loadstring_url(value)
        except ValueError as exc:
            self.creator_output.clear()
            self.show_creator_status(str(exc))
            return
        self.creator_output.setText(result)
        self.show_creator_status("")

    def update_raw_url(self, *_):
        value = self.github_input.text().strip()
        if not value:
            self.github_output.clear()
            self.show_github_status("")
            return
        try:
            raw = github_raw_url(value)
        except ValueError as exc:
            self.github_output.clear()
            self.show_github_status(str(exc))
            return
        self.github_output.setText(raw)
        self.show_github_status("")

    def closeEvent(self, event):
        if self.fetch_cancel is not None:
            self.fetch_cancel.set()
        self.fetch_button.setEnabled(True)
        self.fetch_to_script_button.setEnabled(
            self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) > 0
        )
        if hasattr(self, "deob_button"):
            self.deob_button.setEnabled(not self.deob_running)
        self.show_fetch_status("")
        event.accept()


EXTENSION_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,79}$")
EXTENSION_PERMISSION_NAMES = frozenset({
    "editor", "clipboard", "storage", "ui", "execute", "fastflags", "files", "network", "picker",
    "settings", "theme", "roblox", "proxy", "app_files", "extensions", "sound"
})
EXTENSION_STEP_PERMISSIONS = {
    "editor.set": "editor",
    "editor.append": "editor",
    "editor.prepend": "editor",
    "editor.insert": "editor",
    "editor.clear": "editor",
    "editor.replace": "editor",
    "editor.select_all": "editor",
    "editor.goto_line": "editor",
    "editor.cursor": "editor",
    "editor.line": "editor",
    "selection.replace": "editor",
    "selection.copy": "editor",
    "selection.delete": "editor",
    "editor.new_tab": "editor",
    "tabs.rename": "editor",
    "tabs.select": "editor",
    "tabs.close_current": "editor",
    "tabs.list": "editor",
    "tabs.read": "editor",
    "tabs.set": "editor",
    "clipboard.set": "clipboard",
    "clipboard.append": "clipboard",
    "console.log": "ui",
    "notify": "ui",
    "message": "ui",
    "dialog.input": "ui",
    "dialog.confirm": "ui",
    "ui.open": "ui",
    "ui.window": "ui",
    "ui.smooth_scroll": "ui",
    "visual_wizard.enable": "ui",
    "storage.set": "storage",
    "storage.delete": "storage",
    "storage.clear": "storage",
    "file.read": "files",
    "file.write": "files",
    "file.append": "files",
    "file.delete": "files",
    "file.list": "files",
    "file.pick_read": "picker",
    "file.pick_write": "picker",
    "http.request": "network",
    "var.set": None,
    "var.append": None,
    "var.delete": None,
    "var.number": None,
    "system.now": None,
    "text.transform": None,
    "script.execute": "execute",
    "fastflag.set": "fastflags",
    "fastflag.remove": "fastflags",
    
    
    "package.read": None,
    "package.list": None,
    "settings.get": "settings",
    "settings.set": "settings",
    "theme.get": "theme",
    "theme.set": "theme",
    "theme.preset": "theme",
    "theme.reset": "theme",
    "app.state": None,
    "ui.panel.open": "ui",
    "ui.panel.close": "ui",
    "ui.panel.update": "ui",
    "ui.toolbar.add": "ui",
    "ui.toolbar.remove": "ui",
    "ui.widget.get": "ui",
    "ui.widget.set": "ui",
    "ui.widget.invoke": "ui",
    "flow.if": None,
    "flow.repeat": None,
    "flow.foreach": None,
    "json.get": None,
    "json.set": None,
    
    
    "math.eval": None,
    "math.stats": None,
    "math.vector": None,
    "math.random": None,
    "system.info": None,
    "action.run": None,
    "timer.after": None,
    "timer.every": None,
    "timer.cancel": None,
    "ui.widget.list": "ui",
    "ui.view.open": "ui",
    "ui.icon.list": "ui",
    "app.file.list": "app_files",
    "app.file.read": "app_files",
    "app.file.stat": "app_files",
    "extension.list": "extensions",
    "extension.info": "extensions",
    "extension.set_enabled": "extensions",
    "extension.reload": "extensions",
    "extension.remove": "extensions",
    "roblox.state": "roblox",
    "roblox.join_context": "roblox",
    "roblox.players": "roblox",
    "roblox.server": "roblox",
    "roblox.client": "roblox",
    "roblox.request": "roblox",
    "roblox.attach": "roblox",
    "roblox.reattach": "roblox",
    "roblox.detach": "roblox",
    "roblox.execute": "execute",
    "proxy.state": "proxy",
    "proxy.enable": "proxy",
    "proxy.disable": "proxy",
    "proxy.restart": "proxy",
    "sound.beep": "sound",
    "sound.play": "sound",
    "sound.stop": "sound",
}


def load_extension_state():
    raw = read_json_object(EXTENSION_STATE_PATH, {})
    disabled = raw.get("disabled", []) if isinstance(raw, dict) else []
    data = raw.get("data", {}) if isinstance(raw, dict) else {}
    disabled = sorted({str(item).strip() for item in disabled if str(item).strip()})
    clean_data = {}
    if isinstance(data, dict):
        for ext_id, values in data.items():
            if not isinstance(ext_id, str) or not isinstance(values, dict):
                continue
            clean_values = {}
            for key, value in values.items():
                key = str(key or "").strip()
                if not key or len(key) > 96:
                    continue
                text = str(value if value is not None else "")
                clean_values[key] = text[:65536]
            clean_data[ext_id] = clean_values
    return {"disabled": disabled, "data": clean_data}


def save_extension_state(state):
    state = state if isinstance(state, dict) else {}
    disabled = sorted({str(item).strip() for item in state.get("disabled", []) if str(item).strip()})
    data = state.get("data", {}) if isinstance(state.get("data", {}), dict) else {}
    write_json_object(EXTENSION_STATE_PATH, {"disabled": disabled, "data": data})


def _extension_manifest_text(value, fallback="", limit=200):
    text = str(value if value is not None else fallback).strip()
    return text[:limit]


def normalize_extension_manifest(raw):
    if not isinstance(raw, dict):
        raise ValueError("manifest.json must contain a JSON object.")
    try:
        fmt = int(raw.get("format", 0))
    except (TypeError, ValueError):
        fmt = 0
    if fmt != EXTENSION_FORMAT_VERSION:
        raise ValueError(f"Unsupported LEXT format {fmt}; this build supports format {EXTENSION_FORMAT_VERSION}.")
    ext_id = _extension_manifest_text(raw.get("id"), limit=80).casefold()
    if not EXTENSION_ID_RE.fullmatch(ext_id):
        raise ValueError("Extension id must use lowercase letters, numbers, dots, dashes, or underscores.")
    name = _extension_manifest_text(raw.get("name"), "", 80) or "No title found"
    version = _extension_manifest_text(raw.get("version"), "1.0", 32) or "1.0"
    description = _extension_manifest_text(raw.get("description"), "", 4096) or "No description found"
    icon = _extension_manifest_text(raw.get("icon"), "", 160).replace("\\", "/")
    if icon.startswith("/") or ".." in Path(icon).parts:
        icon = ""

    permissions = []
    for item in raw.get("permissions", []) if isinstance(raw.get("permissions", []), list) else []:
        value = str(item or "").strip().casefold()
        if value in EXTENSION_PERMISSION_NAMES and value not in permissions:
            permissions.append(value)

    def clean_steps(source, label, maximum=96, depth=0):
        if source is None:
            return []
        if depth > 8:
            raise ValueError(f"{label} nests too deeply.")
        if not isinstance(source, list):
            raise ValueError(f"{label} must be a JSON array.")
        if len(source) > maximum:
            raise ValueError(f"{label} has too many steps.")
        result = []
        for step in source:
            if not isinstance(step, dict):
                raise ValueError(f"{label} contains an invalid step.")
            op = str(step.get("op", "")).strip()
            if op not in EXTENSION_STEP_PERMISSIONS:
                raise ValueError(f"{label} uses unsupported operation {op!r}.")
            required = EXTENSION_STEP_PERMISSIONS.get(op)
            if required and required not in permissions:
                raise ValueError(f"{label} uses {op!r} but the manifest does not request the {required!r} permission.")
            item = dict(step)
            if op == "flow.if":
                item["then"] = clean_steps(step.get("then", []), f"{label} flow.if then", 64, depth + 1)
                item["else"] = clean_steps(step.get("else", []), f"{label} flow.if else", 64, depth + 1)
            elif op in {"flow.repeat", "flow.foreach"}:
                item["steps"] = clean_steps(step.get("steps", []), f"{label} {op}", 64, depth + 1)
            result.append(item)
        return result

    startup_steps = clean_steps(raw.get("startup", []), "startup")
    interval_ms = 0
    interval_steps = []
    interval_spec = raw.get("interval")
    if isinstance(interval_spec, dict):
        try:
            interval_ms = int(interval_spec.get("ms", 0) or 0)
        except (TypeError, ValueError):
            interval_ms = 0
        if interval_ms:
            interval_ms = max(250, min(3600000, interval_ms))
            interval_steps = clean_steps(interval_spec.get("steps", []), "interval")
            if not interval_steps:
                interval_ms = 0

    actions = []
    source_actions = raw.get("actions", [])
    if not isinstance(source_actions, list):
        raise ValueError("actions must be a JSON array.")
    if len(source_actions) > 64:
        raise ValueError("An extension can define at most 64 actions.")
    seen_action_ids = set()
    for index, action in enumerate(source_actions):
        if not isinstance(action, dict):
            raise ValueError(f"Action {index + 1} must be an object.")
        action_id = _extension_manifest_text(action.get("id"), f"action{index + 1}", 64)
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", action_id):
            raise ValueError(f"Action id {action_id!r} is invalid.")
        if action_id in seen_action_ids:
            raise ValueError(f"Duplicate action id: {action_id}")
        seen_action_ids.add(action_id)
        title = _extension_manifest_text(action.get("title"), action_id, 80)
        inputs = action.get("inputs", []) if isinstance(action.get("inputs", []), list) else []
        if len(inputs) > 24:
            raise ValueError(f"Action {title!r} has too many inputs.")
        clean_inputs = []
        for spec in inputs:
            if not isinstance(spec, dict):
                continue
            input_id = _extension_manifest_text(spec.get("id"), limit=48)
            if not re.fullmatch(r"[A-Za-z0-9_.-]{1,48}", input_id):
                continue
            clean_inputs.append({
                "id": input_id,
                "title": _extension_manifest_text(spec.get("title"), title, 80),
                "prompt": _extension_manifest_text(spec.get("prompt"), input_id, 180),
                "default": str(spec.get("default", ""))[:2048],
            })
        steps = clean_steps(action.get("steps", []), f"Action {title!r}", 128)
        if not steps:
            raise ValueError(f"Action {title!r} needs at least one step.")
        actions.append({"id": action_id, "title": title, "inputs": clean_inputs, "steps": steps})

    shortcuts = []
    source_shortcuts = raw.get("shortcuts", []) or []
    if not isinstance(source_shortcuts, list):
        raise ValueError("shortcuts must be a JSON array.")
    if len(source_shortcuts) > 32:
        raise ValueError("An extension can define at most 32 shortcuts.")
    for item in source_shortcuts:
        if not isinstance(item, dict):
            continue
        sequence = _extension_manifest_text(item.get("keys"), "", 80)
        action_ref = _extension_manifest_text(item.get("action"), "", 64)
        if sequence and action_ref in seen_action_ids:
            shortcuts.append({"keys": sequence, "action": action_ref})

    
    
    allowed_events = {
        "editor.changed", "selection.changed", "tab.changed", "clipboard.changed",
        "app.activated", "app.deactivated", "roblox.changed"
    }
    events = []
    source_events = raw.get("events", []) or []
    if not isinstance(source_events, list):
        raise ValueError("events must be a JSON array.")
    if len(source_events) > 32:
        raise ValueError("An extension can define at most 32 event hooks.")
    for index, item in enumerate(source_events):
        if not isinstance(item, dict):
            continue
        event_name = _extension_manifest_text(item.get("event"), "", 64).casefold()
        if event_name not in allowed_events:
            raise ValueError(f"Event {event_name!r} is not supported.")
        action_ref = _extension_manifest_text(item.get("action"), "", 64)
        steps = clean_steps(item.get("steps", []), f"Event {event_name!r}", 96) if item.get("steps") is not None else []
        if action_ref and action_ref not in seen_action_ids:
            raise ValueError(f"Event {event_name!r} references unknown action {action_ref!r}.")
        if not action_ref and not steps:
            continue
        events.append({"event": event_name, "action": action_ref, "steps": steps})

    
    
    panels = []
    source_panels = raw.get("panels", []) or []
    if not isinstance(source_panels, list):
        raise ValueError("panels must be a JSON array.")
    if len(source_panels) > 16:
        raise ValueError("An extension can define at most 16 panels.")
    seen_panel_ids = set()
    control_types = {"label", "heading", "markdown", "input", "textarea", "checkbox", "switch", "combo", "list", "slider", "color", "button", "icon_button", "icon", "separator", "spacer"}
    for index, panel in enumerate(source_panels):
        if not isinstance(panel, dict):
            continue
        panel_id = _extension_manifest_text(panel.get("id"), f"panel{index+1}", 64)
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", panel_id) or panel_id in seen_panel_ids:
            raise ValueError(f"Panel id {panel_id!r} is invalid or duplicated.")
        seen_panel_ids.add(panel_id)
        controls = panel.get("controls", []) or []
        if not isinstance(controls, list) or len(controls) > 80:
            raise ValueError(f"Panel {panel_id!r} has an invalid controls list.")
        clean_controls = []
        seen_control_ids = set()
        for cindex, control in enumerate(controls):
            if not isinstance(control, dict):
                continue
            ctype = str(control.get("type", "label") or "label").strip().casefold()
            if ctype not in control_types:
                raise ValueError(f"Panel {panel_id!r} uses unsupported control type {ctype!r}.")
            item = dict(control); item["type"] = ctype
            cid = _extension_manifest_text(control.get("id"), "", 64)
            if cid:
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", cid) or cid in seen_control_ids:
                    raise ValueError(f"Panel control id {cid!r} is invalid or duplicated.")
                seen_control_ids.add(cid); item["id"] = cid
            if ctype in {"button", "icon_button"}:
                action_ref = _extension_manifest_text(control.get("action"), "", 64)
                if action_ref and action_ref not in seen_action_ids:
                    raise ValueError(f"Panel button references unknown action {action_ref!r}.")
                item["action"] = action_ref
            clean_controls.append(item)
        try: width = max(320, min(1400, int(panel.get("width", 620) or 620)))
        except (TypeError, ValueError): width = 620
        try: height = max(240, min(1000, int(panel.get("height", 520) or 520)))
        except (TypeError, ValueError): height = 520
        panels.append({
            "id": panel_id,
            "title": _extension_manifest_text(panel.get("title"), name, 100) or name,
            "width": width, "height": height, "controls": clean_controls,
        })

    watchers = []
    source_watchers = raw.get("watchers", []) or []
    if not isinstance(source_watchers, list):
        raise ValueError("watchers must be a JSON array.")
    if len(source_watchers) > 32:
        raise ValueError("An extension can define at most 32 widget watchers.")
    if source_watchers and "ui" not in permissions:
        raise ValueError("Widget watchers require the 'ui' permission.")
    allowed_signals = {"clicked", "toggled", "text_changed", "value_changed", "current_changed", "selection_changed"}
    for index, item in enumerate(source_watchers):
        if not isinstance(item, dict):
            continue
        watcher_id = _extension_manifest_text(item.get("id"), f"watch{index+1}", 64)
        target = _extension_manifest_text(item.get("target"), "", 120)
        signal_name = _extension_manifest_text(item.get("signal"), "clicked", 40).casefold()
        action_ref = _extension_manifest_text(item.get("action"), "", 64)
        if not target or signal_name not in allowed_signals or action_ref not in seen_action_ids:
            raise ValueError(f"Widget watcher {watcher_id!r} is invalid.")
        watchers.append({"id": watcher_id, "target": target, "signal": signal_name, "action": action_ref})

    toolbar = []
    source_toolbar = raw.get("toolbar", []) or []
    if not isinstance(source_toolbar, list):
        raise ValueError("toolbar must be a JSON array.")
    if len(source_toolbar) > 12:
        raise ValueError("An extension can define at most 12 toolbar buttons.")
    seen_toolbar_ids = set()
    for index, item in enumerate(source_toolbar):
        if not isinstance(item, dict):
            continue
        item_id = _extension_manifest_text(item.get("id"), f"button{index+1}", 64)
        action_ref = _extension_manifest_text(item.get("action"), "", 64)
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", item_id) or item_id in seen_toolbar_ids:
            raise ValueError(f"Toolbar id {item_id!r} is invalid or duplicated.")
        if action_ref not in seen_action_ids:
            raise ValueError(f"Toolbar button {item_id!r} needs a valid action.")
        seen_toolbar_ids.add(item_id)
        toolbar.append({
            "id": item_id,
            "action": action_ref,
            "text": _extension_manifest_text(item.get("text"), "", 40),
            "tooltip": _extension_manifest_text(item.get("tooltip"), name, 120),
            "icon": _extension_manifest_text(item.get("icon"), "", 160).replace("\\", "/"),
        })

    return {
        "format": EXTENSION_FORMAT_VERSION,
        "id": ext_id,
        "name": name,
        "version": version,
        "description": description,
        "icon": icon,
        "permissions": permissions,
        "startup": startup_steps,
        "interval_ms": interval_ms,
        "interval_steps": interval_steps,
        "actions": actions,
        "shortcuts": shortcuts,
        "events": events,
        "panels": panels,
        "toolbar": toolbar,
        "watchers": watchers,
    }


def read_extension_package(path):
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(path)
    if path.stat().st_size > EXTENSION_PACKAGE_LIMIT:
        raise ValueError("Extension package is larger than 32 MiB.")
    if path.suffix.casefold() != ".lext":
        raise ValueError("Extension packages must use the .lext extension.")
    if not zipfile.is_zipfile(path):
        raise ValueError("A .lext package must be a ZIP package containing manifest.json.")
    with zipfile.ZipFile(path, "r") as archive:
        try:
            manifest_info = archive.getinfo("manifest.json")
        except KeyError as exc:
            raise ValueError("The package does not contain manifest.json.") from exc
        if manifest_info.file_size > EXTENSION_MANIFEST_LIMIT:
            raise ValueError("manifest.json is too large.")
        try:
            raw = json.loads(archive.read(manifest_info).decode("utf-8-sig"))
        except (UnicodeError, ValueError, OSError) as exc:
            raise ValueError(f"Could not read manifest.json: {exc}") from exc
        manifest = normalize_extension_manifest(raw)
        icon_bytes = b""
        icon_name = manifest.get("icon", "")
        if icon_name:
            try:
                icon_info = archive.getinfo(icon_name)
                if icon_info.file_size <= EXTENSION_ICON_LIMIT:
                    icon_bytes = archive.read(icon_info)
            except (KeyError, OSError):
                icon_bytes = b""
    return {"path": path, "manifest": manifest, "icon_bytes": icon_bytes, "error": ""}


_EXTENSION_SCAN_CACHE_SIGNATURE = None
_EXTENSION_SCAN_CACHE = []


def extension_folder_signature():
    EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
    signature = []
    for path in sorted(EXTENSIONS_DIR.glob("*.lext"), key=lambda item: item.name.casefold()):
        try:
            stat = path.stat()
            signature.append((path.name.casefold(), int(stat.st_mtime_ns), int(stat.st_size)))
        except OSError:
            continue
    return tuple(signature)


def scan_extension_packages(force=False):
    global _EXTENSION_SCAN_CACHE_SIGNATURE, _EXTENSION_SCAN_CACHE
    signature = extension_folder_signature()
    if not force and signature == _EXTENSION_SCAN_CACHE_SIGNATURE:
        return list(_EXTENSION_SCAN_CACHE)
    records = []
    seen_ids = set()
    for path in sorted(EXTENSIONS_DIR.glob("*.lext"), key=lambda item: item.name.casefold()):
        try:
            record = read_extension_package(path)
            ext_id = record["manifest"]["id"]
            if ext_id in seen_ids:
                raise ValueError(f"Another installed package already uses extension id {ext_id!r}.")
            seen_ids.add(ext_id)
            records.append(record)
        except Exception as exc:
            records.append({"path": path, "manifest": None, "icon_bytes": b"", "error": str(exc)})
    _EXTENSION_SCAN_CACHE_SIGNATURE = signature
    _EXTENSION_SCAN_CACHE = list(records)
    return list(records)


class LelExtensionRuntime:
    _template_re = re.compile(r"\$\{([A-Za-z0-9_.-]+)\}")

    def __init__(self, owner):
        self.owner = owner
        self._panels = {}
        self._toolbar_buttons = {}
        self._widget_watchers = {}
        self._runtime_timers = {}

    def _find_action(self, manifest, action_id):
        action_id = str(action_id or "").strip()
        for action in manifest.get("actions", []):
            if action.get("id") == action_id:
                return action
        return None

    def _find_panel(self, manifest, panel_id):
        panel_id = str(panel_id or "").strip()
        for panel in manifest.get("panels", []):
            if panel.get("id") == panel_id:
                return panel
        return None

    def _package_bytes(self, package, name, limit=EXTENSION_TEXT_LIMIT):
        name = str(name or "").strip().replace("\\", "/")
        if not name or name.startswith("/") or ".." in Path(name).parts:
            raise ValueError("Package resource path is invalid.")
        path = Path(package.get("path", ""))
        if not path.is_file() or not zipfile.is_zipfile(path):
            raise ValueError("Extension package is unavailable.")
        with zipfile.ZipFile(path, "r") as archive:
            try:
                info = archive.getinfo(name)
            except KeyError as exc:
                raise FileNotFoundError(name) from exc
            if info.file_size > limit:
                raise ValueError("Package resource exceeds the extension size limit.")
            return archive.read(info)

    def _package_icon(self, package, name, size=18):
        try:
            data = self._package_bytes(package, name, EXTENSION_ICON_LIMIT)
            pixmap = QPixmap()
            if pixmap.loadFromData(data):
                return QIcon(pixmap.scaled(size, size, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
        except Exception:
            pass
        return QIcon()

    def _host_icon(self, name, size=18):
        """Resolve a read-only icon from LelSploit's icons directory.

        Extensions can use host:save, icons/save.png, or just save. Plain names
        fall back to host icons only when a package resource with that name is
        not present. app_icon() is used so Visual Wizard icon tinting still
        applies consistently.
        """
        value = str(name or "").strip().replace("\\", "/")
        for prefix in ("host:", "icon:", "icons:"):
            if value.casefold().startswith(prefix):
                value = value[len(prefix):]
                break
        if value.casefold().startswith("icons/"):
            value = value[6:]
        value = value.lstrip("/")
        if not value or ".." in Path(value).parts:
            return QIcon()
        rel = Path(value)
        if rel.suffix.casefold() == ".png":
            rel = rel.with_suffix("")
        elif rel.suffix:
            return QIcon()
        icon = app_icon(rel.as_posix())
        if icon.isNull():
            return QIcon()
        return icon

    def _resolve_icon(self, package, name, size=18):
        value = str(name or "").strip().replace("\\", "/")
        if not value:
            return QIcon()
        lowered = value.casefold()
        if lowered.startswith(("host:", "icon:", "icons:", "icons/")):
            return self._host_icon(value, size)
        if lowered.startswith("package:"):
            return self._package_icon(package, value.split(":", 1)[1], size)
        package_icon = self._package_icon(package, value, size)
        return package_icon if not package_icon.isNull() else self._host_icon(value, size)

    @staticmethod
    def _host_icon_names():
        if not ICON_DIR.is_dir():
            return []
        names = []
        for path in ICON_DIR.rglob("*.png"):
            try:
                rel = path.relative_to(ICON_DIR).with_suffix("").as_posix()
            except (ValueError, OSError):
                continue
            names.append(rel)
            if len(names) >= 4000:
                break
        return sorted(set(names), key=str.casefold)

    def retain_extensions(self, enabled_ids):
        enabled_ids = set(enabled_ids or ())
        for key, button in list(self._toolbar_buttons.items()):
            if key[0] not in enabled_ids:
                try: button.deleteLater()
                except Exception: pass
                self._toolbar_buttons.pop(key, None)
        for key, panel in list(self._panels.items()):
            if key[0] not in enabled_ids:
                try: panel.close(); panel.deleteLater()
                except Exception: pass
                self._panels.pop(key, None)
        for key, pair in list(self._widget_watchers.items()):
            if key[0] not in enabled_ids:
                signal, callback = pair
                try: signal.disconnect(callback)
                except Exception: pass
                self._widget_watchers.pop(key, None)
        for key, timer in list(self._runtime_timers.items()):
            if key[0] not in enabled_ids:
                try: timer.stop(); timer.deleteLater()
                except Exception: pass
                self._runtime_timers.pop(key, None)

    def activate_extension(self, package):
        manifest = package.get("manifest") or {}
        ext_id = manifest.get("id", "")
        for spec in manifest.get("toolbar", []):
            key = (ext_id, spec.get("id", ""))
            if key in self._toolbar_buttons:
                continue
            layout = getattr(self.owner, "header_layout", None)
            if layout is None:
                continue
            button = QPushButton(str(spec.get("text", "") or ""))
            button.setObjectName("iconButton" if not spec.get("text") else "extensionToolbarButton")
            button.setToolTip(str(spec.get("tooltip", manifest.get("name", "Extension"))))
            button.setCursor(Qt.CursorShape.PointingHandCursor)
            icon_name = str(spec.get("icon", "") or "")
            icon = self._resolve_icon(package, icon_name, 19) if icon_name else QIcon()
            if not icon.isNull():
                button.setIcon(icon); button.setIconSize(QSize(19, 19))
            if spec.get("text"):
                button.setFixedHeight(34); button.setMinimumWidth(34)
            else:
                button.setFixedSize(34, 34)
            action_id = str(spec.get("action", "") or "")
            button.clicked.connect(lambda checked=False, p=package, aid=action_id: self.run(p, self._find_action(p["manifest"], aid) or {"inputs": [], "steps": []}))
            
            before = getattr(self.owner, "visual_wizard_button", None)
            index = layout.indexOf(before) if before is not None else -1
            if index >= 0: layout.insertWidget(index, button)
            else: layout.addWidget(button)
            self._toolbar_buttons[key] = button

        signal_map = {
            "clicked": "clicked", "toggled": "toggled", "text_changed": "textChanged",
            "value_changed": "valueChanged", "current_changed": "currentIndexChanged",
            "selection_changed": "selectionChanged",
        }
        for spec in manifest.get("watchers", []):
            key = (ext_id, spec.get("id", ""))
            if key in self._widget_watchers:
                continue
            widget = self._find_widget(spec.get("target", ""))
            signal = getattr(widget, signal_map.get(spec.get("signal", ""), ""), None) if widget is not None else None
            if signal is None or not hasattr(signal, "connect"):
                continue
            action_id = str(spec.get("action", "") or "")
            def callback(*args, p=package, aid=action_id, signal_name=spec.get("signal", "")):
                action = self._find_action(p["manifest"], aid)
                if action is None:
                    return
                value = args[0] if args else ""
                if isinstance(value, bool): value = "true" if value else "false"
                elif not isinstance(value, (str, int, float)): value = ""
                try:
                    self.run(p, action, seed_context={"event.name": f"widget.{signal_name}", "event.value": str(value)})
                except Exception as exc:
                    self.owner.log(f"Extension {p['manifest'].get('name', 'No title found')} watcher failed: {exc}", "warning")
            try:
                signal.connect(callback); self._widget_watchers[key] = (signal, callback)
            except Exception:
                pass

    def _find_widget(self, selector):
        selector = str(selector or "").strip()
        if not selector:
            return None
        attr_name = selector[5:] if selector.startswith("attr:") else selector
        candidate = getattr(self.owner, attr_name, None)
        if isinstance(candidate, QWidget):
            return candidate
        for top in QApplication.topLevelWidgets():
            if top.objectName() == selector:
                return top
            found = top.findChild(QWidget, selector)
            if found is not None:
                return found
        return None

    @staticmethod
    def _widget_read(widget, prop):
        prop = str(prop or "text").strip().casefold()
        if prop == "text" and hasattr(widget, "text"): return str(widget.text())
        if prop in {"title", "window_title"}: return str(widget.windowTitle())
        if prop == "tooltip": return str(widget.toolTip())
        if prop == "visible": return "true" if widget.isVisible() else "false"
        if prop == "enabled": return "true" if widget.isEnabled() else "false"
        if prop == "checked" and hasattr(widget, "isChecked"): return "true" if widget.isChecked() else "false"
        if prop == "value" and hasattr(widget, "value"): return str(widget.value())
        if prop == "current_text" and hasattr(widget, "currentText"): return str(widget.currentText())
        if prop == "current_index" and hasattr(widget, "currentIndex"): return str(widget.currentIndex())
        if prop == "placeholder" and hasattr(widget, "placeholderText"): return str(widget.placeholderText())
        if prop == "object_name": return str(widget.objectName())
        if prop == "width": return str(widget.width())
        if prop == "height": return str(widget.height())
        if prop in {"style", "stylesheet"}: return str(widget.styleSheet())
        raise ValueError(f"Unsupported widget property: {prop}")

    @staticmethod
    def _as_bool(value):
        return str(value or "").strip().casefold() not in {"", "0", "false", "no", "off", "none", "null"}

    def _widget_write(self, widget, prop, value):
        prop = str(prop or "text").strip().casefold()
        if prop == "text" and hasattr(widget, "setText"): widget.setText(str(value)); return
        if prop in {"title", "window_title"}: widget.setWindowTitle(str(value)); return
        if prop == "tooltip": widget.setToolTip(str(value)); return
        if prop == "visible": widget.setVisible(self._as_bool(value)); return
        if prop == "enabled": widget.setEnabled(self._as_bool(value)); return
        if prop == "checked" and hasattr(widget, "setChecked"): widget.setChecked(self._as_bool(value)); return
        if prop == "value" and hasattr(widget, "setValue"): widget.setValue(int(float(value))); return
        if prop == "current_index" and hasattr(widget, "setCurrentIndex"): widget.setCurrentIndex(int(float(value))); return
        if prop == "current_text" and hasattr(widget, "setCurrentText"): widget.setCurrentText(str(value)); return
        if prop == "placeholder" and hasattr(widget, "setPlaceholderText"): widget.setPlaceholderText(str(value)); return
        if prop in {"style", "stylesheet"}: widget.setStyleSheet(str(value)[:65536]); return
        if prop == "minimum_width": widget.setMinimumWidth(max(0, int(float(value)))); return
        if prop == "minimum_height": widget.setMinimumHeight(max(0, int(float(value)))); return
        if prop == "maximum_width": widget.setMaximumWidth(max(0, int(float(value)))); return
        if prop == "maximum_height": widget.setMaximumHeight(max(0, int(float(value)))); return
        raise ValueError(f"Unsupported writable widget property: {prop}")

    @staticmethod
    def _bounded(value, label="Extension text"):
        text = str(value if value is not None else "")
        if len(text.encode("utf-8", "replace")) > EXTENSION_TEXT_LIMIT:
            raise ValueError(f"{label} exceeded the 8 MiB sandbox limit.")
        return text

    def _snapshot_context(self, manifest):
        ext_id = manifest["id"]
        permissions = set(manifest.get("permissions", []))
        context = {}
        if "editor" in permissions:
            editor = self.owner.editor
            if editor is None:
                context.update({"editor": "", "selection": "", "tab_name": ""})
            else:
                try:
                    editor_text = editor.text() if self.owner.sci(editor.SCI_GETLENGTH) <= EXTENSION_TEXT_LIMIT else ""
                except Exception:
                    editor_text = ""
                try:
                    selection = editor.selectedText() if editor.hasSelectedText() else ""
                except Exception:
                    selection = ""
                context.update({
                    "editor": editor_text,
                    "selection": selection,
                    "tab_name": str(getattr(editor, "_lel_name", "") or ""),
                })
        if "clipboard" in permissions:
            context["clipboard"] = QApplication.clipboard().text()
        if "storage" in permissions:
            state = load_extension_state()
            storage = state.get("data", {}).get(ext_id, {})
            for key, value in storage.items():
                context[f"storage.{key}"] = str(value)
        context.update({
            "app.roblox_running": "true" if self.owner.roblox_running is True else "false",
            "app.roblox_mode": str(getattr(self.owner, "roblox_session_mode", "") or ""),
            "app.attached": "true" if bool(getattr(self.owner, "api_attached", False)) else "false",
            "app.proxy_active": "true" if bool(getattr(self.owner, "roblox_proxy_active", False)) else "false",
            "app.busy": "true" if bool(getattr(self.owner, "busy", False)) else "false",
            "app.tab_count": str(self.owner.editor_tabs.count() if hasattr(self.owner, "editor_tabs") else 0),
            "app.current_tab": str(self.owner.current_tab_name() if hasattr(self.owner, "current_tab_name") else ""),
        })
        join = current_roblox_join_context(require_running=False) or {}
        context["roblox.place_id"] = str(join.get("place_id", "") or "")
        context["roblox.job_id"] = str(join.get("job_id", "") or "")
        context["roblox.running"] = context["app.roblox_running"]
        context["roblox.attached"] = context["app.attached"]
        context["proxy.active"] = context["app.proxy_active"]
        context["proxy.suspended"] = "true" if bool(getattr(self.owner, "_proxy_api_suspended", False)) else "false"
        return context

    def _render(self, value, context):
        if not isinstance(value, str):
            return str(value if value is not None else "")
        def repl(match):
            return str(context.get(match.group(1), ""))
        return self._bounded(self._template_re.sub(repl, value))

    @staticmethod
    def _require_permission(manifest, op):
        required = EXTENSION_STEP_PERMISSIONS.get(op)
        if required and required not in set(manifest.get("permissions", [])):
            raise PermissionError(f"Operation {op} requires the {required!r} permission in manifest.json.")

    def _write_storage(self, ext_id, key, value=None, delete=False):
        key = str(key or "").strip()
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,96}", key):
            raise ValueError("Storage keys may only contain letters, numbers, dots, dashes, and underscores.")
        state = load_extension_state()
        data = state.setdefault("data", {})
        values = data.setdefault(ext_id, {})
        if delete:
            values.pop(key, None)
        else:
            if len(values) >= 128 and key not in values:
                raise ValueError("This extension already uses the maximum of 128 storage keys.")
            values[key] = self._bounded(value, "Stored value")[:65536]
        save_extension_state(state)
        return str(values.get(key, ""))

    def _extension_data_path(self, ext_id, relative="", create_parent=False):
        relative = str(relative or "").strip().replace("\\", "/")
        if not relative or relative.startswith("/") or re.match(r"^[A-Za-z]:", relative):
            raise ValueError("Extension file paths must be relative to the extension data folder.")
        parts = [part for part in relative.split("/") if part not in {"", "."}]
        if not parts or any(part == ".." for part in parts):
            raise ValueError("Extension file path contains an invalid segment.")
        root = (EXTENSION_DATA_DIR / ext_id).resolve()
        target = (root / Path(*parts)).resolve()
        if target != root and root not in target.parents:
            raise ValueError("Extension file path escaped the sandbox.")
        if create_parent:
            target.parent.mkdir(parents=True, exist_ok=True)
        return target

    def _list_extension_files(self, ext_id):
        root = EXTENSION_DATA_DIR / ext_id
        if not root.is_dir():
            return ""
        items = []
        for path in sorted(root.rglob("*"), key=lambda item: str(item).casefold()):
            if path.is_file():
                try:
                    items.append(path.relative_to(root).as_posix())
                except ValueError:
                    continue
            if len(items) >= 512:
                break
        return "\n".join(items)

    def _apply_fastflag_change(self, name, value=None, remove=False, enabled=True):
        name = str(name or "").strip()
        if not name or len(name) > 180:
            raise ValueError("FastFlag name is invalid.")
        flags = self.owner.load_custom_fastflags()
        state = self.owner.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        bindings = dict(state.get("keybinds", {}))
        if remove:
            flags.pop(name, None)
            disabled.discard(name)
            bindings.pop(name, None)
        else:
            flags[name] = str(value if value is not None else "")
            if enabled:
                disabled.discard(name)
            else:
                disabled.add(name)
        self.owner.save_custom_fastflags(flags)
        self.owner.save_custom_fastflag_state({"disabled": sorted(disabled), "keybinds": bindings})
        self.owner.refresh_custom_fastflag_hotkeys()
        prime_windows_fastflag_cache(self.owner.load_effective_fastflags())
        self.owner.mark_custom_fastflags_changed()
        if self.owner.fastflags_window is not None:
            self.owner.fastflags_window.reload()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()

    @staticmethod
    def _safe_save_name(value, fallback="result"):
        name = str(value or fallback).strip()
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", name):
            raise ValueError("save_as is invalid.")
        return name

    def _safe_math_eval(self, expression):
        expression = str(expression or "").strip()
        if not expression or len(expression) > 4096:
            raise ValueError("math.eval needs an expression up to 4096 characters.")
        funcs = {
            name: getattr(math, name) for name in (
                "sin cos tan asin acos atan atan2 sinh cosh tanh asinh acosh atanh sqrt cbrt exp exp2 expm1 "
                "log log10 log2 log1p floor ceil trunc fabs factorial gamma lgamma erf erfc degrees radians "
                "hypot dist fsum prod gcd lcm comb perm isqrt remainder copysign nextafter ulp"
            ).split() if hasattr(math, name)
        }
        funcs.update({"abs": abs, "min": min, "max": max, "round": round, "pow": pow})
        constants = {"pi": math.pi, "e": math.e, "tau": math.tau, "inf": math.inf, "nan": math.nan}
        tree = ast.parse(expression, mode="eval")
        allowed_bin = {
            ast.Add: lambda a,b:a+b, ast.Sub: lambda a,b:a-b, ast.Mult: lambda a,b:a*b,
            ast.Div: lambda a,b:a/b, ast.FloorDiv: lambda a,b:a//b, ast.Mod: lambda a,b:a%b,
            ast.Pow: lambda a,b:a**b,
        }
        allowed_unary = {ast.UAdd: lambda a:+a, ast.USub: lambda a:-a}
        def walk(node, depth=0):
            if depth > 32:
                raise ValueError("math.eval expression is too deeply nested.")
            if isinstance(node, ast.Expression): return walk(node.body, depth+1)
            if isinstance(node, ast.Constant) and isinstance(node.value, (int,float)): return node.value
            if isinstance(node, ast.Name) and node.id in constants: return constants[node.id]
            if isinstance(node, ast.BinOp) and type(node.op) in allowed_bin:
                left, right = walk(node.left, depth+1), walk(node.right, depth+1)
                if isinstance(node.op, ast.Pow) and abs(float(right)) > 10000:
                    raise ValueError("math.eval exponent is too large.")
                return allowed_bin[type(node.op)](left, right)
            if isinstance(node, ast.UnaryOp) and type(node.op) in allowed_unary:
                return allowed_unary[type(node.op)](walk(node.operand, depth+1))
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in funcs:
                if node.keywords or len(node.args) > 32:
                    raise ValueError("math.eval function call is too large.")
                return funcs[node.func.id](*[walk(arg, depth+1) for arg in node.args])
            raise ValueError("math.eval contains an unsupported expression element.")
        result = walk(tree)
        if isinstance(result, int): return str(result)
        if isinstance(result, float): return repr(result)
        return str(result)

    def _app_read_path(self, relative):
        relative = str(relative or "").strip().replace("\\", "/")
        if not relative or relative.startswith("/") or re.match(r"^[A-Za-z]:", relative):
            raise ValueError("App file paths must be relative to the LelSploit folder.")
        parts = [part for part in relative.split("/") if part not in {"", "."}]
        if not parts or any(part == ".." for part in parts):
            raise ValueError("App file path contains an invalid segment.")
        root = BASE_DIR.resolve()
        target = (root / Path(*parts)).resolve()
        if target != root and root not in target.parents:
            raise ValueError("App file path escaped the LelSploit folder.")
        return target

    def _app_file_listing(self, relative=""):
        root = BASE_DIR.resolve()
        start = root if not str(relative or "").strip() else self._app_read_path(relative)
        if not start.exists(): return []
        paths = [start] if start.is_file() else start.rglob("*")
        out = []
        for path in paths:
            try:
                resolved = path.resolve()
                if resolved != root and root not in resolved.parents: continue
                rel = resolved.relative_to(root).as_posix()
                stat = resolved.stat()
                out.append({"path": rel, "type": "dir" if resolved.is_dir() else "file", "size": int(stat.st_size) if resolved.is_file() else 0})
            except (OSError, ValueError):
                continue
            if len(out) >= 2000: break
        return out

    @staticmethod
    def _roblox_log_bytes(limit=4_000_000):
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data: return b"", None
        log_dir = Path(local_app_data) / "Roblox" / "logs"
        try:
            logs = [p for p in log_dir.glob("*.log") if "player" in p.name.casefold()] or list(log_dir.glob("*.log"))
            if not logs: return b"", None
            log = max(logs, key=lambda p: p.stat().st_mtime_ns)
            with log.open("rb") as handle:
                handle.seek(0, 2); size = handle.tell(); handle.seek(max(0, size-limit)); data = handle.read(limit)
            return data, log
        except OSError:
            return b"", None

    def _roblox_player_snapshot(self):
        data, _log = self._roblox_log_bytes()
        text = data.decode("utf-8", errors="ignore")
        players = {}
        
        patterns = (
            r'"(?:userId|UserId)"\s*:\s*(\d{1,20}).{0,180}?"(?:name|Name|username|Username)"\s*:\s*"([A-Za-z0-9_]{1,32})"',
            r'"(?:name|Name|username|Username)"\s*:\s*"([A-Za-z0-9_]{1,32})".{0,180}?"(?:userId|UserId)"\s*:\s*(\d{1,20})',
        )
        for idx, pattern in enumerate(patterns):
            for match in re.finditer(pattern, text, flags=re.IGNORECASE|re.DOTALL):
                if idx == 0: uid, name = match.group(1), match.group(2)
                else: name, uid = match.group(1), match.group(2)
                players[uid] = {"user_id": uid, "name": name}
                if len(players) >= 200: break
        return list(players.values())

    def _roblox_state(self):
        context = current_roblox_join_context(require_running=False) or {}
        try: processes = roblox_processes()
        except Exception: processes = []
        return {
            "running": bool(self.owner.roblox_running is True or processes),
            "mode": str(getattr(self.owner, "roblox_session_mode", "") or ""),
            "attached": bool(getattr(self.owner, "api_attached", False)),
            "proxy_active": bool(getattr(self.owner, "roblox_proxy_active", False)),
            "proxy_suspended": bool(getattr(self.owner, "_proxy_api_suspended", False)),
            "place_id": str(context.get("place_id", "") or ""),
            "job_id": str(context.get("job_id", "") or ""),
            "processes": list(processes),
            "players_from_log": self._roblox_player_snapshot(),
        }

    def _roblox_server_state(self):
        ctx = current_roblox_join_context(require_running=False) or {}
        place_id, job_id = str(ctx.get("place_id", "") or ""), str(ctx.get("job_id", "") or "")
        result = {"place_id": place_id, "job_id": job_id, "found": False}
        if not place_id.isdecimal() or not job_id:
            return result
        cursor = ""
        for _ in range(5):
            params = {"sortOrder": "Asc", "limit": "100"}
            if cursor: params["cursor"] = cursor
            url = f"https://games.roblox.com/v1/games/{place_id}/servers/Public?" + urllib.parse.urlencode(params)
            req = urllib.request.Request(url, headers={"Accept":"application/json","User-Agent":"LelSploit-Extension/1.1"})
            try:
                with urllib.request.urlopen(req, timeout=8) as response:
                    raw = response.read(2*1024*1024+1)
                if len(raw)>2*1024*1024: break
                payload = json.loads(raw.decode("utf-8", errors="replace"))
            except Exception as exc:
                result["error"] = str(exc); break
            for server in payload.get("data", []) if isinstance(payload, dict) else []:
                if str(server.get("id", "")) == job_id:
                    result.update({
                        "found": True, "playing": server.get("playing"), "max_players": server.get("maxPlayers"),
                        "fps": server.get("fps"), "ping": server.get("ping"),
                    })
                    return result
            cursor = str(payload.get("nextPageCursor") or "") if isinstance(payload, dict) else ""
            if not cursor: break
        return result

    def _set_extension_enabled(self, target_id, enabled):
        target_id = str(target_id or "").strip().casefold()
        known = {r.get("manifest", {}).get("id") for r in scan_extension_packages() if r.get("manifest")}
        if target_id not in known:
            raise ValueError("Unknown installed extension id.")
        state = load_extension_state(); disabled = set(state.get("disabled", []))
        if enabled: disabled.discard(target_id)
        else: disabled.add(target_id)
        state["disabled"] = sorted(disabled); save_extension_state(state)
        QTimer.singleShot(0, lambda tid=target_id: self.owner.refresh_extensions_runtime(restart_id=tid if enabled else None))

    def _play_extension_sound(self, package, ext_id, step, context):
        source = str(step.get("source", "package") or "package").strip().casefold()
        rel = self._render(step.get("path", ""), context)
        if source == "data":
            target = self._extension_data_path(ext_id, rel)
            if not target.is_file(): raise FileNotFoundError(rel)
        else:
            data = self._package_bytes(package, rel, 8*1024*1024)
            if not rel.casefold().endswith(".wav"):
                raise ValueError("sound.play currently supports WAV resources.")
            cache = self._extension_data_path(ext_id, f".sound_cache/{hashlib.sha256(data).hexdigest()[:24]}.wav", create_parent=True)
            if not cache.is_file(): cache.write_bytes(data)
            target = cache
        if not str(target).casefold().endswith(".wav"):
            raise ValueError("sound.play currently supports WAV files.")
        if sys.platform == "win32":
            import winsound
            flags = winsound.SND_FILENAME | (winsound.SND_ASYNC if self._as_bool(step.get("async", True)) else 0)
            winsound.PlaySound(str(target), flags)
        else:
            QApplication.beep()

    def _condition_passes(self, step, context):
        spec = step.get("when")
        if not isinstance(spec, dict):
            return True
        left = self._render(spec.get("value", spec.get("left", "")), context)
        right = self._render(spec.get("right", ""), context)
        operator = str(spec.get("op", spec.get("operator", "truthy")) or "truthy").strip().casefold()
        if operator in {"equals", "eq", "=="}:
            return left == right
        if operator in {"not_equals", "ne", "!="}:
            return left != right
        if operator == "contains":
            return right in left
        if operator == "not_contains":
            return right not in left
        if operator == "starts_with":
            return left.startswith(right)
        if operator == "ends_with":
            return left.endswith(right)
        if operator == "regex":
            return re.search(right, left) is not None
        if operator == "empty":
            return not left
        if operator == "not_empty":
            return bool(left)
        if operator == "falsy":
            return left.strip().casefold() in {"", "0", "false", "no", "off", "none", "null"}
        return left.strip().casefold() not in {"", "0", "false", "no", "off", "none", "null"}

    def _tab_index_from_step(self, step, context):
        name = self._render(step.get("name", ""), context).strip().casefold()
        if name:
            for index in range(self.owner.editor_tabs.count()):
                editor = self.owner.tab_editor(index)
                full_name = str(getattr(editor, "_lel_name", "") or "").casefold()
                shown = self.owner.editor_tabs.tabText(index).casefold()
                if name in {full_name, shown}:
                    return index
            return -1
        if step.get("index") is not None:
            try:
                return int(self._render(str(step.get("index")), context))
            except (TypeError, ValueError):
                return -1
        return self.owner.editor_tabs.currentIndex()

    @staticmethod
    def _network_address_is_public(hostname):
        host = str(hostname or "").strip().rstrip(".").casefold()
        if not host or host in {"localhost", "localhost.localdomain"} or host.endswith(".localhost"):
            return False
        try:
            addresses = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        except OSError as exc:
            raise ValueError(f"Could not resolve extension URL host: {exc}") from exc
        if not addresses:
            return False
        for info in addresses:
            address = info[4][0].split("%", 1)[0]
            try:
                if not ipaddress.ip_address(address).is_global:
                    return False
            except ValueError:
                return False
        return True

    def _validate_network_url(self, value):
        url = self._render(value, {}) if not isinstance(value, str) else value
        url = str(url or "").strip()
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme.casefold() not in {"http", "https"} or not parsed.hostname:
            raise ValueError("Extensions may only request public http/https URLs.")
        if parsed.username or parsed.password:
            raise ValueError("Credentials may not be embedded in an extension URL.")
        if not self._network_address_is_public(parsed.hostname):
            raise ValueError("Extensions cannot request localhost, private, reserved, or link-local addresses.")
        return url

    def _http_request(self, step, context):
        url = self._validate_network_url(self._render(step.get("url", ""), context))
        method = str(step.get("method", "GET") or "GET").strip().upper()
        if method not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
            raise ValueError("http.request supports GET, POST, PUT, PATCH, and DELETE.")
        headers = {"User-Agent": "LelSploit-Extension/1.0", "Accept": "*/*"}
        raw_headers = step.get("headers", {})
        if isinstance(raw_headers, dict):
            for key, value in list(raw_headers.items())[:24]:
                key = str(key or "").strip()
                if not key or key.casefold() in {"host", "content-length", "connection", "proxy-connection"}:
                    continue
                headers[key[:80]] = self._render(value, context)[:4096]
        body = self._render(step.get("body", ""), context)
        data = body.encode("utf-8") if method in {"POST", "PUT", "PATCH", "DELETE"} and body else None
        try:
            timeout = float(step.get("timeout", 10) or 10)
        except (TypeError, ValueError):
            timeout = 10.0
        timeout = max(1.0, min(20.0, timeout))
        request = urllib.request.Request(url, data=data, method=method, headers=headers)
        runtime = self
        class _SafeRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                runtime._validate_network_url(newurl)
                return super().redirect_request(req, fp, code, msg, hdrs, newurl)
        opener = urllib.request.build_opener(_SafeRedirect())
        with opener.open(request, timeout=timeout) as response:
            final_url = self._validate_network_url(response.geturl())
            raw = response.read(EXTENSION_NETWORK_LIMIT + 1)
            if len(raw) > EXTENSION_NETWORK_LIMIT:
                raise ValueError("Extension HTTP response exceeded the 2 MiB limit.")
            charset = response.headers.get_content_charset() or "utf-8"
            content = raw.decode(charset, errors="replace")
            status = int(getattr(response, "status", 200) or 200)
            response_headers = dict(response.headers.items())
        save_as = str(step.get("save_as", "response") or "response").strip()
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
            raise ValueError("save_as is invalid.")
        context[f"var.{save_as}"] = self._bounded(content, "HTTP response")
        context[f"var.{save_as}.status"] = str(status)
        context[f"var.{save_as}.url"] = final_url
        context[f"var.{save_as}.headers"] = json.dumps(response_headers, ensure_ascii=False)

    def _transform(self, source, step, context):
        method = str(step.get("method", "strip")).strip().casefold()
        if method == "upper":
            result = source.upper()
        elif method == "lower":
            result = source.lower()
        elif method == "strip":
            result = source.strip()
        elif method == "json_pretty":
            result = json.dumps(json.loads(source), indent=2, ensure_ascii=False)
        elif method == "url_encode":
            result = urllib.parse.quote(source, safe="")
        elif method == "url_decode":
            result = urllib.parse.unquote(source)
        elif method == "base64_encode":
            result = base64.b64encode(source.encode("utf-8")).decode("ascii")
        elif method == "base64_decode":
            result = base64.b64decode(source.encode("ascii"), validate=True).decode("utf-8")
        elif method == "sha256":
            result = hashlib.sha256(source.encode("utf-8")).hexdigest()
        elif method == "reverse":
            result = source[::-1]
        elif method == "length":
            result = str(len(source))
        elif method == "json_compact":
            result = json.dumps(json.loads(source), ensure_ascii=False, separators=(",", ":"))
        elif method == "lines_sort":
            result = "\n".join(sorted(source.splitlines(), key=str.casefold))
        elif method == "lines_unique":
            result = "\n".join(dict.fromkeys(source.splitlines()))
        elif method == "lines_trim":
            result = "\n".join(line.rstrip() for line in source.splitlines())
        elif method == "normalize_newlines":
            result = source.replace("\r\n", "\n").replace("\r", "\n")
        elif method == "words":
            result = str(len(re.findall(r"\S+", source)))
        elif method == "regex_extract":
            pattern = self._render(step.get("pattern", ""), context)
            matches = re.findall(pattern, source)
            result = "\n".join("\t".join(map(str, item)) if isinstance(item, tuple) else str(item) for item in matches)
        elif method == "regex_replace":
            pattern = self._render(step.get("pattern", ""), context)
            replacement = self._render(step.get("replace", ""), context)
            result = re.sub(pattern, replacement, source, count=max(0, int(step.get("count", 0) or 0)))
        else:
            raise ValueError(f"Unknown text transform: {method}")
        return self._bounded(result, "Transform result")

    def run(self, package, action, seed_context=None, _context=None):
        manifest = package["manifest"]
        ext_id = manifest["id"]
        state = load_extension_state()
        if ext_id in set(state.get("disabled", [])):
            raise PermissionError("This extension is disabled.")
        if _context is None:
            context = self._snapshot_context(manifest)
            context["extension.id"] = ext_id
            context["extension.name"] = manifest["name"]
            if isinstance(seed_context, dict):
                for key, value in seed_context.items():
                    context[str(key)] = self._bounded(value, "Seed context")
        else:
            context = _context
        for spec in action.get("inputs", []):
            text, ok = QInputDialog.getText(
                self.owner,
                spec.get("title", manifest["name"]),
                spec.get("prompt", spec["id"]),
                text=spec.get("default", ""),
            )
            if not ok:
                return False
            context[f"input.{spec['id']}"] = self._bounded(text, "Input")

        for step in action.get("steps", []):
            if not self._condition_passes(step, context):
                continue
            op = str(step.get("op", "")).strip()
            self._require_permission(manifest, op)
            editor = self.owner.editor
            if op.startswith("editor.") or op.startswith("selection."):
                if editor is None:
                    raise RuntimeError("No editor tab is open.")
            if op == "editor.set":
                editor.setText(self._render(step.get("text", ""), context))
            elif op == "editor.append":
                editor.setText(self._bounded(editor.text() + self._render(step.get("text", ""), context)))
            elif op == "editor.prepend":
                editor.setText(self._bounded(self._render(step.get("text", ""), context) + editor.text()))
            elif op == "editor.insert":
                editor.insert(self._render(step.get("text", ""), context))
            elif op == "editor.clear":
                editor.setText("")
            elif op == "editor.select_all":
                editor.selectAll()
            elif op == "editor.goto_line":
                try:
                    line = max(1, int(self._render(step.get("line", "1"), context)))
                    index = max(0, int(self._render(step.get("index", "0"), context)))
                except (TypeError, ValueError):
                    raise ValueError("editor.goto_line needs numeric line/index values.")
                editor.setCursorPosition(line - 1, index)
            elif op == "editor.cursor":
                line, index = editor.getCursorPosition()
                save_as = str(step.get("save_as", "cursor") or "cursor").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}.line"] = str(line + 1)
                context[f"var.{save_as}.index"] = str(index)
            elif op == "editor.line":
                try:
                    line_number = max(1, int(self._render(step.get("line", "1"), context)))
                except (TypeError, ValueError):
                    raise ValueError("editor.line needs a numeric line.")
                value = editor.text(line_number - 1).rstrip("\r\n") if line_number - 1 < editor.lines() else ""
                save_as = str(step.get("save_as", "line") or "line").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = self._bounded(value, "Editor line")
            elif op == "editor.replace":
                source = editor.text()
                find = self._render(step.get("find", ""), context)
                replacement = self._render(step.get("replace", ""), context)
                count = max(0, int(step.get("count", 0) or 0))
                if bool(step.get("regex", False)):
                    result = re.sub(find, replacement, source, count=count)
                else:
                    result = source.replace(find, replacement, count if count > 0 else -1)
                editor.setText(self._bounded(result))
            elif op == "selection.replace":
                replacement = self._render(step.get("text", ""), context)
                if editor.hasSelectedText():
                    editor.replaceSelectedText(replacement)
                elif bool(step.get("append_if_empty", False)):
                    editor.setText(self._bounded(editor.text() + replacement))
            elif op == "selection.copy":
                QApplication.clipboard().setText(editor.selectedText() if editor.hasSelectedText() else "")
            elif op == "selection.delete":
                if editor.hasSelectedText():
                    editor.replaceSelectedText("")
            elif op == "editor.new_tab":
                name = self._render(step.get("name", "extension.luau"), context).strip()[:100] or "extension.luau"
                content = self._render(step.get("text", ""), context)
                self.owner.add_editor_tab(name, content, select=True)
                editor = self.owner.editor
            elif op == "tabs.rename":
                self.owner.set_current_tab_name(self._render(step.get("name", "script.luau"), context).strip()[:180] or "script.luau")
            elif op == "tabs.select":
                target_name = self._render(step.get("name", ""), context).strip().casefold()
                target_index = step.get("index", None)
                chosen = -1
                if target_name:
                    for i in range(self.owner.editor_tabs.count()):
                        editor_widget = self.owner.tab_editor(i)
                        full_name = str(getattr(editor_widget, "_lel_name", "") or "").casefold()
                        if full_name == target_name or self.owner.editor_tabs.tabText(i).casefold() == target_name:
                            chosen = i
                            break
                elif target_index is not None:
                    try:
                        chosen = int(target_index)
                    except (TypeError, ValueError):
                        chosen = -1
                if 0 <= chosen < self.owner.editor_tabs.count():
                    self.owner.editor_tabs.setCurrentIndex(chosen)
                    editor = self.owner.editor
            elif op == "tabs.close_current":
                index = self.owner.editor_tabs.currentIndex()
                if index >= 0:
                    self.owner.close_editor_tab(index)
                editor = self.owner.editor
            elif op == "tabs.list":
                names = []
                for i in range(self.owner.editor_tabs.count()):
                    editor_widget = self.owner.tab_editor(i)
                    names.append(str(getattr(editor_widget, "_lel_name", self.owner.editor_tabs.tabText(i)) or ""))
                save_as = str(step.get("save_as", "tabs") or "tabs").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = "\n".join(names)
                context[f"var.{save_as}.count"] = str(len(names))
            elif op == "tabs.read":
                tab_index = self._tab_index_from_step(step, context)
                if not (0 <= tab_index < self.owner.editor_tabs.count()):
                    raise ValueError("tabs.read could not find the requested tab.")
                editor_widget = self.owner.tab_editor(tab_index)
                value = editor_widget.text() if isinstance(editor_widget, CodeEditor) else ""
                save_as = str(step.get("save_as", "tab") or "tab").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = self._bounded(value, "Tab text")
            elif op == "tabs.set":
                tab_index = self._tab_index_from_step(step, context)
                if not (0 <= tab_index < self.owner.editor_tabs.count()):
                    raise ValueError("tabs.set could not find the requested tab.")
                editor_widget = self.owner.tab_editor(tab_index)
                if not isinstance(editor_widget, CodeEditor):
                    raise ValueError("tabs.set target is not an editor tab.")
                editor_widget.setText(self._render(step.get("text", ""), context))
            elif op == "clipboard.set":
                QApplication.clipboard().setText(self._render(step.get("text", ""), context))
            elif op == "clipboard.append":
                QApplication.clipboard().setText(self._bounded(QApplication.clipboard().text() + self._render(step.get("text", ""), context)))
            elif op == "console.log":
                level = str(step.get("level", "info")).strip().casefold()
                if level not in {"info", "success", "warning"}:
                    level = "info"
                self.owner.log(self._render(step.get("text", ""), context), level)
            elif op == "notify":
                title = self._render(step.get("title", manifest["name"]), context)[:100]
                message = self._render(step.get("text", ""), context)[:1000]
                self.owner.notify_user(title, message, min(10000, max(1000, int(step.get("duration", 3500) or 3500))))
            elif op == "message":
                QMessageBox.information(self.owner, manifest["name"], self._render(step.get("text", ""), context)[:4000])
            elif op == "dialog.input":
                title = self._render(step.get("title", manifest["name"]), context)[:100]
                prompt = self._render(step.get("prompt", "Value:"), context)[:500]
                default = self._render(step.get("default", ""), context)[:4096]
                value, ok = QInputDialog.getText(self.owner, title, prompt, text=default)
                save_as = str(step.get("save_as", "input") or "input").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = self._bounded(value if ok else "", "Dialog result")
                context[f"var.{save_as}.accepted"] = "true" if ok else "false"
            elif op == "dialog.confirm":
                title = self._render(step.get("title", manifest["name"]), context)[:100]
                text = self._render(step.get("text", "Continue?"), context)[:2000]
                answer = QMessageBox.question(self.owner, title, text, QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No, QMessageBox.StandardButton.No)
                save_as = str(step.get("save_as", "confirmed") or "confirmed").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = "true" if answer == QMessageBox.StandardButton.Yes else "false"
            elif op == "ui.open":
                target = self._render(step.get("target", ""), context).strip().casefold()
                openers = {
                    "scriptblox": self.owner.open_scriptblox,
                    "tools": self.owner.open_tools,
                    "fastflags": self.owner.open_fastflags,
                    "extensions": self.owner.open_extensions,
                    "documentation": self.owner.open_documentation,
                    "settings": self.owner.open_settings,
                }
                opener = openers.get(target)
                if opener is None:
                    raise ValueError("ui.open target must be scriptblox, tools, fastflags, extensions, documentation, or settings.")
                QTimer.singleShot(0, opener)
            elif op == "ui.smooth_scroll":
                raw_enabled = self._render(step.get("enabled", "true"), context).strip().casefold()
                enabled = raw_enabled not in {"0", "false", "no", "off"}
                try:
                    duration = int(float(self._render(step.get("duration", "165"), context)))
                except (TypeError, ValueError):
                    duration = 165
                try:
                    strength = float(self._render(step.get("strength", "1.0"), context))
                except (TypeError, ValueError):
                    strength = 1.0
                self.owner.extension_smooth_scroll.set_extension(ext_id, enabled, duration, strength)
            elif op == "visual_wizard.enable":
                self.owner.visual_wizard_service.enable_extension(ext_id)
            elif op == "ui.window":
                action_name = self._render(step.get("action", "show"), context).strip().casefold()
                if action_name == "show":
                    self.owner.show()
                elif action_name == "hide":
                    self.owner.hide()
                elif action_name == "minimize":
                    self.owner.showMinimized()
                elif action_name == "maximize":
                    self.owner.showMaximized()
                elif action_name == "normal":
                    self.owner.showNormal()
                elif action_name == "raise":
                    self.owner.showNormal(); self.owner.raise_(); self.owner.activateWindow()
                else:
                    raise ValueError("ui.window action must be show, hide, minimize, maximize, normal, or raise.")
            elif op == "storage.set":
                key = self._render(step.get("key", ""), context)
                value = self._render(step.get("value", ""), context)
                stored = self._write_storage(ext_id, key, value)
                context[f"storage.{key}"] = stored
            elif op == "storage.delete":
                key = self._render(step.get("key", ""), context)
                self._write_storage(ext_id, key, delete=True)
                context.pop(f"storage.{key}", None)
            elif op == "storage.clear":
                state = load_extension_state()
                state.setdefault("data", {})[ext_id] = {}
                save_extension_state(state)
                for key in [key for key in context if key.startswith("storage.")]:
                    context.pop(key, None)
            elif op == "file.read":
                target = self._extension_data_path(ext_id, self._render(step.get("path", ""), context))
                if not target.is_file():
                    content = ""
                elif target.stat().st_size > EXTENSION_TEXT_LIMIT:
                    raise ValueError("Extension data file exceeded the 8 MiB limit.")
                else:
                    content = target.read_text(encoding="utf-8", errors="replace")
                save_as = str(step.get("save_as", "file") or "file").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = self._bounded(content, "Extension file")
            elif op in {"file.write", "file.append"}:
                target = self._extension_data_path(ext_id, self._render(step.get("path", ""), context), create_parent=True)
                text = self._render(step.get("text", ""), context)
                if op == "file.append" and target.is_file():
                    existing = target.read_text(encoding="utf-8", errors="replace")
                    text = self._bounded(existing + text, "Extension file")
                target.write_text(text, encoding="utf-8", newline="\n")
            elif op == "file.delete":
                target = self._extension_data_path(ext_id, self._render(step.get("path", ""), context))
                target.unlink(missing_ok=True)
            elif op == "file.list":
                save_as = str(step.get("save_as", "files") or "files").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = self._list_extension_files(ext_id)
            elif op == "file.pick_read":
                caption = self._render(step.get("title", "Choose a file"), context)[:120]
                file_filter = self._render(step.get("filter", "Text files (*.txt *.lua *.luau *.json *.md);;All files (*)"), context)[:500]
                path, _ = QFileDialog.getOpenFileName(self.owner, caption, "", file_filter)
                save_as = str(step.get("save_as", "picked") or "picked").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                if not path:
                    context[f"var.{save_as}"] = ""
                    context[f"var.{save_as}.path"] = ""
                else:
                    target = Path(path)
                    if target.stat().st_size > EXTENSION_TEXT_LIMIT:
                        raise ValueError("Selected file exceeds the 8 MiB extension limit.")
                    context[f"var.{save_as}"] = self._bounded(target.read_text(encoding="utf-8", errors="replace"), "Selected file")
                    context[f"var.{save_as}.path"] = str(target)
            elif op == "file.pick_write":
                caption = self._render(step.get("title", "Save a file"), context)[:120]
                suggested = self._render(step.get("name", "extension-output.txt"), context)[:200]
                file_filter = self._render(step.get("filter", "Text files (*.txt);;All files (*)"), context)[:500]
                path, _ = QFileDialog.getSaveFileName(self.owner, caption, suggested, file_filter)
                save_as = str(step.get("save_as", "saved") or "saved").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                if path:
                    Path(path).write_text(self._render(step.get("text", ""), context), encoding="utf-8", newline="\n")
                context[f"var.{save_as}.path"] = str(path or "")
            elif op == "http.request":
                self._http_request(step, context)
            elif op == "var.set":
                save_as = str(step.get("name", "value") or "value").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("Variable name is invalid.")
                context[f"var.{save_as}"] = self._render(step.get("value", ""), context)
            elif op == "var.append":
                save_as = str(step.get("name", "value") or "value").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("Variable name is invalid.")
                context[f"var.{save_as}"] = self._bounded(context.get(f"var.{save_as}", "") + self._render(step.get("value", ""), context))
            elif op == "var.delete":
                save_as = str(step.get("name", "value") or "value").strip()
                context.pop(f"var.{save_as}", None)
            elif op == "var.number":
                name = str(step.get("name", "number") or "number").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", name):
                    raise ValueError("Variable name is invalid.")
                try:
                    left = float(self._render(step.get("left", "0"), context))
                    right = float(self._render(step.get("right", "0"), context))
                except (TypeError, ValueError):
                    raise ValueError("var.number needs numeric left/right values.")
                operation = str(step.get("operation", "add") or "add").strip().casefold()
                if operation == "add": result = left + right
                elif operation == "subtract": result = left - right
                elif operation == "multiply": result = left * right
                elif operation == "divide": result = left / right
                elif operation == "mod": result = left % right
                elif operation == "min": result = min(left, right)
                elif operation == "max": result = max(left, right)
                else: raise ValueError("Unknown var.number operation.")
                context[f"var.{name}"] = str(int(result) if result.is_integer() else result)
            elif op == "system.now":
                name = str(step.get("save_as", "now") or "now").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", name):
                    raise ValueError("save_as is invalid.")
                now = datetime.now().astimezone()
                context[f"var.{name}"] = now.isoformat(timespec="seconds")
                context[f"var.{name}.unix"] = str(int(now.timestamp()))
            elif op == "text.transform":
                source = self._render(step.get("source", ""), context)
                result = self._transform(source, step, context)
                save_as = str(step.get("save_as", "result") or "result").strip()
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", save_as):
                    raise ValueError("save_as is invalid.")
                context[f"var.{save_as}"] = result
            elif op == "script.execute":
                source = self._render(step.get("source", "${editor}"), context)
                if not self.owner.execute_source_text(source, label=manifest["name"]):
                    raise RuntimeError("LelSploit could not start the extension's execute action.")
            elif op == "fastflag.set":
                name = self._render(step.get("name", ""), context)
                value = self._render(step.get("value", ""), context)
                self._apply_fastflag_change(name, value, remove=False, enabled=bool(step.get("enabled", True)))
            elif op == "fastflag.remove":
                name = self._render(step.get("name", ""), context)
                self._apply_fastflag_change(name, remove=True)
            elif op == "package.list":
                with zipfile.ZipFile(Path(package["path"]), "r") as archive:
                    names = [name for name in archive.namelist() if not name.endswith("/")][:1024]
                save_as = str(step.get("save_as", "package_files") or "package_files").strip()
                context[f"var.{save_as}"] = "\n".join(names)
            elif op == "package.read":
                name = self._render(step.get("path", ""), context)
                data = self._package_bytes(package, name, EXTENSION_TEXT_LIMIT)
                encoding = str(step.get("encoding", "utf-8") or "utf-8")[:40]
                value = data.decode(encoding, errors="replace")
                save_as = str(step.get("save_as", "resource") or "resource").strip()
                context[f"var.{save_as}"] = self._bounded(value, "Package resource")
            elif op == "settings.get":
                key = self._render(step.get("key", ""), context).strip()[:160]
                default = self._render(step.get("default", ""), context)
                value = self.owner.settings.value(key, default)
                save_as = str(step.get("save_as", "setting") or "setting").strip()
                context[f"var.{save_as}"] = self._bounded(json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else value)
            elif op == "settings.set":
                key = self._render(step.get("key", ""), context).strip()[:160]
                if not key:
                    raise ValueError("settings.set requires a key.")
                value = self._render(step.get("value", ""), context)
                value_type = str(step.get("type", "string") or "string").strip().casefold()
                if value_type == "bool": value = self._as_bool(value)
                elif value_type == "int": value = int(float(value))
                elif value_type == "float": value = float(value)
                elif value_type == "json": value = json.loads(value)
                self.owner.settings.setValue(key, value); self.owner.settings.sync()
            elif op == "theme.get":
                key = self._render(step.get("key", ""), context).strip()
                save_as = str(step.get("save_as", "theme") or "theme").strip()
                if key:
                    value = self.owner.appearance_manager.value(key, "")
                else:
                    value = json.dumps(self.owner.appearance_manager.theme, ensure_ascii=False)
                context[f"var.{save_as}"] = self._bounded(value)
            elif op == "theme.set":
                key = self._render(step.get("key", ""), context).strip()
                value = self._render(step.get("value", ""), context)
                self.owner.appearance_manager.set_value(key, value)
            elif op == "theme.preset":
                self.owner.appearance_manager.apply_preset(self._render(step.get("name", "LelSploit Default"), context))
            elif op == "theme.reset":
                self.owner.appearance_manager.reset()
            elif op == "app.state":
                name = self._render(step.get("name", ""), context).strip().casefold()
                states = {
                    "roblox_running": self.owner.roblox_running is True,
                    "roblox_mode": str(getattr(self.owner, "roblox_session_mode", "") or ""),
                    "attached": bool(getattr(self.owner, "api_attached", False)),
                    "proxy_active": bool(getattr(self.owner, "roblox_proxy_active", False)),
                    "busy": bool(getattr(self.owner, "busy", False)),
                    "tab_count": self.owner.editor_tabs.count(),
                    "current_tab": self.owner.current_tab_name(),
                    "window_visible": self.owner.isVisible(),
                }
                save_as = str(step.get("save_as", "state") or "state").strip()
                value = states.get(name, states if not name else "")
                context[f"var.{save_as}"] = json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list, bool)) else str(value)
            elif op == "ui.toolbar.add":
                spec = {
                    "id": self._render(step.get("id", "runtime"), context)[:64],
                    "text": self._render(step.get("text", ""), context)[:40],
                    "tooltip": self._render(step.get("tooltip", manifest["name"]), context)[:120],
                    "icon": self._render(step.get("icon", ""), context)[:160],
                    "action": str(step.get("action", "") or ""),
                }
                temp = dict(package); temp_manifest = dict(manifest); temp_manifest["toolbar"] = [spec]; temp["manifest"] = temp_manifest
                self.activate_extension(temp)
            elif op == "ui.toolbar.remove":
                key = (ext_id, self._render(step.get("id", "runtime"), context)[:64])
                button = self._toolbar_buttons.pop(key, None)
                if button is not None: button.deleteLater()
            elif op == "ui.panel.open":
                panel_id = self._render(step.get("id", ""), context).strip()
                spec = self._find_panel(manifest, panel_id)
                if spec is None:
                    raise ValueError(f"Unknown extension panel: {panel_id}")
                key = (ext_id, panel_id)
                panel = self._panels.get(key)
                if panel is None:
                    panel = ExtensionPanelWindow(self, self.owner, package, spec)
                    panel.destroyed.connect(lambda _=None, k=key: self._panels.pop(k, None))
                    self._panels[key] = panel
                panel.show(); panel.raise_(); panel.activateWindow()
            elif op == "ui.panel.close":
                panel_id = self._render(step.get("id", ""), context).strip()
                panel = self._panels.pop((ext_id, panel_id), None)
                if panel is not None: panel.close(); panel.deleteLater()
            elif op == "ui.panel.update":
                panel_id = self._render(step.get("id", ""), context).strip()
                control_id = self._render(step.get("control", ""), context).strip()
                prop = self._render(step.get("property", "text"), context).strip()
                value = self._render(step.get("value", ""), context)
                panel = self._panels.get((ext_id, panel_id))
                if panel is None: raise ValueError("The requested extension panel is not open.")
                panel.set_control_property(control_id, prop, value)
            elif op == "ui.widget.get":
                widget = self._find_widget(self._render(step.get("target", ""), context))
                if widget is None: raise ValueError("ui.widget.get could not find the target widget.")
                save_as = str(step.get("save_as", "widget") or "widget").strip()
                context[f"var.{save_as}"] = self._bounded(self._widget_read(widget, step.get("property", "text")))
            elif op == "ui.widget.set":
                widget = self._find_widget(self._render(step.get("target", ""), context))
                if widget is None: raise ValueError("ui.widget.set could not find the target widget.")
                self._widget_write(widget, step.get("property", "text"), self._render(step.get("value", ""), context))
            elif op == "ui.widget.invoke":
                widget = self._find_widget(self._render(step.get("target", ""), context))
                if widget is None: raise ValueError("ui.widget.invoke could not find the target widget.")
                action_name = self._render(step.get("action", "focus"), context).strip().casefold()
                if action_name == "click" and hasattr(widget, "click"): widget.click()
                elif action_name == "focus": widget.setFocus()
                elif action_name == "show": widget.show()
                elif action_name == "hide": widget.hide()
                elif action_name == "raise": widget.show(); widget.raise_(); widget.activateWindow()
                elif action_name == "clear" and hasattr(widget, "clear"): widget.clear()
                elif action_name == "toggle" and hasattr(widget, "setChecked") and hasattr(widget, "isChecked"): widget.setChecked(not widget.isChecked())
                else: raise ValueError(f"Unsupported widget action: {action_name}")
            elif op == "flow.if":
                branch = step.get("then", []) if self._condition_passes({"when": step.get("condition", step.get("when", {}))}, context) else step.get("else", [])
                if branch:
                    self.run(package, {"inputs": [], "steps": branch}, _context=context)
            elif op == "flow.repeat":
                try: count = max(0, min(500, int(float(self._render(step.get("count", "1"), context)))))
                except (TypeError, ValueError): raise ValueError("flow.repeat needs a numeric count.")
                var_name = str(step.get("index", "loop") or "loop").strip()
                for i in range(count):
                    context[f"var.{var_name}"] = str(i)
                    self.run(package, {"inputs": [], "steps": step.get("steps", [])}, _context=context)
            elif op == "flow.foreach":
                source = self._render(step.get("source", ""), context)
                mode = str(step.get("mode", "lines") or "lines").strip().casefold()
                if mode == "json":
                    parsed = json.loads(source); values = list(parsed.values()) if isinstance(parsed, dict) else list(parsed if isinstance(parsed, list) else [])
                else:
                    values = source.splitlines()
                values = values[:500]
                item_name = str(step.get("item", "item") or "item").strip()
                index_name = str(step.get("index", "index") or "index").strip()
                for i, value in enumerate(values):
                    context[f"var.{item_name}"] = self._bounded(json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else value)
                    context[f"var.{index_name}"] = str(i)
                    self.run(package, {"inputs": [], "steps": step.get("steps", [])}, _context=context)
            elif op == "json.get":
                payload = json.loads(self._render(step.get("source", "{}"), context))
                path = self._render(step.get("path", ""), context).strip()
                value = payload
                if path:
                    for part in path.split("."):
                        if isinstance(value, dict): value = value.get(part)
                        elif isinstance(value, list) and part.isdigit() and int(part) < len(value): value = value[int(part)]
                        else: value = None; break
                save_as = str(step.get("save_as", "json") or "json").strip()
                context[f"var.{save_as}"] = self._bounded(json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list, bool)) or value is None else value)
            elif op == "json.set":
                payload = json.loads(self._render(step.get("source", "{}"), context))
                if not isinstance(payload, dict): raise ValueError("json.set currently requires a JSON object root.")
                path = self._render(step.get("path", ""), context).strip()
                if not path: raise ValueError("json.set requires a dotted path.")
                raw_value = self._render(step.get("value", ""), context)
                try: value = json.loads(raw_value) if bool(step.get("json", False)) else raw_value
                except ValueError: value = raw_value
                node = payload; parts = path.split(".")
                for part in parts[:-1]:
                    child = node.get(part)
                    if not isinstance(child, dict): child = {}; node[part] = child
                    node = child
                node[parts[-1]] = value
                save_as = self._safe_save_name(step.get("save_as", "json"), "json")
                context[f"var.{save_as}"] = self._bounded(json.dumps(payload, ensure_ascii=False))
            elif op == "math.eval":
                save_as = self._safe_save_name(step.get("save_as", "math"), "math")
                context[f"var.{save_as}"] = self._safe_math_eval(self._render(step.get("expression", "0"), context))
            elif op == "math.stats":
                raw = self._render(step.get("values", "[]"), context).strip()
                try:
                    parsed = json.loads(raw)
                    values = [float(v) for v in parsed] if isinstance(parsed, list) else []
                except Exception:
                    values = [float(v.strip()) for v in raw.split(",") if v.strip()]
                if not values or len(values) > 100000: raise ValueError("math.stats needs 1 to 100000 numeric values.")
                result = {"count":len(values),"sum":math.fsum(values),"min":min(values),"max":max(values),"mean":statistics.fmean(values),"median":statistics.median(values)}
                if len(values) >= 2:
                    result.update({"stdev":statistics.stdev(values),"variance":statistics.variance(values),"pstdev":statistics.pstdev(values),"pvariance":statistics.pvariance(values)})
                    try: result["quartiles"] = statistics.quantiles(values, n=4, method="inclusive")
                    except Exception: pass
                if all(v > 0 for v in values):
                    try: result["geometric_mean"] = statistics.geometric_mean(values); result["harmonic_mean"] = statistics.harmonic_mean(values)
                    except Exception: pass
                save_as = self._safe_save_name(step.get("save_as", "stats"), "stats")
                context[f"var.{save_as}"] = json.dumps(result, ensure_ascii=False)
            elif op == "math.vector":
                a = json.loads(self._render(step.get("a", "[]"), context)); b = json.loads(self._render(step.get("b", "[]"), context)) if step.get("b") is not None else None
                if not isinstance(a, list) or len(a) > 64: raise ValueError("math.vector a must be a numeric JSON array up to 64 values.")
                a = [float(x) for x in a]; operation = str(step.get("operation", "magnitude") or "magnitude").strip().casefold()
                if operation == "magnitude": result = math.sqrt(math.fsum(x*x for x in a))
                elif operation == "normalize":
                    mag = math.sqrt(math.fsum(x*x for x in a)); result = [x/mag for x in a] if mag else [0.0 for _ in a]
                else:
                    if not isinstance(b, list) or len(b) != len(a): raise ValueError("math.vector b must match vector a length.")
                    b = [float(x) for x in b]
                    if operation == "dot": result = math.fsum(x*y for x,y in zip(a,b))
                    elif operation == "distance": result = math.dist(a,b)
                    elif operation == "add": result = [x+y for x,y in zip(a,b)]
                    elif operation == "subtract": result = [x-y for x,y in zip(a,b)]
                    elif operation == "cross" and len(a)==3: result = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
                    else: raise ValueError("Unsupported math.vector operation.")
                save_as = self._safe_save_name(step.get("save_as", "vector"), "vector")
                context[f"var.{save_as}"] = json.dumps(result, ensure_ascii=False) if isinstance(result, list) else str(result)
            elif op == "math.random":
                mode = str(step.get("mode", "float") or "float").strip().casefold(); save_as = self._safe_save_name(step.get("save_as", "random"), "random")
                if mode == "int": result = random.randint(int(float(self._render(step.get("min", "0"),context))), int(float(self._render(step.get("max", "100"),context))))
                elif mode == "choice":
                    values = json.loads(self._render(step.get("values", "[]"), context));
                    if not isinstance(values,list) or not values or len(values)>10000: raise ValueError("math.random choice needs a non-empty JSON array.")
                    result = random.choice(values)
                else: result = random.uniform(float(self._render(step.get("min","0"),context)), float(self._render(step.get("max","1"),context)))
                context[f"var.{save_as}"] = json.dumps(result, ensure_ascii=False) if isinstance(result,(dict,list,bool)) or result is None else str(result)
            elif op == "system.info":
                save_as = self._safe_save_name(step.get("save_as", "system"), "system")
                info = {"platform":sys.platform,"python":sys.version.split()[0],"app_dir":str(APPDATA_DIR),"runtime_dir":str(RUNTIME_DIR),"time":datetime.now().astimezone().isoformat(timespec="seconds")}
                context[f"var.{save_as}"] = json.dumps(info, ensure_ascii=False)
            elif op == "action.run":
                target = self._render(step.get("action", ""), context).strip(); action2 = self._find_action(manifest, target)
                if action2 is None: raise ValueError(f"Unknown extension action: {target}")
                self.run(package, action2, _context=context)
            elif op in {"timer.after", "timer.every"}:
                timer_id = self._render(step.get("id", "timer"), context).strip()[:64] or "timer"; action_id = self._render(step.get("action", ""), context).strip()
                action2 = self._find_action(manifest, action_id)
                if action2 is None: raise ValueError("Timer action was not found.")
                try: ms = max(25, min(3600000, int(float(self._render(step.get("ms", "1000"), context)))))
                except Exception: raise ValueError("Timer ms must be numeric.")
                key=(ext_id,timer_id); old=self._runtime_timers.pop(key,None)
                if old is not None: old.stop(); old.deleteLater()
                timer=QTimer(self.owner); timer.setInterval(ms); timer.setSingleShot(op=="timer.after")
                timer.timeout.connect(lambda p=package,a=action2,k=key,single=(op=="timer.after"): (self.run(p,a), self._runtime_timers.pop(k,None) if single else None))
                self._runtime_timers[key]=timer; timer.start()
            elif op == "timer.cancel":
                key=(ext_id,self._render(step.get("id","timer"),context).strip()[:64]); timer=self._runtime_timers.pop(key,None)
                if timer is not None: timer.stop(); timer.deleteLater()
            elif op == "ui.widget.list":
                query=self._render(step.get("contains",""),context).casefold(); rows=[]
                for top in QApplication.topLevelWidgets():
                    for widget in [top]+top.findChildren(QWidget):
                        name=str(widget.objectName() or ""); cls=widget.metaObject().className() if widget.metaObject() else widget.__class__.__name__
                        text=str(widget.text())[:200] if hasattr(widget,"text") else ""
                        if query and query not in (name+" "+cls+" "+text).casefold(): continue
                        rows.append({"object_name":name,"class":str(cls),"text":text,"visible":widget.isVisible(),"enabled":widget.isEnabled()})
                        if len(rows)>=1000: break
                    if len(rows)>=1000: break
                save_as=self._safe_save_name(step.get("save_as","widgets"),"widgets"); context[f"var.{save_as}"]=self._bounded(json.dumps(rows,ensure_ascii=False))
            elif op == "ui.icon.list":
                query = self._render(step.get("contains", ""), context).strip().casefold()
                names = self._host_icon_names()
                if query:
                    names = [name for name in names if query in name.casefold()]
                save_as = self._safe_save_name(step.get("save_as", "icons"), "icons")
                context[f"var.{save_as}"] = self._bounded(json.dumps(names, ensure_ascii=False))
            elif op == "ui.view.open":
                view_id = self._render(step.get("id", "runtime"), context).strip()[:64] or "runtime"
                raw_spec = step.get("view", step.get("spec", {}))
                if not isinstance(raw_spec, dict):
                    raise ValueError("ui.view.open requires a view/spec object.")
                spec = dict(raw_spec)
                spec.setdefault("id", view_id)
                spec.setdefault("title", manifest.get("name", "Extension"))
                try: spec["width"] = max(320, min(1600, int(spec.get("width", 680) or 680)))
                except (TypeError, ValueError): spec["width"] = 680
                try: spec["height"] = max(240, min(1100, int(spec.get("height", 560) or 560)))
                except (TypeError, ValueError): spec["height"] = 560
                controls = spec.get("controls", [])
                if not isinstance(controls, list) or len(controls) > 160:
                    raise ValueError("ui.view.open controls must be an array of at most 160 controls.")
                key = (ext_id, "view:" + view_id)
                panel = self._panels.get(key)
                if panel is None:
                    panel = ExtensionPanelWindow(self, self.owner, package, spec)
                    panel.destroyed.connect(lambda _=None, k=key: self._panels.pop(k, None))
                    self._panels[key] = panel
                panel.show(); panel.raise_(); panel.activateWindow()
            elif op == "app.file.list":
                save_as=self._safe_save_name(step.get("save_as","app_files"),"app_files"); context[f"var.{save_as}"]=self._bounded(json.dumps(self._app_file_listing(self._render(step.get("path",""),context)),ensure_ascii=False))
            elif op == "app.file.read":
                target=self._app_read_path(self._render(step.get("path",""),context));
                if not target.is_file(): raise FileNotFoundError(str(target))
                if target.stat().st_size>EXTENSION_TEXT_LIMIT: raise ValueError("App file exceeds the 8 MiB read limit.")
                raw=target.read_bytes(); encoding=str(step.get("encoding","utf-8") or "utf-8").strip().casefold()
                value=base64.b64encode(raw).decode("ascii") if encoding=="base64" else raw.decode(encoding or "utf-8",errors="replace")
                save_as=self._safe_save_name(step.get("save_as","app_file"),"app_file"); context[f"var.{save_as}"]=self._bounded(value)
            elif op == "app.file.stat":
                target=self._app_read_path(self._render(step.get("path",""),context)); info={"exists":target.exists(),"file":target.is_file(),"directory":target.is_dir()}
                if target.exists():
                    stat=target.stat(); info.update({"size":int(stat.st_size),"modified":datetime.fromtimestamp(stat.st_mtime).astimezone().isoformat(timespec="seconds")})
                save_as=self._safe_save_name(step.get("save_as","app_stat"),"app_stat"); context[f"var.{save_as}"]=json.dumps(info,ensure_ascii=False)
            elif op in {"extension.list","extension.info"}:
                records=[]; disabled=set(load_extension_state().get("disabled",[])); target_id=self._render(step.get("id",""),context).strip().casefold()
                for rec in scan_extension_packages():
                    m=rec.get("manifest")
                    if not m: continue
                    item={"id":m["id"],"name":m["name"],"version":m["version"],"enabled":m["id"] not in disabled,"file":Path(rec["path"]).name,"permissions":m.get("permissions",[])}
                    if op=="extension.info" and m["id"]==target_id: records=item; break
                    if op=="extension.list": records.append(item)
                save_as=self._safe_save_name(step.get("save_as","extensions"),"extensions"); context[f"var.{save_as}"]=json.dumps(records,ensure_ascii=False)
            elif op == "extension.set_enabled":
                self._set_extension_enabled(self._render(step.get("id",""),context), self._as_bool(self._render(step.get("enabled","true"),context)))
            elif op == "extension.reload":
                QTimer.singleShot(0, self.owner.refresh_extensions_runtime)
            elif op == "extension.remove":
                target_id=self._render(step.get("id",""),context).strip().casefold(); target=None
                for rec in scan_extension_packages():
                    if rec.get("manifest",{}).get("id")==target_id: target=rec; break
                if target is None: raise ValueError("Unknown installed extension id.")
                Path(target["path"]).unlink(missing_ok=True)
                if self._as_bool(step.get("clear_data",False)): shutil.rmtree(EXTENSION_DATA_DIR/target_id,ignore_errors=True)
                QTimer.singleShot(0,self.owner.refresh_extensions_runtime)
            elif op in {"roblox.state","roblox.join_context","roblox.players","roblox.server","roblox.client"}:
                if op=="roblox.state": value=self._roblox_state()
                elif op=="roblox.join_context": value=current_roblox_join_context(require_running=False) or {}
                elif op=="roblox.players": value={"players":self._roblox_player_snapshot(),"source":"client_log","complete":False}
                elif op=="roblox.server": value=self._roblox_server_state()
                else:
                    player=latest_roblox_player(); value={"found":player is not None,"executable":str(player or ""),"version":str(player.parent.name if player is not None else "")}
                save_as=self._safe_save_name(step.get("save_as",op.split(".")[-1]),op.split(".")[-1]); context[f"var.{save_as}"]=self._bounded(json.dumps(value,ensure_ascii=False))
            elif op == "roblox.request":
                url=self._render(step.get("url",""),context).strip(); parsed=urllib.parse.urlsplit(url); host=str(parsed.hostname or "").casefold()
                if parsed.scheme.casefold()!="https" or not (host=="roblox.com" or host.endswith(".roblox.com")):
                    raise ValueError("roblox.request only accepts public HTTPS Roblox endpoints.")
                self._http_request(step,context)
            elif op in {"roblox.attach","roblox.reattach"}:
                action_name="reattach" if op.endswith("reattach") else "attach"
                if not self.owner._begin_api_action(action_name,None): raise RuntimeError(f"Could not start {action_name}.")
            elif op == "roblox.detach":
                QTimer.singleShot(0,self.owner.detach_from_fastflags)
            elif op == "roblox.execute":
                source=self._render(step.get("source","${editor}"),context)
                if not self.owner.execute_source_text(source,label=manifest["name"]): raise RuntimeError("Could not start execute action.")
            elif op == "proxy.state":
                value={"active":bool(self.owner.roblox_proxy_active),"suspended":bool(getattr(self.owner,"_proxy_api_suspended",False)),"mode":str(self.owner.roblox_session_mode or ""),"needed":bool(self.owner.proxy_features_needed()),"starting":bool(getattr(self.owner,"_proxy_starting",False))}
                save_as=self._safe_save_name(step.get("save_as","proxy"),"proxy"); context[f"var.{save_as}"]=json.dumps(value,ensure_ascii=False)
            elif op == "proxy.enable":
                self.owner.set_proxy_api_suspended(False); self.owner.refresh_proxy_for_active_session()
            elif op == "proxy.disable":
                self.owner.set_proxy_api_suspended(True,notify=False)
            elif op == "proxy.restart":
                QTimer.singleShot(0,self.owner.restart_roblox_into_proxy_mode)
            elif op == "sound.beep":
                try: freq=max(37,min(32767,int(float(self._render(step.get("frequency","880"),context))))); dur=max(20,min(5000,int(float(self._render(step.get("duration","120"),context)))))
                except Exception: raise ValueError("sound.beep frequency/duration must be numeric.")
                if sys.platform=="win32":
                    import winsound; winsound.Beep(freq,dur)
                else: QApplication.beep()
            elif op == "sound.play":
                self._play_extension_sound(package,ext_id,step,context)
            elif op == "sound.stop":
                if sys.platform=="win32":
                    import winsound; winsound.PlaySound(None,0)
            else:
                raise ValueError(f"Unsupported extension operation: {op}")

            
            permissions = set(manifest.get("permissions", []))
            current = self.owner.editor
            if "editor" in permissions and current is not None:
                try:
                    if self.owner.sci(current.SCI_GETLENGTH) <= EXTENSION_TEXT_LIMIT:
                        context["editor"] = current.text()
                    context["selection"] = current.selectedText() if current.hasSelectedText() else ""
                    context["tab_name"] = str(getattr(current, "_lel_name", "") or "")
                except Exception:
                    pass
            if "clipboard" in permissions:
                context["clipboard"] = QApplication.clipboard().text()
        return True



class ExtensionPanelWindow(QDialog):
    """Declarative, sandboxed extension UI surface.

    It deliberately exposes common controls and action dispatch rather than raw
    QObject/native-code access. That makes custom extension UIs composable while
    keeping the operating system outside the extension trust boundary.
    """
    def __init__(self, runtime, owner, package, spec):
        super().__init__(owner)
        self.runtime = runtime
        self.owner = owner
        self.package = package
        self.spec = spec
        self.controls = {}
        self.setWindowTitle(str(spec.get("title", package["manifest"].get("name", "Extension"))))
        self.resize(int(spec.get("width", 620)), int(spec.get("height", 520)))
        self.setMinimumSize(320, 240)
        if spec.get("resizable", True) is False:
            self.setFixedSize(self.size())
        apply_window_icon(self)
        root = blur_content_layout(self, self, self.windowTitle(), (14, 12, 14, 14), 9)
        subtitle = self._render_initial(spec.get("description", spec.get("subtitle", "")))
        if subtitle:
            sub = QLabel(subtitle); sub.setObjectName("extensionViewSubtitle"); sub.setWordWrap(True); root.addWidget(sub)
        scroll = QScrollArea(); scroll.setWidgetResizable(True); scroll.setFrameShape(QFrame.Shape.NoFrame)
        body = QWidget(); layout = QVBoxLayout(body); layout.setContentsMargins(2, 2, 2, 2); layout.setSpacing(int(spec.get("spacing", 9) or 9))
        for control in spec.get("controls", []):
            self._add_control(layout, control)
        layout.addStretch(1); scroll.setWidget(body); root.addWidget(scroll, 1)
        apply_blur_style(self)
        service = getattr(owner, "visual_wizard_service", None)
        if service is not None and getattr(service, "_claims", None):
            QTimer.singleShot(0, lambda: owner.appearance_manager._apply_widget(self))

    def _render_initial(self, value):
        manifest = self.package["manifest"]
        context = self.runtime._snapshot_context(manifest)
        context["extension.id"] = manifest["id"]; context["extension.name"] = manifest["name"]
        return self.runtime._render(value, context)

    def _control_icon(self, spec, size=18):
        return self.runtime._resolve_icon(self.package, spec.get("icon", ""), int(spec.get("icon_size", size) or size))

    def _wire_change_action(self, widget, spec):
        action_id = str(spec.get("on_change", spec.get("change_action", "")) or "").strip()
        if not action_id:
            return
        signal = None
        if isinstance(widget, (QLineEdit, QPlainTextEdit)):
            signal = widget.textChanged
        elif isinstance(widget, QCheckBox):
            signal = widget.toggled
        elif isinstance(widget, QComboBox):
            signal = widget.currentTextChanged
        elif isinstance(widget, QListWidget):
            signal = widget.currentTextChanged
        elif isinstance(widget, QSlider):
            signal = widget.valueChanged
        if signal is not None:
            signal.connect(lambda *_, aid=action_id: self._dispatch(aid, False))

    def _add_control(self, layout, spec, depth=0):
        if depth > 8 or not isinstance(spec, dict):
            return
        ctype = str(spec.get("type", "label") or "label").casefold()
        cid = str(spec.get("id", "") or "")
        if ctype in {"card", "section"}:
            widget = QFrame(); widget.setObjectName("extensionCard")
            card = QVBoxLayout(widget); card.setContentsMargins(12, 11, 12, 11); card.setSpacing(8)
            title = self._render_initial(spec.get("title", spec.get("label", "")))
            description = self._render_initial(spec.get("description", ""))
            if title:
                header = QHBoxLayout(); header.setContentsMargins(0,0,0,0); header.setSpacing(8)
                icon = self._control_icon(spec, 18)
                if not icon.isNull():
                    icon_label = QLabel(); icon_label.setPixmap(icon.pixmap(18,18)); icon_label.setFixedSize(20,20); header.addWidget(icon_label)
                title_label = QLabel(title); title_label.setObjectName("extensionSectionTitle"); header.addWidget(title_label,1); card.addLayout(header)
            if description:
                desc = QLabel(description); desc.setObjectName("extensionViewSubtitle"); desc.setWordWrap(True); card.addWidget(desc)
            children = spec.get("controls", spec.get("children", []))
            if isinstance(children, list):
                for child in children[:80]: self._add_control(card, child, depth + 1)
            layout.addWidget(widget)
        elif ctype == "row":
            widget = QWidget(); row = QHBoxLayout(widget); row.setContentsMargins(0,0,0,0); row.setSpacing(int(spec.get("spacing", 8) or 8))
            children = spec.get("controls", spec.get("children", []))
            if isinstance(children, list):
                for child in children[:32]: self._add_control(row, child, depth + 1)
            if spec.get("stretch", True): row.addStretch(1)
            layout.addWidget(widget)
        elif ctype == "heading":
            widget = QLabel(self._render_initial(spec.get("text", spec.get("title", "")))); widget.setObjectName("extensionSectionTitle"); widget.setWordWrap(True); layout.addWidget(widget)
        elif ctype == "icon":
            widget = QLabel(); icon = self._control_icon(spec, int(spec.get("size", 24) or 24)); size=max(8,min(128,int(spec.get("size",24) or 24)))
            if not icon.isNull(): widget.setPixmap(icon.pixmap(size,size)); widget.setFixedSize(size,size)
            layout.addWidget(widget)
        elif ctype == "label":
            widget = QLabel(self._render_initial(spec.get("text", ""))); widget.setWordWrap(True); layout.addWidget(widget)
        elif ctype == "markdown":
            widget = QTextBrowser(); widget.setOpenExternalLinks(True); widget.setMarkdown(self._render_initial(spec.get("text", ""))); widget.setMinimumHeight(int(spec.get("height", 90) or 90)); layout.addWidget(widget)
        elif ctype in {"input", "textarea"}:
            title = str(spec.get("label", "") or "")
            if title: layout.addWidget(QLabel(title))
            widget = QLineEdit() if ctype == "input" else QPlainTextEdit()
            value = self._render_initial(spec.get("value", spec.get("default", "")))
            if isinstance(widget, QLineEdit):
                widget.setText(value); widget.setPlaceholderText(str(spec.get("placeholder", "") or ""))
            else:
                widget.setPlainText(value); widget.setPlaceholderText(str(spec.get("placeholder", "") or "")); widget.setMinimumHeight(int(spec.get("height", 110) or 110))
            layout.addWidget(widget)
        elif ctype in {"checkbox", "switch"}:
            widget = QCheckBox(str(spec.get("label", spec.get("text", "")) or "")); widget.setChecked(self.runtime._as_bool(self._render_initial(spec.get("checked", "false")))); layout.addWidget(widget)
        elif ctype == "combo":
            host = QWidget(); row = QHBoxLayout(host); row.setContentsMargins(0,0,0,0); row.setSpacing(8)
            label = str(spec.get("label", "") or "")
            if label: row.addWidget(QLabel(label))
            widget = LelComboBox(); options = spec.get("options", []) if isinstance(spec.get("options", []), list) else []
            widget.addItems([str(item) for item in options]); current = str(spec.get("value", "") or "")
            if current: widget.setCurrentText(current)
            row.addWidget(widget, 1); layout.addWidget(host)
        elif ctype == "list":
            title = str(spec.get("label", "") or "")
            if title: layout.addWidget(QLabel(title))
            widget = QListWidget(); options = spec.get("options", []) if isinstance(spec.get("options", []), list) else []
            widget.addItems([str(item) for item in options]); widget.setMinimumHeight(int(spec.get("height", 120) or 120)); layout.addWidget(widget)
            current = str(spec.get("value", "") or "")
            matches = widget.findItems(current, Qt.MatchFlag.MatchExactly) if current else []
            if matches: widget.setCurrentItem(matches[0])
        elif ctype == "slider":
            host = QWidget(); row = QHBoxLayout(host); row.setContentsMargins(0,0,0,0); row.setSpacing(8)
            row.addWidget(QLabel(str(spec.get("label", "") or "")))
            widget = QSlider(Qt.Orientation.Horizontal)
            try: minimum = int(spec.get("min", 0)); maximum = int(spec.get("max", 100)); value = int(spec.get("value", minimum))
            except (TypeError, ValueError): minimum, maximum, value = 0, 100, 0
            widget.setRange(minimum, max(minimum, maximum)); widget.setValue(max(minimum, min(maximum, value)))
            value_label = QLabel(str(widget.value())); value_label.setMinimumWidth(40); value_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
            widget.valueChanged.connect(lambda v, lab=value_label: lab.setText(str(v)))
            row.addWidget(widget, 1); row.addWidget(value_label); layout.addWidget(host)
        elif ctype == "color":
            host = QWidget(); row = QHBoxLayout(host); row.setContentsMargins(0,0,0,0); row.setSpacing(8)
            label = str(spec.get("label", "Color") or "Color"); row.addWidget(QLabel(label), 1)
            widget = QPushButton(); widget.setFixedSize(112, 30); widget.setCursor(Qt.CursorShape.PointingHandCursor); widget.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            initial = QColor(str(spec.get("value", "#ffffff") or "#ffffff")); initial = initial if initial.isValid() else QColor("#ffffff")
            widget._lext_color = initial.name()
            def refresh_color_button(btn=widget):
                color = QColor(btn._lext_color); lum = 0.2126*color.red()+0.7152*color.green()+0.0722*color.blue(); fg = "#090909" if lum > 150 else "#ffffff"
                btn.setText(color.name().upper()); btn.setStyleSheet(f"background:{color.name()};color:{fg};border:1px solid #45454a;border-radius:6px;padding:0;")
            def choose_color(checked=False, btn=widget):
                chosen = QColorDialog.getColor(QColor(btn._lext_color), self, label)
                if chosen.isValid(): btn._lext_color = chosen.name(); refresh_color_button(btn)
            widget.clicked.connect(choose_color); refresh_color_button(); row.addWidget(widget); layout.addWidget(host)
        elif ctype in {"button", "icon_button"}:
            text = str(spec.get("text", spec.get("label", "" if ctype == "icon_button" else "Run")) or "")
            widget = QPushButton(text); widget.setCursor(Qt.CursorShape.PointingHandCursor); widget.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            icon = self._control_icon(spec, 18)
            if not icon.isNull(): widget.setIcon(icon); widget.setIconSize(QSize(int(spec.get("icon_size",18) or 18), int(spec.get("icon_size",18) or 18)))
            if ctype == "icon_button": widget.setObjectName("iconButton"); widget.setFixedSize(int(spec.get("size",34) or 34), int(spec.get("size",34) or 34))
            action_id = str(spec.get("action", "") or "")
            widget.clicked.connect(lambda checked=False, aid=action_id, close=bool(spec.get("close", False)): self._dispatch(aid, close))
            layout.addWidget(widget)
        elif ctype == "separator":
            widget = QFrame(); widget.setFrameShape(QFrame.Shape.HLine); layout.addWidget(widget)
        elif ctype == "spacer":
            widget = QWidget(); widget.setFixedHeight(max(0, min(200, int(spec.get("height", 10) or 10)))); layout.addWidget(widget)
        else:
            return
        if cid:
            self.controls[cid] = widget
        if isinstance(widget, QWidget) and spec.get("tooltip"):
            widget.setToolTip(str(spec.get("tooltip"))[:500])
        if isinstance(widget, QWidget):
            self._wire_change_action(widget, spec)

    def values_context(self):
        context = {}
        for cid, widget in self.controls.items():
            if isinstance(widget, QLineEdit): value = widget.text()
            elif isinstance(widget, QPlainTextEdit): value = widget.toPlainText()
            elif isinstance(widget, QCheckBox): value = "true" if widget.isChecked() else "false"
            elif isinstance(widget, QComboBox): value = widget.currentText()
            elif isinstance(widget, QListWidget): value = widget.currentItem().text() if widget.currentItem() is not None else ""
            elif isinstance(widget, QSlider): value = str(widget.value())
            elif isinstance(widget, QPushButton) and hasattr(widget, "_lext_color"): value = str(widget._lext_color)
            elif isinstance(widget, QLabel): value = widget.text()
            else: continue
            context[f"ui.{cid}"] = value
        return context

    def _dispatch(self, action_id, close=False):
        action = self.runtime._find_action(self.package["manifest"], action_id)
        if action is None:
            return
        try:
            self.runtime.run(self.package, action, seed_context=self.values_context())
            if close: self.close()
        except Exception as exc:
            self.owner.log(f"Extension {self.package['manifest'].get('name', 'No title found')} failed: {exc}", "warning")

    def set_control_property(self, control_id, prop, value):
        widget = self.controls.get(str(control_id or ""))
        if widget is None:
            raise ValueError("Panel control was not found.")
        prop = str(prop or "text").strip().casefold()
        if isinstance(widget, QPlainTextEdit) and prop in {"text", "value"}: widget.setPlainText(str(value)); return
        if isinstance(widget, QTextBrowser) and prop in {"markdown", "text", "value"}:
            widget.setMarkdown(str(value)) if prop == "markdown" else widget.setPlainText(str(value)); return
        if isinstance(widget, QListWidget) and prop in {"text", "value"}:
            matches = widget.findItems(str(value), Qt.MatchFlag.MatchExactly)
            if matches: widget.setCurrentItem(matches[0])
            return
        if isinstance(widget, QPushButton) and hasattr(widget, "_lext_color") and prop in {"text", "value", "color"}:
            color = QColor(str(value))
            if color.isValid():
                widget._lext_color = color.name(); lum=0.2126*color.red()+0.7152*color.green()+0.0722*color.blue(); fg="#090909" if lum>150 else "#ffffff"
                widget.setText(color.name().upper()); widget.setStyleSheet(f"background:{color.name()};color:{fg};border:1px solid #45454a;border-radius:6px;padding:0;")
            return
        self.runtime._widget_write(widget, prop, value)



EXTENSION_TEMPLATES = (
    {
        "id": "lelsploit.template.recoveryvault",
        "name": "Recovery Vault",
        "description": (
            "A **four-generation recovery system** for the active Luau tab. It snapshots your work every 20 seconds "
            "inside the extension sandbox, records the last tab/hash/time, and gives you shortcuts to restore the newest "
            "snapshot or open the previous generation in a separate tab.\n\n"
            "**Shortcuts:** `Ctrl+Alt+R` opens the previous snapshot, `Ctrl+Alt+Shift+R` safely restores the latest one."
        ),
        "permissions": ["editor", "files", "storage", "ui"],
        "startup": [],
        "interval": {"ms": 20000, "steps": [
            {"op": "text.transform", "source": "${tab_name}\n${editor}", "method": "sha256", "save_as": "snapshot_hash"},
            {"op": "system.now", "save_as": "snapshot_time"},
            {"op": "file.read", "path": "snapshots/3.luau", "save_as": "snap3",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.write", "path": "snapshots/4.luau", "text": "${var.snap3}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.read", "path": "snapshots/2.luau", "save_as": "snap2",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.write", "path": "snapshots/3.luau", "text": "${var.snap2}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.read", "path": "snapshots/1.luau", "save_as": "snap1",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.write", "path": "snapshots/2.luau", "text": "${var.snap1}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "file.write", "path": "snapshots/1.luau", "text": "${editor}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "storage.set", "key": "last_tab", "value": "${tab_name}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "storage.set", "key": "last_snapshot", "value": "${var.snapshot_time}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}},
            {"op": "storage.set", "key": "last_hash", "value": "${var.snapshot_hash}",
             "when": {"left": "${var.snapshot_hash}", "op": "not_equals", "right": "${storage.last_hash}"}}
        ]},
        "actions": [
            {
                "id": "open_previous",
                "title": "Open previous snapshot",
                "steps": [
                    {"op": "file.read", "path": "snapshots/2.luau", "save_as": "previous"},
                    {"op": "editor.new_tab", "name": "Recovery - previous.luau", "text": "${var.previous}",
                     "when": {"value": "${var.previous}", "op": "not_empty"}},
                    {"op": "message", "text": "No previous recovery snapshot exists yet.",
                     "when": {"value": "${var.previous}", "op": "empty"}}
                ]
            },
            {
                "id": "restore_latest",
                "title": "Restore latest snapshot",
                "steps": [
                    {"op": "file.read", "path": "snapshots/1.luau", "save_as": "latest"},
                    {"op": "message", "text": "No recovery snapshot exists yet.",
                     "when": {"value": "${var.latest}", "op": "empty"}},
                    {"op": "dialog.confirm", "title": "Restore latest snapshot",
                     "text": "Replace the current editor contents with the newest Recovery Vault snapshot?",
                     "save_as": "restore", "when": {"value": "${var.latest}", "op": "not_empty"}},
                    {"op": "editor.set", "text": "${var.latest}",
                     "when": {"value": "${var.restore}", "op": "truthy"}}
                ]
            }
        ],
        "shortcuts": [
            {"keys": "Ctrl+Alt+R", "action": "open_previous"},
            {"keys": "Ctrl+Alt+Shift+R", "action": "restore_latest"}
        ]
    },
    {
        "id": "lelsploit.template.luaupowertools",
        "name": "Luau Editing Power Tools",
        "description": (
            "A focused set of editor operations for Luau: **clean the whole script**, clean only the current selection, "
            "wrap selected code in `task.spawn`, wrap it in an error-reporting `pcall`, or turn it into a block comment. "
            "The cleaner normalizes newlines, strips trailing whitespace, and collapses excessive blank lines without "
            "trying to rewrite your code semantics.\n\n"
            "**Shortcuts:** `Ctrl+Alt+T` clean document, `Ctrl+Alt+Shift+T` clean selection, `Ctrl+Alt+S` task.spawn, "
            "`Ctrl+Alt+P` pcall, `Ctrl+Alt+/` block comment."
        ),
        "permissions": ["editor", "ui"],
        "actions": [
            {
                "id": "clean_document", "title": "Clean current document", "steps": [
                    {"op": "text.transform", "source": "${editor}", "method": "normalize_newlines", "save_as": "clean1"},
                    {"op": "text.transform", "source": "${var.clean1}", "method": "lines_trim", "save_as": "clean2"},
                    {"op": "text.transform", "source": "${var.clean2}", "method": "regex_replace",
                     "pattern": "\n{3,}", "replace": "\n\n", "save_as": "clean3"},
                    {"op": "editor.set", "text": "${var.clean3}"},
                    {"op": "console.log", "level": "success", "text": "Luau Editing Power Tools cleaned ${tab_name}."}
                ]
            },
            {
                "id": "clean_selection", "title": "Clean selected code", "steps": [
                    {"op": "text.transform", "source": "${selection}", "method": "normalize_newlines", "save_as": "clean1",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "text.transform", "source": "${var.clean1}", "method": "lines_trim", "save_as": "clean2",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "text.transform", "source": "${var.clean2}", "method": "regex_replace",
                     "pattern": "\n{3,}", "replace": "\n\n", "save_as": "clean3",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "selection.replace", "text": "${var.clean3}",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "notify", "text": "Select some code first.", "duration": 2200,
                     "when": {"value": "${selection}", "op": "empty"}}
                ]
            },
            {
                "id": "wrap_spawn", "title": "Wrap selection in task.spawn", "steps": [
                    {"op": "selection.replace", "text": "task.spawn(function()\n${selection}\nend)",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "notify", "text": "Select code to wrap first.", "duration": 2200,
                     "when": {"value": "${selection}", "op": "empty"}}
                ]
            },
            {
                "id": "wrap_pcall", "title": "Wrap selection in pcall", "steps": [
                    {"op": "selection.replace",
                     "text": "local ok, err = pcall(function()\n${selection}\nend)\nif not ok then\n    warn(err)\nend",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "notify", "text": "Select code to wrap first.", "duration": 2200,
                     "when": {"value": "${selection}", "op": "empty"}}
                ]
            },
            {
                "id": "block_comment", "title": "Block-comment selection", "steps": [
                    {"op": "selection.replace", "text": "--[[\n${selection}\n]]",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "notify", "text": "Select code to comment first.", "duration": 2200,
                     "when": {"value": "${selection}", "op": "empty"}}
                ]
            }
        ],
        "shortcuts": [
            {"keys": "Ctrl+Alt+T", "action": "clean_document"},
            {"keys": "Ctrl+Alt+Shift+T", "action": "clean_selection"},
            {"keys": "Ctrl+Alt+S", "action": "wrap_spawn"},
            {"keys": "Ctrl+Alt+P", "action": "wrap_pcall"},
            {"keys": "Ctrl+Alt+/", "action": "block_comment"}
        ]
    },
    {
        "id": "lelsploit.template.snippetvault",
        "name": "Snippet Vault",
        "description": (
            "A persistent **code-snippet notebook** that stays inside its extension sandbox. Save the current selection with "
            "a label and timestamp, instantly insert the most recently saved snippet at the cursor, or open the complete "
            "Markdown vault in a new tab. Nothing is uploaded anywhere.\n\n"
            "**Shortcuts:** `Ctrl+Alt+K` save selection, `Ctrl+Alt+J` insert latest, `Ctrl+Alt+Shift+K` open vault."
        ),
        "permissions": ["editor", "files", "storage", "ui"],
        "actions": [
            {
                "id": "save_snippet", "title": "Save selected snippet",
                "steps": [
                    {"op": "message", "text": "Select the code you want to save first.",
                     "when": {"value": "${selection}", "op": "empty"}},
                    {"op": "dialog.input", "title": "Snippet Vault", "prompt": "Name this snippet:",
                     "default": "Useful snippet", "save_as": "label",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "system.now", "save_as": "saved_at",
                     "when": {"value": "${var.label}", "op": "not_empty"}},
                    {"op": "file.append", "path": "snippets.md",
                     "text": "## ${var.label} — ${var.saved_at}\n\n```luau\n${selection}\n```\n\n",
                     "when": {"value": "${var.label}", "op": "not_empty"}},
                    {"op": "storage.set", "key": "latest", "value": "${selection}",
                     "when": {"value": "${var.label}", "op": "not_empty"}},
                    {"op": "storage.set", "key": "latest_label", "value": "${var.label}",
                     "when": {"value": "${var.label}", "op": "not_empty"}},
                    {"op": "notify", "text": "Saved '${var.label}' to Snippet Vault.", "duration": 2400,
                     "when": {"value": "${var.label}", "op": "not_empty"}}
                ]
            },
            {
                "id": "insert_latest", "title": "Insert latest snippet", "steps": [
                    {"op": "editor.insert", "text": "${storage.latest}",
                     "when": {"value": "${storage.latest}", "op": "not_empty"}},
                    {"op": "message", "text": "Snippet Vault has no saved snippets yet.",
                     "when": {"value": "${storage.latest}", "op": "empty"}}
                ]
            },
            {
                "id": "open_vault", "title": "Open snippet vault", "steps": [
                    {"op": "file.read", "path": "snippets.md", "save_as": "vault"},
                    {"op": "editor.new_tab", "name": "Snippet Vault.md", "text": "${var.vault}",
                     "when": {"value": "${var.vault}", "op": "not_empty"}},
                    {"op": "message", "text": "Snippet Vault is empty. Save a selection first.",
                     "when": {"value": "${var.vault}", "op": "empty"}}
                ]
            }
        ],
        "shortcuts": [
            {"keys": "Ctrl+Alt+K", "action": "save_snippet"},
            {"keys": "Ctrl+Alt+J", "action": "insert_latest"},
            {"keys": "Ctrl+Alt+Shift+K", "action": "open_vault"}
        ]
    },
    {
        "id": "lelsploit.template.filebridge",
        "name": "Safe File Bridge",
        "description": (
            "Adds deliberate, **user-approved import/export** without giving the extension unrestricted filesystem access. "
            "Open a text/Lua/Luau/JSON/Markdown file into a fresh tab, export the whole current tab, or export only the "
            "current selection. Every external path is chosen through a normal file dialog.\n\n"
            "**Shortcuts:** `Ctrl+Alt+O` import, `Ctrl+Alt+E` export tab, `Ctrl+Alt+Shift+E` export selection."
        ),
        "permissions": ["editor", "picker", "ui"],
        "actions": [
            {
                "id": "import_file", "title": "Import file into new tab", "steps": [
                    {"op": "file.pick_read", "title": "Import into LelSploit",
                     "filter": "Code and text (*.lua *.luau *.txt *.json *.md);;All files (*)", "save_as": "imported"},
                    {"op": "editor.new_tab", "name": "Imported file", "text": "${var.imported}",
                     "when": {"value": "${var.imported.path}", "op": "not_empty"}},
                    {"op": "notify", "text": "Imported ${var.imported.path}", "duration": 2600,
                     "when": {"value": "${var.imported.path}", "op": "not_empty"}}
                ]
            },
            {
                "id": "export_tab", "title": "Export current tab", "steps": [
                    {"op": "file.pick_write", "title": "Export current tab", "name": "script.luau",
                     "filter": "Luau (*.luau);;Lua (*.lua);;Text (*.txt);;All files (*)", "text": "${editor}", "save_as": "exported"},
                    {"op": "notify", "text": "Exported to ${var.exported.path}", "duration": 2600,
                     "when": {"value": "${var.exported.path}", "op": "not_empty"}}
                ]
            },
            {
                "id": "export_selection", "title": "Export selected code", "steps": [
                    {"op": "file.pick_write", "title": "Export selected code", "name": "selection.luau",
                     "filter": "Luau (*.luau);;Lua (*.lua);;Text (*.txt);;All files (*)", "text": "${selection}", "save_as": "exported_selection",
                     "when": {"value": "${selection}", "op": "not_empty"}},
                    {"op": "message", "text": "Select the code you want to export first.",
                     "when": {"value": "${selection}", "op": "empty"}},
                    {"op": "notify", "text": "Exported selection to ${var.exported_selection.path}", "duration": 2600,
                     "when": {"value": "${var.exported_selection.path}", "op": "not_empty"}}
                ]
            }
        ],
        "shortcuts": [
            {"keys": "Ctrl+Alt+O", "action": "import_file"},
            {"keys": "Ctrl+Alt+E", "action": "export_tab"},
            {"keys": "Ctrl+Alt+Shift+E", "action": "export_selection"}
        ]
    },
    {
        "id": "lelsploit.template.httplab",
        "name": "HTTP Response Lab",
        "description": (
            "A small public-web API workbench built into the editor. Fetch a URL as text, fetch and pretty-print a JSON "
            "response, or POST a JSON body and open the response in a new tab. Requests keep LelSploit's extension safety "
            "rules: localhost/private-network targets are blocked, redirects are revalidated, responses are size-limited, "
            "and timeouts are capped.\n\n"
            "**Shortcuts:** `Ctrl+Alt+H` GET text, `Ctrl+Alt+Shift+H` GET + pretty JSON, `Ctrl+Alt+Shift+P` POST JSON."
        ),
        "permissions": ["editor", "network", "ui"],
        "actions": [
            {
                "id": "get_text", "title": "GET public URL",
                "inputs": [{"id": "url", "title": "HTTP Response Lab", "prompt": "Public HTTP/HTTPS URL:", "default": "https://"}],
                "steps": [
                    {"op": "http.request", "url": "${input.url}", "method": "GET", "timeout": 12, "save_as": "response"},
                    {"op": "editor.new_tab", "name": "HTTP ${var.response.status}.txt", "text": "${var.response}"},
                    {"op": "console.log", "level": "success",
                     "text": "HTTP ${var.response.status} — ${var.response.url}"}
                ]
            },
            {
                "id": "get_json", "title": "GET and pretty-print JSON",
                "inputs": [{"id": "url", "title": "HTTP Response Lab", "prompt": "Public JSON endpoint:", "default": "https://"}],
                "steps": [
                    {"op": "http.request", "url": "${input.url}", "method": "GET", "timeout": 12, "save_as": "response"},
                    {"op": "text.transform", "source": "${var.response}", "method": "json_pretty", "save_as": "pretty"},
                    {"op": "editor.new_tab", "name": "HTTP ${var.response.status}.json", "text": "${var.pretty}"},
                    {"op": "console.log", "level": "success",
                     "text": "Fetched and formatted JSON from ${var.response.url}"}
                ]
            },
            {
                "id": "post_json", "title": "POST JSON",
                "inputs": [
                    {"id": "url", "title": "HTTP Response Lab", "prompt": "Public HTTP/HTTPS URL:", "default": "https://"},
                    {"id": "body", "title": "HTTP Response Lab", "prompt": "JSON body:", "default": "{}"}
                ],
                "steps": [
                    {"op": "text.transform", "source": "${input.body}", "method": "json_compact", "save_as": "body"},
                    {"op": "http.request", "url": "${input.url}", "method": "POST", "timeout": 12,
                     "headers": {"Content-Type": "application/json", "Accept": "application/json, text/plain, */*"},
                     "body": "${var.body}", "save_as": "response"},
                    {"op": "editor.new_tab", "name": "POST ${var.response.status}.txt", "text": "${var.response}"},
                    {"op": "console.log", "level": "success",
                     "text": "POST ${var.response.status} — ${var.response.url}"}
                ]
            }
        ],
        "shortcuts": [
            {"keys": "Ctrl+Alt+H", "action": "get_text"},
            {"keys": "Ctrl+Alt+Shift+H", "action": "get_json"},
            {"keys": "Ctrl+Alt+Shift+P", "action": "post_json"}
        ]
    },
)


def extension_template_icon():
    for path in (IMAGES_DIR / "template.png", ICON_DIR / "template.png"):
        if path.is_file():
            icon = QIcon(str(path))
            if not icon.isNull():
                return icon
    icon = app_icon("extensions")
    return icon if not icon.isNull() else lelsploit_icon()


def write_extension_template(template):
    manifest = {
        "format": EXTENSION_FORMAT_VERSION,
        "id": template["id"],
        "name": template["name"],
        "version": "1.0",
        "description": template["description"],
        "permissions": list(template.get("permissions", [])),
        "startup": list(template.get("startup", [])),
        "actions": list(template.get("actions", [])),
        "shortcuts": list(template.get("shortcuts", [])),
    }
    if template.get("interval"):
        manifest["interval"] = template["interval"]
    icon_path = IMAGES_DIR / "template.png"
    if not icon_path.is_file():
        icon_path = ICON_DIR / "template.png"
    if icon_path.is_file():
        manifest["icon"] = "template.png"
    EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
    target = EXTENSIONS_DIR / f"{template['id']}.lext"
    temp = target.with_suffix(target.suffix + ".tmp")
    with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False))
        if icon_path.is_file():
            archive.writestr("template.png", icon_path.read_bytes())
    os.replace(temp, target)
    return target


UI_CONFIG_PATH = APPDATA_DIR / "ui_config.json"
SYNTAX_COLORS_PATH = APPDATA_DIR / "syntax_colors.json"

UI_CONFIG_DEFAULT = {
    "window": {
        "background": "#08090a", "panel": "#0b0c0d", "surface": "#101214", "surface_alt": "#16191b",
        "hover": "#1c2022", "border": "#272b2e", "text": "#e8e9ea", "muted": "#92989b",
        "accent": "#9cab91", "selection": "#252a2d",
    },
    "editor": {
        "background": "#121416", "text": "#f1f2f2", "caret": "#ffffff", "selection": "#292e31",
        "corner_radius": 6, "inner_padding": 3,
    },
    "tabs": {
        "tab_background": "#131517", "tab_hover": "#191c1e", "tab_selected": "#1e2225",
        "text": "#ffffff", "corner_radius": 3,
    },
    "buttons": {
        "background": "#101214", "hover": "#1c2022", "border": "#272b2e", "corner_radius": 5,
        "text_width": 116, "text_height": 34, "icon_size": 34, "spacing": 5,
    },
    "title": {"color": "#e3e5e6", "font_size": 14, "font_weight": 800, "font_style": "oblique"},
}
SYNTAX_COLORS_DEFAULT = {
    "syntax_comment": "#7f936f", "syntax_keyword": "#86a8e7", "syntax_string": "#a8c77a",
    "syntax_number": "#c9a56f", "syntax_operator": "#d7dadd", "syntax_builtin": "#7db0d5",
    "syntax_function": "#7daee0", "syntax_type": "#b5a0d2",
}
def _seed_appdata_config(path, bundled_name, default):
    path = Path(path)
    if path.is_file():
        return
    bundled = RUNTIME_DIR / bundled_name
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        if bundled.is_file():
            shutil.copy2(bundled, path)
        else:
            write_json_object(path, default)
    except OSError:
        pass


_seed_appdata_config(UI_CONFIG_PATH, "ui_config.json", UI_CONFIG_DEFAULT)
_seed_appdata_config(SYNTAX_COLORS_PATH, "syntax_colors.json", SYNTAX_COLORS_DEFAULT)
UI_CONFIG = read_json_object(UI_CONFIG_PATH, UI_CONFIG_DEFAULT)
SYNTAX_COLORS_CONFIG = read_json_object(SYNTAX_COLORS_PATH, SYNTAX_COLORS_DEFAULT)

def ui_config(section, key, default=None):
    values = UI_CONFIG.get(section, {})
    fallback = UI_CONFIG_DEFAULT.get(section, {})
    if not isinstance(values, dict):
        values = {}
    return values.get(key, fallback.get(key, default))

def syntax_config(key, default=None):
    value = SYNTAX_COLORS_CONFIG.get(key, SYNTAX_COLORS_DEFAULT.get(key, default))
    color = QColor(str(value))
    return color.name() if color.isValid() else str(default or "#ffffff")

VISUAL_THEME_PATH = APPDATA_DIR / "visual_theme.json"
VISUAL_ICON_THEME = {"hue": 0, "saturation": 100, "brightness": 100}
VISUAL_ICON_CACHE = {}

VISUAL_THEME_DEFAULT = {
    "window_bg": ui_config("window", "background", "#08090a"),
    "panel_bg": ui_config("window", "panel", "#0b0c0d"),
    "surface": ui_config("window", "surface", "#101214"),
    "surface_alt": ui_config("window", "surface_alt", "#16191b"),
    "hover": ui_config("window", "hover", "#1c2022"),
    "border": ui_config("window", "border", "#272b2e"),
    "text": ui_config("window", "text", "#e8e9ea"),
    "muted": ui_config("window", "muted", "#92989b"),
    "accent": ui_config("window", "accent", "#9cab91"),
    "selection": ui_config("window", "selection", "#252a2d"),
    "danger": "#b84a4a",
    "editor_bg": ui_config("editor", "background", "#121416"),
    "editor_text": ui_config("editor", "text", "#f1f2f2"),
    "caret": ui_config("editor", "caret", "#ffffff"),
    "editor_selection": ui_config("editor", "selection", "#292e31"),
    "syntax_comment": syntax_config("syntax_comment", "#7f936f"),
    "syntax_keyword": syntax_config("syntax_keyword", "#86a8e7"),
    "syntax_string": syntax_config("syntax_string", "#a8c77a"),
    "syntax_number": syntax_config("syntax_number", "#c9a56f"),
    "syntax_operator": syntax_config("syntax_operator", "#d7dadd"),
    "syntax_builtin": syntax_config("syntax_builtin", "#7db0d5"),
    "syntax_function": syntax_config("syntax_function", "#7daee0"),
    "syntax_type": syntax_config("syntax_type", "#b5a0d2"),
    "icon_hue": 0, "icon_saturation": 100, "icon_brightness": 100,
    "font_size": 11, "editor_font_size": 11,
    "corner_radius": int(ui_config("editor", "corner_radius", 6)), "border_width": 1,
    "custom_qss": "",
}

VISUAL_THEME_PRESETS = {
    "LelSploit Default": {},
    "Deep Ocean": {
        "window_bg": "#05080d", "panel_bg": "#080d14", "surface": "#0c131d", "surface_alt": "#101a27",
        "hover": "#162333", "border": "#203247", "text": "#d9e7f5", "muted": "#7f98ad", "accent": "#5db9ff",
        "selection": "#17324b", "editor_bg": "#04080d", "editor_text": "#e7f2ff",
        "editor_selection": "#17324b", "syntax_comment": "#63947d", "syntax_keyword": "#79a8ff", "syntax_string": "#d4b978",
        "syntax_number": "#ff9f7a", "syntax_builtin": "#64d9d0", "syntax_function": "#5fc8ff", "syntax_type": "#b89cff",
        "icon_hue": 26,
    },
    "Amethyst": {
        "window_bg": "#09070d", "panel_bg": "#0d0a12", "surface": "#15101c", "surface_alt": "#1b1425",
        "hover": "#251b32", "border": "#382949", "text": "#eee7f7", "muted": "#9c8baa", "accent": "#c68cff",
        "selection": "#37244c", "editor_bg": "#08060b", "editor_text": "#f3ebff",
        "editor_selection": "#37244c", "syntax_comment": "#7d8f77", "syntax_keyword": "#df83ff", "syntax_string": "#e5bf7a",
        "syntax_number": "#ff9b8a", "syntax_builtin": "#73d6ca", "syntax_function": "#8fb6ff", "syntax_type": "#d8a3ff",
        "icon_hue": 102,
    },
    "Ember": {
        "window_bg": "#0c0705", "panel_bg": "#120b08", "surface": "#1a100c", "surface_alt": "#22150f",
        "hover": "#302016", "border": "#493021", "text": "#f4e7dc", "muted": "#aa8d79", "accent": "#ff9a5b",
        "selection": "#4a2818", "editor_bg": "#090604", "editor_text": "#fff0e5",
        "editor_selection": "#4a2818", "syntax_comment": "#708b68", "syntax_keyword": "#ff7d79", "syntax_string": "#f2c078",
        "syntax_number": "#ffa05c", "syntax_builtin": "#6ed1b8", "syntax_function": "#7eb8ff", "syntax_type": "#cf9cff",
        "icon_hue": -24,
    },
    "Graphite": {
        "window_bg": "#070809", "panel_bg": "#0a0c0e", "surface": "#111417", "surface_alt": "#171b1f",
        "hover": "#20262b", "border": "#2d353c", "text": "#e4e8eb", "muted": "#8c969e", "accent": "#8fd3ff",
        "selection": "#253441", "editor_bg": "#050607", "editor_text": "#eef2f4",
        "editor_selection": "#253441", "icon_saturation": 70,
    },
}


def palette_icon(size=20):
    pixmap = QPixmap(size, size)
    pixmap.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    painter.setPen(Qt.PenStyle.NoPen)
    painter.setBrush(QColor("#ffffff"))
    path = QPainterPath()
    path.moveTo(size * 0.51, size * 0.10)
    path.cubicTo(size * 0.22, size * 0.08, size * 0.08, size * 0.30, size * 0.09, size * 0.51)
    path.cubicTo(size * 0.10, size * 0.78, size * 0.32, size * 0.91, size * 0.52, size * 0.89)
    path.cubicTo(size * 0.63, size * 0.88, size * 0.65, size * 0.80, size * 0.61, size * 0.73)
    path.cubicTo(size * 0.56, size * 0.64, size * 0.62, size * 0.56, size * 0.72, size * 0.57)
    path.cubicTo(size * 0.87, size * 0.58, size * 0.94, size * 0.47, size * 0.89, size * 0.34)
    path.cubicTo(size * 0.83, size * 0.19, size * 0.68, size * 0.11, size * 0.51, size * 0.10)
    path.closeSubpath()
    painter.drawPath(path)
    painter.setBrush(QColor("#050505"))
    for x, y, r in ((0.31, 0.32, 0.065), (0.49, 0.24, 0.06), (0.67, 0.31, 0.06), (0.25, 0.52, 0.06)):
        painter.drawEllipse(QPoint(int(size*x), int(size*y)), max(1, int(size*r)), max(1, int(size*r)))
    painter.end()
    return QIcon(pixmap)


class AppearanceManager(QObject):
    def __init__(self, owner):
        super().__init__(owner)
        self.owner = owner
        self.theme = dict(VISUAL_THEME_DEFAULT)
        self._revision = 0
        saved = read_json_object(VISUAL_THEME_PATH, {})
        if isinstance(saved, dict):
            for key, default in VISUAL_THEME_DEFAULT.items():
                value = saved.get(key, default)
                if isinstance(default, str) and key != "custom_qss":
                    if QColor(str(value)).isValid(): self.theme[key] = QColor(str(value)).name()
                elif key == "custom_qss":
                    self.theme[key] = str(value or "")[:100000]
                elif isinstance(default, int):
                    try: self.theme[key] = int(value)
                    except (TypeError, ValueError): pass
        
        
        
        self.active = False
        self._set_default_live_icons()

    @staticmethod
    def _set_default_live_icons():
        global VISUAL_ICON_THEME, VISUAL_ICON_CACHE
        VISUAL_ICON_THEME = {"hue": 0, "saturation": 100, "brightness": 100}
        VISUAL_ICON_CACHE.clear()

    def activate(self):
        if not self.active:
            self.active = True
        self._revision += 1
        self._sync_icon_settings()
        self.apply_all()

    def deactivate(self):
        if not self.active:
            self._set_default_live_icons()
            self.owner.refresh_visual_icons()
            return
        self.active = False
        self._revision += 1
        self._set_default_live_icons()
        app = QApplication.instance()
        if app is not None:
            for widget in app.topLevelWidgets():
                if not isinstance(widget, QWidget):
                    continue
                base = widget.property("vwBaseStyle")
                if base is not None:
                    try:
                        widget.setStyleSheet(str(base or ""))
                        widget.setProperty("vwThemeRevision", None)
                    except RuntimeError:
                        pass
        self._restore_editor_defaults()
        self.owner.refresh_visual_icons()

    def _restore_editor_defaults(self):
        if not hasattr(self.owner, "editor_tabs"):
            return
        for index in range(self.owner.editor_tabs.count()):
            editor = self.owner.tab_editor(index)
            if not isinstance(editor, CodeEditor):
                continue
            lexer = getattr(editor, "_lel_lexer", None)
            if lexer is None:
                continue
            editor._lel_syntax_styles = {
                syntax_config("syntax_comment", "#7f936f"): (lexer.Comment, lexer.LineComment),
                syntax_config("syntax_keyword", "#86a8e7"): (lexer.Keyword,),
                syntax_config("syntax_string", "#a8c77a"): (lexer.String, lexer.Character, lexer.LiteralString, lexer.UnclosedString),
                syntax_config("syntax_number", "#c9a56f"): (lexer.Number,),
                syntax_config("syntax_operator", "#d7dadd"): (lexer.Operator,),
                syntax_config("syntax_builtin", "#7db0d5"): (lexer.BasicFunctions, lexer.KeywordSet5, lexer.KeywordSet6, lexer.KeywordSet7),
                syntax_config("syntax_function", "#7daee0"): (lexer.StringTableMathsFunctions, lexer.CoroutinesIOSystemFacilities),
                syntax_config("syntax_type", "#b5a0d2"): (lexer.KeywordSet8,),
            }
            editor_bg = ui_config("editor", "background", "#121416")
            editor_text = ui_config("editor", "text", "#f1f2f2")
            editor.setColor(QColor(editor_text))
            editor.setPaper(QColor(editor_bg))
            editor.setStyleSheet(f"QsciScintilla {{ background: {editor_bg}; border: none; border-radius: 0px; }}")
            editor.setCaretForegroundColor(QColor(ui_config("editor", "caret", "#ffffff")))
            editor.setSelectionBackgroundColor(QColor(ui_config("editor", "selection", "#292e31")))
            editor.setSelectionForegroundColor(QColor(editor_text))
            font = editor.font()
            font.setPointSize(11)
            editor.setFont(font)
        if hasattr(self.owner, "update_colors"):
            self.owner.update_colors()

    def color(self, key, default):
        value = str(self.theme.get(key, default) or default)
        return value if QColor(value).isValid() else default

    def value(self, key, default=None): return self.theme.get(key, default)

    def set_value(self, key, value, save=True):
        if key not in VISUAL_THEME_DEFAULT: return
        default = VISUAL_THEME_DEFAULT[key]
        if isinstance(default, str) and key != "custom_qss":
            color = QColor(str(value))
            if not color.isValid(): return
            value = color.name()
        elif key == "custom_qss": value = str(value or "")[:100000]
        else:
            try: value = int(value)
            except (TypeError, ValueError): return
        self.theme[key] = value
        self.apply(save=save)

    def apply_preset(self, name):
        preset = VISUAL_THEME_PRESETS.get(str(name), {})
        custom_qss = self.theme.get("custom_qss", "")
        self.theme = dict(VISUAL_THEME_DEFAULT); self.theme.update(preset); self.theme["custom_qss"] = custom_qss
        self.apply(save=True)

    def reset(self): self.theme = dict(VISUAL_THEME_DEFAULT); self.apply(save=True)

    def _sync_icon_settings(self):
        global VISUAL_ICON_THEME, VISUAL_ICON_CACHE
        VISUAL_ICON_THEME = {
            "hue": max(-180, min(180, int(self.theme.get("icon_hue", 0) or 0))),
            "saturation": max(0, min(200, int(self.theme.get("icon_saturation", 100) or 100))),
            "brightness": max(40, min(180, int(self.theme.get("icon_brightness", 100) or 100))),
        }
        VISUAL_ICON_CACHE.clear()

    def _qss(self):
        t = self.theme
        radius = max(0, min(18, int(t.get("corner_radius", 7) or 7)))
        border_w = max(0, min(3, int(t.get("border_width", 1) or 1)))
        font_size = max(8, min(18, int(t.get("font_size", 11) or 11)))
        small_radius = max(0, radius - 2)
        qss = f'''\n/* Visual Wizard live override - transparent child containers */
QMainWindow, QDialog {{ background: {t['window_bg']}; color: {t['text']}; }}
QWidget {{ color: {t['text']}; font-size: {font_size}px; }}
QWidget#blurWindowBody {{ background: {t['panel_bg']}; }}
QFrame#blurTitleBar {{ background: {t['surface']}; border: none; border-bottom: {border_w}px solid {t['border']}; }}
QLabel, QCheckBox {{ background: transparent; color: {t['text']}; }}
QLabel#settingsHint, QLabel#extensionMeta {{ color: {t['muted']}; }}
QFrame#visualColorRow {{ background: {t['surface']}; border: {border_w}px solid {t['border']}; border-radius: {radius}px; }}
QFrame#visualColorRow:hover {{ background: {t['surface_alt']}; border-color: {t['hover']}; }}
QPushButton {{ background: {t['surface']}; color: {t['text']}; border: {border_w}px solid {t['border']}; border-radius: {radius}px; padding: 7px 12px; }}
QPushButton:hover {{ background: {t['hover']}; border-color: {t['accent']}; }}
QPushButton:pressed {{ background: {t['panel_bg']}; }}
QPushButton:checked, QPushButton:focus {{ background: {t['surface_alt']}; border-color: {t['accent']}; }}
QPushButton:disabled {{ color: {t['muted']}; background: {t['panel_bg']}; border-color: {t['border']}; }}
QPushButton#blurWindowControl, QPushButton#blurPinButton, QPushButton#blurCloseButton {{ background: transparent; border-color: transparent; padding: 0; }}
QLineEdit, QPlainTextEdit, QTextBrowser, QComboBox, QSpinBox, QListWidget, QTableWidget {{ background: {t['surface_alt']}; color: {t['text']}; border: {border_w}px solid {t['border']}; border-radius: {radius}px; selection-background-color: {t['selection']}; selection-color: {t['text']}; }}
QLineEdit:focus, QPlainTextEdit:focus, QTextBrowser:focus, QComboBox:focus, QSpinBox:focus {{ border-color: {t['accent']}; }}
QComboBox::drop-down, QSpinBox::up-button, QSpinBox::down-button {{ background: transparent; border: none; }}
QComboBox QAbstractItemView {{ background: {t['surface_alt']}; color: {t['text']}; border: {border_w}px solid {t['border']}; selection-background-color: {t['selection']}; outline: none; }}
QMenu {{ background: {t['surface_alt']}; color: {t['text']}; border: {border_w}px solid {t['border']}; border-radius: {radius}px; padding: 5px; }}
QMenu::item {{ padding: 6px 18px 6px 9px; border-radius: {small_radius}px; }}
QMenu::item:selected {{ background: {t['selection']}; color: {t['text']}; }}
QMenu::separator {{ background: {t['border']}; height: 1px; margin: 5px; }}
QTabWidget {{ background: transparent; }}
QTabWidget::pane {{ border: {border_w}px solid {t['border']}; border-radius: {radius}px; background: {t['panel_bg']}; }}
QTabWidget#visualWizardTabs::pane {{ border: 0px; background: transparent; margin: 0px; padding: 0px; }}
QTabWidget#visualWizardTabs QTabBar {{ border: none; background: transparent; }}
QTabWidget#visualWizardTabs QTabBar::tab {{ margin-right: 4px; border-bottom: 0px; }}
QTabBar {{ background: transparent; }}
QTabBar::tab {{ background: {t['surface']}; color: #ffffff; border: {border_w}px solid transparent; border-radius: {small_radius}px; padding: 7px 12px; }}
QTabBar::tab:hover {{ background: {t['hover']}; color: #ffffff; }}
QTabBar::tab:selected {{ background: {t['surface_alt']}; color: #ffffff; border-color: {t['border']}; }}
QHeaderView::section {{ background: {t['surface']}; color: {t['text']}; border-color: {t['border']}; }}
QTableWidget {{ gridline-color: {t['border']}; }}
QScrollArea, QScrollArea > QWidget, QScrollArea > QWidget > QWidget {{ background: transparent; border: none; }}
QAbstractScrollArea::viewport {{ background: transparent; }}
QScrollBar {{ background: {t['panel_bg']}; border: none; }}
QScrollBar:vertical {{ width: 10px; }} QScrollBar:horizontal {{ height: 10px; }}
QScrollBar::handle {{ background: {t['border']}; border: none; border-radius: 4px; min-height: 20px; min-width: 20px; }}
QScrollBar::handle:hover {{ background: {t['muted']}; }}
QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; background: transparent; border: none; }}
QSlider {{ background: transparent; border: none; }}
QSlider::groove:horizontal {{ height: 4px; background: {t['border']}; border: none; border-radius: 2px; }}
QSlider::sub-page:horizontal {{ background: {t['accent']}; border-radius: 2px; }}
QSlider::add-page:horizontal {{ background: {t['surface_alt']}; border-radius: 2px; }}
QSlider::handle:horizontal {{ width: 12px; margin: -4px 0; background: {t['text']}; border: 1px solid {t['border']}; border-radius: 6px; }}
QFrame#extensionCard {{ background: {t['surface']}; border: {border_w}px solid {t['border']}; border-radius: {radius}px; }}
QLabel#extensionSectionTitle {{ background: transparent; color: {t['text']}; font-weight: 600; }}
QLabel#extensionViewSubtitle {{ background: transparent; color: {t['muted']}; }}
QToolTip {{ background: {t['surface_alt']}; color: {t['text']}; border: 1px solid {t['border']}; padding: 4px 6px; }}
QMessageBox {{ background: {t['window_bg']}; color: {t['text']}; }}
'''
        custom = str(t.get("custom_qss", "") or "").strip()
        if custom: qss += "\n/* Visual Wizard advanced QSS */\n" + custom + "\n"
        return qss

    def _apply_widget(self, widget):
        if not isinstance(widget, QWidget) or bool(widget.property("vwSkipTheme")): return
        if widget.property("vwThemeRevision") == self._revision: return
        base = widget.property("vwBaseStyle")
        if base is None:
            base = widget.styleSheet(); widget.setProperty("vwBaseStyle", base)
        try:
            widget.setStyleSheet(str(base or "") + self._qss()); widget.setProperty("vwThemeRevision", self._revision)
        except RuntimeError: pass

    def apply(self, save=True):
        self._revision += 1
        if save:
            write_json_object(VISUAL_THEME_PATH, self.theme)
        if self.active:
            self._sync_icon_settings()
            self.apply_all()

    def apply_all(self):
        app = QApplication.instance()
        if app is None:
            return
        
        
        
        for widget in app.topLevelWidgets():
            if isinstance(widget, QWidget):
                self._apply_widget(widget)
        self._apply_editor_theme()
        self.owner.refresh_visual_icons()

    def _apply_editor_theme(self):
        if not hasattr(self.owner, "editor_tabs"): return
        for index in range(self.owner.editor_tabs.count()):
            editor = self.owner.tab_editor(index)
            if not isinstance(editor, CodeEditor): continue
            lexer = getattr(editor, "_lel_lexer", None)
            if lexer is None: continue
            editor._lel_syntax_styles = {
                self.color("syntax_comment", "#7f936f"): (lexer.Comment, lexer.LineComment), self.color("syntax_keyword", "#86a8e7"): (lexer.Keyword,),
                self.color("syntax_string", "#a8c77a"): (lexer.String, lexer.Character, lexer.LiteralString, lexer.UnclosedString), self.color("syntax_number", "#c9a56f"): (lexer.Number,),
                self.color("syntax_operator", "#d7dadd"): (lexer.Operator,), self.color("syntax_builtin", "#7db0d5"): (lexer.BasicFunctions, lexer.KeywordSet5, lexer.KeywordSet6, lexer.KeywordSet7),
                self.color("syntax_function", "#7daee0"): (lexer.StringTableMathsFunctions, lexer.CoroutinesIOSystemFacilities), self.color("syntax_type", "#b5a0d2"): (lexer.KeywordSet8,),
            }
            editor.setColor(QColor(self.color("editor_text", "#ffffff"))); editor.setPaper(QColor(self.color("editor_bg", "#08080a")))
            editor.setCaretForegroundColor(QColor(self.color("caret", "#ffffff"))); editor.setSelectionBackgroundColor(QColor(self.color("editor_selection", "#2b2b2b"))); editor.setSelectionForegroundColor(QColor(self.color("editor_text", "#ffffff")))
            font = editor.font(); font.setPointSize(max(8, min(24, int(self.theme.get("editor_font_size", 11) or 11)))); editor.setFont(font)
            self.owner.apply_editor_colors(editor, self.owner.colors.isChecked() if hasattr(self.owner, "colors") else True)

    def _apply_widget_safe(self, widget):
        try:
            self._apply_widget(widget)
        except RuntimeError:
            pass

    def eventFilter(self, watched, event):
        
        
        try:
            if event.type() == QEvent.Type.Show and isinstance(watched, QWidget) and watched.isWindow():
                QTimer.singleShot(0, lambda w=watched: self._apply_widget_safe(w))
        except RuntimeError:
            pass
        return False


class VisualWizardWindow(QDialog):
    COLOR_GROUPS = (
        ("Interface", (("window_bg", "Window background"), ("panel_bg", "Panel background"), ("surface", "Controls"), ("surface_alt", "Raised surface"), ("hover", "Hover"), ("border", "Borders"), ("text", "Primary text"), ("muted", "Muted text"), ("accent", "Accent"), ("selection", "Selection"), ("danger", "Danger / destructive"))),
        ("Editor", (("editor_bg", "Editor background"), ("editor_text", "Editor text"), ("caret", "Caret"), ("editor_selection", "Editor selection"))),
    )
    def __init__(self, owner, manager):
        super().__init__(owner); self.owner = owner; self.manager = manager
        self._qss_timer = QTimer(self); self._qss_timer.setSingleShot(True); self._qss_timer.setInterval(350); self._qss_timer.timeout.connect(self._apply_custom_qss)
        self.setWindowTitle("Visual Wizard"); self.resize(790, 680); self.setMinimumSize(650, 520); apply_window_icon(self)
        root = blur_content_layout(self, self, "Visual Wizard", (16, 12, 16, 16), 10)
        preset_row = QHBoxLayout(); preset_row.setSpacing(8)
        self.preset = QComboBox(); self.preset.addItems(VISUAL_THEME_PRESETS.keys()); self.preset.setMinimumWidth(190)
        self.preset.currentTextChanged.connect(self._preset_changed)
        preset_row.addWidget(QLabel("Theme")); preset_row.addWidget(self.preset, 1)
        reset = QPushButton("Reset"); reset.clicked.connect(self._reset); export = QPushButton("Export"); export.clicked.connect(self._export_theme); import_btn = QPushButton("Import"); import_btn.clicked.connect(self._import_theme)
        for b in (reset, export, import_btn):
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        preset_row.addWidget(import_btn); preset_row.addWidget(export); preset_row.addWidget(reset); root.addLayout(preset_row)
        self.tabs = QTabWidget(); self.tabs.setObjectName("visualWizardTabs"); self.tabs.setDocumentMode(False); self.tabs.tabBar().setDrawBase(False); self.tabs.setContentsMargins(0,0,0,0); self.tabs.setStyleSheet("QTabWidget::pane { border: 0px; margin: 0px; padding: 0px; } QTabBar { border: 0px; }"); root.addWidget(self.tabs, 1); self.color_buttons = {}
        for group_name, items in self.COLOR_GROUPS:
            page = QWidget(); scroll = QScrollArea(); scroll.setWidgetResizable(True); scroll.setFrameShape(QFrame.Shape.NoFrame); content = QWidget(); lay = QVBoxLayout(content); lay.setContentsMargins(8,8,8,8); lay.setSpacing(7)
            for key, label_text in items:
                row = QFrame(); row.setObjectName("visualColorRow"); r = QHBoxLayout(row); r.setContentsMargins(10,7,8,7); r.addWidget(QLabel(label_text),1)
                button = QPushButton(); button.setFixedSize(112,29); button.setProperty("vwSkipTheme", True); button.clicked.connect(lambda checked=False, k=key: self._pick_color(k)); button.setCursor(Qt.CursorShape.PointingHandCursor); button.setFocusPolicy(Qt.FocusPolicy.NoFocus); self.color_buttons[key]=button; r.addWidget(button); lay.addWidget(row)
            lay.addStretch(1); scroll.setWidget(content); page_lay=QVBoxLayout(page); page_lay.setContentsMargins(0,0,0,0); page_lay.addWidget(scroll); self.tabs.addTab(page, group_name.replace("&", "&&"))
        details=QWidget(); details_lay=QVBoxLayout(details); details_lay.setContentsMargins(12,12,12,12); details_lay.setSpacing(12)
        self.icon_hue=self._slider_row(details_lay,"Icon hue",-180,180,"icon_hue","°"); self.icon_sat=self._slider_row(details_lay,"Icon saturation",0,200,"icon_saturation","%"); self.icon_bright=self._slider_row(details_lay,"Icon brightness",40,180,"icon_brightness","%")
        self.ui_font=self._slider_row(details_lay,"UI font size",8,18,"font_size"," px"); self.editor_font=self._slider_row(details_lay,"Editor font size",8,24,"editor_font_size"," px"); self.radius=self._slider_row(details_lay,"Corner radius",0,18,"corner_radius"," px"); self.border=self._slider_row(details_lay,"Border width",0,3,"border_width"," px"); details_lay.addStretch(1); self.tabs.addTab(details,"Shape && icons")
        advanced=QWidget(); adv=QVBoxLayout(advanced); adv.setContentsMargins(10,10,10,10); adv.setSpacing(8); hint=QLabel("Advanced Qt stylesheet override. This is applied last, so you can target almost any widget/object name in LelSploit."); hint.setWordWrap(True); hint.setObjectName("settingsHint"); adv.addWidget(hint)
        self.custom_qss=QPlainTextEdit(); self.custom_qss.setPlaceholderText("/* Example: QPushButton#iconButton { border-radius: 12px; } */"); self.custom_qss.textChanged.connect(lambda: self._qss_timer.start()); adv.addWidget(self.custom_qss,1); self.tabs.addTab(advanced,"Advanced QSS")
        self.setStyleSheet('QFrame#visualColorRow { background:transparent; } QLabel#settingsHint { background:transparent; }'); apply_blur_style(self); self.reload(); QTimer.singleShot(0, lambda: self.manager._apply_widget(self))
    def _preset_changed(self, name):
        if not str(name or "").strip():
            return
        self.manager.apply_preset(name)
        self.reload()

    def _slider_row(self, layout, title, minimum, maximum, key, suffix):
        host=QWidget(); row=QHBoxLayout(host); row.setContentsMargins(0,0,0,0); row.setSpacing(9); label=QLabel(title); label.setMinimumWidth(145); row.addWidget(label); slider=QSlider(Qt.Orientation.Horizontal); slider.setRange(minimum,maximum); row.addWidget(slider,1); value=QLabel(); value.setMinimumWidth(58); value.setAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter); row.addWidget(value)
        def changed(v): value.setText(f"{v}{suffix}"); self.manager.set_value(key,v)
        slider.valueChanged.connect(changed); slider._vw_value_label=value; slider._vw_key=key; slider._vw_suffix=suffix; layout.addWidget(host); return slider
    def _pick_color(self,key):
        chosen=QColorDialog.getColor(QColor(self.manager.color(key,VISUAL_THEME_DEFAULT[key])),self,"Visual Wizard color")
        if chosen.isValid(): self.manager.set_value(key,chosen.name()); self.reload_colors()
    def reload_colors(self):
        for key,button in self.color_buttons.items():
            color=QColor(self.manager.color(key,VISUAL_THEME_DEFAULT[key])); lum=0.2126*color.red()+0.7152*color.green()+0.0722*color.blue(); fg="#090909" if lum>150 else "#ffffff"; button.setText(color.name().upper()); button.setStyleSheet(f"background:{color.name()};color:{fg};border:1px solid {self.manager.color('border','#292929')};border-radius:{max(2,int(self.manager.value('corner_radius',7))-2)}px;padding:0;")
    def reload(self):
        self.reload_colors()
        for slider in (self.icon_hue,self.icon_sat,self.icon_bright,self.ui_font,self.editor_font,self.radius,self.border):
            slider.blockSignals(True); slider.setValue(int(self.manager.value(slider._vw_key,VISUAL_THEME_DEFAULT[slider._vw_key]))); slider.blockSignals(False); slider._vw_value_label.setText(f"{slider.value()}{slider._vw_suffix}")
        self.custom_qss.blockSignals(True); self.custom_qss.setPlainText(str(self.manager.value("custom_qss","") or "")); self.custom_qss.blockSignals(False)
    def _apply_custom_qss(self): self.manager.set_value("custom_qss",self.custom_qss.toPlainText()); self.reload_colors()
    def _reset(self): self.manager.reset(); self.reload()
    def _export_theme(self):
        path,_=QFileDialog.getSaveFileName(self,"Export Visual Wizard theme","lelsploit-theme.json","JSON (*.json)")
        if path: write_json_object(path,self.manager.theme)
    def _import_theme(self):
        path,_=QFileDialog.getOpenFileName(self,"Import Visual Wizard theme","","JSON (*.json)")
        if not path: return
        raw=read_json_object(path,{})
        if not isinstance(raw,dict): return
        merged=dict(VISUAL_THEME_DEFAULT)
        for key,default in VISUAL_THEME_DEFAULT.items():
            value=raw.get(key,default)
            if isinstance(default,str) and key!="custom_qss":
                if QColor(str(value)).isValid(): merged[key]=QColor(str(value)).name()
            elif key=="custom_qss": merged[key]=str(value or "")[:100000]
            elif isinstance(default,int):
                try: merged[key]=int(value)
                except (TypeError,ValueError): pass
        self.manager.theme=merged; self.manager.apply(save=True); self.reload()


class VisualWizardService(QObject):
    def __init__(self, owner): super().__init__(owner); self.owner=owner; self._claims=set(); self.window=None
    def enable_extension(self, ext_id):
        ext_id=str(ext_id or "").strip()
        if ext_id:
            first = not self._claims
            self._claims.add(ext_id)
            self._sync()
            if first:
                app = QApplication.instance()
                if app is not None:
                    app.installEventFilter(self.owner.appearance_manager)
                
                QTimer.singleShot(0, self.owner.appearance_manager.activate)
    def retain_extensions(self, enabled_ids):
        had_claims = bool(self._claims)
        self._claims.intersection_update(set(enabled_ids or ()))
        if had_claims and not self._claims:
            app = QApplication.instance()
            if app is not None:
                app.removeEventFilter(self.owner.appearance_manager)
            self.owner.appearance_manager.deactivate()
        self._sync()
    def _sync(self):
        button=getattr(self.owner,"visual_wizard_button",None)
        if button is not None:
            button.setVisible(bool(self._claims))
            button.updateGeometry()
        layout=getattr(self.owner,"header_layout",None)
        if layout is not None:
            layout.invalidate(); layout.activate()
    def open(self):
        if not self._claims: return
        if self.window is None: self.window=VisualWizardWindow(self.owner,self.owner.appearance_manager)
        self.window.show(); self.window.raise_(); self.window.activateWindow()


class ExtensionsWindow(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent
        self.runtime = LelExtensionRuntime(parent)
        self.setWindowTitle("Extensions")
        self.resize(780, 640)
        self.setMinimumSize(620, 440)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "Extensions", (18, 12, 18, 16), 9)
        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)
        top.addStretch(1)
        self.install_button = QPushButton("Import Extension")
        self.install_button.setObjectName("extensionPrimary")
        icon = app_icon("extensions")
        if not icon.isNull():
            self.install_button.setIcon(icon)
            self.install_button.setIconSize(QSize(17, 17))
        self.install_button.setCursor(Qt.CursorShape.PointingHandCursor)
        self.install_button.clicked.connect(self.install_extension)
        top.addWidget(self.install_button)
        layout.addLayout(top)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll.setObjectName("extensionScroll")
        layout.addWidget(self.scroll, 1)

        self.setStyleSheet(r"""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel { background: transparent; }
            QScrollArea#extensionScroll { background: transparent; border: none; }
            QFrame#extensionCard, QFrame#templateCard {
                background: #0a0a0c; border: 1px solid #25252a; border-radius: 8px;
            }
            QFrame#extensionCard:hover, QFrame#templateCard:hover { border-color: #33333a; background: #0d0d10; }
            QLabel#extensionTitle { color: #f1f1f3; font-size: 13px; font-weight: 600; }
            QLabel#extensionMeta { color: #85858c; font-size: 10px; }
            QLabel#extensionDescription { color: #aaaaaf; }
            QLabel#extensionDescription a { color: #82aee8; }
            QLabel#extensionError { color: #e99191; }
            QLabel#extensionEmpty { color: #77777d; padding: 22px 10px; }
            QLabel#extensionSection { color:#d6d6da; font-size:12px; font-weight:600; padding: 8px 1px 2px 1px; }
            QPushButton {
                background: #121214; color: #e9e9eb; border: 1px solid #2b2b30;
                border-radius: 5px; padding: 6px 10px;
            }
            QPushButton:hover { background: #1a1a1e; border-color: #3a3a41; }
            QPushButton:disabled { color: #5f5f66; background: #0c0c0e; border-color: #202024; }
            QPushButton#extensionPrimary { background: #15181d; border-color: #303641; }
            QPushButton#extensionPrimary:hover { background: #1d222a; border-color: #424a58; }
            QPushButton#extensionIconButton, QPushButton#extensionRemoveIcon { padding:0; min-width:30px; max-width:30px; min-height:30px; max-height:30px; }
            QPushButton#extensionRemoveIcon:hover { background:#241516; border-color:#553033; }
            QScrollBar:vertical { width: 9px; background: transparent; }
            QScrollBar::handle:vertical { background: #35353b; border-radius: 4px; min-height: 28px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
        """)
        apply_blur_style(self)
        self._folder_signature = None
        self.reload()
        self._folder_watch_timer = QTimer(self)
        self._folder_watch_timer.setInterval(1200)
        self._folder_watch_timer.timeout.connect(self._poll_extension_folder)
        self._folder_watch_timer.start()

    def showEvent(self, event):
        super().showEvent(event)
        self.reload()

    @staticmethod
    def _markdown_label(text):
        label = QLabel(str(text or "No description found"))
        label.setObjectName("extensionDescription")
        label.setWordWrap(True)
        label.setTextFormat(Qt.TextFormat.MarkdownText)
        label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        return label

    @staticmethod
    def _image_action_button(icon_name, tooltip, object_name="extensionIconButton"):
        button = QPushButton()
        button.setObjectName(object_name)
        button.setFixedSize(30, 30)
        button.setToolTip(tooltip)
        button.setCursor(Qt.CursorShape.PointingHandCursor)
        button.setProperty("_lel_icon_name", icon_name)
        icon = app_icon(icon_name)
        if icon.isNull():
            for path in (IMAGES_DIR / f"{icon_name}.png", ICON_DIR / f"{icon_name}.png"):
                if path.is_file():
                    icon = QIcon(str(path)); break
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(17, 17))
        return button

    def _extension_icon(self, record):
        icon_bytes = record.get("icon_bytes", b"")
        if icon_bytes:
            pixmap = QPixmap()
            if pixmap.loadFromData(icon_bytes):
                return QIcon(pixmap)
        missing = IMAGES_DIR / "missing.png"
        if missing.is_file():
            icon = QIcon(str(missing))
            if not icon.isNull():
                return icon
        icon = app_icon("extensions")
        return icon if not icon.isNull() else lelsploit_icon()

    @staticmethod
    def _extension_folder_signature():
        return extension_folder_signature()

    def _poll_extension_folder(self):
        if not self.isVisible():
            return
        signature = self._extension_folder_signature()
        if signature != self._folder_signature:
            self.owner.refresh_extensions_runtime()
            self.reload()

    def _clear_cards(self):
        old = self.scroll.takeWidget()
        if old is not None:
            old.deleteLater()

    def reload(self):
        self._clear_cards()
        records = scan_extension_packages()
        disabled = set(load_extension_state().get("disabled", []))
        installed_ids = {record["manifest"]["id"] for record in records if record.get("manifest")}

        content = QWidget()
        content.setStyleSheet("background: transparent;")
        cards = QVBoxLayout(content)
        cards.setContentsMargins(0, 2, 4, 2)
        cards.setSpacing(8)

        if not records:
            empty = QLabel("No extensions installed.")
            empty.setObjectName("extensionEmpty")
            empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
            cards.addWidget(empty)
        else:
            for record in records:
                cards.addWidget(self._build_card(record, disabled))

        available_templates = [template for template in EXTENSION_TEMPLATES if template["id"] not in installed_ids]
        if available_templates:
            template_title = QLabel("Templates")
            template_title.setObjectName("extensionSection")
            cards.addWidget(template_title)
            for template in available_templates:
                cards.addWidget(self._build_template_card(template))
        cards.addStretch(1)
        self.scroll.setWidget(content)
        self._folder_signature = self._extension_folder_signature()

    def _build_card(self, record, disabled):
        card = QFrame(); card.setObjectName("extensionCard")
        root = QHBoxLayout(card); root.setContentsMargins(12, 11, 11, 11); root.setSpacing(11)

        icon_label = QLabel(); icon_label.setFixedSize(46, 46); icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = self._extension_icon(record)
        if not icon.isNull(): icon_label.setPixmap(icon.pixmap(40, 40))
        root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)

        info = QVBoxLayout(); info.setContentsMargins(0, 0, 0, 0); info.setSpacing(3)
        manifest = record.get("manifest")
        if manifest is None:
            title = QLabel("No title found"); title.setObjectName("extensionTitle"); info.addWidget(title)
            info.addWidget(self._markdown_label("No description found"))
            error = QLabel(record.get("error", "Invalid extension package")); error.setObjectName("extensionError"); error.setWordWrap(True); info.addWidget(error)
        else:
            title = QLabel(manifest.get("name") or "No title found"); title.setObjectName("extensionTitle"); info.addWidget(title)
            meta_bits = [f"v{manifest['version']}", manifest["id"]]
            if manifest.get("permissions"): meta_bits.append("permissions: " + ", ".join(manifest["permissions"]))
            meta = QLabel("  ·  ".join(meta_bits)); meta.setObjectName("extensionMeta"); meta.setWordWrap(True); info.addWidget(meta)
            info.addWidget(self._markdown_label(manifest.get("description") or "No description found"))
        root.addLayout(info, 1)

        buttons = QVBoxLayout(); buttons.setContentsMargins(0, 0, 0, 0); buttons.setSpacing(6)
        if manifest is not None:
            ext_id = manifest["id"]
            is_disabled = ext_id in disabled
            toggle = self._image_action_button("enable" if is_disabled else "disable", "Enable extension" if is_disabled else "Disable extension")
            toggle.clicked.connect(lambda checked=False, eid=ext_id: self.toggle_extension(eid))
            buttons.addWidget(toggle)
        remove = self._image_action_button("remove", "Remove extension", "extensionRemoveIcon")
        remove.clicked.connect(lambda checked=False, r=record: self.remove_extension(r))
        buttons.addWidget(remove)
        buttons.addStretch(1)
        root.addLayout(buttons)
        return card

    def _build_template_card(self, template):
        card = QFrame(); card.setObjectName("templateCard")
        root = QHBoxLayout(card); root.setContentsMargins(12, 11, 11, 11); root.setSpacing(11)
        icon_label = QLabel(); icon_label.setFixedSize(46, 46); icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = extension_template_icon()
        if not icon.isNull(): icon_label.setPixmap(icon.pixmap(40, 40))
        root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)
        info = QVBoxLayout(); info.setContentsMargins(0, 0, 0, 0); info.setSpacing(3)
        title = QLabel(template["name"]); title.setObjectName("extensionTitle"); info.addWidget(title)
        meta = QLabel("Template  ·  " + ", ".join(template.get("permissions", []))); meta.setObjectName("extensionMeta"); info.addWidget(meta)
        info.addWidget(self._markdown_label(template["description"]))
        root.addLayout(info, 1)
        install = self._image_action_button("install", "Install template")
        install.clicked.connect(lambda checked=False, t=template: self.install_template(t))
        root.addWidget(install, 0, Qt.AlignmentFlag.AlignTop)
        return card

    def install_template(self, template):
        try:
            target = write_extension_template(template)
            record = read_extension_package(target)
            self.owner.log(f"Installed extension template {record['manifest']['name']}.", "success")
            self.owner.refresh_extensions_runtime(restart_id=record["manifest"]["id"])
            self.reload()
        except Exception as exc:
            QMessageBox.warning(self, "Install template", f"Could not install this template.\n\n{exc}")

    def install_extension(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import Extension", "", "LelSploit extensions (*.lext)")
        if not path: return
        source = Path(path)
        try:
            record = read_extension_package(source)
            EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
            target = EXTENSIONS_DIR / source.name
            if target.exists() and target.resolve() != source.resolve():
                answer = QMessageBox.question(self, "Replace extension?", f"{target.name} is already installed. Replace it?", QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No, QMessageBox.StandardButton.No)
                if answer != QMessageBox.StandardButton.Yes: return
            if target.resolve() != source.resolve(): shutil.copy2(source, target)
            self.owner.log(f"Installed extension {record['manifest']['name']}.", "success")
            self.owner.refresh_extensions_runtime(restart_id=record["manifest"]["id"])
            self.reload()
        except Exception as exc:
            QMessageBox.warning(self, "Import Extension", f"Could not import this extension.\n\n{exc}")

    def toggle_extension(self, ext_id):
        state = load_extension_state(); disabled = set(state.get("disabled", []))
        if ext_id in disabled: disabled.discard(ext_id)
        else: disabled.add(ext_id)
        state["disabled"] = sorted(disabled); save_extension_state(state)
        self.owner.refresh_extensions_runtime(restart_id=ext_id if ext_id not in disabled else None)
        self.reload()

    def remove_extension(self, record):
        manifest = record.get("manifest")
        try:
            record["path"].unlink(missing_ok=True)
            if manifest:
                ext_id = manifest["id"]
                state = load_extension_state(); disabled = set(state.get("disabled", [])); disabled.discard(ext_id)
                state["disabled"] = sorted(disabled); state.get("data", {}).pop(ext_id, None); save_extension_state(state)
                shutil.rmtree(EXTENSION_DATA_DIR / ext_id, ignore_errors=True)
                self.owner.refresh_extensions_runtime()
            self.reload()
        except OSError as exc:
            QMessageBox.warning(self, "Remove extension", str(exc))


EXTENSIONS_DOCUMENTATION_HTML = r"""
<style>
body { color:#d4d4d4; font-family:'Segoe UI'; font-size:10.5pt; line-height:1.55; background:#0b0c0d; margin:0; }
h1,h2,h3 { color:#f0f0f2; } h1 { font-size:20pt; } h2 { margin-top:20px; font-size:14pt; }
code,pre { font-family:Consolas,monospace; } code { color:#a9d8ff; } pre { background:#0b0b0d; border:1px solid #242429; padding:10px; border-radius:6px; }
table { border-collapse:collapse; width:100%; margin:8px 0 14px 0; } th,td { border:1px solid #29292f; padding:6px 8px; text-align:left; vertical-align:top; } th { background:#101014; color:#f2f2f4; }
strong { color:#f3f3f5; } li { margin:3px 0; } .note { border-left:3px solid #3a4d63; padding:7px 10px; background:#0a0b0d; }
</style>
<h1>Extensions / LExt API</h1>
<p>LExt v1 is LelSploit's declarative extension format. It is designed around composable operations: extensions can build windows and toolbar controls, watch LelSploit events/widgets, manipulate editors/tabs, use public HTTP, perform advanced math/data work, inspect Roblox session state, drive Attach/Execute/proxy actions, play sounds, manage extensions, and read LelSploit files while keeping writes inside their own data directory.</p>

<h2>Package and manifest</h2>
<pre>my-extension.lext  (ZIP)
├─ manifest.json
├─ icon.png
└─ assets/...</pre>
<p><code>manifest.json</code> fields: <code>format</code> (must be 1), <code>id</code>, <code>name</code>, <code>version</code>, <code>description</code> (Markdown), <code>icon</code>, <code>permissions</code>, <code>startup</code>, <code>interval</code>, <code>actions</code>, <code>shortcuts</code>, <code>events</code>, <code>panels</code>, <code>toolbar</code>, and <code>watchers</code>. Enabled extensions start automatically. IDs use lowercase letters/numbers plus <code>._-</code>.</p>
<p><b>Actions</b> contain an <code>id</code>, optional text <code>inputs</code>, and <code>steps</code>. Every ordinary step can include <code>when</code>. <b>Startup</b> is a step array. <b>Interval</b> is <code>{"ms":1000,"steps":[...]}</code>. <b>Shortcuts</b> map keys to action IDs.</p>


<h2>Extension manager</h2>
<ul>
<li><b>Import Extension</b> installs a validated <code>.lext</code> ZIP package.</li>
<li>Installed cards show the extension name, version, id, requested permissions and Markdown description, and can be enabled/disabled or removed without restarting LelSploit.</li>
<li>The extension folder is watched for changes and the live runtime refreshes automatically.</li>
<li>Built-in extension templates appear when their ids are not already installed and can be installed directly from the Extensions window.</li>
</ul>

<h2>Manifest lifecycle, hooks and limits</h2>
<table><tr><th>Feature</th><th>Supported behavior</th></tr>
<tr><td>Package</td><td><code>.lext</code> ZIP up to 32 MiB; <code>manifest.json</code> up to 256 KiB; package icon up to 2 MiB.</td></tr>
<tr><td>Identity</td><td><code>format</code> must be 1. Ids use lowercase letters/numbers plus <code>._-</code> and are at most 80 characters.</td></tr>
<tr><td>Actions</td><td>Up to 64 actions, up to 24 text inputs per action, and nested flow up to 8 levels.</td></tr>
<tr><td>Startup</td><td><code>startup</code> is a step list run when an enabled package is activated.</td></tr>
<tr><td>Interval</td><td><code>interval</code> uses <code>{"ms":1000,"steps":[...]}</code>; interval values are clamped from 250 ms to 3,600,000 ms.</td></tr>
<tr><td>Shortcuts</td><td>Up to 32 key sequences targeting declared action ids.</td></tr>
<tr><td>Events</td><td>Up to 32 hooks: <code>editor.changed</code>, <code>selection.changed</code>, <code>tab.changed</code>, <code>clipboard.changed</code>, <code>app.activated</code>, <code>app.deactivated</code>, <code>roblox.changed</code>. An event can run an action or inline steps.</td></tr>
<tr><td>Panels</td><td>Up to 16 manifest panels with up to 80 controls each. Runtime <code>ui.view.open</code> accepts up to 160 controls.</td></tr>
<tr><td>Toolbar</td><td>Up to 12 manifest buttons, plus runtime add/remove through <code>ui.toolbar.add</code> and <code>ui.toolbar.remove</code>.</td></tr>
<tr><td>Watchers</td><td>Up to 32 widget watchers. Signals: <code>clicked</code>, <code>toggled</code>, <code>text_changed</code>, <code>value_changed</code>, <code>current_changed</code>, <code>selection_changed</code>.</td></tr>
<tr><td>Data bounds</td><td>Extension text/file operations are bounded to 8 MiB where applicable; network responses are bounded to 2 MiB.</td></tr>
</table>

<h2>Variables / interpolation</h2>
<p>Strings use <code>${name}</code>. Common values: <code>${editor}</code>, <code>${selection}</code>, <code>${tab_name}</code>, <code>${clipboard}</code>, <code>${input.id}</code>, <code>${ui.controlId}</code>, <code>${var.name}</code>, <code>${storage.key}</code>, <code>${event.name}</code>, <code>${event.value}</code>, <code>${extension.id}</code>, <code>${extension.name}</code>, <code>${app.roblox_running}</code>, <code>${app.roblox_mode}</code>, <code>${app.attached}</code>, <code>${app.proxy_active}</code>, <code>${app.tab_count}</code>, <code>${app.current_tab}</code>, <code>${roblox.place_id}</code>, <code>${roblox.job_id}</code>, <code>${proxy.active}</code>, and <code>${proxy.suspended}</code>.</p>

<h2>Permissions</h2>
<table><tr><th>Permission</th><th>Access</th></tr>
<tr><td><code>editor</code></td><td>Editor text, selection, cursor and tabs.</td></tr>
<tr><td><code>clipboard</code></td><td>Clipboard reads/writes.</td></tr>
<tr><td><code>storage</code></td><td>Persistent extension-scoped key/value storage.</td></tr>
<tr><td><code>files</code></td><td>Read/write/delete only inside <code>extension_data/&lt;extension-id&gt;</code>.</td></tr>
<tr><td><code>app_files</code></td><td>Read/list/stat files under the LelSploit directory; no writes.</td></tr>
<tr><td><code>picker</code></td><td>User-approved external file open/save dialogs.</td></tr>
<tr><td><code>network</code></td><td>Bounded HTTP(S) to public addresses; local/private IPs are blocked.</td></tr>
<tr><td><code>ui</code></td><td>Panels, toolbar buttons, dialogs, notifications, widget inspection/control.</td></tr>
<tr><td><code>settings</code></td><td>LelSploit JSON settings tree.</td></tr>
<tr><td><code>theme</code></td><td>Visual Wizard theme values/presets.</td></tr>
<tr><td><code>execute</code></td><td>Execute source through LelSploit.</td></tr>
<tr><td><code>roblox</code></td><td>Roblox session/join/server metadata and Attach/Detach actions.</td></tr>
<tr><td><code>proxy</code></td><td>Proxy state and enable/disable/restart controls.</td></tr>
<tr><td><code>fastflags</code></td><td>Custom FastFlag management.</td></tr>
<tr><td><code>extensions</code></td><td>List, enable/disable, reload or remove installed extensions.</td></tr>
<tr><td><code>sound</code></td><td>Beep and WAV playback from package/extension-data resources.</td></tr></table>

<h2>Complete operation reference</h2>
<h3>Editor and tabs (<code>editor</code>)</h3>
<p><code>editor.set</code> text; <code>editor.append</code> text; <code>editor.prepend</code> text; <code>editor.insert</code> text at cursor; <code>editor.clear</code>; <code>editor.replace</code> find/replace with optional regex/count; <code>editor.select_all</code>; <code>editor.goto_line</code> line/index; <code>editor.cursor</code> → <code>var.&lt;save_as&gt;.line/index</code>; <code>editor.line</code> line → value; <code>selection.replace</code>, <code>selection.copy</code>, <code>selection.delete</code>; <code>editor.new_tab</code> name/text; <code>tabs.rename</code>, <code>tabs.select</code>, <code>tabs.close_current</code>, <code>tabs.list</code>, <code>tabs.read</code>, <code>tabs.set</code>.</p>
<h3>Clipboard and dialogs</h3>
<p><code>console.log</code> is retained for older extensions; the visible LelSploit console has been removed. <code>clipboard.set</code>, <code>clipboard.append</code>; <code>notify</code> title/text/duration; <code>message</code>; <code>dialog.input</code> → value + <code>.accepted</code>; <code>dialog.confirm</code> → boolean.</p>
<h3>UI</h3>
<p><code>ui.open</code> opens ScriptBlox/Tools/FastFlags/Extensions/Documentation/Settings. <code>ui.window</code> controls the main window. <code>ui.smooth_scroll</code> tunes smooth scrolling. <code>visual_wizard.enable</code> claims the Visual Wizard button. <code>ui.panel.open/close/update</code> controls manifest panels. <code>ui.view.open</code> can build an entire runtime window from one declarative JSON view object, so extensions normally do not need low-level widget operations. <code>ui.toolbar.add/remove</code> adds extension toolbar buttons. <code>ui.widget.get/set/invoke</code> works with object names or <code>attr:owner_attribute</code>. <code>ui.widget.list</code> returns up to 1000 discoverable widgets as JSON. <code>ui.icon.list</code> lists every PNG icon exposed read-only from LelSploit's <code>icons</code> directory.</p>
<p>Panel/view controls: <code>label</code>, <code>heading</code>, <code>markdown</code>, <code>input</code>, <code>textarea</code>, <code>checkbox</code>/<code>switch</code>, <code>combo</code>, <code>list</code>, <code>slider</code>, <code>color</code>, <code>button</code>, <code>icon_button</code>, <code>icon</code>, <code>card</code>/<code>section</code>, <code>row</code>, <code>separator</code>, and <code>spacer</code>. Cards/rows can contain nested <code>controls</code>. Set <code>on_change</code> on inputs, switches, combos, lists, or sliders to dispatch an action automatically. Control values become <code>${ui.id}</code>.</p><p><b>Icons:</b> use <code>host:save</code>, <code>icons:save</code>, or <code>icons/save.png</code> in toolbar/control <code>icon</code> fields to use LelSploit's built-in icon library. A plain name first checks the extension package and then the host icon library. Package resources can be forced with <code>package:my-icon.png</code>.</p>

<h3>Declarative UI controls</h3>
<p>Manifest panels and runtime views can compose <code>label</code>, <code>heading</code>, <code>markdown</code>, <code>input</code>, <code>textarea</code>, <code>checkbox</code>, <code>switch</code>, <code>combo</code>, <code>list</code>, <code>slider</code>, <code>color</code>, <code>button</code>, <code>icon_button</code>, <code>icon</code>, <code>card</code>, <code>section</code>, <code>row</code>, <code>separator</code> and <code>spacer</code>. Cards, sections and rows can nest controls. Inputs, switches, combos, lists and sliders can use <code>on_change</code> to dispatch actions. Values are exposed as <code>${ui.id}</code>.</p>
<p><b>Widget addressing:</b> <code>ui.widget.get/set/invoke</code> accepts an object name or <code>attr:owner_attribute</code>. <code>ui.widget.list</code> can enumerate up to 1000 discoverable widgets. <b>Icons:</b> use <code>host:name</code>, <code>icons:name</code>, <code>icons/name.png</code>, a plain package/host name, or <code>package:path.png</code>.</p>

<h3>Storage and files</h3>
<p><code>storage.set/delete/clear</code>. Writable sandbox: <code>file.read/write/append/delete/list</code> only inside <code>extension_data/&lt;id&gt;</code>. User-approved external files: <code>file.pick_read</code>, <code>file.pick_write</code>. Package resources: <code>package.list/read</code>. Read-only LelSploit tree: <code>app.file.list</code>, <code>app.file.read</code> (UTF-8/other encoding or base64), <code>app.file.stat</code>.</p>
<h3>HTTP</h3>
<p><code>http.request</code>: URL, method GET/POST/PUT/PATCH/DELETE, headers, body, timeout, save_as. It returns <code>var.name</code>, <code>var.name.status</code>, <code>var.name.url</code>, and <code>var.name.headers</code>. Public HTTP(S) only, 2 MiB response limit, redirect destinations rechecked.</p>
<h3>Variables, text, JSON and flow</h3>
<p><code>var.set</code>, <code>var.append</code>, <code>var.delete</code>, <code>var.number</code>; <code>system.now</code>; <code>system.info</code>; <code>text.transform</code> supports upper/lower/strip, JSON pretty/compact, URL/base64 encode/decode, SHA-256, reverse, length, line sort/unique/trim, newline normalization, word count, regex extract/replace. <code>json.get</code>, <code>json.set</code>. <code>flow.if</code>, <code>flow.repeat</code>, <code>flow.foreach</code>. <code>action.run</code> calls another action. <code>timer.after</code>, <code>timer.every</code>, <code>timer.cancel</code> schedule actions without blocking the UI.</p>
<h3>Advanced math</h3>
<p><code>math.eval</code> safely evaluates numeric expressions with constants <code>pi/e/tau</code>, arithmetic and a broad <code>math</code> function set (trig/hyperbolic, logs, gamma/erf, factorial, comb/perm, gcd/lcm, distance, fsum/prod and more). <code>math.stats</code> returns count/sum/min/max/mean/median, variance/deviation, quartiles and positive-value geometric/harmonic means. <code>math.vector</code> supports magnitude, normalize, dot, distance, add, subtract and 3D cross. <code>math.random</code> supports float/int/choice.</p>
<h3>Roblox and execution</h3>
<p><code>roblox.state</code> → JSON with running/mode/attached/proxy/place/job/process information plus strongly identified player pairs found in the current client log. <code>roblox.join_context</code> returns place/job/log join metadata. <code>roblox.players</code> returns player name/id pairs that are explicitly present in the client log and marks whether the snapshot is complete. <code>roblox.server</code> looks up public metadata for the current server (playing/max players/fps/ping when available). <code>roblox.client</code> returns the detected Roblox executable/version. <code>roblox.request</code> is a generic public HTTPS request primitive restricted to Roblox domains, so extensions can use new public Roblox REST endpoints without another LelSploit host change. <code>roblox.attach</code>, <code>roblox.reattach</code>, <code>roblox.detach</code>, and <code>roblox.execute</code> use LelSploit's normal Roblox action paths. <code>script.execute</code> remains as the compact execute operation.</p>
<p class="note">Roblox intentionally does not expose a public API that maps every live server player token to username/user ID. LExt returns identities only when the client itself exposes a strong name/id pair in its local log; extensions can still execute Luau through <code>roblox.execute</code> for in-client logic.</p>
<h3>Proxy and FastFlags</h3>
<p><code>proxy.state</code>, <code>proxy.enable</code>, <code>proxy.disable</code>, <code>proxy.restart</code>. <code>fastflag.set</code> and <code>fastflag.remove</code>. Proxy controls use the same host logic as LelSploit, including custom-FastFlag snapshot/restore behavior.</p>
<h3>Extensions</h3>
<p><code>extension.list</code>, <code>extension.info</code>, <code>extension.set_enabled</code>, <code>extension.reload</code>, <code>extension.remove</code>. Changes trigger a live runtime refresh; a full LelSploit restart is not required.</p>
<h3>Theme/settings/sound</h3>
<p><code>settings.get/set</code>; <code>theme.get/set/preset/reset</code>; <code>sound.beep</code> frequency/duration; <code>sound.play</code> WAV from <code>package</code> or extension <code>data</code>; <code>sound.stop</code>.</p>

<h2>Events and watchers</h2>
<p>Events: <code>editor.changed</code>, <code>selection.changed</code>, <code>tab.changed</code>, <code>clipboard.changed</code>, <code>app.activated</code>, <code>app.deactivated</code>, <code>roblox.changed</code>. Event entries can reference an action or contain steps. Watchers connect actions to existing widget signals: <code>clicked</code>, <code>toggled</code>, <code>text_changed</code>, <code>value_changed</code>, <code>current_changed</code>, <code>selection_changed</code>.</p>


<h2>Full operation inventory</h2>
<p>This table mirrors every step operation accepted by this build. A permission of <b>None</b> means the operation itself does not need an extra manifest permission.</p>
<table>
<tr><th>Area</th><th>Operation</th><th>Permission</th></tr>
<tr><td rowspan="14"><b>Data / flow</b></td><td><code>action.run</code></td><td>None</td></tr>
<tr><td><code>flow.foreach</code></td><td>None</td></tr>
<tr><td><code>flow.if</code></td><td>None</td></tr>
<tr><td><code>flow.repeat</code></td><td>None</td></tr>
<tr><td><code>json.get</code></td><td>None</td></tr>
<tr><td><code>json.set</code></td><td>None</td></tr>
<tr><td><code>text.transform</code></td><td>None</td></tr>
<tr><td><code>timer.after</code></td><td>None</td></tr>
<tr><td><code>timer.cancel</code></td><td>None</td></tr>
<tr><td><code>timer.every</code></td><td>None</td></tr>
<tr><td><code>var.append</code></td><td>None</td></tr>
<tr><td><code>var.delete</code></td><td>None</td></tr>
<tr><td><code>var.number</code></td><td>None</td></tr>
<tr><td><code>var.set</code></td><td>None</td></tr>
<tr><td rowspan="3"><b>App files</b></td><td><code>app.file.list</code></td><td><code>app_files</code></td></tr>
<tr><td><code>app.file.read</code></td><td><code>app_files</code></td></tr>
<tr><td><code>app.file.stat</code></td><td><code>app_files</code></td></tr>
<tr><td rowspan="1"><b>App state</b></td><td><code>app.state</code></td><td>None</td></tr>
<tr><td rowspan="2"><b>Clipboard</b></td><td><code>clipboard.append</code></td><td><code>clipboard</code></td></tr>
<tr><td><code>clipboard.set</code></td><td><code>clipboard</code></td></tr>
<tr><td rowspan="5"><b>Messages / dialogs</b></td><td><code>console.log</code></td><td><code>ui</code></td></tr>
<tr><td><code>dialog.confirm</code></td><td><code>ui</code></td></tr>
<tr><td><code>dialog.input</code></td><td><code>ui</code></td></tr>
<tr><td><code>message</code></td><td><code>ui</code></td></tr>
<tr><td><code>notify</code></td><td><code>ui</code></td></tr>
<tr><td rowspan="20"><b>Editor / tabs</b></td><td><code>editor.append</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.clear</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.cursor</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.goto_line</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.insert</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.line</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.new_tab</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.prepend</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.replace</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.select_all</code></td><td><code>editor</code></td></tr>
<tr><td><code>editor.set</code></td><td><code>editor</code></td></tr>
<tr><td><code>selection.copy</code></td><td><code>editor</code></td></tr>
<tr><td><code>selection.delete</code></td><td><code>editor</code></td></tr>
<tr><td><code>selection.replace</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.close_current</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.list</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.read</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.rename</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.select</code></td><td><code>editor</code></td></tr>
<tr><td><code>tabs.set</code></td><td><code>editor</code></td></tr>
<tr><td rowspan="5"><b>Extension management</b></td><td><code>extension.info</code></td><td><code>extensions</code></td></tr>
<tr><td><code>extension.list</code></td><td><code>extensions</code></td></tr>
<tr><td><code>extension.reload</code></td><td><code>extensions</code></td></tr>
<tr><td><code>extension.remove</code></td><td><code>extensions</code></td></tr>
<tr><td><code>extension.set_enabled</code></td><td><code>extensions</code></td></tr>
<tr><td rowspan="2"><b>FastFlags</b></td><td><code>fastflag.remove</code></td><td><code>fastflags</code></td></tr>
<tr><td><code>fastflag.set</code></td><td><code>fastflags</code></td></tr>
<tr><td rowspan="7"><b>Extension files / pickers</b></td><td><code>file.append</code></td><td><code>files</code></td></tr>
<tr><td><code>file.delete</code></td><td><code>files</code></td></tr>
<tr><td><code>file.list</code></td><td><code>files</code></td></tr>
<tr><td><code>file.pick_read</code></td><td><code>picker</code></td></tr>
<tr><td><code>file.pick_write</code></td><td><code>picker</code></td></tr>
<tr><td><code>file.read</code></td><td><code>files</code></td></tr>
<tr><td><code>file.write</code></td><td><code>files</code></td></tr>
<tr><td rowspan="1"><b>Network</b></td><td><code>http.request</code></td><td><code>network</code></td></tr>
<tr><td rowspan="6"><b>Math / system</b></td><td><code>math.eval</code></td><td>None</td></tr>
<tr><td><code>math.random</code></td><td>None</td></tr>
<tr><td><code>math.stats</code></td><td>None</td></tr>
<tr><td><code>math.vector</code></td><td>None</td></tr>
<tr><td><code>system.info</code></td><td>None</td></tr>
<tr><td><code>system.now</code></td><td>None</td></tr>
<tr><td rowspan="2"><b>Package resources</b></td><td><code>package.list</code></td><td>None</td></tr>
<tr><td><code>package.read</code></td><td>None</td></tr>
<tr><td rowspan="4"><b>Proxy</b></td><td><code>proxy.disable</code></td><td><code>proxy</code></td></tr>
<tr><td><code>proxy.enable</code></td><td><code>proxy</code></td></tr>
<tr><td><code>proxy.restart</code></td><td><code>proxy</code></td></tr>
<tr><td><code>proxy.state</code></td><td><code>proxy</code></td></tr>
<tr><td rowspan="11"><b>Roblox / execute</b></td><td><code>roblox.attach</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.client</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.detach</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.execute</code></td><td><code>execute</code></td></tr>
<tr><td><code>roblox.join_context</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.players</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.reattach</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.request</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.server</code></td><td><code>roblox</code></td></tr>
<tr><td><code>roblox.state</code></td><td><code>roblox</code></td></tr>
<tr><td><code>script.execute</code></td><td><code>execute</code></td></tr>
<tr><td rowspan="6"><b>Settings / theme</b></td><td><code>settings.get</code></td><td><code>settings</code></td></tr>
<tr><td><code>settings.set</code></td><td><code>settings</code></td></tr>
<tr><td><code>theme.get</code></td><td><code>theme</code></td></tr>
<tr><td><code>theme.preset</code></td><td><code>theme</code></td></tr>
<tr><td><code>theme.reset</code></td><td><code>theme</code></td></tr>
<tr><td><code>theme.set</code></td><td><code>theme</code></td></tr>
<tr><td rowspan="3"><b>Sound</b></td><td><code>sound.beep</code></td><td><code>sound</code></td></tr>
<tr><td><code>sound.play</code></td><td><code>sound</code></td></tr>
<tr><td><code>sound.stop</code></td><td><code>sound</code></td></tr>
<tr><td rowspan="3"><b>Storage</b></td><td><code>storage.clear</code></td><td><code>storage</code></td></tr>
<tr><td><code>storage.delete</code></td><td><code>storage</code></td></tr>
<tr><td><code>storage.set</code></td><td><code>storage</code></td></tr>
<tr><td rowspan="15"><b>UI</b></td><td><code>ui.icon.list</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.open</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.panel.close</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.panel.open</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.panel.update</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.smooth_scroll</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.toolbar.add</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.toolbar.remove</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.view.open</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.widget.get</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.widget.invoke</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.widget.list</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.widget.set</code></td><td><code>ui</code></td></tr>
<tr><td><code>ui.window</code></td><td><code>ui</code></td></tr>
<tr><td><code>visual_wizard.enable</code></td><td><code>ui</code></td></tr>
</table>


<h2>Example</h2>
<pre>{
  "format": 1,
  "id": "example.sessiontool",
  "name": "Session Tool",
  "permissions": ["ui","roblox","proxy"],
  "actions": [
    {"id":"open","steps":[{"op":"ui.panel.open","id":"main"}]},
    {"id":"refresh","steps":[
      {"op":"roblox.state","save_as":"rbx"},
      {"op":"ui.panel.update","id":"main","control":"state","property":"text","value":"```json\\n${var.rbx}\\n```"}
    ]}
  ],
  "panels": [{"id":"main","title":"Session Tool","controls":[
    {"type":"markdown","id":"state","text":"Press Refresh"},
    {"type":"button","text":"Refresh","action":"refresh"}
  ]}],
  "toolbar": [{"id":"open","tooltip":"Session Tool","icon":"icon.png","action":"open"}]
}</pre>

<h2>Limits / safety boundary</h2>
<p>LExt is deliberately powerful inside LelSploit, but packages still do not receive arbitrary Python execution, DLL loading, raw process creation, registry writes, unrestricted machine-wide writes, or private-network access. Read-only app-file access is rooted to LelSploit; writable files stay inside the extension's own data directory unless the user explicitly chooses a path through a picker. This keeps the API broad without turning a downloaded theme/tool into unrestricted native code.</p>
"""

DOCUMENTATION_HTML = r"""
<style>
body { color: #d4d4d4; font-family: 'Segoe UI'; font-size: 10.5pt; line-height: 1.55; background: #0b0c0d; margin: 0; }
h1 { color: #ffffff; font-size: 19pt; margin: 2px 0 6px 0; }
h2 { color: #f2f2f2; font-size: 13pt; margin: 26px 0 8px 0; }
h3 { color: #e7e7e7; font-size: 11pt; margin: 17px 0 6px 0; }
p { margin: 5px 0 10px 0; }
ul, ol { margin: 7px 0 12px 22px; }
li { margin: 4px 0; }
code { color: #9fe8aa; background: #0d0d0d; }
pre { color: #d8d8d8; background: #0a0a0a; border: 1px solid #1f1f1f; padding: 11px; }
a { color: #8fcfff; text-decoration: none; }
.note { color: #c5c5c5; background: #0a0a0a; border-left: 3px solid #383838; padding: 9px 11px; }
.kbd { color: #eeeeee; background: #151515; border: 1px solid #2d2d2d; }
</style>

<h1>LelSploit Documentation</h1>
<p>A practical guide to writing, organizing, loading, and running Luau scripts with LelSploit.</p>

<p><b>Contents:</b>
<a href="#start">Getting started</a> ·
<a href="#editor">Editor</a> ·
<a href="#luau">Luau basics</a> ·
<a href="#run">Running scripts</a> ·
<a href="#tabs">Tabs & files</a> ·
<a href="#scriptblox">ScriptBlox</a> ·
<a href="#tools">Tools</a> ·
<a href="#fastflags">FastFlags</a> ·
<a href="#shortcuts">Shortcuts</a> ·
<a href="#troubleshooting">Troubleshooting</a>
</p>

<h2 id="start">Getting started</h2>
<ol>
<li>Start Roblox and join the experience you want to work with.</li>
<li>Open LelSploit. The first editor tab contains a small <code>print</code> example.</li>
<li>Press <b>Attach</b> to connect the configured local API bridge to the running Roblox client.</li>
<li>Write or paste Luau in the active tab.</li>
<li>Press <b>Execute</b> to send the active tab through the local bridge.</li>
</ol>
<p class="note"><b>Local execution:</b> LelSploit sends the active script through its configured local API bridge. Script text is handled on your machine and is sent to the locally attached client context. The editor itself does not require a cloud service to store or execute your current tab.</p>

<h2 id="editor">The code editor</h2>
<p>The main editor is optimized for Lua/Luau source. Syntax colors distinguish comments, strings, numbers, operators, keywords, built-in functions, and Luau-specific types.</p>
<h3>Useful editor habits</h3>
<ul>
<li>Keep one feature or experiment per tab. Smaller scripts are easier to test and debug.</li>
<li>Use descriptive tab names such as <code>movement.luau</code>, <code>ui-test.luau</code>, or <code>network-debug.luau</code>.</li>
<li>Use comments beginning with <code>--</code> to explain assumptions and temporary tests.</li>
<li>Prefer local variables for values that do not need to be global.</li>
<li>When a script becomes large, split helpers into logical sections and keep related functions together.</li>
</ul>

<h2 id="luau">Luau basics</h2>
<h3>Output</h3>
<pre>print("Hello from LelSploit")
warn("This is a warning")</pre>
<h3>Variables</h3>
<pre>local playerName = "Player"
local speed = 16
local enabled = true</pre>
<h3>Functions</h3>
<pre>local function greet(name)
    print("Hello, " .. name)
end

greet("Player")</pre>
<h3>Tables</h3>
<pre>local settings = {
    Enabled = true,
    Speed = 16,
    Modes = {"Normal", "Fast"}
}

print(settings.Speed)</pre>
<h3>Conditionals</h3>
<pre>local value = 10

if value > 5 then
    print("value is greater than 5")
else
    print("value is 5 or lower")
end</pre>
<h3>Loops</h3>
<pre>for index = 1, 5 do
    print(index)
end

local items = {"A", "B", "C"}
for index, item in ipairs(items) do
    print(index, item)
end</pre>
<h3>Roblox objects</h3>
<pre>local Players = game:GetService("Players")
local player = Players.LocalPlayer

print(player and player.Name)</pre>
<p>Roblox APIs and available objects depend on the client context and the script environment provided by the attached bridge. Test assumptions before building larger scripts around them.</p>

<h2 id="run">Execute, Attach, and Roblox controls</h2>
<h3>Execute</h3>
<p><b>Execute</b> sends only the currently selected editor tab. If there is no open tab, there is nothing to execute.</p>
<h3>Attach / Reattach</h3>
<p><b>Attach</b> asks the local bridge to connect to Roblox. After a successful connection the button becomes <b>Reattach</b>. Reattach is useful after a client transition, reconnect, or when the bridge no longer reports an attached state.</p>
<h3>Start Roblox / End Roblox</h3>
<p>The Roblox button reflects whether a supported Roblox player process is detected. Ending Roblox also cancels an attach attempt that is still waiting for a client.</p>
<h3>Roblox not detected</h3>
<p>If you Execute or Attach while no Roblox Player is detected, LelSploit asks whether you want to continue. Continuing lets the local bridge attempt its normal behavior; cancelling returns you to the editor.</p>

<h2 id="tabs">Tabs and files</h2>
<ul>
<li>Use the <b>+</b> control beside the right-most tab to create a new script.</li>
<li>Hover a tab to reveal its close icon.</li>
<li>Right-click a tab to close it immediately.</li>
<li>Double-click a tab, or press <b>F2</b>, to rename the current script.</li>
<li>The source extension remains protected while renaming.</li>
<li>You can close every tab. Creating a new tab after all tabs are closed starts again at <code>script1.luau</code>.</li>
<li>When many tabs are open, use the mouse wheel over the tab strip to move through them.</li>
</ul>
<h3>Open and save</h3>
<p>Use the Open and Save icons at the top-right of the code window. Open accepts <code>.luau</code>, <code>.lua</code>, <code>.txt</code>, <code>.script</code>, and extensionless files. Save asks where to save the current tab and remembers the last directory you used.</p>

<h2 id="scriptblox">ScriptBlox</h2>
<p>ScriptBlox provides a searchable script catalog inside LelSploit.</p>
<ul>
<li><b>Search scripts</b> filters by script terms.</li>
<li><b>Search games or place ID</b> narrows results to a game or numeric place identifier.</li>
<li><b>Keyless</b> is green while enabled.</li>
<li><b>Load More</b> appears at the bottom only when the API reports another page.</li>
<li><b>Install</b> follows your configured install behavior.</li>
<li>The star button saves or removes a script from your local Saved Scripts library.</li>
</ul>
<h3>Install behavior</h3>
<p>Settings lets you choose whether Install should use the current tab, create a new tab, execute immediately, or ask on the first install. <b>Put in new code window & run</b> keeps the installed source separate from your current work and is the recommended automatic mode.</p>
<h3>Saved Scripts</h3>
<p>Saved Scripts keeps favorites in <code>saved_scripts.json</code>. Entering Saved Scripts temporarily removes the normal browse filters; when you return, the previous search text, game/place filter, sorting, and Keyless state are restored.</p>

<h2 id="tools">Tools</h2>
<h3>Loadstring Reverser</h3>
<p>Paste a script containing an HTTP loadstring. LelSploit extracts the URL and retrieves the text response so you can inspect the source before using it.</p>
<pre>loadstring(game:HttpGet("https://example.com/script.lua"))()</pre>
<p>Large responses are streamed into the output field in chunks to avoid unnecessarily building one huge text value at once.</p>
<h3>Loadstring Creator</h3>
<p>Paste any valid HTTP or HTTPS raw URL and LelSploit creates the common HttpGet loadstring form:</p>
<pre>loadstring(game:HttpGet("https://example.com/raw-script.lua"))()</pre>
<h3>GitHub Rawifier</h3>
<p>Converts a normal GitHub <code>/blob/</code> URL into a <code>raw.githubusercontent.com</code> URL suitable for retrieving the file contents directly.</p>

<h2 id="fastflags">FastFlags and client modifications</h2>
<p>The FastFlags window contains four pages: FastFlags, Assets, Username, and Custom. FastFlag management is off by default. When enabled, LelSploit stores the selected flags in <code>fastflags.json</code> and synchronizes them into the current Roblox version's <code>ClientSettings/ClientAppSettings.json</code>.</p>
<ul>
<li>Rendering mode, MSAA, display scaling, Alt+Enter fullscreen, texture quality, mesh LOD, FRM quality, grey sky, voxelizer pause, grass distances/motion, and the Roblox framerate cap can be configured.</li>
<li>The Assets page manages a custom font, sounds, skyboxes, textures, and default R6 avatar meshes. Sources can be local files, HTTP/HTTPS URLs, public asset IDs, or <code>remove</code>.</li>
<li>The Username page stores and applies client-side username/verified/creator overrides through the local execution bridge.</li>
<li>The Custom page maps any relative Roblox resource path to a replacement source and keeps an original-file backup for reset.</li>
<li>Saved resource modifications are reapplied when LelSploit detects a new Roblox version folder.</li>
</ul>
<p>Preset changes that need a fresh client show the restart notice. Custom FastFlags are supplied through the live ClientSettings path while Roblox is running.</p>

<h2>Settings</h2>
<h3>Tab names</h3>
<p>The <b>Show .luau in tab names</b> option controls whether the source extension is displayed in the tab strip. It does not change the actual source filename logic.</p>
<h3>Close behavior and system tray</h3>
<p>Settings can choose whether closing LelSploit exits completely or keeps it running in the system tray. When tray mode is enabled, clicking the tray icon restores the existing editor session and the tray menu provides quick access to execution, Roblox controls, ScriptBlox, Tools, FastFlags/client mods, Extensions, Documentation, Settings, and Exit.</p>
<h3>Danger Zone</h3>
<p><b>Erase Data</b> removes the local contents of <code>workspace</code>, <code>logs</code>, and <code>autoexec</code>, together with LelSploit's local settings, FastFlags, saved scripts, and client-modification data. LelSploit asks for confirmation first.</p>

<h2 id="shortcuts">Keyboard shortcuts</h2>
<ul>
<li><b>Ctrl + Enter</b> — Execute the current tab.</li>
<li><b>Ctrl + O</b> — Open a script file.</li>
<li><b>Ctrl + S</b> — Save the current tab.</li>
<li><b>Ctrl + Shift + S</b> — Save the current tab as a new file.</li>
<li><b>F2</b> — Rename the current tab.</li>
</ul>

<h2>Organizing larger scripts</h2>
<p>A useful structure for a larger Luau script is:</p>
<pre>-- Services
local Players = game:GetService("Players")

-- State
local enabled = true

-- Helpers
local function log(message)
    print("[MyScript]", message)
end

-- Main behavior
local function start()
    if not enabled then
        return
    end
    log("Started")
end

start()</pre>
<ul>
<li>Resolve services once near the top.</li>
<li>Keep configuration/state together.</li>
<li>Put reusable logic in small functions.</li>
<li>Give functions names that describe what they do.</li>
<li>Return early when a required condition is missing.</li>
<li>Use clear output messages while testing.</li>
</ul>

<h2>Working with remote source</h2>
<p>Before running code loaded from a URL, inspect the response when possible. Remote content can change independently of the loadstring that points to it. The Loadstring Reverser exists specifically to make inspection easier.</p>
<p>For your own projects, raw GitHub links are convenient because the script remains readable in a normal repository while the raw URL can be consumed directly.</p>

<h2>Performance tips</h2>
<ul>
<li>Avoid extremely long single lines; they are expensive for code editors to lay out.</li>
<li>LelSploit may pause syntax colors for very large files or unusually long lines.</li>
<li>Large file loads and large remote responses are processed incrementally where practical.</li>
<li>Split unrelated experiments into separate tabs instead of growing one permanent scratch file.</li>
</ul>

<h2 id="troubleshooting">Troubleshooting</h2>
<h3>Attach waits for a long time</h3>
<ul>
<li>Confirm Roblox Player is running.</li>
<li>Wait until the client has fully opened before attaching.</li>
<li>If Roblox was closed during attach, start it again and retry.</li>
<li>Use Reattach after a client restart.</li>
</ul>
<h3>Execute does not produce the expected result</h3>
<ul>
<li>Confirm the correct tab is selected.</li>
<li>Verify the script itself has no syntax or runtime error.</li>
<li>Check that the APIs used by the script are available in the attached environment.</li>
</ul>
<h3>A remote script does not load</h3>
<ul>
<li>Make sure the URL is HTTP or HTTPS.</li>
<li>Use a raw file URL rather than a normal webpage when appropriate.</li>
<li>Try the Loadstring Reverser to inspect the returned response.</li>
<li>For GitHub files, use GitHub Rawifier on a <code>/blob/</code> URL.</li>
</ul>
<h3>FastFlags did not apply</h3>
<ul>
<li>Confirm FastFlag management is enabled.</li>
<li>Save the changes.</li>
<li>Restart Roblox when LelSploit says a restart is required.</li>
<li>Remember that the current Roblox client may no longer honor a particular flag.</li>
</ul>

<h2>Local files used by LelSploit</h2>
<ul>
<li><code>settings.json</code> — interface and behavior preferences.</li>
<li><code>fastflags.json</code> — saved FastFlag configuration.</li>
<li><code>saved_scripts.json</code> — ScriptBlox favorites and cached saved-script information.</li>
<li><code>icons/</code> — interface icons.</li>
<li><code>libls.dll</code> and dependency DLLs — local API runtime files stored beside LelSploit.</li>
</ul>

<h2>Final workflow</h2>
<ol>
<li>Start Roblox.</li>
<li>Attach.</li>
<li>Create or open a tab.</li>
<li>Write and review the Luau source.</li>
<li>Save anything you want to keep.</li>
<li>Execute the active tab.</li>
</ol>
"""


class DocumentationWindow(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.setWindowTitle("Documentation")
        self.resize(850, 700)
        self.setMinimumSize(640, 470)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "Documentation", (22, 12, 18, 16), 8)
        self.tabs = QTabWidget()
        self.tabs.setObjectName("documentationTabs")
        self.tabs.setDocumentMode(True)
        self.tabs.tabBar().setDrawBase(False)

        self.browser = self._make_browser(DOCUMENTATION_HTML)
        self.extension_browser = self._make_browser(EXTENSIONS_DOCUMENTATION_HTML)
        main_icon = lelsploit_icon()
        if not main_icon.isNull():
            self.tabs.addTab(self.browser, main_icon, "LelSploit")
        else:
            self.tabs.addTab(self.browser, "LelSploit")
        extension_icon = app_icon("extensions")
        if not extension_icon.isNull():
            self.tabs.addTab(self.extension_browser, extension_icon, "Extensions")
        else:
            self.tabs.addTab(self.extension_browser, "Extensions")
        layout.addWidget(self.tabs, 1)

        self.setStyleSheet("""
            QDialog { background: #08090a; color: #d7d7d7; }
            QTabWidget#documentationTabs { background: transparent; }
            QTabWidget#documentationTabs::pane { border: none; background: #0b0c0d; top: -1px; }
            QTabWidget#documentationTabs QTabBar { background: transparent; }
            QTabWidget#documentationTabs QTabBar::tab {
                background: #0c0c0e; color: #99999e; border: 1px solid #242428;
                border-bottom: none; padding: 7px 13px; margin-right: 4px;
                border-top-left-radius: 5px; border-top-right-radius: 5px;
            }
            QTabWidget#documentationTabs QTabBar::tab:hover { background: #141417; color: #dedee1; }
            QTabWidget#documentationTabs QTabBar::tab:selected { background: #18181c; color: #ffffff; border-color: #35353b; }
            QTextBrowser#documentationBrowser {
                background: #0b0c0d; color: #d7d7d7; border: none; border-radius: 0;
                padding: 8px 12px 8px 0; selection-background-color: #2b2b2b; selection-color: #ffffff;
            }
            QTextBrowser#documentationBrowser QWidget { background: #0b0c0d; }
            QTextBrowser#documentationBrowser QScrollBar:vertical { background: transparent; width: 8px; margin: 2px 0; }
            QTextBrowser#documentationBrowser QScrollBar::handle:vertical { background: #343434; border-radius: 4px; min-height: 28px; }
            QTextBrowser#documentationBrowser QScrollBar::handle:vertical:hover { background: #484848; }
            QTextBrowser#documentationBrowser QScrollBar::add-line:vertical,
            QTextBrowser#documentationBrowser QScrollBar::sub-line:vertical { height: 0; }
        """)
        apply_blur_style(self)

    @staticmethod
    def _make_browser(html):
        browser = QTextBrowser()
        browser.setObjectName("documentationBrowser")
        browser.setOpenExternalLinks(False)
        browser.setReadOnly(True)
        browser.setFrameShape(QFrame.Shape.NoFrame)
        browser.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        browser.viewport().setStyleSheet("background:#0b0c0d;border:none;")
        browser.setHtml(html)
        return browser

    def showEvent(self, event):
        super().showEvent(event)
        for browser in (self.browser, self.extension_browser):
            if browser.verticalScrollBar().value() < 0:
                browser.verticalScrollBar().setValue(0)


class SettingsWindow(QDialog):
    INSTALL_ITEMS = (
        ("Ask on first install", "ask"),
        ("Put in current code window", "current"),
        ("Put in current code window & run", "current_execute"),
        ("Put in new code window", "new"),
        ("Put in new code window & run (Recommended)", "new_execute"),
    )
    CLOSE_ITEMS = (
        ("Run in system tray", "tray"),
        ("Exit LelSploit", "exit"),
    )
    RESTART_ITEMS = (
        ("Rejoin same server", "server"),
        ("Rejoin same game", "game"),
        ("Just restart Roblox", "restart"),
    )
    PROXY_START_ITEMS = (
        ("Start on first launch", "first"),
        ("Always when possible", "always"),
        ("Never — start manually", "manual"),
    )

    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent
        self.setWindowTitle("Settings")
        self.resize(600, 790)
        self.setMinimumSize(550, 720)
        apply_window_icon(self)

        outer_layout = blur_content_layout(self, self, "Settings", (0, 0, 0, 0), 0)
        settings_scroll = QScrollArea()
        settings_scroll.setWidgetResizable(True)
        settings_scroll.setFrameShape(QFrame.Shape.NoFrame)
        settings_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        settings_scroll.setStyleSheet("QScrollArea { border: 0; background: transparent; } QScrollArea > QWidget > QWidget { background: transparent; }")
        settings_body = QWidget()
        layout = QVBoxLayout(settings_body)
        layout.setContentsMargins(22, 20, 22, 22)
        layout.setSpacing(14)
        settings_scroll.setWidget(settings_body)
        outer_layout.addWidget(settings_scroll, 1)

        install_title = QLabel("ScriptBlox install behavior")
        install_title.setStyleSheet("color: #eeeeee; font-size: 14px; font-weight: 600;")
        layout.addWidget(install_title)

        self.install_combo = LelComboBox()
        for label, value in self.INSTALL_ITEMS:
            self.install_combo.addItem(label, value)
        self.install_combo.currentIndexChanged.connect(self.save_install_behavior)
        self.install_combo.setFixedHeight(36)
        layout.addWidget(self.install_combo)
        layout.addSpacing(4)

        tabs_title = QLabel("Tabs")
        tabs_title.setStyleSheet("color: #eeeeee; font-size: 14px; font-weight: 600;")
        layout.addWidget(tabs_title)

        self.show_extension_check = BrightCheckBox("Show .luau in tab names")
        self.show_extension_check.toggled.connect(self.owner.set_show_tab_extension)
        layout.addWidget(self.show_extension_check)
        layout.addSpacing(8)

        editor_title = QLabel("Editor")
        editor_title.setStyleSheet("color: #eeeeee; font-size: 14px; font-weight: 600;")
        layout.addWidget(editor_title)
        self.syntax_colors_check = BrightCheckBox("Syntax colors")
        self.syntax_colors_check.toggled.connect(self.owner.set_syntax_colors_enabled)
        layout.addWidget(self.syntax_colors_check)
        self.syntax_color_buttons = {}
        syntax_grid = QGridLayout()
        syntax_grid.setContentsMargins(0, 4, 0, 4)
        syntax_grid.setHorizontalSpacing(36)
        syntax_grid.setVerticalSpacing(10)
        syntax_grid.setColumnStretch(0, 1)
        syntax_grid.setColumnStretch(1, 1)
        syntax_grid.setColumnMinimumWidth(0, 225)
        syntax_grid.setColumnMinimumWidth(1, 225)
        for index, (key, label_text, default) in enumerate((
            ("syntax_comment", "Comments", syntax_config("syntax_comment", "#7f936f")),
            ("syntax_keyword", "Keywords", syntax_config("syntax_keyword", "#86a8e7")),
            ("syntax_string", "Strings", syntax_config("syntax_string", "#a8c77a")),
            ("syntax_number", "Numbers", syntax_config("syntax_number", "#c9a56f")),
            ("syntax_operator", "Operators", syntax_config("syntax_operator", "#d7dadd")),
            ("syntax_builtin", "Built-ins", syntax_config("syntax_builtin", "#7db0d5")),
            ("syntax_function", "Functions", syntax_config("syntax_function", "#7daee0")),
            ("syntax_type", "Types / enums", syntax_config("syntax_type", "#b5a0d2")),
        )):
            host = QWidget()
            host.setObjectName("syntaxColorRow")
            host.setMinimumWidth(225)
            host.setFixedHeight(40)
            row = QHBoxLayout(host)
            row.setContentsMargins(0, 7, 0, 7)
            row.setSpacing(12)
            label = QLabel(label_text)
            label.setMinimumWidth(92)
            row.addWidget(label, 1)
            button = QPushButton()
            button.setFixedSize(72, 22)
            button.clicked.connect(lambda checked=False, k=key, d=default: self.pick_syntax_color(k, d))
            self.syntax_color_buttons[key] = (button, default)
            row.addWidget(button)
            syntax_grid.addWidget(host, index // 2, index % 2)
            syntax_grid.setRowMinimumHeight(index // 2, 40)
        layout.addLayout(syntax_grid)
        layout.addSpacing(14)

        app_title = QLabel("Application")
        app_title.setStyleSheet("color: #eeeeee; font-size: 14px; font-weight: 600;")
        layout.addWidget(app_title)
        close_row = QHBoxLayout()
        close_row.addWidget(QLabel("When LelSploit is closed"))
        close_row.addStretch(1)
        self.close_combo = LelComboBox()
        self.close_combo.setFixedSize(210, 34)
        for label, value in self.CLOSE_ITEMS:
            self.close_combo.addItem(label, value)
        self.close_combo.currentIndexChanged.connect(self.save_close_behavior)
        close_row.addWidget(self.close_combo)
        layout.addLayout(close_row)
        layout.addSpacing(8)

        restart_row = QHBoxLayout()
        restart_row.addWidget(QLabel("When Restart now is clicked"))
        restart_row.addStretch(1)
        self.restart_combo = LelComboBox()
        self.restart_combo.setFixedSize(210, 34)
        for label, value in self.RESTART_ITEMS:
            self.restart_combo.addItem(label, value)
        self.restart_combo.currentIndexChanged.connect(self.save_restart_behavior)
        restart_row.addWidget(self.restart_combo)
        layout.addLayout(restart_row)
        layout.addSpacing(8)

        proxy_row = QHBoxLayout()
        proxy_row.addWidget(QLabel("Local proxy start behavior"))
        proxy_row.addStretch(1)
        self.proxy_start_combo = LelComboBox()
        self.proxy_start_combo.setFixedSize(230, 34)
        for label, value in self.PROXY_START_ITEMS:
            self.proxy_start_combo.addItem(label, value)
        self.proxy_start_combo.currentIndexChanged.connect(self.save_proxy_start_behavior)
        proxy_row.addWidget(self.proxy_start_combo)
        layout.addLayout(proxy_row)

        self.capture_exclusion_check = BrightCheckBox("Hide from recordings/screenshare")
        self.capture_exclusion_check.toggled.connect(self.owner.set_screen_capture_hidden)
        self.capture_exclusion_check.setEnabled(sys.platform == "win32")
        layout.addWidget(self.capture_exclusion_check)

        self.tray_notice_check = BrightCheckBox("Show notification when LelSploit is sent to the system tray")
        self.tray_notice_check.toggled.connect(self.owner.set_tray_notice_enabled)
        layout.addWidget(self.tray_notice_check)
        layout.addSpacing(6)

        danger_separator = QFrame()
        danger_separator.setFrameShape(QFrame.Shape.HLine)
        danger_separator.setStyleSheet("color: #242424;")
        layout.addWidget(danger_separator)
        layout.addSpacing(3)

        danger_title = QLabel("Danger Zone")
        danger_title.setObjectName("dangerTitle")
        layout.addWidget(danger_title)

        self.erase_button = QPushButton("Erase Data")
        self.erase_button.setObjectName("dangerButton")
        self.erase_button.setFixedSize(124, 34)
        self.erase_button.clicked.connect(self.erase_data)
        layout.addWidget(self.erase_button, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addStretch(1)

        self.setStyleSheet("""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel, QCheckBox { background: transparent; }
            QWidget#syntaxColorRow { background: transparent; }
            QLabel { color: #b7bbbd; }
            QLabel#dangerTitle { color: #ef7b7b; font-size: 14px; font-weight: 600; }
            QPushButton { background: #101214; border: 1px solid #2d3235;
                border-radius: 4px; padding: 5px 10px; }
            QPushButton:hover { background: #1e2225; }
            QPushButton#dangerButton {
                background: #5a1f1f; color: #ffffff; border: 1px solid #8d3535;
                font-weight: 600;
            }
            QPushButton#dangerButton:hover { background: #742828; border-color: #a94747; }
        """)
        apply_blur_style(self)
        self.reload()

    def reload(self):
        behavior = self.owner.install_behavior()
        index = self.install_combo.findData(behavior)
        self.install_combo.blockSignals(True)
        self.install_combo.setCurrentIndex(max(0, index))
        self.install_combo.blockSignals(False)
        self.show_extension_check.blockSignals(True)
        self.show_extension_check.setChecked(self.owner.show_tab_extension())
        self.show_extension_check.blockSignals(False)
        self.syntax_colors_check.blockSignals(True)
        self.syntax_colors_check.setChecked(self.owner.syntax_colors_enabled)
        self.syntax_colors_check.setEnabled(not self.owner.loading)
        self.syntax_colors_check.blockSignals(False)
        for key, (button, default) in self.syntax_color_buttons.items():
            color = QColor(self.owner.syntax_color(key, default))
            lum = 0.2126 * color.red() + 0.7152 * color.green() + 0.0722 * color.blue()
            button.setText(color.name().upper())
            button.setStyleSheet(f"background:{color.name()};color:{'#090909' if lum > 150 else '#ffffff'};border:1px solid #3a3a3a;border-radius:4px;padding:0;")
        close_behavior = self.owner.close_behavior()
        close_index = self.close_combo.findData(close_behavior)
        self.close_combo.blockSignals(True)
        self.close_combo.setCurrentIndex(max(0, close_index))
        self.close_combo.blockSignals(False)
        restart_behavior = self.owner.fastflag_restart_behavior()
        restart_index = self.restart_combo.findData(restart_behavior)
        self.restart_combo.blockSignals(True)
        self.restart_combo.setCurrentIndex(max(0, restart_index))
        self.restart_combo.blockSignals(False)
        self.capture_exclusion_check.blockSignals(True)
        self.capture_exclusion_check.setChecked(self.owner.screen_capture_hidden())
        self.capture_exclusion_check.blockSignals(False)
        self.tray_notice_check.blockSignals(True)
        self.tray_notice_check.setChecked(self.owner.tray_notice_enabled())
        self.tray_notice_check.setEnabled(not self.owner.screen_capture_hidden())
        self.tray_notice_check.blockSignals(False)
        proxy_behavior = self.owner.proxy_start_behavior()
        proxy_index = self.proxy_start_combo.findData(proxy_behavior)
        self.proxy_start_combo.blockSignals(True)
        self.proxy_start_combo.setCurrentIndex(max(0, proxy_index))
        self.proxy_start_combo.blockSignals(False)

    def pick_syntax_color(self, key, default):
        chosen = QColorDialog.getColor(QColor(self.owner.syntax_color(key, default)), self, "Syntax color")
        if chosen.isValid():
            self.owner.set_syntax_color(key, chosen.name())
            self.reload()

    def save_install_behavior(self, _index):
        value = self.install_combo.currentData()
        if value:
            self.owner.settings.setValue("scriptblox/install_behavior", value)
            self.owner.settings.sync()

    def save_close_behavior(self, _index):
        value = self.close_combo.currentData()
        if value:
            self.owner.set_close_behavior(value)

    def save_restart_behavior(self, _index):
        value = self.restart_combo.currentData()
        if value:
            self.owner.set_fastflag_restart_behavior(value)

    def save_proxy_start_behavior(self, _index):
        value = self.proxy_start_combo.currentData()
        if value:
            self.owner.set_proxy_start_behavior(value)

    def erase_data(self):
        box = QMessageBox(self)
        box.setWindowTitle("Erase Data")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("Erase LelSploit data?")
        box.setInformativeText(
            "This permanently clears LelSploit user/generated data, including extensions, extension data, themes, workspace, logs, autoexec, FastFlags, settings, saved scripts, caches, proxy state, and client modification data. Required program/runtime files are kept."
        )
        erase = box.addButton("Erase Data", QMessageBox.ButtonRole.DestructiveRole)
        box.addButton(QMessageBox.StandardButton.Cancel)
        box.setDefaultButton(QMessageBox.StandardButton.Cancel)
        box.exec()
        if box.clickedButton() is not erase:
            return

        errors = self.owner.erase_local_data()
        if errors:
            QMessageBox.warning(
                self,
                "Erase Data",
                "Some data could not be erased:\n" + "\n".join(errors[:8]),
            )
            return
        self.reload()
        self.owner.log("LelSploit data erased.", "success")


class FastFlagCheckButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("fastFlagCheck")
        self.setCheckable(True)
        self.setFixedSize(22, 22)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAccessibleName("Toggle")
        self.toggled.connect(self._sync_mark)
        self._sync_mark(False)

    def _sync_mark(self, checked):
        self.setText("✓" if checked else "")


class BrightCheckBox(QWidget):
    toggled = pyqtSignal(bool)

    def __init__(self, text, parent=None):
        super().__init__(parent)
        self._checked = False
        self._hovered = False
        self.setObjectName("brightCheck")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setMinimumHeight(24)

        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(7)
        self.indicator = QLabel()
        self.indicator.setObjectName("brightCheckIndicator")
        self.indicator.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.indicator.setFixedSize(16, 16)
        self.indicator.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        row.addWidget(self.indicator)
        self.label = QLabel(str(text))
        self.label.setObjectName("brightCheckLabel")
        self.label.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        row.addWidget(self.label)
        row.addStretch(1)
        self._refresh()

    def isChecked(self):
        return self._checked

    def setChecked(self, checked):
        checked = bool(checked)
        if checked == self._checked:
            self._refresh()
            return
        self._checked = checked
        self._refresh()
        self.toggled.emit(checked)

    def toggle(self):
        self.setChecked(not self._checked)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self.rect().contains(event.position().toPoint()):
            self.toggle()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key.Key_Space, Qt.Key.Key_Return, Qt.Key.Key_Enter):
            self.toggle()
            event.accept()
            return
        super().keyPressEvent(event)

    def enterEvent(self, event):
        self._hovered = True
        self._refresh()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._hovered = False
        self._refresh()
        super().leaveEvent(event)

    def _refresh(self):
        if self._checked:
            border = "#79df91" if not self._hovered else "#a0efb0"
            background = "#1c6b35" if not self._hovered else "#247e40"
            self.indicator.setText("✓")
            self.indicator.setStyleSheet(
                f"QLabel {{ background:{background}; border:1px solid {border}; border-radius:4px; "
                "color:#ffffff; font-size:12px; font-weight:700; }}"
            )
            self.label.setStyleSheet("QLabel { color:#e6f7ea; background:transparent; }")
        else:
            border = "#555555" if not self._hovered else "#808080"
            background = "#101010" if not self._hovered else "#171717"
            self.indicator.setText("")
            self.indicator.setStyleSheet(
                f"QLabel {{ background:{background}; border:1px solid {border}; border-radius:4px; }}"
            )
            self.label.setStyleSheet("QLabel { color:#d8d8d8; background:transparent; }")


class ModificationSourceRow(QFrame):
    def __init__(self, window, display_name, target, kind="asset"):
        super().__init__()
        self.window = window
        self.display_name = display_name
        self.target = target
        self.kind = kind
        self.setObjectName("modRow")
        row = QHBoxLayout(self)
        row.setContentsMargins(10, 6, 10, 6)
        row.setSpacing(8)
        self.name_label = QLabel(display_name)
        self.name_label.setMinimumWidth(145)
        self.name_label.setMaximumWidth(190)
        row.addWidget(self.name_label)
        self.status = QLabel("Not Set")
        self.status.setObjectName("modStatus")
        self.status.setFixedWidth(58)
        row.addWidget(self.status)
        self.source = QLineEdit()
        self.source.setPlaceholderText('ID, URL, path, or "none"')
        self.source.returnPressed.connect(self.apply_source)
        row.addWidget(self.source, 1)
        self.browse = QPushButton("Browse")
        self.browse.setFixedWidth(76)
        self.browse.clicked.connect(self.browse_source)
        row.addWidget(self.browse)
        self.reset = QPushButton("Reset")
        self.reset.setObjectName("flatButton")
        self.reset.setFixedWidth(58)
        self.reset.clicked.connect(self.reset_source)
        row.addWidget(self.reset)
        self.refresh()

    def refresh(self):
        entry = find_modification(self.target)
        self.source.blockSignals(True)
        self.source.setText(str(entry.get("source", "")) if entry else "")
        self.source.blockSignals(False)
        self.status.setText("Applied" if entry else "Not Set")
        self.status.setProperty("applied", bool(entry))
        self.status.style().unpolish(self.status)
        self.status.style().polish(self.status)
        self.reset.setEnabled(bool(entry))

    def browse_source(self):
        path, _ = QFileDialog.getOpenFileName(self, f"Choose source for {self.display_name}", "", "All files (*)")
        if not path:
            return
        self.source.setText(path)
        self.apply_source()

    def apply_source(self):
        value = self.source.text().strip()
        if not value:
            return
        try:
            target = set_modification(self.display_name, self.target, value, self.kind)
            self.window.owner.log(f"Applied {self.display_name}.", "success")
            self.window.owner.set_fastflags_restart_required(self.window.owner.roblox_running is True)
            self.refresh()
        except Exception as exc:
            QMessageBox.warning(self, "Client modification", str(exc))
            self.window.owner.log(f"Could not apply {self.display_name}: {exc}", "warning")

    def reset_source(self):
        try:
            remove_modification(self.target)
            self.window.owner.log(f"Reset {self.display_name}.", "success")
            self.window.owner.set_fastflags_restart_required(self.window.owner.roblox_running is True)
        except Exception as exc:
            QMessageBox.warning(self, "Client modification", str(exc))
        self.refresh()


class CustomModificationDialog(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent.owner
        self.setWindowTitle("Add Custom Modification")
        self.resize(520, 250)
        apply_window_icon(self)
        layout = blur_content_layout(self, self, "Add Custom Modification", (14, 14, 14, 14), 10)

        def field_row(label, widget, button=None):
            row = QHBoxLayout()
            text = QLabel(label)
            text.setFixedWidth(92)
            row.addWidget(text)
            row.addWidget(widget, 1)
            if button is not None:
                row.addWidget(button)
            layout.addLayout(row)

        self.display_name = QLineEdit()
        self.display_name.setPlaceholderText("e.g. Custom Skybox")
        field_row("Display name", self.display_name)
        self.target = QLineEdit()
        self.target.setPlaceholderText(r"content\sounds\oof.ogg")
        target_browse = QPushButton("Browse")
        target_browse.clicked.connect(self.browse_target)
        field_row("Target path", self.target, target_browse)
        self.source = QLineEdit()
        self.source.setPlaceholderText('ID, URL, path, or "none"')
        source_browse = QPushButton("Browse")
        source_browse.clicked.connect(self.browse_source)
        field_row("Source", self.source, source_browse)
        buttons = QHBoxLayout()
        buttons.addStretch(1)
        cancel = QPushButton("Cancel")
        cancel.clicked.connect(self.reject)
        add = QPushButton("Add")
        add.setObjectName("primaryButton")
        add.clicked.connect(self.validate_and_accept)
        buttons.addWidget(cancel)
        buttons.addWidget(add)
        layout.addStretch(1)
        layout.addLayout(buttons)
        self.setStyleSheet("QLineEdit { min-height: 32px; background:#101010; border:1px solid #292929; border-radius:5px; padding:0 8px; }")
        apply_blur_style(self)

    def browse_target(self):
        root = roblox_resource_dir()
        if root is None:
            QMessageBox.warning(self, "Roblox directory", "Roblox Player installation was not found.")
            return
        path, _ = QFileDialog.getSaveFileName(self, "Choose target inside Roblox", str(root), "All files (*)")
        if not path:
            return
        try:
            rel = Path(path).resolve().relative_to(root.resolve())
        except (ValueError, OSError):
            QMessageBox.warning(self, "Target path", "Choose a target inside the current Roblox Player directory.")
            return
        self.target.setText(str(rel).replace("/", "\\"))

    def browse_source(self):
        path, _ = QFileDialog.getOpenFileName(self, "Choose modification source", "", "All files (*)")
        if path:
            self.source.setText(path)

    def validate_and_accept(self):
        if not self.display_name.text().strip():
            self.display_name.setFocus()
            return
        try:
            _normalise_target_path(self.target.text())
        except ValueError as exc:
            QMessageBox.warning(self, "Target path", str(exc))
            return
        if not self.source.text().strip():
            self.source.setFocus()
            return
        self.accept()


class JsonSyntaxHighlighter(QSyntaxHighlighter):
    def __init__(self, document):
        super().__init__(document)
        self.key_format = QTextCharFormat()
        self.key_format.setForeground(QColor("#89b4fa"))
        self.key_format.setFontWeight(QFont.Weight.DemiBold)
        self.string_format = QTextCharFormat()
        self.string_format.setForeground(QColor("#a6e3a1"))
        self.number_format = QTextCharFormat()
        self.number_format.setForeground(QColor("#fab387"))
        self.literal_format = QTextCharFormat()
        self.literal_format.setForeground(QColor("#cba6f7"))
        self.literal_format.setFontWeight(QFont.Weight.DemiBold)
        self.punctuation_format = QTextCharFormat()
        self.punctuation_format.setForeground(QColor("#89dceb"))
        self.escape_format = QTextCharFormat()
        self.escape_format.setForeground(QColor("#f9e2af"))
        self._string_re = re.compile(r'"(?:\\.|[^"\\])*"')
        self._key_re = re.compile(r'"(?:\\.|[^"\\])*"(?=\s*:)')
        self._escape_re = re.compile(r'\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4})')
        self._number_re = re.compile(r'(?<![\w.])-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w.])')
        self._literal_re = re.compile(r'\b(?:true|false|null)\b')
        self._punctuation_re = re.compile(r'[{}\[\],:]')

    def highlightBlock(self, text):
        for match in self._punctuation_re.finditer(text):
            self.setFormat(match.start(), match.end() - match.start(), self.punctuation_format)
        for match in self._number_re.finditer(text):
            self.setFormat(match.start(), match.end() - match.start(), self.number_format)
        for match in self._literal_re.finditer(text):
            self.setFormat(match.start(), match.end() - match.start(), self.literal_format)
        string_ranges = []
        for match in self._string_re.finditer(text):
            string_ranges.append((match.start(), match.end()))
            self.setFormat(match.start(), match.end() - match.start(), self.string_format)
        for match in self._key_re.finditer(text):
            self.setFormat(match.start(), match.end() - match.start(), self.key_format)
        for start, end in string_ranges:
            fragment = text[start:end]
            for match in self._escape_re.finditer(fragment):
                self.setFormat(start + match.start(), match.end() - match.start(), self.escape_format)


class FastFlagsWindow(QDialog):
    MSAA_ITEMS = (("Default", None), ("1x", "1"), ("2x", "2"), ("4x", "4"))
    TEXTURE_ITEMS = (("Default", None), ("Level 0", "0"), ("Level 1", "1"), ("Level 2", "2"), ("Level 3", "3"))
    RENDER_ITEMS = (("Default", None), ("D3D11", "D3D11"), ("Vulkan", "Vulkan"), ("OpenGL", "OpenGL"))

    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent
        self.current_flags = {}
        self._baseline_flags = {}
        self._baseline_enabled = False
        self._baseline_fps = 0
        self._baseline_custom_flags = {}
        self._baseline_username_settings = {}
        self._reloading = False
        self.asset_rows = []
        self.auto_save_timer = QTimer(self)
        self.auto_save_timer.setSingleShot(True)
        self.auto_save_timer.setInterval(260)
        self.auto_save_timer.timeout.connect(lambda: self.save_changes(quiet=True))
        self.username_save_timer = QTimer(self)
        self.username_save_timer.setSingleShot(True)
        self.username_save_timer.setInterval(220)
        self.username_save_timer.timeout.connect(self.persist_username_spoofer)
        self.setObjectName("fastFlagsWindow")
        self.setWindowTitle("FastFlags")
        self.resize(980, 700)
        self.setMinimumSize(780, 540)
        apply_window_icon(self)
        outer = blur_content_layout(self, self, "FastFlags", (14, 12, 14, 14), 9)

        self.attached_banner = QFrame()
        self.attached_banner.setObjectName("attachedWarning")
        attached_row = QHBoxLayout(self.attached_banner)
        attached_row.setContentsMargins(11, 8, 11, 8)
        attached_row.setSpacing(8)
        self.attached_label = QLabel("")
        self.attached_label.setTextFormat(Qt.TextFormat.RichText)
        self.attached_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        self.attached_label.setOpenExternalLinks(False)
        self.attached_label.linkActivated.connect(self.owner.handle_fastflags_mode_link)
        attached_row.addWidget(self.attached_label, 1)
        outer.addWidget(self.attached_banner)

        nav = QHBoxLayout()
        nav.setSpacing(5)
        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)
        self.nav_buttons = []
        for index, label in enumerate(("FastFlags", "Custom Flags", "Assets", "Username", "Custom")):
            button = QPushButton(label)
            button.setObjectName("clientNav")
            button.setCheckable(True)
            button.setFixedHeight(31)
            button.clicked.connect(lambda checked=False, i=index: self.stack.setCurrentIndex(i))
            self.nav_group.addButton(button)
            self.nav_buttons.append(button)
            nav.addWidget(button)
        nav.addStretch(1)
        outer.addLayout(nav)

        self.stack = QStackedWidget()
        self.stack.setObjectName("clientStack")
        self.stack.setAutoFillBackground(False)
        self.stack.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.stack.addWidget(self.build_fastflag_page())
        self.stack.addWidget(self.build_custom_fastflags_page())
        self.stack.addWidget(self.build_assets_page())
        self.stack.addWidget(self.build_username_page())
        self.stack.addWidget(self.build_custom_page())
        outer.addWidget(self.stack, 1)
        self.nav_buttons[0].setChecked(True)

        self.restart_bar = QFrame()
        self.restart_bar.setObjectName("restartBar")
        restart_layout = QHBoxLayout(self.restart_bar)
        restart_layout.setContentsMargins(11, 7, 11, 7)
        self.restart_label = QLabel('Restart Roblox to apply changes. <a href="restart" style="color:#9ec5ff;text-decoration:none;"><b>Restart now</b></a>')
        self.restart_label.setTextFormat(Qt.TextFormat.RichText)
        self.restart_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        self.restart_label.setOpenExternalLinks(False)
        self.restart_label.linkActivated.connect(self.restart_now)
        restart_layout.addWidget(self.restart_label)
        restart_layout.addStretch(1)
        outer.addWidget(self.restart_bar)

        self.setStyleSheet(r'''
            QDialog#fastFlagsWindow { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QCheckBox { background:transparent; color:#f1f1f1; spacing:7px; }
            QCheckBox::indicator { width:16px; height:16px; border:1px solid #696969; border-radius:3px; background:#090909; }
            QCheckBox::indicator:hover { border-color:#a0a0a0; background:#121212; }
            QCheckBox::indicator:checked { border-color:#8be3a5; background:#3c995d; }
            QPushButton { background:#111111; color:#e7e7e7; border:1px solid #292929; border-radius:5px; padding:6px 10px; }
            QPushButton:hover { background:#191919; border-color:#3a3a3a; }
            QPushButton#clientNav { background:transparent; border:0; color:#999; padding:5px 12px; }
            QPushButton#clientNav:hover { color:#eee; background:#101010; }
            QPushButton#clientNav:checked { color:#fff; background:#171717; }
            QStackedWidget#clientStack { border:0; background:transparent; }
            QStackedWidget#clientStack > QWidget { border:0; background:transparent; }
            QWidget#fastFlagsPage, QWidget#customFastFlagsPage, QWidget#assetsPage, QWidget#usernamePage, QWidget#customModsPage { background:transparent; border:0; }
            QFrame#fastFlagCard, QFrame#modRow { background:#0b0b0b; border:1px solid #242424; border-radius:7px; }
            QFrame#fastFlagManagerCard { background:#0d0d0d; border:1px solid #2b2b2b; border-radius:7px; }
            QLabel#sectionTitle { color:#8e8e8e; font-size:11px; font-weight:600; padding:7px 2px 2px; }
            QLabel#modStatus { color:#888; font-style:italic; }
            QLabel#modStatus[applied="true"] { color:#7fce91; font-style:normal; }
            QLineEdit, QSpinBox { background:#0d0d0e; color:#ececec; border:1px solid #2a2a2c; border-radius:6px; min-height:32px; padding:0 9px; }
            QLineEdit:focus, QSpinBox:focus { border-color:#454548; background:#101012; }
            QSlider { background:transparent; border:none; }
            QSlider::groove:horizontal { height:4px; background:#2c2c2f; border:none; border-radius:2px; }
            QSlider::sub-page:horizontal { background:#56565b; border-radius:2px; }
            QSlider::add-page:horizontal { background:#242426; border-radius:2px; }
            QSlider::handle:horizontal { width:12px; margin:-4px 0; background:#8a8a8f; border:1px solid #a0a0a4; border-radius:6px; }
            QSlider::handle:horizontal:hover { background:#a8a8ad; border-color:#c0c0c4; }
            QFrame#restartBar { background:#0c0c0d; border:1px solid #2a2a2c; border-radius:7px; }
            QFrame#attachedWarning { background:#18130a; border:1px solid #55401b; border-radius:7px; }
            QFrame#attachedWarning QLabel { color:#e8d7ad; background:transparent; }
            QPlainTextEdit#customFlagEditor { background:#09090a; color:#e8e8e8; border:1px solid #28282b; border-radius:7px; padding:8px; selection-background-color:#303033; }
            QPlainTextEdit#customFlagEditor[invalid="true"] { border-color:#8b3a3a; }
            QLabel#customFlagStatus { color:#888; background:transparent; }
            QTableWidget#customFlagTable { background:transparent; alternate-background-color:transparent; border:1px solid #252528; border-radius:7px; gridline-color:transparent; selection-background-color:#18191b; selection-color:#f0f0f0; }
            QTableWidget#customFlagTable::item { padding:6px 7px; border-bottom:1px solid #151517; }
            QHeaderView::section { background:#0d0d0f; color:#bcbcbc; border:0; border-bottom:1px solid #252528; padding:7px; font-weight:600; }
            QPushButton#hotkeyButton { background:#101012; border:1px solid #2d2d31; border-radius:5px; padding:0 9px; color:#d6d6d6; }
            QPushButton#hotkeyButton:hover { background:#171719; border-color:#45454a; color:#ffffff; }
            QPushButton#hotkeyResetButton { background:transparent; border:1px solid transparent; border-radius:5px; padding:0; }
            QPushButton#hotkeyResetButton:hover { background:#171719; border-color:#303034; }
            QPushButton#hotkeyResetButton:disabled { background:transparent; border-color:transparent; }
            QPushButton#fastFlagCheck { background:#080808; color:#fff; border:1px solid #444; border-radius:4px; padding:0; font-weight:700; }
            QPushButton#fastFlagCheck:checked { background:#356846; border-color:#6da17d; }
            QPushButton#flatButton, QPushButton#resetLink { background:transparent; border:0; color:#999; }
            QPushButton#flatButton:hover, QPushButton#resetLink:hover { color:#eee; background:transparent; }
            QScrollArea, QScrollArea > QWidget > QWidget { border:0; background:transparent; }
            QScrollBar:vertical { width:9px; background:#070707; }
            QScrollBar::handle:vertical { background:#333; border-radius:4px; min-height:25px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0; }
        ''')
        apply_blur_style(self)
        self.reload()

    @staticmethod
    def row_card(label, control, prominent=False):
        card = QFrame()
        card.setObjectName("fastFlagManagerCard" if prominent else "fastFlagCard")
        card.setMinimumHeight(48)
        row = QHBoxLayout(card)
        row.setContentsMargins(12, 8, 12, 8)
        row.setSpacing(10)
        text = QLabel(label)
        if prominent:
            text.setStyleSheet("color:#eee;font-weight:600;background:transparent;")
        row.addWidget(text, 1)
        row.addWidget(control, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        return card

    def build_fastflag_page(self):
        page = QWidget()
        page.setObjectName("fastFlagsPage")
        page.setAutoFillBackground(False)
        page_layout = QVBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(1, 1, 1, 1)
        layout.setSpacing(8)
        self.manager_check = FastFlagCheckButton()
        layout.addWidget(self.row_card("Allow LelSploit to manage FastFlags", self.manager_check, True))
        self.managed_panel = QWidget()
        managed = QVBoxLayout(self.managed_panel)
        managed.setContentsMargins(0, 0, 0, 0)
        managed.setSpacing(7)
        title = QLabel("Rendering")
        title.setObjectName("sectionTitle")
        managed.addWidget(title)
        self.render_combo = LelComboBox(); self.render_combo.setFixedWidth(190)
        for label, value in self.RENDER_ITEMS: self.render_combo.addItem(label, value)
        managed.addWidget(self.row_card("Rendering Mode", self.render_combo))
        self.msaa_combo = LelComboBox(); self.msaa_combo.setFixedWidth(190)
        for label, value in self.MSAA_ITEMS: self.msaa_combo.addItem(label, value)
        managed.addWidget(self.row_card("MSAA Level", self.msaa_combo))
        self.scaling_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Fix Display Scaling", self.scaling_check))
        self.fullscreen_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Alt+Enter Fullscreen", self.fullscreen_check))
        self.texture_combo = LelComboBox(); self.texture_combo.setFixedWidth(190)
        for label, value in self.TEXTURE_ITEMS: self.texture_combo.addItem(label, value)
        managed.addWidget(self.row_card("Texture Quality", self.texture_combo))

        title = QLabel("Quality overrides"); title.setObjectName("sectionTitle"); managed.addWidget(title)
        self.mesh_check = FastFlagCheckButton()
        self.mesh_slider = JumpSlider(Qt.Orientation.Horizontal); self.mesh_slider.setRange(0, 4); self.mesh_slider.setFixedWidth(170)
        self.mesh_value = QLabel("Default"); self.mesh_value.setFixedWidth(55)
        mesh_ctl = QWidget(); mesh_ctl.setStyleSheet("background:transparent;border:none;"); mesh_row = QHBoxLayout(mesh_ctl); mesh_row.setContentsMargins(0,0,0,0); mesh_row.setSpacing(8)
        mesh_row.addWidget(self.mesh_check); mesh_row.addWidget(self.mesh_slider); mesh_row.addWidget(self.mesh_value)
        managed.addWidget(self.row_card("Mesh LOD Override", mesh_ctl))
        self.frm_check = FastFlagCheckButton()
        self.frm_slider = JumpSlider(Qt.Orientation.Horizontal); self.frm_slider.setRange(0, 21); self.frm_slider.setFixedWidth(170)
        self.frm_value = QLabel("Default"); self.frm_value.setFixedWidth(62)
        frm_ctl = QWidget(); frm_ctl.setStyleSheet("background:transparent;border:none;"); frm_row = QHBoxLayout(frm_ctl); frm_row.setContentsMargins(0,0,0,0); frm_row.setSpacing(8)
        frm_row.addWidget(self.frm_check); frm_row.addWidget(self.frm_slider); frm_row.addWidget(self.frm_value)
        managed.addWidget(self.row_card("FRM Quality Override", frm_ctl))
        self.grey_sky_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Grey Sky (Debug)", self.grey_sky_check))
        self.pause_voxelizer_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Pause Voxelizer", self.pause_voxelizer_check))

        title = QLabel("Environment"); title.setObjectName("sectionTitle"); managed.addWidget(title)
        self.grass_max = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Distance Max", self.grass_max))
        self.grass_min = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Distance Min", self.grass_min))
        self.grass_motion = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Motion Factor", self.grass_motion))
        self.fps_cap = QSpinBox(); self.fps_cap.setRange(0, 1000); self.fps_cap.setSpecialValueText("Default"); self.fps_cap.setFixedWidth(190)
        managed.addWidget(self.row_card("Framerate Cap (FPS)", self.fps_cap))
        self.reset_button = QPushButton("Reset configuration"); self.reset_button.setObjectName("resetLink"); self.reset_button.clicked.connect(self.reset_configuration)
        managed.addWidget(self.reset_button, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(self.managed_panel)
        layout.addStretch(1)
        scroll.setWidget(content)
        page_layout.addWidget(scroll, 1)
        self.manager_check.toggled.connect(self.on_manager_toggled)
        controls = [self.render_combo, self.msaa_combo, self.scaling_check, self.fullscreen_check, self.texture_combo,
                    self.mesh_check, self.mesh_slider, self.frm_check, self.frm_slider, self.grey_sky_check,
                    self.pause_voxelizer_check, self.grass_max, self.grass_min, self.grass_motion, self.fps_cap]
        for control in controls:
            signal = getattr(control, "toggled", None) or getattr(control, "valueChanged", None) or getattr(control, "currentIndexChanged", None)
            if signal is not None:
                signal.connect(self.update_change_state)
        self.mesh_slider.valueChanged.connect(self._update_slider_labels)
        self.frm_slider.valueChanged.connect(self._update_slider_labels)
        return page

    def build_custom_fastflags_page(self):
        page = QWidget()
        page.setObjectName("customFastFlagsPage")
        page.setAutoFillBackground(False)
        root = QVBoxLayout(page)
        root.setContentsMargins(4, 4, 4, 4)
        root.setSpacing(10)

        header = QHBoxLayout()
        title = QLabel("Custom FastFlags")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#f0f0f0;background:transparent;")
        header.addWidget(title)
        header.addStretch(1)
        root.addLayout(header)

        self.custom_flag_status = QLabel("")
        self.custom_flag_status.setObjectName("customFlagStatus")
        self.custom_flag_status.setStyleSheet("color:#e06c75;background:transparent;")
        self.custom_flag_status.hide()
        root.addWidget(self.custom_flag_status)

        toolbar_top = QHBoxLayout()
        toolbar_top.setSpacing(7)
        self.custom_flag_search = QLineEdit()
        self.custom_flag_search.setPlaceholderText("Search custom FastFlags…")
        self.custom_flag_search.textChanged.connect(self._filter_custom_flag_rows)
        self.fastflag_list_button = QPushButton("FastFlags List")
        list_icon = app_icon("fflaglist")
        if not list_icon.isNull():
            self.fastflag_list_button.setIcon(list_icon)
            self.fastflag_list_button.setIconSize(QSize(16, 16))
        self.fastflag_list_button.clicked.connect(self.open_fastflag_list)
        toolbar_top.addWidget(self.custom_flag_search, 1)
        toolbar_top.addWidget(self.fastflag_list_button)
        root.addLayout(toolbar_top)

        toolbar_actions = QHBoxLayout()
        toolbar_actions.setSpacing(7)
        add_button = QPushButton("Add flag")
        import_button = QPushButton("Import JSON")
        export_button = QPushButton("Export JSON")
        add_button.clicked.connect(self.add_custom_fastflag)
        import_button.clicked.connect(self.import_custom_fastflags)
        export_button.clicked.connect(self.export_custom_fastflags)
        toolbar_actions.addWidget(add_button)
        toolbar_actions.addStretch(1)
        toolbar_actions.addWidget(import_button)
        toolbar_actions.addWidget(export_button)
        root.addLayout(toolbar_actions)

        self.custom_flag_table = QTableWidget(0, 4)
        self.custom_flag_table.setObjectName("customFlagTable")
        self.custom_flag_table.setAutoFillBackground(False)
        self.custom_flag_table.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.custom_flag_table.viewport().setAutoFillBackground(False)
        self.custom_flag_table.viewport().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.custom_flag_table.viewport().setStyleSheet("background:transparent;border:0;")
        self.custom_flag_table.setHorizontalHeaderLabels(("Name", "Value", "Status", "Hotkey"))
        self.custom_flag_table.verticalHeader().setVisible(False)
        self.custom_flag_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.custom_flag_table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.custom_flag_table.setAlternatingRowColors(False)
        self.custom_flag_table.setShowGrid(False)
        self.custom_flag_table.setEditTriggers(
            QAbstractItemView.EditTrigger.DoubleClicked
            | QAbstractItemView.EditTrigger.SelectedClicked
            | QAbstractItemView.EditTrigger.EditKeyPressed
        )
        self.custom_flag_table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.custom_flag_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.custom_flag_table.customContextMenuRequested.connect(self._remove_custom_flag_at_position)
        header_view = self.custom_flag_table.horizontalHeader()
        header_view.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header_view.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header_view.setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        header_view.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        self.custom_flag_table.setColumnWidth(1, 170)
        self.custom_flag_table.setColumnWidth(2, 76)
        self.custom_flag_table.setColumnWidth(3, 310)
        self.custom_flag_table.cellChanged.connect(self._custom_flag_table_changed)
        self.custom_flag_table.cellClicked.connect(self._begin_custom_flag_edit)
        self.custom_flag_table.verticalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Fixed)
        self.custom_flag_table.verticalHeader().setMinimumSectionSize(54)
        self.custom_flag_table.verticalHeader().setDefaultSectionSize(54)
        root.addWidget(self.custom_flag_table, 1)

        return page

    def _parse_custom_fastflag_editor(self):
        return normalize_fastflags(self.owner.load_custom_fastflags())

    def _set_custom_flag_status(self, text="", invalid=False):
        self.custom_flag_status.setText(text if invalid else "")
        self.custom_flag_status.setVisible(bool(invalid and text))

    def _custom_flags_from_table(self):
        flags = {}
        for row in range(self.custom_flag_table.rowCount()):
            name_item = self.custom_flag_table.item(row, 0)
            value_item = self.custom_flag_table.item(row, 1)
            name = name_item.text().strip() if name_item else ""
            if name:
                flags[name] = value_item.text() if value_item else ""
        return normalize_fastflags(flags)

    def _sync_custom_json_from_saved(self, flags=None):
        return

    def _load_custom_flag_table(self):
        if not hasattr(self, "custom_flag_table"):
            return
        flags = normalize_fastflags(self.owner.load_custom_fastflags())
        state = self.owner.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        bindings = state.get("keybinds", {}) if isinstance(state.get("keybinds"), dict) else {}
        self.custom_flag_table.blockSignals(True)
        try:
            self.custom_flag_table.clearContents()
            self.custom_flag_table.setRowCount(len(flags))
            self._custom_status_buttons = {}
            self._custom_hotkey_buttons = {}
            self._custom_hotkey_reset_buttons = {}
            for row, (name, value) in enumerate(sorted(flags.items(), key=lambda item: item[0].casefold())):
                name_item = QTableWidgetItem(name)
                name_item.setData(Qt.ItemDataRole.UserRole, name)
                name_item.setToolTip("Click to rename this FastFlag")
                value_item = QTableWidgetItem(str(value))
                value_item.setToolTip("Click to edit this value")
                self.custom_flag_table.setItem(row, 0, name_item)
                self.custom_flag_table.setItem(row, 1, value_item)

                status_host = QWidget()
                status_host.setStyleSheet("background:transparent;")
                status_layout = QHBoxLayout(status_host)
                status_layout.setContentsMargins(0, 0, 0, 0)
                status_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
                status_button = FastFlagCheckButton()
                status_button.setChecked(name not in disabled)
                status_button.setToolTip("Enabled" if name not in disabled else "Disabled")
                status_button.toggled.connect(lambda checked, n=name: self._set_custom_flag_enabled(n, checked))
                status_layout.addWidget(status_button)
                self.custom_flag_table.setCellWidget(row, 2, status_host)
                self._custom_status_buttons[name] = status_button

                self.custom_flag_table.setRowHeight(row, 54)
                hotkey_host = QWidget()
                hotkey_host.setStyleSheet("background:transparent;")
                hotkey_layout = QHBoxLayout(hotkey_host)
                hotkey_layout.setContentsMargins(6, 8, 6, 8)
                hotkey_layout.setSpacing(6)
                hotkey_layout.setAlignment(Qt.AlignmentFlag.AlignVCenter)
                hotkey_button = QPushButton(hotkey_text(bindings.get(name)))
                hotkey_button.setMinimumWidth(225)
                hotkey_button.setFixedHeight(30)
                hotkey_button.setObjectName("hotkeyButton")
                hotkey_button.setToolTip("Click to set a global hotkey")
                hotkey_button.clicked.connect(lambda checked=False, n=name: self.edit_custom_fastflag_hotkey(n))
                hotkey_layout.addWidget(hotkey_button, 1)
                hotkey_reset = QPushButton()
                hotkey_reset.setObjectName("hotkeyResetButton")
                hotkey_reset.setToolTip("Clear hotkey")
                hotkey_reset.setFixedSize(30, 30)
                hotkey_reset.setFocusPolicy(Qt.FocusPolicy.NoFocus)
                reset_icon = app_icon("reattach")
                if not reset_icon.isNull():
                    hotkey_reset.setIcon(reset_icon)
                    hotkey_reset.setIconSize(QSize(13, 13))
                hotkey_reset.setEnabled(name in bindings)
                hotkey_reset.clicked.connect(lambda checked=False, n=name: self.clear_custom_fastflag_hotkey(n))
                hotkey_layout.addWidget(hotkey_reset)
                self.custom_flag_table.setCellWidget(row, 3, hotkey_host)
                self._custom_hotkey_buttons[name] = hotkey_button
                self._custom_hotkey_reset_buttons[name] = hotkey_reset
        finally:
            self.custom_flag_table.blockSignals(False)
        self.custom_flag_table.horizontalScrollBar().setValue(0)
        self._filter_custom_flag_rows(self.custom_flag_search.text() if hasattr(self, "custom_flag_search") else "")

    def _filter_custom_flag_rows(self, text=""):
        if not hasattr(self, "custom_flag_table"):
            return
        query = str(text or "").strip().casefold()
        for row in range(self.custom_flag_table.rowCount()):
            name_item = self.custom_flag_table.item(row, 0)
            value_item = self.custom_flag_table.item(row, 1)
            haystack = ((name_item.text() if name_item else "") + " " + (value_item.text() if value_item else "")).casefold()
            self.custom_flag_table.setRowHidden(row, bool(query and query not in haystack))

    def _persist_custom_flag_mapping(self, flags):
        flags = normalize_fastflags(flags)
        previous = normalize_fastflags(self.owner.load_custom_fastflags())
        if flags == previous:
            return False
        proxy_was_needed = self.owner.proxy_features_needed()
        self.owner.save_custom_fastflags(flags)
        state = self.owner.save_custom_fastflag_state(self.owner.load_custom_fastflag_state())
        self.owner.refresh_custom_fastflag_hotkeys()
        self._baseline_custom_flags = dict(flags)
        effective = self.owner.load_effective_fastflags()
        prime_windows_fastflag_cache(effective)
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        proxy_is_needed = self.owner.proxy_features_needed()
        if self.owner.roblox_running is True and (not self.owner.roblox_proxy_active or proxy_was_needed != proxy_is_needed):
            self.owner.set_fastflags_restart_required(True)
        self._sync_custom_json_from_saved(flags)
        return True

    def _begin_custom_flag_edit(self, row, column):
        if column not in (0, 1) or self._reloading:
            return
        item = self.custom_flag_table.item(row, column)
        if item is not None:
            QTimer.singleShot(0, lambda i=item: self.custom_flag_table.editItem(i))

    def _rename_custom_fastflag(self, old_name, new_name, value):
        old_name = str(old_name or "").strip()
        new_name = str(new_name or "").strip()
        if not old_name or not new_name or old_name == new_name:
            return False
        flags = self.owner.load_custom_fastflags()
        if new_name in flags and new_name != old_name:
            return False
        state = self.owner.load_custom_fastflag_state()
        flags.pop(old_name, None)
        flags[new_name] = value
        disabled = set(state.get("disabled", []))
        if old_name in disabled:
            disabled.discard(old_name)
            disabled.add(new_name)
        bindings = dict(state.get("keybinds", {}))
        binding = bindings.pop(old_name, None)
        if binding is not None:
            bindings[new_name] = binding
        self.owner.save_custom_fastflags(flags)
        self.owner.save_custom_fastflag_state({"disabled": sorted(disabled), "keybinds": bindings})
        self.owner.refresh_custom_fastflag_hotkeys()
        self._baseline_custom_flags = normalize_fastflags(flags)
        prime_windows_fastflag_cache(self.owner.load_effective_fastflags())
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        if self.owner.roblox_running is True and not self.owner.roblox_proxy_active:
            self.owner.set_fastflags_restart_required(True)
        self._sync_custom_json_from_saved(flags)
        return True

    def _custom_flag_table_changed(self, row, column):
        if self._reloading or column not in (0, 1):
            return
        name_item = self.custom_flag_table.item(row, 0)
        value_item = self.custom_flag_table.item(row, 1)
        if name_item is None:
            return
        current_name = name_item.text().strip()
        original_name = str(name_item.data(Qt.ItemDataRole.UserRole) or current_name).strip()
        value = value_item.text() if value_item is not None else ""
        if column == 0:
            if not current_name:
                self.custom_flag_table.blockSignals(True)
                try:
                    name_item.setText(original_name)
                finally:
                    self.custom_flag_table.blockSignals(False)
                return
            if current_name != original_name:
                if current_name in self.owner.load_custom_fastflags():
                    self.custom_flag_table.blockSignals(True)
                    try:
                        name_item.setText(original_name)
                    finally:
                        self.custom_flag_table.blockSignals(False)
                    self._set_custom_flag_status("A FastFlag with that name already exists.", True)
                    return
                if self._rename_custom_fastflag(original_name, current_name, value):
                    self._set_custom_flag_status()
                    self._load_custom_flag_table()
                return
        flags = self.owner.load_custom_fastflags()
        if current_name:
            flags[current_name] = value
            self._persist_custom_flag_mapping(flags)


    def _set_custom_flag_enabled(self, name, enabled):
        if self._reloading:
            return
        state = self.owner.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        if enabled:
            disabled.discard(name)
        else:
            disabled.add(name)
        state["disabled"] = sorted(disabled)
        self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        if self.owner.roblox_running is True and not self.owner.roblox_proxy_active:
            self.owner.set_fastflags_restart_required(True)
        button = getattr(self, "_custom_status_buttons", {}).get(name)
        if button is not None:
            button.setToolTip("Enabled" if enabled else "Disabled")

    def clear_custom_fastflag_hotkey(self, name):
        state = self.owner.load_custom_fastflag_state()
        bindings = dict(state.get("keybinds", {}))
        if name not in bindings:
            return
        bindings.pop(name, None)
        state["keybinds"] = bindings
        state = self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        button = getattr(self, "_custom_hotkey_buttons", {}).get(name)
        reset = getattr(self, "_custom_hotkey_reset_buttons", {}).get(name)
        if button is not None:
            button.setText(hotkey_text(None))
        if reset is not None:
            reset.setEnabled(False)

    def add_catalog_fastflags(self, additions):
        additions = normalize_fastflags(additions)
        if not additions:
            return
        flags = self.owner.load_custom_fastflags()
        flags.update(additions)
        self._persist_custom_flag_mapping(flags)
        self._load_custom_flag_table()

    def open_fastflag_list(self):
        dialog = FastFlagListDialog(self)
        dialog.exec()

    def edit_custom_fastflag_hotkey(self, name):
        if sys.platform != "win32":
            QMessageBox.information(self, "FastFlag Hotkey", "Global FastFlag hotkeys are currently available on Windows.")
            return
        dialog = FastFlagHotkeyCaptureDialog(name, self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        state = self.owner.load_custom_fastflag_state()
        bindings = dict(state.get("keybinds", {}))
        if dialog.clear_requested:
            bindings.pop(name, None)
        elif dialog.binding is not None:
            bindings[name] = dialog.binding
        state["keybinds"] = bindings
        state = self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        button = getattr(self, "_custom_hotkey_buttons", {}).get(name)
        reset = getattr(self, "_custom_hotkey_reset_buttons", {}).get(name)
        current_binding = state.get("keybinds", {}).get(name)
        if button is not None:
            button.setText(hotkey_text(current_binding))
        if reset is not None:
            reset.setEnabled(current_binding is not None)

    def add_custom_fastflag(self):
        catalog = useful_fastflag_catalog()
        dialog = QDialog(self)
        dialog.setObjectName("addCustomFastFlagDialog")
        dialog.setWindowTitle("Add Custom FastFlag")
        dialog.resize(570, 390)
        dialog.setMinimumSize(500, 330)
        apply_window_icon(dialog)
        root = blur_content_layout(dialog, dialog, "Add Custom FastFlag", (16, 12, 16, 16), 9)

        name = QLineEdit()
        name.setPlaceholderText("FastFlag name — type anything or choose a suggestion")
        root.addWidget(name)
        suggestions = QListWidget()
        suggestions.setObjectName("fastFlagSuggestions")
        suggestions.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        root.addWidget(suggestions, 1)
        value = QLineEdit()
        value.setPlaceholderText("Value")
        root.addWidget(value)

        info = QLabel("The list contains curated suggestions. Any other FastFlag name is still accepted.")
        info.setStyleSheet("color:#85858a;background:transparent;")
        info.setWordWrap(True)
        root.addWidget(info)

        actions = QHBoxLayout()
        add = QPushButton("Add")
        cancel = QPushButton("Cancel")
        actions.addStretch(1)
        actions.addWidget(cancel)
        actions.addWidget(add)
        root.addLayout(actions)

        def update_suggestions(text_value=""):
            query = str(text_value or "").strip().casefold()
            suggestions.clear()
            matches = []
            for flag_name, meta in catalog.items():
                haystack = (flag_name + " " + str(meta.get("category", "")) + " " + " ".join(meta.get("presets", ()))).casefold()
                if query and query not in haystack:
                    continue
                matches.append((flag_name, meta))
            matches.sort(key=lambda item: (0 if item[0].casefold().startswith(query) else 1, item[0].casefold()))
            for flag_name, meta in matches[:80]:
                item = QListWidgetItem(flag_name)
                item.setData(Qt.ItemDataRole.UserRole, flag_name)
                detail = str(meta.get("value", ""))
                source = str(meta.get("source", ""))
                item.setToolTip(f"{source} · default value: {detail}" if source else f"Default value: {detail}")
                suggestions.addItem(item)

        def choose_item(item):
            if item is None:
                return
            flag_name = str(item.data(Qt.ItemDataRole.UserRole) or item.text()).strip()
            name.setText(flag_name)
            meta = catalog.get(flag_name, {})
            if not value.text().strip():
                value.setText(str(meta.get("value", "")))
            value.setFocus()
            value.selectAll()

        name.textChanged.connect(update_suggestions)
        suggestions.itemClicked.connect(choose_item)
        suggestions.itemDoubleClicked.connect(lambda item: (choose_item(item), dialog.accept()))
        add.clicked.connect(dialog.accept)
        cancel.clicked.connect(dialog.reject)
        name.returnPressed.connect(lambda: value.setFocus())
        value.returnPressed.connect(dialog.accept)

        dialog.setStyleSheet(r'''
            QDialog#addCustomFastFlagDialog { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QLineEdit { background:#0d0d0e; color:#ededed; border:1px solid #2a2a2d; border-radius:6px; min-height:33px; padding:0 9px; }
            QLineEdit:focus { background:#101012; border-color:#45454a; }
            QListWidget#fastFlagSuggestions { background:#080809; border:1px solid #252528; border-radius:7px; padding:3px; outline:0; }
            QListWidget#fastFlagSuggestions::item { min-height:27px; padding:3px 8px; border-radius:5px; }
            QListWidget#fastFlagSuggestions::item:hover { background:#121214; }
            QListWidget#fastFlagSuggestions::item:selected { background:#1d1e21; color:#fff; }
            QPushButton { background:#111113; color:#e9e9e9; border:1px solid #2a2a2d; border-radius:6px; padding:6px 11px; }
            QPushButton:hover { background:#19191c; border-color:#414146; }
        ''')
        apply_blur_style(dialog)
        update_suggestions()
        name.setFocus()
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        key = name.text().strip()
        if not key:
            QMessageBox.warning(self, "Custom FastFlags", "FastFlag name cannot be empty.")
            return
        flags = self.owner.load_custom_fastflags()
        flags[key] = value.text()
        self._persist_custom_flag_mapping(flags)
        self._load_custom_flag_table()

    def _remove_custom_flag_at_position(self, position):
        row = self.custom_flag_table.rowAt(position.y())
        if row < 0:
            return
        self.custom_flag_table.clearSelection()
        self.custom_flag_table.selectRow(row)
        self.remove_selected_custom_fastflags()

    def remove_selected_custom_fastflags(self):
        rows = sorted({index.row() for index in self.custom_flag_table.selectionModel().selectedRows()}, reverse=True)
        if not rows:
            return
        names = []
        for row in rows:
            item = self.custom_flag_table.item(row, 0)
            if item:
                names.append(item.text())
        flags = self.owner.load_custom_fastflags()
        for name in names:
            flags.pop(name, None)
        if self._persist_custom_flag_mapping(flags):
            self._load_custom_flag_table()

    def schedule_custom_fastflag_save(self, *_):
        if self._reloading:
            return
        try:
            self._parse_custom_fastflag_editor()
        except Exception as exc:
            self._set_custom_flag_status(str(exc), True)
            return
        self._set_custom_flag_status()

    def persist_custom_fastflags(self, *_):
        if self._reloading:
            return
        try:
            flags = self._parse_custom_fastflag_editor()
        except Exception as exc:
            self._set_custom_flag_status(str(exc), True)
            return
        self._set_custom_flag_status()
        if self._persist_custom_flag_mapping(flags):
            self._load_custom_flag_table()
        self.update_change_state()

    def import_custom_fastflags(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import FastFlags", "", "JSON (*.json);;All files (*)")
        if not path:
            return
        try:
            payload = read_json_object(path, {})
            if not isinstance(payload, dict):
                raise ValueError("The JSON root must be an object of FastFlag name/value pairs.")
            flags = normalize_fastflags(payload)
            self._persist_custom_flag_mapping(flags)
            self._load_custom_flag_table()
            self._sync_custom_json_from_saved(flags)
        except Exception as exc:
            QMessageBox.warning(self, "Custom FastFlags", str(exc))

    def export_custom_fastflags(self):
        flags = self.owner.load_custom_fastflags()
        path, _ = QFileDialog.getSaveFileName(self, "Export FastFlags", "custom_fastflags.json", "JSON (*.json)")
        if path:
            write_json_object(path, flags)

    def update_attached_state(self):
        if self.owner.api_attached:
            self.attached_label.setText(
                'LelSploit is currently attached to Roblox. Live FastFlags and proxy features are unavailable in this session. '
                '<a href="detach" style="color:#79b8ff;text-decoration:none;"><b>Detach & restart</b></a>'
            )
            self.attached_banner.setVisible(True)
            return
        if (
            self.owner.roblox_running is True
            and self.owner.proxy_features_needed()
            and self.owner.roblox_session_mode == "attach"
            and not getattr(self.owner, "_fastflags_detach_restart_in_progress", False)
        ):
            self.attached_label.setText(
                'Roblox is running in Attach mode. Roblox must restart before live FastFlags can use the client proxy. '
                '<a href="proxy_restart" style="color:#79b8ff;text-decoration:none;"><b>Restart now</b></a>'
            )
            self.attached_banner.setVisible(True)
            return
        self.attached_banner.hide()

    @staticmethod
    def _default_spin(minimum, maximum):
        spin = QSpinBox()
        spin.setRange(minimum - 1, maximum)
        spin.setSpecialValueText("Default")
        spin.setValue(minimum - 1)
        spin.setFixedWidth(190)
        return spin

    def build_assets_page(self):
        page = QWidget(); page.setObjectName("assetsPage"); page.setAutoFillBackground(False); root = QVBoxLayout(page); root.setContentsMargins(0,0,0,0)
        scroll = QScrollArea(); scroll.setWidgetResizable(True)
        content = QWidget(); layout = QVBoxLayout(content); layout.setContentsMargins(1,1,1,1); layout.setSpacing(7)
        font_title = QLabel("Custom Font"); font_title.setObjectName("sectionTitle"); layout.addWidget(font_title)
        font_row = ModificationSourceRow(self, "Custom Font", "__font__", "font")
        self.asset_rows.append(font_row); layout.addWidget(font_row)
        for category, items in ASSET_TARGETS.items():
            title = QLabel(category); title.setObjectName("sectionTitle"); layout.addWidget(title)
            if category == "Skyboxes":
                apply_all = QPushButton("Apply to all Sky faces")
                apply_all.setObjectName("flatButton")
                apply_all.clicked.connect(self.apply_all_sky_faces)
                layout.addWidget(apply_all, 0, Qt.AlignmentFlag.AlignLeft)
            for label, target in items.items():
                row = ModificationSourceRow(self, label, target, "asset")
                self.asset_rows.append(row); layout.addWidget(row)
        layout.addStretch(1); scroll.setWidget(content); root.addWidget(scroll,1)
        return page

    def apply_all_sky_faces(self):
        path, _ = QFileDialog.getOpenFileName(self, "Choose skybox source", "", "All files (*)")
        if not path:
            return
        targets = [(label, target) for label, target in ASSET_TARGETS["Skyboxes"].items() if label.startswith("Sky —")]
        errors = []
        for label, target in targets:
            try: set_modification(label, target, path, "asset")
            except Exception as exc: errors.append(str(exc))
        for row in self.asset_rows: row.refresh()
        self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
        if errors: QMessageBox.warning(self, "Skybox", errors[0])
        else: self.owner.log("Applied source to all default sky faces.", "success")

    def build_username_page(self):
        page = QWidget()
        page.setObjectName("usernamePage")
        page.setAutoFillBackground(False)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 12, 14, 14)
        layout.setSpacing(14)

        heading = QHBoxLayout()
        title = QLabel("Username Spoofer")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#f1f1f1;background:transparent;")
        heading.addWidget(title)
        heading.addStretch(1)
        layout.addLayout(heading)

        card = QFrame()
        card.setObjectName("usernameSpoofCard")
        card.setStyleSheet(
            "QFrame#usernameSpoofCard { background:#0c0c0c; border:1px solid #242424; border-radius:8px; }"
        )
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(12, 12, 12, 12)
        card_layout.setSpacing(10)

        grid = QGridLayout()
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(10)
        grid.setColumnMinimumWidth(0, 92)
        grid.setColumnStretch(1, 1)
        grid.setColumnMinimumWidth(2, 112)
        grid.setColumnMinimumWidth(3, 82)

        everyone_label = QLabel("Everyone Else")
        everyone_label.setStyleSheet("background:transparent;color:#d8d8d8;")
        grid.addWidget(everyone_label, 0, 0, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_others = QLineEdit()
        self.spoof_others.setPlaceholderText("Spoofed username")
        self.spoof_others.setMinimumHeight(34)
        grid.addWidget(self.spoof_others, 0, 1)
        self.spoof_others_apply = BrightCheckBox("Apply Ingame")
        grid.addWidget(self.spoof_others_apply, 0, 2, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_others_verified = BrightCheckBox("Verified")
        grid.addWidget(self.spoof_others_verified, 0, 3, Qt.AlignmentFlag.AlignVCenter)

        yours_label = QLabel("Your Username")
        yours_label.setStyleSheet("background:transparent;color:#d8d8d8;")
        grid.addWidget(yours_label, 1, 0, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_yours = QLineEdit()
        self.spoof_yours.setPlaceholderText("Spoofed username")
        self.spoof_yours.setMinimumHeight(34)
        grid.addWidget(self.spoof_yours, 1, 1)
        self.spoof_yours_apply = BrightCheckBox("Apply Ingame")
        grid.addWidget(self.spoof_yours_apply, 1, 2, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_yours_verified = BrightCheckBox("Verified")
        grid.addWidget(self.spoof_yours_verified, 1, 3, Qt.AlignmentFlag.AlignVCenter)
        card_layout.addLayout(grid)

        divider = QFrame()
        divider.setFixedHeight(1)
        divider.setStyleSheet("background:#202020;border:0;")
        card_layout.addWidget(divider)

        self.spoof_creator = BrightCheckBox("Make Yourself Game Creator")
        card_layout.addWidget(self.spoof_creator, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(card)

        layout.addStretch(1)

        for control in (self.spoof_others, self.spoof_others_apply, self.spoof_others_verified,
                        self.spoof_yours, self.spoof_yours_apply, self.spoof_yours_verified, self.spoof_creator):
            signal = getattr(control, "textChanged", None) or getattr(control, "toggled", None)
            if signal is not None:
                signal.connect(self.schedule_username_persist)
        return page

    def _username_settings(self):
        return {
            "save": True,
            "others_username": self.spoof_others.text().strip(),
            "others_apply": self.spoof_others_apply.isChecked(),
            "others_verified": self.spoof_others_verified.isChecked(),
            "your_username": self.spoof_yours.text().strip(),
            "your_apply": self.spoof_yours_apply.isChecked(),
            "your_verified": self.spoof_yours_verified.isChecked(),
            "make_creator": self.spoof_creator.isChecked(),
        }

    def schedule_username_persist(self, *_):
        if not self._reloading:
            self.username_save_timer.start()

    def persist_username_spoofer(self, *_):
        if self._reloading:
            return
        settings = self._username_settings()
        changed = settings != self._baseline_username_settings
        save_username_spoofer_settings(settings)
        save_username_proxy_runtime(settings)
        self._baseline_username_settings = dict(settings)
        if changed and self.owner.roblox_running is True:
            self.owner.set_fastflags_restart_required(True)
            self.update_change_state()

    def build_custom_page(self):
        page = QWidget()
        page.setObjectName("customModsPage")
        page.setAutoFillBackground(False)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(12)
        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)
        title = QLabel("Custom Modifications")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#eee;background:transparent;")
        top.addWidget(title)
        top.addStretch(1)
        add = QPushButton("Add modification")
        add.setFixedHeight(32)
        add.clicked.connect(self.add_custom_modification)
        top.addWidget(add)
        layout.addLayout(top)
        self.custom_scroll = QScrollArea()
        self.custom_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.custom_scroll.setWidgetResizable(True)
        self.custom_scroll.setStyleSheet("QScrollArea{border:0;background:transparent;} QScrollArea QWidget{background:transparent;}")
        self.custom_content = QWidget()
        self.custom_content.setStyleSheet("background:transparent;")
        self.custom_layout = QVBoxLayout(self.custom_content)
        self.custom_layout.setContentsMargins(0, 0, 0, 0)
        self.custom_layout.setSpacing(8)
        self.custom_empty = QLabel("No custom modifications yet.")
        self.custom_empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.custom_empty.setStyleSheet("color:#666;background:transparent;padding:28px;")
        self.custom_layout.addWidget(self.custom_empty)
        self.custom_layout.addStretch(1)
        self.custom_scroll.setWidget(self.custom_content)
        layout.addWidget(self.custom_scroll, 1)
        return page

    def add_custom_modification(self):
        dialog = CustomModificationDialog(self)
        if dialog.exec() != QDialog.DialogCode.Accepted: return
        try:
            set_modification(dialog.display_name.text().strip(), dialog.target.text().strip(), dialog.source.text().strip(), "custom")
            self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
            self.owner.log(f"Applied {dialog.display_name.text().strip()}.", "success")
            self.refresh_custom_mods()
        except Exception as exc:
            QMessageBox.warning(self, "Custom Modification", str(exc))

    def refresh_custom_mods(self):
        if not hasattr(self, "custom_layout"):
            return
        while self.custom_layout.count() > 1:
            item = self.custom_layout.takeAt(0)
            widget = item.widget()
            if widget is not None and widget is not getattr(self, "custom_empty", None):
                widget.deleteLater()
        entries = [entry for entry in _read_modifications_data().get("entries", []) if entry.get("kind") == "custom"]
        self.custom_empty.setVisible(not entries)
        if self.custom_layout.indexOf(self.custom_empty) < 0:
            self.custom_layout.insertWidget(0, self.custom_empty)
        insert_at = 1 if self.custom_empty.isVisible() else 0
        for entry in entries:
            card = QFrame()
            card.setObjectName("modRow")
            row = QHBoxLayout(card)
            row.setContentsMargins(12, 9, 10, 9)
            details = QVBoxLayout()
            name = QLabel(str(entry.get("display_name") or "Modification"))
            name.setStyleSheet("color:#eee;font-weight:600;background:transparent;")
            details.addWidget(name)
            target = QLabel(str(entry.get("target") or ""))
            target.setStyleSheet("color:#777;font-size:10px;background:transparent;")
            details.addWidget(target)
            row.addLayout(details, 1)
            remove = QPushButton("Remove")
            remove.setFixedWidth(72)
            remove.clicked.connect(lambda checked=False, target=entry.get("target"): self.remove_custom_mod(target))
            row.addWidget(remove)
            self.custom_layout.insertWidget(insert_at, card)
            insert_at += 1

    def remove_custom_mod(self, target):
        try:
            remove_modification(target); self.owner.set_fastflags_restart_required(self.owner.roblox_running is True); self.refresh_custom_mods()
        except Exception as exc: QMessageBox.warning(self, "Custom Modification", str(exc))

    def _update_slider_labels(self, *_):
        value = self.mesh_slider.value(); self.mesh_value.setText("Default" if value == 0 else f"Level {value-1}")
        value = self.frm_slider.value(); self.frm_value.setText("Default" if value == 0 else f"Quality {value}")

    def on_manager_toggled(self, enabled):
        self.managed_panel.setVisible(bool(enabled)); self.update_change_state()

    def reload(self):
        self._reloading = True
        try:
            self.current_flags = self.owner.load_fastflags(); keys = FASTFLAG_KEYS; enabled = self.owner.fastflags_enabled()
            self.manager_check.setChecked(enabled); self.managed_panel.setVisible(enabled)
            mode = None
            if self.current_flags.get(keys["render_d3d11"]) == "True": mode = "D3D11"
            elif self.current_flags.get(keys["render_vulkan"]) == "True": mode = "Vulkan"
            elif self.current_flags.get(keys["render_opengl"]) == "True": mode = "OpenGL"
            self.render_combo.setCurrentIndex(max(0, self.render_combo.findData(mode)))
            self.msaa_combo.setCurrentIndex(max(0, self.msaa_combo.findData(self.current_flags.get(keys["msaa"]))))
            self.scaling_check.setChecked(self.current_flags.get(keys["display_scaling"]) == "True")
            self.fullscreen_check.setChecked(self.current_flags.get(keys["manual_fullscreen"]) == "True")
            self.texture_combo.setCurrentIndex(max(0, self.texture_combo.findData(self.current_flags.get(keys["texture_level"]))))
            static = self.current_flags.get(keys["lod_static"])
            self.mesh_check.setChecked(static is not None)
            self.mesh_slider.setValue(max(0, min(4, int(static)+1)) if str(static).lstrip("-").isdigit() else 0)
            frm = self.current_flags.get(keys["frm_quality"])
            self.frm_check.setChecked(frm is not None)
            self.frm_slider.setValue(max(0, min(21, int(frm))) if str(frm).isdigit() else 0)
            self.grey_sky_check.setChecked(self.current_flags.get(keys["grey_sky"]) == "True")
            self.pause_voxelizer_check.setChecked(self.current_flags.get(keys["pause_voxelizer"]) == "True")
            for spin, key in ((self.grass_max,"grass_max"),(self.grass_min,"grass_min"),(self.grass_motion,"grass_motion")):
                value = self.current_flags.get(keys[key]); spin.setValue(int(value) if str(value).lstrip("-").isdigit() else spin.minimum())
            saved_fps = self.owner.settings.value("global/framerate_cap", None)
            if saved_fps is None: saved_fps = read_roblox_framerate_cap() or 0
            try: saved_fps = int(saved_fps)
            except (TypeError, ValueError): saved_fps = 0
            self.fps_cap.setValue(max(0,min(1000,saved_fps)))
            self._baseline_fps = self.fps_cap.value(); self._baseline_flags = normalize_fastflags(self.current_flags); self._baseline_enabled = bool(enabled)
            custom_flags = self.owner.load_custom_fastflags()
            self._sync_custom_json_from_saved(custom_flags)
            self._baseline_custom_flags = normalize_fastflags(custom_flags)
            self._load_custom_flag_table()
            self._update_slider_labels()
            saved = load_username_spoofer_settings()
            self.spoof_others.setText(str(saved.get("others_username", ""))); self.spoof_others_apply.setChecked(bool(saved.get("others_apply")))
            self.spoof_others_verified.setChecked(bool(saved.get("others_verified"))); self.spoof_yours.setText(str(saved.get("your_username", ""))); self.spoof_yours_apply.setChecked(bool(saved.get("your_apply")))
            self.spoof_yours_verified.setChecked(bool(saved.get("your_verified"))); self.spoof_creator.setChecked(bool(saved.get("make_creator")))
            self._baseline_username_settings = dict(self._username_settings())
            for row in self.asset_rows: row.refresh()
            self.refresh_custom_mods()
        finally:
            self._reloading = False
        self.update_attached_state()
        self.update_change_state()

    def collect_flags(self):
        flags = dict(self.current_flags); keys = FASTFLAG_KEYS
        for key in keys.values(): flags.pop(key, None)
        mode = self.render_combo.currentData()
        if mode:
            flags[keys[{"D3D11":"render_d3d11","Vulkan":"render_vulkan","OpenGL":"render_opengl"}[mode]]] = "True"
            if mode in ("Vulkan", "OpenGL"): flags[keys["render_disable_d3d11"]] = "True"
        msaa = self.msaa_combo.currentData()
        if msaa is not None: flags[keys["msaa"]] = str(msaa)
        if self.scaling_check.isChecked(): flags[keys["display_scaling"]] = "True"
        if self.fullscreen_check.isChecked(): flags[keys["manual_fullscreen"]] = "True"
        texture = self.texture_combo.currentData()
        if texture is not None: flags[keys["texture_enabled"]] = "True"; flags[keys["texture_level"]] = str(texture)
        if self.mesh_check.isChecked() and self.mesh_slider.value() > 0:
            level = self.mesh_slider.value()
            for i, key in enumerate(("lod_l0","lod_l12","lod_l23","lod_l34")):
                flags[keys[key]] = str(max(0,min(level-1-i,3)))
            flags[keys["lod_static"]] = str(level-1)
        if self.frm_check.isChecked() and self.frm_slider.value() > 0: flags[keys["frm_quality"]] = str(self.frm_slider.value())
        if self.grey_sky_check.isChecked(): flags[keys["grey_sky"]] = "True"
        if self.pause_voxelizer_check.isChecked(): flags[keys["pause_voxelizer"]] = "True"
        for spin, key in ((self.grass_max,"grass_max"),(self.grass_min,"grass_min"),(self.grass_motion,"grass_motion")):
            if spin.value() > spin.minimum(): flags[keys[key]] = str(spin.value())
        return normalize_fastflags(flags)

    def has_unsaved_changes(self):
        return not self._reloading and (bool(self.manager_check.isChecked()) != self._baseline_enabled or self.collect_flags() != self._baseline_flags or self.fps_cap.value() != self._baseline_fps)

    def update_change_state(self, *_):
        if self._reloading:
            return
        dirty = self.has_unsaved_changes()
        self.restart_bar.setVisible(
            self.owner.roblox_running is True
            and (dirty or self.owner.fastflags_restart_required())
        )
        if dirty:
            self.auto_save_timer.start()

    def save_changes(self, _checked=False, quiet=False):
        flags = self.collect_flags(); enabled = self.manager_check.isChecked(); changed = flags != self._baseline_flags or enabled != self._baseline_enabled
        fps_changed = self.fps_cap.value() != self._baseline_fps
        if enabled != self._baseline_enabled and not enabled: self.owner.set_fastflags_enabled(False)
        if flags != self._baseline_flags: self.current_flags = self.owner.save_fastflags(flags)
        else: self.current_flags = dict(flags)
        if enabled != self._baseline_enabled and enabled: self.owner.set_fastflags_enabled(True)
        elif enabled and flags != self._baseline_flags: self.owner.request_fastflag_sync(force=True)
        if fps_changed:
            value = self.fps_cap.value()
            self.owner.settings.setValue("global/framerate_cap", value)
            self.owner.settings.sync()
            if self.owner.roblox_running is not True:
                self.owner.apply_saved_framerate_cap()
        self._baseline_flags = normalize_fastflags(self.current_flags); self._baseline_enabled = bool(enabled); self._baseline_fps = self.fps_cap.value()
        if changed or fps_changed:
            self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
            if enabled:
                prime_windows_fastflag_cache(self.owner.load_effective_fastflags())
                self.owner.refresh_proxy_for_active_session()
        if not quiet and (changed or fps_changed): self.owner.log("Client settings saved.", "success")
        self.update_change_state(); return changed or fps_changed

    def reset_configuration(self):
        self.render_combo.setCurrentIndex(0); self.msaa_combo.setCurrentIndex(0); self.scaling_check.setChecked(False); self.fullscreen_check.setChecked(False); self.texture_combo.setCurrentIndex(0)
        self.mesh_check.setChecked(False); self.mesh_slider.setValue(0); self.frm_check.setChecked(False); self.frm_slider.setValue(0); self.grey_sky_check.setChecked(False); self.pause_voxelizer_check.setChecked(False)
        for spin in (self.grass_max,self.grass_min,self.grass_motion): spin.setValue(spin.minimum())
        self.fps_cap.setValue(0); self.update_change_state()

    def restart_now(self, _link="restart"):
        self.save_changes(quiet=True); self.owner.restart_roblox_from_fastflags() if self.owner.roblox_running is True else self.update_change_state()

    def closeEvent(self, event):
        try: self.save_changes(quiet=True); self.persist_username_spoofer(); self.persist_custom_fastflags()
        except Exception as exc: self.owner.log(f"Could not save client settings: {exc}", "warning")
        event.accept()


class LelSploitWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("LelSploit")
        self.resize(900, 640)
        self.setMinimumSize(660, 460)
        apply_window_icon(self)
        self.busy = False
        self.loading = False
        self.stopping = threading.Event()
        self.requests = queue.Queue(maxsize=1)
        self.events = queue.Queue()
        self.api_cancel = None
        self.api_action = None
        self._auto_detach_pending = False
        self._attached_join_signature = None
        self.syntax_colors_enabled = True
        self.load_cancel = None
        self.load_queue = None
        self.paste_source = None
        self.loaded_bytes = 0
        self.line_bytes = 0
        self.long_line = False
        self.scriptblox_window = None
        self.tools_window = None
        self.settings_window = None
        self.fastflags_window = None
        self.extensions_window = None
        self.documentation_window = None
        self.extension_smooth_scroll = SmoothScrollService(self)
        self.extension_runtime = LelExtensionRuntime(self)
        self._extension_events = {}
        self._extension_event_timers = {}
        self._extension_timers = {}
        self._extension_started_ids = set()
        self._extension_shortcuts = []
        self.settings = JsonSettings(SETTINGS_PATH)
        self.capture_exclusion_service = CaptureExclusionService(self)
        self.appearance_manager = AppearanceManager(self)
        self.visual_wizard_service = VisualWizardService(self)
        try:
            QApplication.clipboard().dataChanged.connect(lambda: self._queue_extension_event("clipboard.changed", 60))
            QApplication.instance().applicationStateChanged.connect(self._on_extension_app_state)
        except Exception:
            pass
        saved_spoofer = load_username_spoofer_settings()
        if saved_spoofer:
            saved_spoofer["save"] = True
            save_username_spoofer_settings(saved_spoofer)
            save_username_proxy_runtime(saved_spoofer)
        self.roblox_events = queue.Queue()
        self.fastflag_checking = False
        self.fastflag_last_target = None
        self.mod_checking = False
        self.mod_last_root = None
        self.roblox_busy = False
        self.roblox_checking = False
        self.roblox_running = None
        self.api_attached = False
        self.tray_icon = None
        self.tray_roblox_action = None
        self._force_exit = False
        self._tray_visible_windows = []
        self.proxy_process = None
        self.proxy_port = PROXY_PORT
        self.roblox_proxy_active = False
        self.roblox_session_mode = "unknown"
        self._pending_api_after_restart = None
        self._attach_restart_join_signature = None
        self._attach_wait_token = 0
        self._pending_proxy_restart_after_detach = False
        self._auto_proxy_probe_token = 0
        self._proxy_api_suspended = False
        self._proxy_attach_notice_shown = False
        self._proxy_custom_fastflag_snapshot = None
        self._fastflags_detach_restart_in_progress = False
        self._proxy_starting = False
        self._proxy_first_start_used = False
        self._proxy_skip_next_detection = False
        self._set_proxy_runtime_suspended(False)
        self.fastflag_hotkeys = FastFlagHotkeyService(self)
        self.fastflag_hotkeys.activated.connect(self.toggle_custom_fastflag_hotkey)
        self.refresh_custom_fastflag_hotkeys()

        root = QWidget()
        self.setCentralWidget(root)
        layout = blur_content_layout(self, root, "LelSploit", (16, 4, 16, 16), 7)
        self.tab_counter = 0
        self.scriptblox_button = QPushButton("ScriptBlox")
        self.scriptblox_button.setFixedHeight(36)
        self.scriptblox_button.setMinimumWidth(104)
        self.scriptblox_button.clicked.connect(self.open_scriptblox)
        self.set_button_icon(self.scriptblox_button, "scriptblox")
        self.extensions_button = QPushButton()
        self.extensions_button.setObjectName("iconButton")
        self.extensions_button.setFixedSize(36, 36)
        self.extensions_button.clicked.connect(self.open_extensions)
        self.set_button_icon(self.extensions_button, "extensions")
        self.visual_wizard_button = QPushButton()
        self.visual_wizard_button.setObjectName("iconButton")
        self.visual_wizard_button.setFixedSize(36, 36)
        self.visual_wizard_button.setIcon(palette_icon(20))
        self.visual_wizard_button.setIconSize(QSize(19, 19))
        self.visual_wizard_button.setCursor(Qt.CursorShape.PointingHandCursor)
        self.visual_wizard_button.clicked.connect(self.visual_wizard_service.open)
        self.visual_wizard_button.hide()

        self.editor_tabs = EditorTabs()
        self.editor_tabs.setObjectName("editorTabs")
        self.editor_tabs.setTabsClosable(False)
        self.editor_tabs.setTabBarAutoHide(False)
        self.editor_tabs.setDocumentMode(False)
        self.editor_tabs.setContentsMargins(0, 0, 0, 0)
        self.editor_tabs.currentChanged.connect(self.on_editor_tab_changed)
        tab_bar = self.editor_tabs._editor_bar
        tab_bar.closeRequested.connect(self.close_editor_tab)
        tab_bar.newRequested.connect(self.add_blank_tab)
        tab_bar.renameRequested.connect(self.begin_tab_rename)

        editor_actions = QWidget(self.editor_tabs)
        editor_actions.setObjectName("editorActions")
        editor_actions.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        editor_actions.setStyleSheet("background: transparent; border: none;")
        editor_actions_layout = QHBoxLayout(editor_actions)
        editor_actions_layout.setContentsMargins(0, 0, 2, 2)
        editor_actions_layout.setSpacing(4)
        self.editor_open_button = QPushButton()
        self.editor_open_button.setObjectName("editorIconButton")
        self.editor_open_button.setFixedSize(28, 28)
        self.set_button_icon(self.editor_open_button, "open")
        self.editor_open_button.clicked.connect(self.open_script)
        self.editor_save_button = QPushButton()
        self.editor_save_button.setObjectName("editorIconButton")
        self.editor_save_button.setFixedSize(28, 28)
        self.set_button_icon(self.editor_save_button, "save")
        self.editor_save_button.clicked.connect(self.save_script_as)
        editor_actions_layout.addWidget(self.editor_open_button)
        editor_actions_layout.addWidget(self.editor_save_button)
        self.editor_tabs.setCornerWidget(editor_actions, Qt.Corner.TopRightCorner)

        self.editor = None
        self.loading_editor = None
        self.add_editor_tab("script1.luau", "print('Hello, World!')", select=True)

        self.execute_button = QPushButton("Execute")
        self.execute_button.clicked.connect(self.execute)
        self.open_button = QPushButton("Open File", self)
        self.open_button.clicked.connect(self.open_script)
        self.open_button.hide()
        self.save_button = QPushButton("Save File", self)
        self.save_button.clicked.connect(self.save_script)
        self.save_button.hide()
        self.reattach_button = QPushButton("Attach")
        self.reattach_button.clicked.connect(self.reattach)
        self.roblox_button = QPushButton("Start Roblox")
        self.roblox_button.clicked.connect(self.toggle_roblox)

        self.documentation_button = QPushButton()
        self.documentation_button.setObjectName("iconButton")
        self.documentation_button.clicked.connect(self.open_documentation)

        self.tools_button = QPushButton()
        self.tools_button.setObjectName("iconButton")
        self.tools_button.clicked.connect(self.open_tools)
        self.fastflags_button = QPushButton()
        self.fastflags_button.setObjectName("iconButton")
        self.fastflags_button.clicked.connect(self.open_fastflags)
        self.settings_button = QPushButton()
        self.settings_button.setObjectName("iconButton")
        self.settings_button.clicked.connect(self.open_settings)

        text_button_size = QSize(
            int(ui_config("buttons", "text_width", 116)),
            int(ui_config("buttons", "text_height", 34)),
        )
        icon_size = int(ui_config("buttons", "icon_size", 34))
        icon_button_size = QSize(icon_size, icon_size)
        for button, icon_name in (
            (self.execute_button, "execute"),
            (self.open_button, "file"),
            (self.save_button, "file"),
            (self.reattach_button, "attach"),
            (self.scriptblox_button, "scriptblox"),
            (self.roblox_button, "start"),
        ):
            button.setFixedSize(text_button_size)
            self.set_button_icon(button, icon_name)
        for button, icon_name in (
            (self.tools_button, "tools"),
            (self.documentation_button, "documentation"),
            (self.fastflags_button, "fastflags"),
            (self.settings_button, "settings"),
        ):
            button.setFixedSize(icon_button_size)
            self.set_button_icon(button, icon_name)

        controls = QGridLayout()
        controls.setContentsMargins(0, 0, 0, 0)
        controls.setHorizontalSpacing(int(ui_config("buttons", "spacing", 5)))
        controls.setVerticalSpacing(int(ui_config("buttons", "spacing", 5)))

        controls.addWidget(self.execute_button, 0, 0)
        controls.addWidget(self.reattach_button, 0, 1)
        controls.addWidget(self.scriptblox_button, 0, 2)
        controls.setColumnStretch(3, 1)

        right_top = QHBoxLayout()
        self.header_layout = right_top
        right_top.setContentsMargins(0, 0, 0, 0)
        right_top.setSpacing(int(ui_config("buttons", "spacing", 5)))
        right_top.addWidget(self.visual_wizard_button)
        right_top.addWidget(self.extensions_button)
        right_top.addWidget(self.fastflags_button)
        right_top.addWidget(self.tools_button)
        right_top.addWidget(self.documentation_button)
        right_top.addWidget(self.settings_button)
        controls.addLayout(right_top, 0, 4, 1, 7, Qt.AlignmentFlag.AlignRight)
        layout.addWidget(self.editor_tabs, 1)
        layout.addLayout(controls)

        window_bg = ui_config("window", "background", "#08090a")
        surface = ui_config("buttons", "background", "#101214")
        hover = ui_config("buttons", "hover", "#1c2022")
        border = ui_config("buttons", "border", "#272b2e")
        text_color = ui_config("window", "text", "#e8e9ea")
        muted = ui_config("window", "muted", "#92989b")
        button_radius = int(ui_config("buttons", "corner_radius", 5))
        self.setStyleSheet(f"""
            QMainWindow, QWidget {{ background: {window_bg}; color: {text_color}; }}
            QLabel, QCheckBox {{ background: transparent; }}
            QLabel {{ color: #b7bbbd; }}
            QPushButton {{ background: {surface}; border: 1px solid {border};
                border-radius: {button_radius}px; padding: 6px 10px; }}
            QPushButton:hover {{ background: {hover}; border-color: #343a3e; }}
            QPushButton:disabled {{ color: #737a7e; }}
            QPushButton#iconButton {{ padding: 0; font-size: 17px; font-weight: 600; }}
            QPushButton#topMenuButton {{ padding: 4px 9px; text-align: left; }}
            QPlainTextEdit {{ background: #111315; border: 1px solid #2b3033; }}
            QMenu {{ background:#141719; border:1px solid #2d3235; padding:5px; }}
            QMenu::item {{ padding:7px 28px 7px 10px; border-radius:4px; }}
            QMenu::item:selected {{ background:#252a2d; color:#ffffff; }}
            QMenu::item:disabled {{ color:#6f767a; }}
            QMenu::separator {{ height:1px; background:#2b3033; margin:5px 4px; }}
            QScrollBar {{ background: #0b0c0d; }}
            QScrollBar:vertical {{ width: 10px; }}
            QScrollBar:horizontal {{ height: 10px; }}
            QScrollBar::handle {{ background: #3b4145; min-width: 20px; min-height: 20px; border-radius: 4px; }}
            QScrollBar::handle:hover {{ background: #555d62; }}
            QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; }}
        """)
        apply_blur_style(self)
        editor_bg = ui_config("editor", "background", "#121416")
        editor_radius = max(0, int(ui_config("editor", "corner_radius", 6)))
        tab_bg = ui_config("tabs", "tab_background", "#131517")
        tab_hover = ui_config("tabs", "tab_hover", "#191c1e")
        tab_selected = ui_config("tabs", "tab_selected", "#1e2225")
        tab_text = ui_config("tabs", "text", "#ffffff")
        tab_radius = max(0, int(ui_config("tabs", "corner_radius", 3)))
        self.editor_tabs.setStyleSheet(f"""
            QTabWidget#editorTabs {{ background: transparent; border: none; margin: 0; padding: 0; }}
            QTabWidget#editorTabs::pane {{ background: transparent; border: none; margin: 0; padding: 0; top: 0; }}
            QWidget#editorPage {{ border: none; }}
            QWidget#editorActions {{ background: transparent; border: none; }}
            QPushButton#editorIconButton {{ background: transparent; border: none; padding: 0; }}
            QPushButton#editorIconButton:hover {{ background: {tab_selected}; border: none; border-radius: 4px; }}
            QPushButton#editorIconButton:pressed {{ background: {tab_hover}; border: none; }}
            QTabWidget#editorTabs QTabBar {{ background: transparent; border: none; margin: 0; padding: 0; }}
            QTabWidget#editorTabs QTabBar::tab {{
                min-width: 82px; max-width: 190px; min-height: 27px;
                padding: 2px 7px 2px 10px; margin: 0px 3px 2px 0;
                background: {tab_bg}; color: {tab_text}; border: none; border-radius: {tab_radius}px;
            }}
            QTabWidget#editorTabs QTabBar::tab:hover {{ background: {tab_hover}; color: {tab_text}; }}
            QTabWidget#editorTabs QTabBar::tab:selected {{ background: {tab_selected}; color: {tab_text}; }}
            QPushButton#tabAddButton, QPushButton#tabHoverClose {{
                background: transparent; border: none; border-radius: 4px; padding: 0;
            }}
            QPushButton#tabAddButton:hover {{ background: {tab_selected}; }}
            QPushButton#tabHoverClose:hover, QPushButton#tabHoverClose:pressed {{
                background: transparent; border: none;
            }}
        """)
        self.editor_tabs._editor_bar.setDrawBase(False)
        
        
        
        
        self.setCursor(Qt.CursorShape.ArrowCursor)
        root.setCursor(Qt.CursorShape.ArrowCursor)
        for widget in self.findChildren(QPushButton):
            widget.setCursor(Qt.CursorShape.PointingHandCursor)
        for widget in self.findChildren(QCheckBox):
            widget.setCursor(Qt.CursorShape.PointingHandCursor)
        self.shortcuts = []
        for key, action in (
            ("Ctrl+Return", self.execute),
            ("Ctrl+O", self.open_script),
            ("Ctrl+S", self.save_script),
            ("Ctrl+Shift+S", self.save_script_as),
            ("Ctrl+G", self.go_to_line),
            ("Ctrl+D", self.duplicate_current_line),
            ("Ctrl+/", self.toggle_comment),
            ("F2", self.rename_current_tab),
        ):
            shortcut = QShortcut(QKeySequence(key), self)
            shortcut.activated.connect(action)
            self.shortcuts.append(shortcut)

        self.load_timer = QTimer(self)
        self.load_timer.setInterval(1)
        self.load_timer.timeout.connect(self.load_tick)
        self.event_timer = QTimer(self)
        self.event_timer.setInterval(50)
        self.event_timer.timeout.connect(self.poll_api)
        self.event_timer.start()
        self.roblox_timer = QTimer(self)
        self.roblox_timer.setInterval(1000)
        self.roblox_timer.timeout.connect(self.request_roblox_check)
        self.fastflag_timer = QTimer(self)
        self.fastflag_timer.setInterval(5000)
        self.fastflag_timer.timeout.connect(self.request_fastflag_sync)
        self.fastflag_timer.timeout.connect(self.request_modification_sync)
        if sys.platform == "win32":
            self.roblox_timer.start()
            self.fastflag_timer.start()
            QTimer.singleShot(0, self.request_roblox_check)
            QTimer.singleShot(0, lambda: self.request_fastflag_sync(force=True))
            QTimer.singleShot(0, lambda: self.request_modification_sync(force=True))
        else:
            self.roblox_button.setEnabled(False)
            self.roblox_button.setToolTip("Available on Windows")
        self.update_colors()
        QTimer.singleShot(2500, self.update_colors)
        QTimer.singleShot(8000, self.update_colors)
        self.setup_system_tray()
        self.editor.setFocus()
        self._extension_runtime_signature = extension_folder_signature()
        self._extension_folder_timer = QTimer(self)
        self._extension_folder_timer.setInterval(1200)
        self._extension_folder_timer.timeout.connect(self._poll_extensions_runtime_folder)
        self._extension_folder_timer.start()
        QTimer.singleShot(450, self.refresh_extensions_runtime)
        QTimer.singleShot(900, self._preload_fastflags_window)
        threading.Thread(target=self.api_worker, daemon=True).start()

    def close_behavior(self):
        value = str(self.settings.value("application/close_behavior", "tray") or "tray").strip().casefold()
        return value if value in {"tray", "exit"} else "tray"

    def set_close_behavior(self, value):
        value = str(value or "tray").strip().casefold()
        if value not in {"tray", "exit"}:
            value = "tray"
        self.settings.setValue("application/close_behavior", value)
        self.settings.sync()

    def fastflag_restart_behavior(self):
        value = str(self.settings.value("fastflags/restart_behavior", "server") or "server").strip().casefold()
        return value if value in {"restart", "game", "server"} else "server"

    def set_fastflag_restart_behavior(self, value):
        value = str(value or "server").strip().casefold()
        if value not in {"restart", "game", "server"}:
            value = "server"
        self.settings.setValue("fastflags/restart_behavior", value)
        self.settings.sync()

    def screen_capture_hidden(self):
        return self._setting_bool(self.settings.value("application/exclude_from_capture", False), False)

    def _apply_capture_exclusion(self):
        if hasattr(self, "capture_exclusion_service"):
            self.capture_exclusion_service.apply_all(self.screen_capture_hidden())

    def set_screen_capture_hidden(self, enabled):
        enabled = bool(enabled)
        self.settings.setValue("application/exclude_from_capture", enabled)
        self.settings.sync()
        if sys.platform == "win32" and hasattr(self, "capture_exclusion_service"):
            QTimer.singleShot(0, lambda state=enabled: self.capture_exclusion_service.apply_all(state))
        if self.tray_icon is not None:
            if enabled:
                self.tray_icon.hide()
            else:
                self.tray_icon.show()
        if self.settings_window is not None and hasattr(self.settings_window, "tray_notice_check"):
            self.settings_window.tray_notice_check.setEnabled(not enabled)

    def tray_notice_enabled(self):
        value = self.settings.value("application/tray_notification", True)
        if isinstance(value, str):
            return value.strip().casefold() not in {"0", "false", "no", "off"}
        return bool(value)

    def set_tray_notice_enabled(self, enabled):
        self.settings.setValue("application/tray_notification", bool(enabled))
        self.settings.sync()

    @staticmethod
    def _setting_bool(value, default=False):
        if value is None:
            return bool(default)
        if isinstance(value, str):
            return value.strip().casefold() not in {"0", "false", "no", "off", ""}
        return bool(value)

    def proxy_start_behavior(self):
        value = str(self.settings.value("proxy/start_behavior", "") or "").strip().casefold()
        if value in {"first", "always", "manual"}:
            return value

        
        legacy_lelsploit = self._setting_bool(self.settings.value("proxy/autostart_lelsploit", False), False)
        legacy_roblox = self._setting_bool(self.settings.value("proxy/autostart_roblox", False), False)
        if legacy_roblox:
            return "always"
        if legacy_lelsploit:
            return "first"
        return "manual"

    def set_proxy_start_behavior(self, value):
        value = str(value or "manual").strip().casefold()
        if value not in {"first", "always", "manual"}:
            value = "manual"
        self.settings.setValue("proxy/start_behavior", value)
        
        self.settings.setValue("proxy/autostart_lelsploit", False)
        self.settings.setValue("proxy/autostart_roblox", False)
        self.settings.sync()

        if value == "first":
            self._proxy_first_start_used = False
        if (
            value in {"first", "always"}
            and self.roblox_running is True
            and self.proxy_features_needed()
            and not self.proxy_suspended_for_api()
            and self.roblox_session_mode != "attach"
        ):
            if value == "first":
                self._proxy_first_start_used = True
            self._set_proxy_runtime_suspended(False)
            self.start_proxy_in_background()

    def _proxy_should_autostart(self, consume_first=False):
        behavior = self.proxy_start_behavior()
        if behavior == "manual":
            return False
        if behavior == "always":
            return True
        if self._proxy_first_start_used:
            return False
        if consume_first:
            self._proxy_first_start_used = True
        return True

    def notify_user(self, title, message, duration=3500):
        if self.screen_capture_hidden():
            return
        if self.tray_icon is None:
            return
        if not self.tray_icon.isVisible():
            self.tray_icon.show()
        try:
            self.tray_icon.showMessage(str(title), str(message), lelsploit_icon(), int(duration))
        except TypeError:
            self.tray_icon.showMessage(
                str(title), str(message), QSystemTrayIcon.MessageIcon.Information, int(duration)
            )

    def setup_system_tray(self):
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        self.tray_icon = QSystemTrayIcon(lelsploit_icon(), self)
        self.tray_icon.setToolTip("LelSploit")
        menu = QMenu()
        menu.setStyleSheet("""
            QMenu {
                background-color: #090b0f;
                color: #dedede;
                border: 1px solid #20242b;
                border-radius: 7px;
                padding: 5px;
            }
            QMenu::item {
                background: transparent;
                padding: 7px 24px 7px 10px;
                border-radius: 4px;
            }
            QMenu::item:selected { background-color: #171b22; }
            QMenu::item:disabled { color: #686b70; }
            QMenu::separator {
                height: 1px;
                background: #242830;
                margin: 5px 7px;
            }
        """)
        open_action = menu.addAction("Open LelSploit")
        open_action.setIcon(lelsploit_icon())
        open_action.triggered.connect(self.restore_from_tray)
        menu.addSeparator()
        execute_action = menu.addAction("Execute current script")
        execute_action.setIcon(app_icon("execute"))
        execute_action.triggered.connect(self.execute)
        attach_action = menu.addAction("Attach / Reattach")
        attach_action.setIcon(app_icon("attach"))
        attach_action.triggered.connect(self.reattach)
        self.tray_roblox_action = menu.addAction("Start Roblox")
        self.tray_roblox_action.setIcon(app_icon("start"))
        self.tray_roblox_action.triggered.connect(self.toggle_roblox)
        menu.addSeparator()
        scriptblox_action = menu.addAction("ScriptBlox")
        scriptblox_action.setIcon(app_icon("scriptblox"))
        scriptblox_action.triggered.connect(self.open_scriptblox)
        tools_action = menu.addAction("Tools")
        tools_action.setIcon(app_icon("tools"))
        tools_action.triggered.connect(self.open_tools)
        fastflags_action = menu.addAction("FastFlags && Client Mods")
        fastflags_action.setIcon(app_icon("fastflags"))
        fastflags_action.triggered.connect(self.open_fastflags)
        extensions_action = menu.addAction("Extensions")
        extensions_action.setIcon(app_icon("extensions"))
        extensions_action.triggered.connect(self.open_extensions)
        docs_action = menu.addAction("Documentation")
        docs_action.setIcon(app_icon("documentation"))
        docs_action.triggered.connect(self.open_documentation)
        settings_action = menu.addAction("Settings")
        settings_action.setIcon(app_icon("settings"))
        settings_action.triggered.connect(self.open_settings)
        menu.addSeparator()
        exit_action = menu.addAction("Exit LelSploit")
        exit_action.setIcon(app_icon("end"))
        exit_action.triggered.connect(self.quit_application)
        self.tray_icon.setContextMenu(menu)
        self.tray_icon.activated.connect(self.on_tray_activated)
        if not self.screen_capture_hidden():
            self.tray_icon.show()

    def on_tray_activated(self, reason):
        if reason in (QSystemTrayIcon.ActivationReason.Trigger, QSystemTrayIcon.ActivationReason.DoubleClick):
            self.restore_from_tray()

    def hide_to_tray(self, show_notice=True):
        self._tray_main_state = self.windowState()
        self._tray_visible_windows = []
        for name in ("scriptblox_window", "tools_window", "settings_window", "fastflags_window", "documentation_window"):
            window = getattr(self, name, None)
            if window is not None and window.isVisible():
                self._tray_visible_windows.append(name)
                window.hide()
        self.hide()
        if show_notice and self.tray_notice_enabled():
            QTimer.singleShot(180, lambda: self.notify_user(
                "LelSploit",
                "LelSploit is still running in the system tray.",
                4000,
            ))

    def restore_from_tray(self):
        state = getattr(self, "_tray_main_state", Qt.WindowState.WindowNoState)
        if state & Qt.WindowState.WindowMaximized:
            self.showMaximized()
        else:
            self.showNormal()
        self.show()
        self.raise_()
        self.activateWindow()
        for name in getattr(self, "_tray_visible_windows", []):
            window = getattr(self, name, None)
            if window is not None:
                window.show()
                window.raise_()
        self._tray_visible_windows = []

    def quit_application(self):
        self._force_exit = True
        self.close()

    def show_edit_menu(self):
        menu = QMenu(self)
        editor = self.editor

        undo = menu.addAction("Undo")
        undo.setShortcut(QKeySequence.StandardKey.Undo)
        undo.setEnabled(editor is not None)
        undo.triggered.connect(lambda: self.editor.undo() if self.editor is not None else None)
        redo = menu.addAction("Redo")
        redo.setShortcut(QKeySequence.StandardKey.Redo)
        redo.setEnabled(editor is not None)
        redo.triggered.connect(lambda: self.editor.redo() if self.editor is not None else None)
        menu.addSeparator()

        cut = menu.addAction("Cut")
        cut.setShortcut(QKeySequence.StandardKey.Cut)
        cut.setEnabled(editor is not None)
        cut.triggered.connect(lambda: self.editor.cut() if self.editor is not None else None)
        copy = menu.addAction("Copy")
        copy.setShortcut(QKeySequence.StandardKey.Copy)
        copy.setEnabled(editor is not None)
        copy.triggered.connect(lambda: self.editor.copy() if self.editor is not None else None)
        paste = menu.addAction("Paste")
        paste.setShortcut(QKeySequence.StandardKey.Paste)
        paste.setEnabled(editor is not None)
        paste.triggered.connect(self.paste)
        delete = menu.addAction("Delete Selection")
        delete.setEnabled(editor is not None)
        delete.triggered.connect(self.delete_selection)
        menu.addSeparator()

        find = menu.addAction("Find")
        find.setShortcut(QKeySequence.StandardKey.Find)
        find.setEnabled(editor is not None)
        find.triggered.connect(lambda: self.editor.show_find() if self.editor is not None else None)
        go_line = menu.addAction("Go to Line...")
        go_line.setShortcut(QKeySequence("Ctrl+G"))
        go_line.setEnabled(editor is not None)
        go_line.triggered.connect(self.go_to_line)
        menu.addSeparator()

        duplicate = menu.addAction("Duplicate Line")
        duplicate.setShortcut(QKeySequence("Ctrl+D"))
        duplicate.setEnabled(editor is not None)
        duplicate.triggered.connect(self.duplicate_current_line)
        comment = menu.addAction("Toggle Comment")
        comment.setShortcut(QKeySequence("Ctrl+/"))
        comment.setEnabled(editor is not None)
        comment.triggered.connect(self.toggle_comment)
        select_all = menu.addAction("Select All")
        select_all.setShortcut(QKeySequence.StandardKey.SelectAll)
        select_all.setEnabled(editor is not None)
        select_all.triggered.connect(lambda: self.editor.selectAll() if self.editor is not None else None)

        menu.exec(self.edit_button.mapToGlobal(QPoint(0, self.edit_button.height() + 4)))

    def delete_selection(self):
        if self.editor is None:
            return
        if self.editor.hasSelectedText():
            self.editor.removeSelectedText()

    def go_to_line(self):
        if self.editor is None:
            return
        current, _ = self.editor.getCursorPosition()
        line, ok = QInputDialog.getInt(
            self, "Go to Line", "Line number", current + 1, 1, max(1, self.editor.lines())
        )
        if ok:
            self.editor.setCursorPosition(line - 1, 0)
            self.editor.ensureLineVisible(line - 1)
            self.editor.setFocus()

    def duplicate_current_line(self):
        if self.editor is None:
            return
        line, index = self.editor.getCursorPosition()
        text = self.editor.text(line)
        if not text.endswith(("\n", "\r")):
            text += "\n"
        self.editor.setCursorPosition(line, len(self.editor.text(line).rstrip("\r\n")))
        self.editor.insert("\n" + self.editor.text(line).rstrip("\r\n"))
        self.editor.setCursorPosition(line + 1, min(index, len(self.editor.text(line + 1).rstrip("\r\n"))))

    def toggle_comment(self):
        if self.editor is None:
            return
        start_line, _start_index, end_line, _end_index = self.editor.getSelection()
        if start_line < 0:
            start_line, _ = self.editor.getCursorPosition()
            end_line = start_line
        lines = [self.editor.text(row).rstrip("\r\n") for row in range(start_line, end_line + 1)]
        nonempty = [line for line in lines if line.strip()]
        uncomment = bool(nonempty) and all(re.match(r"^\s*--", line) for line in nonempty)
        self.editor.beginUndoAction()
        try:
            for row in range(end_line, start_line - 1, -1):
                text = self.editor.text(row).rstrip("\r\n")
                if not text.strip():
                    continue
                if uncomment:
                    updated = re.sub(r"^(\s*)--\s?", r"\1", text, count=1)
                else:
                    match = re.match(r"\s*", text)
                    pos = len(match.group(0)) if match else 0
                    updated = text[:pos] + "-- " + text[pos:]
                self.editor.setSelection(row, 0, row, len(text))
                self.editor.replaceSelectedText(updated)
        finally:
            self.editor.endUndoAction()
        self.editor.setSelection(start_line, 0, end_line, len(self.editor.text(end_line).rstrip("\r\n")))

    def open_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Open folder")
        if not folder:
            return
        root = Path(folder)
        try:
            paths = sorted(
                path for path in root.rglob("*")
                if path.is_file() and path.suffix.casefold() in {".luau", ".lua", ".txt", ".md"}
            )
        except OSError as exc:
            self.log(f"Could not open folder: {exc}", "warning")
            return
        if not paths:
            self.log("No supported script or text files were found in that folder.", "warning")
            return
        if len(paths) > 128:
            result = QMessageBox.question(
                self,
                "Open Folder",
                f"This folder contains {len(paths)} supported files. Open the first 128?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel,
                QMessageBox.StandardButton.Cancel,
            )
            if result != QMessageBox.StandardButton.Yes:
                return
            paths = paths[:128]
        opened = 0
        for path in paths:
            try:
                if path.stat().st_size > 16 * 1024 * 1024:
                    continue
                text = path.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeError):
                continue
            editor = self.add_editor_tab(path.name, text, select=False)
            editor._lel_path = str(path)
            opened += 1
        if opened:
            self.editor_tabs.setCurrentIndex(self.editor_tabs.count() - opened)
            self.log(f"Opened {opened} file{'s' if opened != 1 else ''} from {root.name}.", "success")
        else:
            self.log("The supported files in that folder could not be opened.", "warning")

    def _save_script_to_path(self, path):
        if self.editor is None:
            return False
        try:
            source = self.editor.text()
            Path(path).write_text(source, encoding="utf-8", newline="")
            self.set_current_tab_name(Path(path).name)
            self.editor._lel_path = str(path)
            self.log(f"Saved {Path(path).name}.", "success")
            return True
        except (OSError, MemoryError, UnicodeError) as exc:
            self.log(f"Could not save script: {exc}", "warning")
            return False

    def save_script_as(self):
        if self.loading:
            self.log("Finish or cancel the current load before saving.", "warning")
            return
        if self.editor is None:
            self.log("No script tab is open.", "warning")
            return
        suggested = self.current_tab_name().strip() or "script.luau"
        current_path = str(getattr(self.editor, "_lel_path", "") or "")
        start_dir = Path(current_path).parent if current_path else Path(str(self.settings.value("files/last_directory", "") or ""))
        initial = str(start_dir / suggested) if str(start_dir) not in {"", "."} else suggested
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Save script as",
            initial,
            "Supported files (*.luau *.lua *.txt *.script);;Luau (*.luau);;Lua (*.lua);;Script (*.script);;Text (*.txt);;Extensionless / all files (*)",
        )
        if path:
            self.settings.setValue("files/last_directory", str(Path(path).parent))
            self.settings.sync()
            self._save_script_to_path(path)

    def next_tab_name(self):
        used = set()
        for index in range(self.editor_tabs.count()):
            editor = self.tab_editor(index)
            if not isinstance(editor, CodeEditor):
                continue
            match = re.fullmatch(r"script(\d+)\.luau", str(getattr(editor, "_lel_name", "") or "").casefold())
            if match:
                used.add(int(match.group(1)))
        number = 1
        while number in used:
            number += 1
        self.tab_counter = number
        return f"script{number}.luau"

    def tab_editor(self, index_or_widget):
        widget = index_or_widget
        if isinstance(index_or_widget, int):
            if index_or_widget < 0 or index_or_widget >= self.editor_tabs.count():
                return None
            widget = self.editor_tabs.widget(index_or_widget)
        if isinstance(widget, CodeEditor):
            return widget
        editor = getattr(widget, "_lel_editor", None)
        return editor if isinstance(editor, CodeEditor) else None

    def editor_tab_index(self, editor):
        if not isinstance(editor, CodeEditor):
            return -1
        index = self.editor_tabs.indexOf(editor)
        if index >= 0:
            return index
        parent = editor.parentWidget()
        while parent is not None:
            index = self.editor_tabs.indexOf(parent)
            if index >= 0:
                return index
            parent = parent.parentWidget()
        return -1

    def configure_editor(self, editor):
        editor.paste_handler = self.paste
        editor.setUtf8(True)
        manager = getattr(self, "appearance_manager", None)
        editor_font_size = manager.value("editor_font_size", 11) if manager is not None and manager.active else 11
        font = QFont("Consolas", max(8, min(24, int(editor_font_size))))
        font.setStyleHint(QFont.StyleHint.Monospace)
        editor.setFont(font)
        editor_bg = self.appearance_color("editor_bg", ui_config("editor", "background", "#121416"))
        editor._lel_background = editor_bg
        editor.setColor(QColor(self.appearance_color("editor_text", ui_config("editor", "text", "#f1f2f2"))))
        editor.setPaper(QColor(editor_bg))
        editor.setFrameShape(QFrame.Shape.NoFrame)
        editor.setLineWidth(0)
        editor.setStyleSheet(f"QsciScintilla {{ background: {editor_bg}; border: none; border-radius: 0px; padding: 0px; }}")
        editor.viewport().setStyleSheet(f"background: {editor_bg}; border: none;")
        editor.setCaretForegroundColor(QColor(self.appearance_color("caret", ui_config("editor", "caret", "#ffffff"))))
        editor.setSelectionBackgroundColor(QColor(self.appearance_color("editor_selection", ui_config("editor", "selection", "#292e31"))))
        editor.setSelectionForegroundColor(QColor(self.appearance_color("editor_text", ui_config("editor", "text", "#f1f2f2"))))
        editor.setCaretLineVisible(False)
        editor.setMargins(0)
        editor.setTabWidth(4)
        editor.setIndentationsUseTabs(False)
        editor.setAutoIndent(True)
        editor.setWrapMode(QsciScintilla.WrapMode.WrapNone)
        editor.setFolding(QsciScintilla.FoldStyle.NoFoldStyle)
        editor.setBraceMatching(QsciScintilla.BraceMatch.StrictBraceMatch)
        editor.setIndentationGuides(True)
        editor.setAutoCompletionSource(QsciScintilla.AutoCompletionSource.AcsNone)
        editor.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        editor.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        editor.SendScintilla(editor.SCI_SETSCROLLWIDTH, 1)
        editor.SendScintilla(editor.SCI_SETSCROLLWIDTHTRACKING, 1)
        editor.SendScintilla(editor.SCI_SETLAYOUTCACHE, editor.SC_CACHE_PAGE)
        editor.SendScintilla(editor.SCI_SETIDLESTYLING, editor.SC_IDLESTYLING_ALL)
        lexer = LuauLexer(editor)
        lexer.setPaper(QColor(editor_bg))
        editor._lel_lexer = lexer
        editor._lel_syntax_styles = self.editor_syntax_styles(editor)
        editor.SendScintilla(editor.SCI_STYLESETFORE, editor.STYLE_DEFAULT, QColor(self.appearance_color("editor_text", ui_config("editor", "text", "#f1f2f2"))))
        editor.SendScintilla(editor.SCI_STYLESETBACK, editor.STYLE_DEFAULT, QColor(self.appearance_color("editor_bg", ui_config("editor", "background", "#121416"))))
        editor.SendScintilla(editor.SCI_STYLESETFONT, editor.STYLE_DEFAULT, b"Consolas")
        editor.SendScintilla(editor.SCI_STYLESETSIZE, editor.STYLE_DEFAULT, 11)
        editor.SendScintilla(editor.SCI_STYLECLEARALL)

    def editor_syntax_styles(self, editor):
        lexer = editor._lel_lexer
        return {
            self.syntax_color("syntax_comment", syntax_config("syntax_comment", "#7f936f")): (lexer.Comment, lexer.LineComment),
            self.syntax_color("syntax_keyword", syntax_config("syntax_keyword", "#86a8e7")): (lexer.Keyword,),
            self.syntax_color("syntax_string", syntax_config("syntax_string", "#a8c77a")): (lexer.String, lexer.Character, lexer.LiteralString, lexer.UnclosedString),
            self.syntax_color("syntax_number", syntax_config("syntax_number", "#c9a56f")): (lexer.Number,),
            self.syntax_color("syntax_operator", syntax_config("syntax_operator", "#d7dadd")): (lexer.Operator,),
            self.syntax_color("syntax_builtin", syntax_config("syntax_builtin", "#7db0d5")): (lexer.BasicFunctions, lexer.KeywordSet5, lexer.KeywordSet6, lexer.KeywordSet7),
            self.syntax_color("syntax_function", syntax_config("syntax_function", "#7daee0")): (lexer.StringTableMathsFunctions, lexer.CoroutinesIOSystemFacilities),
            self.syntax_color("syntax_type", syntax_config("syntax_type", "#b5a0d2")): (lexer.KeywordSet8,),
        }

    def syntax_color(self, key, default):
        default = syntax_config(key, default)
        value = str(self.settings.value(f"editor/syntax_colors/{key}", default) or default)
        legacy = {
            "#66945f": "#7f936f", "#ff7ab2": "#86a8e7", "#e6c07b": "#a8c77a", "#f5a97f": "#c9a56f",
            "#d8dee9": "#d7dadd", "#64d1c1": "#7db0d5", "#65b7f3": "#7daee0", "#c792ea": "#b5a0d2",
        }
        value = legacy.get(value.lower(), value)
        return QColor(value).name() if QColor(value).isValid() else default

    def set_syntax_color(self, key, value):
        color = QColor(str(value))
        if not color.isValid():
            return
        self.settings.setValue(f"editor/syntax_colors/{key}", color.name())
        self.settings.sync()
        for index in range(self.editor_tabs.count()):
            editor = self.tab_editor(index)
            if isinstance(editor, CodeEditor):
                editor._lel_syntax_styles = self.editor_syntax_styles(editor)
        self.update_colors()

    def show_tab_extension(self):
        value = self.settings.value("tabs/show_extension", False)
        if isinstance(value, bool):
            return value
        return str(value).strip().casefold() not in {"0", "false", "off", "no"}

    def set_show_tab_extension(self, enabled):
        self.settings.setValue("tabs/show_extension", bool(enabled))
        self.settings.sync()
        self.refresh_tab_labels()

    def tab_display_name(self, name):
        value = str(name or "script.luau")
        if not self.show_tab_extension() and value.casefold().endswith(".luau"):
            return value[:-5]
        return value

    def refresh_tab_labels(self):
        for index in range(self.editor_tabs.count()):
            editor = self.tab_editor(index)
            if isinstance(editor, CodeEditor):
                self.editor_tabs.setTabText(
                    index, self.tab_display_name(getattr(editor, "_lel_name", "script.luau"))
                )

    def add_editor_tab(self, name=None, text="", path=None, select=True):
        if not name:
            name = self.next_tab_name()
        else:
            if name.startswith("script") and name.endswith(".luau"):
                try:
                    number = int(name[6:-5])
                    self.tab_counter = max(self.tab_counter, number)
                except ValueError:
                    pass
        editor = CodeEditor(self)
        self.configure_editor(editor)
        editor._lel_path = str(path) if path else None
        editor._lel_name = str(name)
        editor.setText(text or "")
        editor.SendScintilla(editor.SCI_EMPTYUNDOBUFFER)
        try:
            editor.textChanged.connect(lambda: self._queue_extension_event("editor.changed", 120))
            editor.selectionChanged.connect(lambda: self._queue_extension_event("selection.changed", 80))
        except Exception:
            pass
        page = EditorPage(editor, self.editor_tabs)
        index = self.editor_tabs.addTab(page, app_icon("tab"), self.tab_display_name(editor._lel_name))
        self.editor_tabs._editor_bar.install_close_button(index)
        if select:
            self.editor_tabs.setCurrentIndex(index)
        enabled = self.syntax_colors_enabled
        self.apply_editor_colors(editor, enabled)
        self.editor_tabs._editor_bar._place_new_button()
        self.update_editor_action_state()
        return editor

    def add_blank_tab(self):
        if self.loading:
            return
        editor = self.add_editor_tab(self.next_tab_name(), "", select=True)
        editor.setFocus()

    def on_editor_tab_changed(self, index):
        editor = self.tab_editor(index) if index >= 0 else None
        self.editor = editor if isinstance(editor, CodeEditor) else None
        self.update_editor_action_state()
        if hasattr(self, "_extension_events"):
            self._queue_extension_event("tab.changed", 10)

    def close_editor_tab(self, index):
        if self.loading or index < 0 or index >= self.editor_tabs.count():
            return
        page = self.editor_tabs.widget(index)
        editor = self.tab_editor(index)
        if editor is None:
            return
        rename_editor = getattr(self, "_tab_rename_editor", None)
        if rename_editor is editor:
            self._finish_tab_rename(False)
        self.editor_tabs.removeTab(index)
        if page is not None:
            page.deleteLater()
        else:
            editor.deleteLater()
        if self.editor_tabs.count() == 0:
            self.editor = None
            self.tab_counter = 0
        self.editor_tabs._editor_bar._place_new_button()
        self.update_editor_action_state()

    def current_tab_name(self):
        if self.editor is None:
            return ""
        return str(getattr(self.editor, "_lel_name", "script.luau") or "script.luau")

    def set_current_tab_name(self, name):
        if self.editor is None:
            return
        index = self.editor_tab_index(self.editor)
        if index < 0:
            return
        full_name = str(name or "script.luau")
        self.editor._lel_name = full_name
        self.editor_tabs.setTabText(index, self.tab_display_name(full_name))

    def update_editor_action_state(self):
        has_editor = self.editor is not None
        if hasattr(self, "execute_button"):
            self.execute_button.setEnabled(has_editor and not self.busy and not self.loading)
        if hasattr(self, "save_button"):
            self.save_button.setEnabled(has_editor and not self.loading)
        if hasattr(self, "editor_save_button"):
            self.editor_save_button.setEnabled(has_editor and not self.loading)

    def rename_current_tab(self):
        index = self.editor_tabs.currentIndex()
        if index >= 0:
            self.begin_tab_rename(index)

    def begin_tab_rename(self, index):
        if self.loading or index < 0 or index >= self.editor_tabs.count():
            return
        if getattr(self, "_tab_rename_edit", None) is not None:
            self._finish_tab_rename(True)
        editor = self.tab_editor(index)
        if not isinstance(editor, CodeEditor):
            return
        self.editor_tabs.setCurrentIndex(index)
        full_name = str(getattr(editor, "_lel_name", "script.luau") or "script.luau")
        if full_name.casefold().endswith(".luau"):
            base_name = full_name[:-5]
        else:
            base_name = Path(full_name).stem or "script"
        bar = self.editor_tabs._editor_bar
        bar._set_hover_index(-1)
        rect = bar.tabRect(index).adjusted(5, 3, -23, -3)
        edit = QLineEdit(bar)
        edit.setObjectName("tabRenameEdit")
        edit.setGeometry(rect)
        edit.setText(base_name)
        edit.setMaxLength(180)
        self._tab_rename_edit = edit
        self._tab_rename_editor = editor
        edit.returnPressed.connect(lambda: self._finish_tab_rename(True))
        edit.editingFinished.connect(lambda e=edit: self._finish_tab_rename(True) if getattr(self, "_tab_rename_edit", None) is e else None)
        escape = QShortcut(QKeySequence("Escape"), edit)
        escape.activated.connect(lambda: self._finish_tab_rename(False))
        edit._lel_escape_shortcut = escape
        edit.show()
        edit.raise_()
        edit.setFocus()
        edit.selectAll()

    def _finish_tab_rename(self, commit):
        edit = getattr(self, "_tab_rename_edit", None)
        editor = getattr(self, "_tab_rename_editor", None)
        if edit is None:
            return
        self._tab_rename_edit = None
        self._tab_rename_editor = None
        if commit and isinstance(editor, CodeEditor):
            index = self.editor_tab_index(editor)
            if index >= 0:
                base_name = edit.text().strip()
                while base_name.casefold().endswith(".luau"):
                    base_name = base_name[:-5].rstrip()
                for char in '\\/:*?"<>|':
                    base_name = base_name.replace(char, "_")
                base_name = base_name.strip().strip(".")
                if base_name:
                    editor._lel_name = base_name + ".luau"
                    self.editor_tabs.setTabText(
                        index, self.tab_display_name(editor._lel_name)
                    )
        edit.hide()
        edit.deleteLater()

    def apply_editor_colors(self, editor, enabled):
        if editor is None:
            return
        if hasattr(editor, "set_semantic_highlighting_enabled"):
            editor.set_semantic_highlighting_enabled(enabled)
        send = editor.SendScintilla
        send(editor.SCI_SETIDLESTYLING, editor.SC_IDLESTYLING_ALL)
        background = QColor(self.appearance_color("editor_bg", ui_config("editor", "background", "#121416")))
        foreground = QColor(self.appearance_color("editor_text", ui_config("editor", "text", "#f1f2f2")))
        lexer = editor._lel_lexer
        lexer.setPaper(background)
        send(editor.SCI_SETLEXER, editor.SCLEX_NULL)
        for style in range(33):
            send(editor.SCI_STYLESETFORE, style, foreground)
            send(editor.SCI_STYLESETBACK, style, background)
        if not enabled:
            send(editor.SCI_COLOURISE, 0, -1)
            return
        send(editor.SCI_SETLEXER, editor.SCLEX_LUA)
        for style in range(33):
            send(editor.SCI_STYLESETBACK, style, background)
        for color, styles in editor._lel_syntax_styles.items():
            for style in styles:
                send(editor.SCI_STYLESETFORE, style, QColor(color))
        for number in range(1, 9):
            words = (lexer.keywords(number) or "").encode("utf-8")
            send(editor.SCI_SETKEYWORDS, number - 1, words)
        send(editor.SCI_SETPROPERTY, b"fold", b"0")
        send(editor.SCI_COLOURISE, 0, -1)

    def sci(self, message, *args):
        return self.editor.SendScintilla(message, *args)

    @staticmethod
    def set_button_icon(button, name):
        button.setProperty("_lel_icon_name", str(name))
        icon = app_icon(name)
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(18, 18))

    def refresh_visual_icons(self):
        for button in self.findChildren(QPushButton):
            name = button.property("_lel_icon_name")
            if name:
                icon = app_icon(str(name))
                if not icon.isNull(): button.setIcon(icon)
        if hasattr(self, "visual_wizard_button"):
            self.visual_wizard_button.setIcon(palette_icon(20))
        if hasattr(self, "editor_tabs"):
            icon = app_icon("tab")
            for index in range(self.editor_tabs.count()):
                self.editor_tabs.setTabIcon(index, icon)
        
        

    def appearance_color(self, key, default):
        manager = getattr(self, "appearance_manager", None)
        return manager.color(key, default) if manager is not None and manager.active else default

    def _proxy_snapshot_has_enabled_custom_fastflags(self):
        snapshot = getattr(self, "_proxy_custom_fastflag_snapshot", None)
        if not isinstance(snapshot, dict):
            return False
        names = set(snapshot.get("names", ()))
        disabled = set(snapshot.get("disabled", ()))
        return bool(names - disabled)

    def _disable_custom_fastflags_for_proxy(self):
        if getattr(self, "_proxy_custom_fastflag_snapshot", None) is not None:
            return
        flags = self.load_custom_fastflags()
        state = self.load_custom_fastflag_state()
        names = set(flags)
        disabled_before = set(state.get("disabled", ())) & names
        self._proxy_custom_fastflag_snapshot = {
            "names": sorted(names),
            "disabled": sorted(disabled_before),
        }
        if not names:
            return
        disabled_now = set(state.get("disabled", ()))
        disabled_now.update(names)
        state["disabled"] = sorted(disabled_now)
        self.save_custom_fastflag_state(state)
        self.mark_custom_fastflags_changed()
        self.refresh_custom_fastflag_hotkeys()
        window = getattr(self, "fastflags_window", None)
        if window is not None:
            window._load_custom_flag_table()

    def _restore_custom_fastflags_after_proxy(self):
        snapshot = getattr(self, "_proxy_custom_fastflag_snapshot", None)
        if not isinstance(snapshot, dict):
            return
        self._proxy_custom_fastflag_snapshot = None
        flags = self.load_custom_fastflags()
        state = self.load_custom_fastflag_state()
        current_names = set(flags)
        original_names = set(snapshot.get("names", ())) & current_names
        original_disabled = set(snapshot.get("disabled", ())) & current_names
        disabled_now = set(state.get("disabled", ()))
        disabled_now.difference_update(original_names)
        disabled_now.update(original_disabled)
        state["disabled"] = sorted(disabled_now)
        self.save_custom_fastflag_state(state)
        self.mark_custom_fastflags_changed()
        self.refresh_custom_fastflag_hotkeys()
        window = getattr(self, "fastflags_window", None)
        if window is not None:
            window._load_custom_flag_table()

    def _set_proxy_runtime_suspended(self, suspended):
        suspended = bool(suspended)
        if not suspended:
            self._restore_custom_fastflags_after_proxy()
        state = username_proxy_runtime()
        state["suspended"] = suspended
        write_json_object(PROXY_RUNTIME_PATH, state)
        self._proxy_api_suspended = suspended

    def proxy_suspended_for_api(self):
        return bool(getattr(self, "_proxy_api_suspended", False) or self.api_attached)

    def proxy_features_needed(self):
        return (
            self.fastflags_any_enabled()
            or self._proxy_snapshot_has_enabled_custom_fastflags()
            or username_proxy_enabled()
        )

    def refresh_proxy_for_active_session(self):
        if self.proxy_suspended_for_api() or not self.proxy_features_needed():
            return False
        if self.roblox_running is True and self.roblox_session_mode == "proxy":
            self.start_proxy_in_background()
            return True
        if self.roblox_running is True:
            self.set_fastflags_restart_required(True)
        return False

    def notify_proxy_attached_limit(self):
        if self._proxy_attach_notice_shown:
            return
        self._proxy_attach_notice_shown = True
        message = (
            "Attach mode and the local client proxy cannot be used in the same Roblox session. "
            "Roblox must restart when switching between them."
        )
        self.log(message, "warning")
        self.notify_user("LelSploit", message, 5500)

    def stop_interception_proxy(self):
        self._disable_custom_fastflags_for_proxy()
        self._set_proxy_runtime_suspended(True)
        self._auto_proxy_probe_token += 1
        process = self.proxy_process
        self.proxy_process = None
        self._proxy_starting = False
        self._proxy_ready_logged = False
        if process is not None and process.poll() is None:
            try:
                process.terminate()
                process.wait(timeout=2)
            except Exception:
                try:
                    process.kill()
                except Exception:
                    pass
        try:
            PROXY_READY_PATH.unlink(missing_ok=True)
        except OSError:
            pass
        try:
            restore_roblox_proxy_ca()
        except Exception:
            pass

    def set_proxy_api_suspended(self, suspended, notify=False):
        suspended = bool(suspended)
        if suspended:
            self.stop_interception_proxy()
            if notify and self.proxy_features_needed():
                self.notify_proxy_attached_limit()
            return

        self._set_proxy_runtime_suspended(False)
        self._proxy_attach_notice_shown = False
        if self.roblox_running is True:
            if self.roblox_session_mode == "proxy" and self.proxy_features_needed():
                self.refresh_proxy_for_active_session()
            elif self.proxy_features_needed() and not self.roblox_proxy_active:
                self.set_fastflags_restart_required(True)
            return

    def _install_proxy_dependency(self):
        answer = QMessageBox.question(
            self,
            "Local Roblox proxy",
            "Live client customization needs two small networking packages that are not installed. Install them now?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.Yes,
        )
        if answer != QMessageBox.StandardButton.Yes:
            return False
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            result = subprocess.run(
                [python_console_executable(), "-m", "pip", "install", "cryptography", "zstandard"],
                capture_output=True,
                text=True,
                errors="replace",
                timeout=180,
                creationflags=NO_WINDOW,
                check=False,
            )
        except Exception as exc:
            QMessageBox.warning(self, "Local Roblox proxy", f"Could not install the networking dependency: {exc}")
            return False
        finally:
            QApplication.restoreOverrideCursor()
        if result.returncode != 0:
            detail = (result.stderr or result.stdout or "pip failed").strip().splitlines()[-1]
            QMessageBox.warning(self, "Local Roblox proxy", f"Could not install the networking dependency:\n{detail}")
            return False
        return proxy_dependencies_available()

    def ensure_interception_proxy(self, interactive=False):
        if self.proxy_suspended_for_api():
            if interactive:
                self.notify_proxy_attached_limit()
            return False
        if sys.platform != "win32":
            if interactive:
                QMessageBox.warning(self, "Local Roblox proxy", "Live Roblox traffic customization is currently available on Windows.")
            return False
        if self.proxy_process is not None and self.proxy_process.poll() is None:
            ca = PROXY_DIR / "ca.crt"
            if ca.is_file():
                patch_roblox_proxy_ca(ca)
            return True
        if not proxy_dependencies_available():
            if not interactive or not self._install_proxy_dependency():
                return False
        try:
            PROXY_READY_PATH.unlink(missing_ok=True)
        except OSError:
            pass
        PROXY_DIR.mkdir(parents=True, exist_ok=True)
        try:
            self.proxy_port = choose_proxy_port(PROXY_PORT)
        except OSError as exc:
            if interactive:
                QMessageBox.warning(self, "Local Roblox proxy", str(exc))
            return False
        
        
        
        executable = Path(sys.executable)
        if executable.name.casefold() in {"python.exe", "pythonw.exe", "python3.exe", "python3"} or executable.name.casefold().startswith("python"):
            command = [
                python_console_executable(),
                str(RUNTIME_DIR / "main.pyw"),
                "--lelsploit-proxy",
                "--port", str(self.proxy_port),
                "--base", str(APPDATA_DIR),
            ]
        else:
            command = [
                str(executable),
                "--lelsploit-proxy",
                "--port", str(self.proxy_port),
                "--base", str(APPDATA_DIR),
            ]
        try:
            self.proxy_process = subprocess.Popen(
                command,
                cwd=str(APPDATA_DIR),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=NO_WINDOW,
                close_fds=True,
            )
        except OSError as exc:
            self.proxy_process = None
            if interactive:
                QMessageBox.warning(self, "Local Roblox proxy", f"Could not start the local proxy: {exc}")
            return False
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if self.proxy_process.poll() is not None:
                break
            ready = read_json_object(PROXY_READY_PATH, default={})
            ca = PROXY_DIR / "ca.crt"
            if isinstance(ready, dict) and int(ready.get("port", 0) or 0) == self.proxy_port and ca.is_file():
                patch_roblox_proxy_ca(ca)
                if not getattr(self, "_proxy_ready_logged", False):
                    self._proxy_ready_logged = True
                    self.log(f"Local Roblox proxy ready on 127.0.0.1:{self.proxy_port}.", "success")
                return True
            time.sleep(0.1)
        if interactive:
            QMessageBox.warning(self, "Local Roblox proxy", "The local proxy did not finish starting.")
        return False

    def start_proxy_in_background(self):
        if sys.platform != "win32" or self.proxy_suspended_for_api():
            return
        if getattr(self, "_proxy_starting", False):
            return
        self._proxy_starting = True

        def worker():
            try:
                self.ensure_interception_proxy(interactive=False)
            finally:
                self._proxy_starting = False

        threading.Thread(target=worker, daemon=True).start()

    def roblox_launch_environment(self):
        if not self.proxy_features_needed() or self.proxy_suspended_for_api() or self.roblox_session_mode == "attach":
            return None
        if not self.ensure_interception_proxy(interactive=False):
            return None
        proxy = f"http://127.0.0.1:{self.proxy_port}"
        env = os.environ.copy()
        for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
            env[key] = proxy
        env["NO_PROXY"] = "127.0.0.1,localhost"
        env["no_proxy"] = env["NO_PROXY"]
        return env

    def fastflags_enabled(self):
        value = self.settings.value("fastflags/enabled", False)
        if isinstance(value, str):
            return value.strip().casefold() not in {"0", "false", "no", "off"}
        return bool(value)

    def custom_fastflags_enabled(self):
        return bool(active_custom_fastflags(self.load_custom_fastflags()))

    def fastflags_any_enabled(self):
        return self.fastflags_enabled() or self.custom_fastflags_enabled()

    def load_custom_fastflags(self):
        return load_custom_fastflags()

    def save_custom_fastflags(self, flags):
        return save_custom_fastflags(flags)

    def load_custom_fastflag_state(self):
        return load_custom_fastflag_state()

    def save_custom_fastflag_state(self, state):
        return save_custom_fastflag_state(state)

    def refresh_custom_fastflag_hotkeys(self):
        if not hasattr(self, "fastflag_hotkeys"):
            return
        state = self.load_custom_fastflag_state()
        flags = self.load_custom_fastflags()
        bindings = {name: spec for name, spec in state.get("keybinds", {}).items() if name in flags}
        self.fastflag_hotkeys.set_bindings(bindings)

    def toggle_custom_fastflag_hotkey(self, name):
        flags = self.load_custom_fastflags()
        if name not in flags:
            return
        state = self.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        enabled = name in disabled
        if enabled:
            disabled.discard(name)
        else:
            disabled.add(name)
        state["disabled"] = sorted(disabled)
        self.save_custom_fastflag_state(state)
        self.mark_custom_fastflags_changed()
        if not self.proxy_suspended_for_api():
            self.refresh_proxy_for_active_session()
        if self.roblox_running is True and not self.roblox_proxy_active:
            self.set_fastflags_restart_required(True)
        if self.fastflags_window is not None:
            self.fastflags_window._load_custom_flag_table()
        self.log(f"FastFlag {name} {'enabled' if enabled else 'disabled'} by hotkey.", "success")

    def load_effective_fastflags(self):
        return merge_fastflags(
            self.load_fastflags(), self.load_custom_fastflags(),
            self.fastflags_enabled(), self.custom_fastflags_enabled(),
        )

    def mark_custom_fastflags_changed(self):
        state = read_json_object(PROXY_STATE_PATH, {})
        if not isinstance(state, dict):
            state = {}
        state["custom_fastflags_generation"] = int(state.get("custom_fastflags_generation", 0) or 0) + 1
        state["custom_fastflags_changed_at"] = time.time()
        write_json_object(PROXY_STATE_PATH, state)

    def set_fastflags_enabled(self, enabled):
        enabled = bool(enabled)
        previous = self.fastflags_enabled()
        self.settings.setValue("fastflags/enabled", enabled)
        self.settings.sync()
        if previous and not enabled:
            remove_matching_fastflags_from_roblox(self.load_fastflags())
        elif enabled:
            self.request_fastflag_sync(force=True)
            prime_windows_fastflag_cache(self.load_effective_fastflags())
            if self.proxy_suspended_for_api():
                self.notify_proxy_attached_limit()
            elif self.roblox_running is True:
                self.refresh_proxy_for_active_session()

    def load_fastflags(self):
        return load_saved_fastflags()

    def save_fastflags(self, flags):
        return save_saved_fastflags(flags)

    def request_fastflag_sync(self, force=False):
        if sys.platform != "win32" or self.fastflag_checking:
            return
        if not force and not self.fastflags_any_enabled():
            return
        self.fastflag_checking = True
        threading.Thread(target=self.fastflag_sync_worker, daemon=True).start()

    def fastflag_sync_worker(self):
        try:
            target = sync_saved_fastflags_to_roblox(
                self.load_effective_fastflags(), self.fastflags_any_enabled()
            )
            self.roblox_events.put(("fastflags_synced", str(target) if target else ""))
        except Exception as exc:
            self.roblox_events.put(("fastflags_sync_error", str(exc)))

    def apply_saved_framerate_cap(self):
        value = self.settings.value("global/framerate_cap", None)
        if value is None:
            return 0
        try:
            value = int(value)
        except (TypeError, ValueError):
            return 0
        return write_roblox_framerate_cap(60 if value == 0 else value)

    def request_modification_sync(self, force=False):
        if sys.platform != "win32" or self.mod_checking:
            return
        if not _read_modifications_data().get("entries"):
            return
        root = roblox_resource_dir()
        if root is None:
            return
        if not force and self.mod_last_root == str(root):
            return
        self.mod_checking = True
        threading.Thread(target=self.modification_sync_worker, daemon=True).start()

    def modification_sync_worker(self):
        try:
            applied = sync_saved_modifications_to_roblox()
            if not roblox_is_running():
                self.apply_saved_framerate_cap()
            root = roblox_resource_dir()
            self.roblox_events.put(("mods_synced", str(root) if root else "", len(applied)))
        except Exception as exc:
            self.roblox_events.put(("mods_sync_error", str(exc)))

    def restart_roblox_from_fastflags(self):
        if sys.platform != "win32" or self.roblox_busy:
            return
        if self.proxy_features_needed() and not self.ensure_interception_proxy(interactive=True):
            return
        self.roblox_busy = True
        self.roblox_button.setEnabled(False)
        self.roblox_button.setText("Restarting...")
        threading.Thread(
            target=self.roblox_action_worker, args=("restart",), daemon=True
        ).start()

    def fastflags_restart_required(self):
        value = self.settings.value("fastflags/restart_required", False)
        if isinstance(value, str):
            return value.strip().casefold() not in {"0", "false", "no", "off"}
        return bool(value)

    def set_fastflags_restart_required(self, required):
        required = bool(required)
        if self.fastflags_restart_required() == required:
            if self.fastflags_window is not None:
                self.fastflags_window.update_change_state()
            return
        self.settings.setValue("fastflags/restart_required", required)
        self.settings.sync()
        if self.fastflags_window is not None:
            self.fastflags_window.update_change_state()

    def erase_local_data(self):
        """Erase LelSploit-owned mutable data without touching installation/runtime assets.

        This intentionally deletes only paths LelSploit itself owns as user state,
        cache, backup, extension content, or runtime output. Unknown files/folders
        beside the app are preserved because packaged builds can contain seemingly
        arbitrary dependency directories that are required to start.
        """
        errors = []

        def remove_file(path):
            path = Path(path)
            try:
                path.unlink(missing_ok=True)
            except Exception as exc:
                errors.append(f"{path}: {exc}")

        def remove_tree(path):
            path = Path(path)
            try:
                if path.exists():
                    shutil.rmtree(path)
            except Exception as exc:
                errors.append(f"{path}: {exc}")

        def clear_owned_directory(path):
            path = Path(path)
            try:
                clear_directory_contents(path)
            except Exception as exc:
                
                if path.name.casefold() != "logs":
                    errors.append(f"{path}: {exc}")

        
        
        try:
            remove_matching_fastflags_from_roblox(self.load_fastflags())
            restore_all_modifications()
            restore_roblox_proxy_ca()
        except Exception as exc:
            errors.append(f"Client modifications: {exc}")

        if self.proxy_process is not None and self.proxy_process.poll() is None:
            try:
                self.proxy_process.terminate()
                self.proxy_process.wait(timeout=2)
            except Exception:
                try:
                    self.proxy_process.kill()
                except Exception:
                    pass
        self.proxy_process = None
        self.roblox_proxy_active = False

        
        try:
            self.extension_runtime.retain_extensions(set())
            self.extension_smooth_scroll.retain_extensions(set())
            self.visual_wizard_service.retain_extensions(set())
            self._clear_extension_shortcuts()
        except Exception:
            pass

        
        
        for path in (
            BASE_DIR / "workspace",
            BASE_DIR / "logs",
            BASE_DIR / "autoexec",
        ):
            clear_owned_directory(path)

        
        mutable_files = (
            FASTFLAGS_PATH, CUSTOM_FASTFLAGS_PATH, CUSTOM_FASTFLAG_STATE_PATH,
            FASTFLAG_CATALOG_CACHE_PATH, SETTINGS_PATH, SAVED_SCRIPTS_PATH,
            MODIFICATIONS_PATH, PROXY_RUNTIME_PATH, PROXY_USERNAME_ACTIVE_PATH,
            PROXY_STATE_PATH, PROXY_READY_PATH, EXTENSION_STATE_PATH,
            VISUAL_THEME_PATH, BASE_DIR / "proxy_live_fastflags.json",
            BASE_DIR / "startup_error.log",
        )
        for path in mutable_files:
            remove_file(path)
            remove_file(Path(path).with_name(Path(path).name + ".tmp"))

        
        
        
        for directory in (
            MOD_BACKUP_DIR, MOD_CACHE_DIR, FASTFLAG_BACKUP_DIR, PROXY_DIR,
            EXTENSIONS_DIR, EXTENSION_DATA_DIR, APPDATA_DIR / "__pycache__",
        ):
            remove_tree(directory)

        
        
        for pattern in ("*.json.tmp", "*.lext.tmp"):
            try:
                for path in BASE_DIR.glob(pattern):
                    remove_file(path)
            except Exception:
                pass

        
        with self.settings.lock:
            self.settings.data.clear()
        try:
            self.appearance_manager.theme = dict(VISUAL_THEME_DEFAULT)
            self.appearance_manager.deactivate()
        except Exception:
            pass
        self._extension_started_ids.clear()
        self._extension_records_by_id = {}
        self._extension_events = {}
        self._extension_runtime_signature = None

        if self.scriptblox_window is not None:
            self.scriptblox_window.saved_scripts.clear()
            if self.scriptblox_window.saved_only:
                self.scriptblox_window.refresh_saved()

        if self.extensions_window is not None:
            try:
                self.extensions_window.close()
                self.extensions_window.deleteLater()
            except Exception:
                pass
            self.extensions_window = None

        self.fastflag_last_target = None
        self.mod_last_root = None
        self.refresh_tab_labels()
        self.refresh_visual_icons()
        if self.fastflags_window is not None:
            self.fastflags_window.hide()
            self.fastflags_window = None

        
        try:
            EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
        except Exception as exc:
            errors.append(f"{EXTENSIONS_DIR}: {exc}")
        return errors

    def install_behavior(self):
        value = str(self.settings.value("scriptblox/install_behavior", "ask") or "ask")
        aliases = {
            "editor": "current",
            "editor_execute": "current_execute",
        }
        value = aliases.get(value, value)
        if value not in {"ask", "current", "current_execute", "new", "new_execute"}:
            value = "ask"
        return value

    def resolve_install_behavior(self):
        behavior = self.install_behavior()
        if behavior != "ask":
            return behavior

        dialog = ScriptBloxInstallDialog(self)
        if dialog.exec() != QDialog.DialogCode.Accepted or not dialog.behavior:
            return None

        behavior = dialog.behavior
        self.settings.setValue("scriptblox/install_behavior", behavior)
        self.settings.sync()
        if self.settings_window is not None:
            self.settings_window.reload()
        return behavior

    def log(self, message, level=None):
        return

    def set_syntax_colors_enabled(self, enabled):
        self.syntax_colors_enabled = bool(enabled)
        if self.settings_window is not None and hasattr(self.settings_window, "syntax_colors_check"):
            check = self.settings_window.syntax_colors_check
            check.blockSignals(True)
            check.setChecked(self.syntax_colors_enabled)
            check.blockSignals(False)
        self.update_colors()

    def update_colors(self, *_):
        if self.loading:
            return
        enabled = self.syntax_colors_enabled
        for index in range(self.editor_tabs.count()):
            editor = self.tab_editor(index)
            if isinstance(editor, CodeEditor):
                self.apply_editor_colors(editor, enabled)

    def open_script(self):
        if self.loading:
            self.finish_load(cancelled=True)
            return
        start_dir = str(self.settings.value("files/last_directory", "") or "")
        path, _ = QFileDialog.getOpenFileName(
            self,
            "Open script",
            start_dir,
            "Supported files (*.luau *.lua *.txt *.script);;Luau (*.luau);;Lua (*.lua);;Script (*.script);;Text (*.txt);;Extensionless / all files (*)",
        )
        if path:
            self.settings.setValue("files/last_directory", str(Path(path).parent))
            self.settings.sync()
            self.load_path(path)

    def save_script(self):
        if self.loading:
            self.log("Finish or cancel the current load before saving.", "warning")
            return
        if self.editor is None:
            self.log("No script tab is open.", "warning")
            return
        current_path = str(getattr(self.editor, "_lel_path", "") or "")
        if current_path:
            self._save_script_to_path(current_path)
        else:
            self.save_script_as()

    @staticmethod
    def _toggle_window(window):
        if window is not None and window.isVisible():
            window.close()
            return True
        return False

    def _on_extension_app_state(self, state):
        active = state == Qt.ApplicationState.ApplicationActive
        self._queue_extension_event("app.activated" if active else "app.deactivated", 20)

    def _queue_extension_event(self, event_name, delay=80):
        if event_name not in self._extension_events or not self._extension_events.get(event_name):
            return
        timer = self._extension_event_timers.get(event_name)
        if timer is None:
            timer = QTimer(self); timer.setSingleShot(True)
            timer.timeout.connect(lambda name=event_name: self._trigger_extension_event(name))
            self._extension_event_timers[event_name] = timer
        timer.start(max(0, int(delay)))

    def _trigger_extension_event(self, event_name):
        bindings = list(self._extension_events.get(event_name, ()))
        disabled = set(load_extension_state().get("disabled", []))
        for record, binding in bindings:
            manifest = record.get("manifest") or {}
            ext_id = manifest.get("id", "")
            if not ext_id or ext_id in disabled:
                continue
            try:
                action_id = str(binding.get("action", "") or "")
                action = self.extension_runtime._find_action(manifest, action_id) if action_id else None
                if action is None:
                    action = {"id": f"event_{event_name}", "title": event_name, "inputs": [], "steps": list(binding.get("steps", []))}
                self.extension_runtime.run(record, action, seed_context={"event.name": event_name})
            except Exception as exc:
                self.log(f"Extension {manifest.get('name', 'No title found')} failed on {event_name}: {exc}", "warning")

    def _run_extension_background(self, record, steps, label):
        manifest = record.get("manifest") if isinstance(record, dict) else None
        if not manifest or not steps:
            return
        try:
            action = {"id": label.casefold().replace(" ", "_"), "title": label, "inputs": [], "steps": list(steps)}
            self.extension_runtime.run(record, action)
        except Exception as exc:
            self.log(f"Extension {manifest.get('name', 'No title found')} failed during {label}: {exc}", "warning")

    def _run_extension_interval(self, ext_id):
        state = load_extension_state()
        if ext_id in set(state.get("disabled", [])):
            return
        record = getattr(self, "_extension_records_by_id", {}).get(ext_id)
        if record is not None:
            manifest = record.get("manifest") or {}
            self._run_extension_background(record, manifest.get("interval_steps", []), "Interval")

    def _run_extension_action_by_id(self, ext_id, action_id):
        disabled = set(load_extension_state().get("disabled", []))
        if ext_id in disabled:
            return
        record = getattr(self, "_extension_records_by_id", {}).get(ext_id)
        if record is None:
            return
        manifest = record.get("manifest") or {}
        for action in manifest.get("actions", []):
            if action.get("id") == action_id:
                try:
                    self.extension_runtime.run(record, action)
                except Exception as exc:
                    self.log(f"Extension {manifest.get('name', 'No title found')} failed: {exc}", "warning")
                return

    def _clear_extension_shortcuts(self):
        for shortcut in self._extension_shortcuts:
            try:
                shortcut.setEnabled(False)
                shortcut.deleteLater()
            except Exception:
                pass
        self._extension_shortcuts = []

    def _poll_extensions_runtime_folder(self):
        signature = extension_folder_signature()
        if signature == getattr(self, "_extension_runtime_signature", None):
            return
        self._extension_runtime_signature = signature
        self.refresh_extensions_runtime()
        window = getattr(self, "extensions_window", None)
        if window is not None and window.isVisible():
            window.reload()

    def refresh_extensions_runtime(self, restart_id=None):
        records = scan_extension_packages()
        self._extension_runtime_signature = extension_folder_signature()
        self._extension_records_by_id = {r["manifest"]["id"]: r for r in records if r.get("manifest")}
        disabled = set(load_extension_state().get("disabled", []))
        enabled = {
            record["manifest"]["id"]: record
            for record in records
            if record.get("manifest") and record["manifest"]["id"] not in disabled
        }
        self.extension_smooth_scroll.retain_extensions(set(enabled))
        self.visual_wizard_service.retain_extensions(set(enabled))
        self.extension_runtime.retain_extensions(set(enabled))
        self._extension_events = {}
        for record in enabled.values():
            self.extension_runtime.activate_extension(record)
            for binding in record["manifest"].get("events", []):
                self._extension_events.setdefault(binding.get("event", ""), []).append((record, binding))
        layout = getattr(self, "header_layout", None)
        if layout is not None:
            layout.invalidate(); layout.activate()
        central = self.centralWidget()
        if central is not None:
            central.updateGeometry(); central.update()

        for ext_id, timer in list(self._extension_timers.items()):
            record = enabled.get(ext_id)
            expected = int(record["manifest"].get("interval_ms", 0) or 0) if record else 0
            if record is None or not expected or timer.interval() != expected or ext_id == restart_id:
                timer.stop()
                timer.deleteLater()
                self._extension_timers.pop(ext_id, None)

        self._extension_started_ids.intersection_update(enabled)
        if restart_id:
            self._extension_started_ids.discard(restart_id)

        self._clear_extension_shortcuts()
        used_sequences = set()
        for ext_id, record in enabled.items():
            for binding in record["manifest"].get("shortcuts", []):
                sequence = str(binding.get("keys", "") or "").strip()
                action_id = str(binding.get("action", "") or "").strip()
                folded = sequence.casefold()
                if not sequence or not action_id or folded in used_sequences:
                    continue
                shortcut = QShortcut(QKeySequence(sequence), self)
                shortcut.setContext(Qt.ShortcutContext.ApplicationShortcut)
                shortcut.activated.connect(lambda eid=ext_id, aid=action_id: self._run_extension_action_by_id(eid, aid))
                self._extension_shortcuts.append(shortcut)
                used_sequences.add(folded)

        for ext_id, record in enabled.items():
            manifest = record["manifest"]
            if ext_id not in self._extension_started_ids:
                startup = list(manifest.get("startup", []))
                if startup:
                    self._run_extension_background(record, startup, "Startup")
                self._extension_started_ids.add(ext_id)

            interval_ms = int(manifest.get("interval_ms", 0) or 0)
            interval_steps = manifest.get("interval_steps", [])
            if interval_ms and interval_steps and ext_id not in self._extension_timers:
                timer = QTimer(self)
                timer.setInterval(interval_ms)
                timer.timeout.connect(lambda eid=ext_id: self._run_extension_interval(eid))
                timer.start()
                self._extension_timers[ext_id] = timer

    def _preload_fastflags_window(self):
        if self.fastflags_window is not None or self.stopping.is_set():
            return
        try:
            self.fastflags_window = FastFlagsWindow(self)
            self.fastflags_window.hide()
        except Exception as exc:
            self.fastflags_window = None
            self.log(f"Could not preload FastFlags: {exc}", "warning")

    def open_scriptblox(self):
        if self._toggle_window(self.scriptblox_window):
            return
        if self.scriptblox_window is None:
            self.scriptblox_window = ScriptBloxWindow(self, self.install_script)
        else:
            self.scriptblox_window.prefill_current_game()
        self.scriptblox_window.show()
        self.scriptblox_window.raise_()
        self.scriptblox_window.activateWindow()

    def open_documentation(self):
        if self._toggle_window(self.documentation_window):
            return
        if self.documentation_window is None:
            self.documentation_window = DocumentationWindow(self)
        self.documentation_window.show()
        self.documentation_window.raise_()
        self.documentation_window.activateWindow()

    def open_tools(self):
        if self._toggle_window(self.tools_window):
            return
        if self.tools_window is None:
            self.tools_window = ToolsWindow(self)

        if self.editor is not None and self.sci(self.editor.SCI_GETLENGTH) <= 2 * 1024 * 1024:
            try:
                source = self.editor.text()
            except MemoryError:
                source = ""
            if source:
                self.tools_window.prefill_loadstring(source)
        self.tools_window.show()
        self.tools_window.raise_()
        self.tools_window.activateWindow()

    def open_extensions(self):
        if self._toggle_window(self.extensions_window):
            return
        try:
            if self.extensions_window is None:
                self.extensions_window = ExtensionsWindow(self)
            else:
                self.extensions_window.reload()
            self.extensions_window.show()
            self.extensions_window.raise_()
            self.extensions_window.activateWindow()
        except Exception as exc:
            self.extensions_window = None
            self.log(f"Could not open Extensions: {exc}", "warning")
            QMessageBox.warning(self, "Extensions", f"Could not open Extensions.\n\n{exc}")

    def open_settings(self):
        if self._toggle_window(self.settings_window):
            return
        try:
            if self.settings_window is None:
                self.settings_window = SettingsWindow(self)
            else:
                self.settings_window.reload()
            self.settings_window.show()
            self.settings_window.raise_()
            self.settings_window.activateWindow()
        except Exception as exc:
            self.settings_window = None
            self.log(f"Could not open Settings: {exc}", "warning")
            QMessageBox.warning(self, "Settings", f"Could not open Settings.\n\n{exc}")

    def open_fastflags(self):
        if self._toggle_window(self.fastflags_window):
            return
        try:
            if self.fastflags_window is None:
                self.fastflags_window = FastFlagsWindow(self)
            else:
                self.fastflags_window.update_attached_state()
            self.fastflags_window.show()
            self.fastflags_window.raise_()
            self.fastflags_window.activateWindow()
        except Exception as exc:
            self.fastflags_window = None
            self.log(f"Could not open FastFlags: {exc}", "warning")
            QMessageBox.warning(self, "FastFlags", f"Could not open FastFlags.\n\n{exc}")

    def install_script(self, code, title):
        behavior = self.resolve_install_behavior()
        if behavior is None:
            return False
        if self.loading:
            self.finish_load(cancelled=True)

        name = str(title or "script").strip() or "script"
        if not name.casefold().endswith(".luau"):
            name += ".luau"

        use_new_tab = behavior in {"new", "new_execute"} or self.editor is None
        if use_new_tab:
            target = self.add_editor_tab(name, code, select=True)
        else:
            target = self.editor
            target.SendScintilla(target.SCI_SETLEXER, target.SCLEX_NULL)
            target.SendScintilla(target.SCI_SETUNDOCOLLECTION, 0)
            target.setUpdatesEnabled(False)
            try:
                target.clear()
                target.setText(code)
                target.SendScintilla(target.SCI_EMPTYUNDOBUFFER)
                target.SendScintilla(target.SCI_SETUNDOCOLLECTION, 1)
            finally:
                target.setUpdatesEnabled(True)
            self.set_current_tab_name(name)

        self.editor = target
        self.set_syntax_colors_enabled(True)
        self.apply_editor_colors(target, True)
        target.setCursorPosition(0, 0)
        target.setFocus()
        self.update_editor_action_state()
        self.log(f"Installed {title} from ScriptBlox.", "success")
        if behavior in {"current_execute", "new_execute"}:
            QTimer.singleShot(0, self.execute)
        return True

    def load_path(self, path):
        if self.loading:
            return
        try:
            size = Path(path).stat().st_size
            if sys.maxsize <= 2**32 and size > 64 * 1024 * 1024:
                raise OSError("Use 64-bit Python to open this large file.")
            if size >= 2**31:
                raise OSError("This build supports files below 2 GiB.")
        except OSError as exc:
            self.log(f"Could not open script: {exc}")
            return
        self.load_name = Path(path).name
        self.expected_size = size
        self.loading_editor = self.add_editor_tab(self.load_name, "", path=path, select=True)
        self.begin_load()
        self.load_queue = queue.Queue(maxsize=2)
        self.load_cancel = threading.Event()
        threading.Thread(target=stream_file, args=(path, self.load_queue, self.load_cancel), daemon=True).start()
        self.load_timer.start()

    def begin_load(self):
        self.loading = True
        if self.loading_editor is None:
            self.loading_editor = self.editor
        self.editor = self.loading_editor
        self.editor_tabs.tabBar().setEnabled(False)
        self.editor_tabs._editor_bar.new_button.setEnabled(False)
        self.loaded_bytes = 0
        self.line_bytes = 0
        self.long_line = False
        self.editor.setReadOnly(True)


        self.editor.setUpdatesEnabled(False)
        self.saved_event_mask = self.sci(self.editor.SCI_GETMODEVENTMASK)
        self.sci(self.editor.SCI_SETMODEVENTMASK, 0)
        self.sci(self.editor.SCI_SETLEXER, self.editor.SCLEX_NULL)
        self.editor.setColor(QColor(self.appearance_color("editor_text", ui_config("editor", "text", "#f1f2f2"))))
        self.editor.setPaper(QColor(self.appearance_color("editor_bg", ui_config("editor", "background", "#121416"))))
        self.sci(self.editor.SCI_SETUNDOCOLLECTION, 0)
        self.sci(self.editor.SCI_EMPTYUNDOBUFFER)
        self.execute_button.setEnabled(False)
        self.save_button.setEnabled(False)
        self.open_button.setText("Cancel")
        if self.settings_window is not None and hasattr(self.settings_window, "syntax_colors_check"):
            self.settings_window.syntax_colors_check.setEnabled(False)

    def insert_chunk(self, chunk):
        self.sci(self.editor.SCI_SETSTATUS, 0)
        self.editor.setReadOnly(False)
        try:
            if self.paste_source is None:
                self.sci(self.editor.SCI_APPENDTEXT, len(chunk), chunk)
            else:
                self.sci(self.editor.SCI_ADDTEXT, len(chunk), chunk)
        finally:
            self.editor.setReadOnly(True)
        if self.sci(self.editor.SCI_GETSTATUS) != 0:
            raise MemoryError("The editor could not allocate more memory.")
        self.loaded_bytes += len(chunk)

        segments = chunk.replace(b"\r", b"\n").split(b"\n")
        self.line_bytes += len(segments[0])
        self.long_line |= self.line_bytes > LONG_LINE_LIMIT
        if len(segments) > 1:
            self.long_line |= any(len(part) > LONG_LINE_LIMIT for part in segments[1:])
            self.line_bytes = len(segments[-1])

    def load_tick(self):
        if not self.loading:
            return
        try:
            if self.paste_source is not None:
                end = min(self.paste_offset + READ_CHUNK, len(self.paste_source))
                if end == self.paste_offset:
                    self.finish_load()
                    return
                chunk = self.paste_source[self.paste_offset:end].encode("utf-8")
                self.paste_offset = end
                self.insert_chunk(chunk)
                return
            try:
                kind, value = self.load_queue.get_nowait()
            except queue.Empty:
                return
            if kind == "start":
                self.editor.setReadOnly(False)
                self.editor.clear()
                self.editor.setReadOnly(True)
                self.set_current_tab_name(self.load_name)

                self.sci(self.editor.SCI_SETSTATUS, 0)
                self.sci(self.editor.SCI_ALLOCATE, self.expected_size)
                if self.sci(self.editor.SCI_GETSTATUS) != 0:
                    raise MemoryError("Not enough memory to open this file.")
                if value:
                    self.insert_chunk(value)
            elif kind == "chunk":
                self.insert_chunk(value)
            elif kind == "error":
                self.log(f"Loading stopped: {value}")
                self.finish_load()
            elif kind == "end":
                self.finish_load()
        except (MemoryError, UnicodeError, OverflowError) as exc:
            self.log(f"Loading stopped: {exc}")
            self.finish_load()

    def finish_load(self, cancelled=False):
        self.load_timer.stop()
        if self.load_cancel is not None:
            self.load_cancel.set()
        self.load_cancel = None
        self.load_queue = None
        was_paste = self.paste_source is not None
        self.paste_source = None
        self.loading = False
        self.editor.setReadOnly(False)
        self.sci(self.editor.SCI_SETMODEVENTMASK, self.saved_event_mask)
        size = self.sci(self.editor.SCI_GETLENGTH)
        self.sci(self.editor.SCI_EMPTYUNDOBUFFER)
        self.sci(self.editor.SCI_SETUNDOCOLLECTION, int(size < UNDO_LIMIT))
        if size > COLOR_LIMIT or self.long_line:
            self.set_syntax_colors_enabled(False)
            self.log("Syntax colors paused for this file's size or long lines. Use Syntax colors to enable them.")
        if self.settings_window is not None and hasattr(self.settings_window, "syntax_colors_check"):
            self.settings_window.syntax_colors_check.setEnabled(True)
        self.open_button.setText("Open File")
        self.update_editor_action_state()
        if not was_paste:
            self.editor.setCursorPosition(0, 0)
        self.apply_editor_colors(self.editor, self.syntax_colors_enabled)
        self.editor.setUpdatesEnabled(True)
        self.editor.viewport().update()
        self.editor.update()

        self.editor_tabs.tabBar().setEnabled(True)
        self.editor_tabs._editor_bar.new_button.setEnabled(True)
        self.loading_editor = None
        self.editor.setFocus()
        if cancelled:
            self.log("Loading cancelled. Text loaded so far was kept.")

    def paste(self):
        if self.loading:
            return
        source = QApplication.clipboard().text()
        if not source:
            return
        self.loading_editor = self.editor
        self.begin_load()
        self.editor.setReadOnly(False)
        self.editor.removeSelectedText()
        self.editor.setReadOnly(True)
        self.paste_source = source
        self.paste_offset = 0
        self.load_timer.start()

    def clear_editor(self):
        if self.editor is None:
            return
        if self.loading:
            self.finish_load(cancelled=True)
        self.sci(self.editor.SCI_SETLEXER, self.editor.SCLEX_NULL)
        self.sci(self.editor.SCI_SETUNDOCOLLECTION, 0)
        self.editor.clear()
        self.sci(self.editor.SCI_EMPTYUNDOBUFFER)
        self.sci(self.editor.SCI_SETUNDOCOLLECTION, 1)
        self.set_syntax_colors_enabled(True)

    def confirm_attach_without_roblox(self):
        if sys.platform != "win32":
            return True
        running = self.roblox_running
        if running is None:
            try:
                running = roblox_is_running()
                self.set_roblox_state(running)
            except Exception:
                return True
        if running:
            return True
        box = QMessageBox(self)
        box.setWindowTitle("Roblox not found")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("LelSploit couldn't find a running Roblox Player instance.")
        box.setInformativeText(
            "Do you want to continue anyway? LelSploit will still attempt to attach."
        )
        proceed = box.addButton("Proceed", QMessageBox.ButtonRole.AcceptRole)
        cancel = box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(cancel)
        box.exec()
        return box.clickedButton() is proceed

    def apply_saved_username_spoofer(self):
        settings = load_username_spoofer_settings()
        if not (settings.get("save") or settings.get("save_settings")):
            return
        save_username_proxy_runtime(settings)


    def _api_mode_restart_warning(self, action):
        verb = "execute scripts" if action == "execute" else "attach"
        box = QMessageBox(self)
        box.setWindowTitle("Roblox restart required")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("Roblox is currently running through LelSploit's client proxy.")
        box.setInformativeText(
            f"Proxy mode and Attach mode cannot run in the same Roblox session. "
            f"LelSploit must restart Roblox without the proxy before it can {verb} properly."
        )
        restart = box.addButton("Restart && continue", QMessageBox.ButtonRole.AcceptRole)
        cancel = box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(restart)
        box.exec()
        return box.clickedButton() is restart

    def _api_action_needs_attach(self, action):
        return action in {"attach", "reattach"} or (action == "execute" and not self.api_attached)

    def _prepare_roblox_window_for_attach(self, action):
        if sys.platform != "win32" or not self._api_action_needs_attach(action):
            return
        if exit_roblox_fullscreen_for_attach():
            self.log("Roblox was taken out of fullscreen for Attach mode.", "success")

    def _start_api_request(self, action, payload=None):
        self._prepare_roblox_window_for_attach(action)
        self.stop_interception_proxy()
        self.roblox_session_mode = "attach"
        self.busy = True
        self.update_editor_action_state()
        self.reattach_button.setEnabled(False)
        cancel = threading.Event()
        self.api_cancel = cancel
        self.api_action = action
        if action == "execute":
            self.execute_button.setText("Executing...")
        else:
            self.reattach_button.setText("Reattaching..." if action == "reattach" else "Attaching...")
        self.requests.put((action, payload, cancel))
        if self.fastflags_window is not None:
            self.fastflags_window.update_attached_state()
        return True

    def _begin_api_action(self, action, payload=None):
        if self.busy or self.loading:
            return False
        if not self.confirm_attach_without_roblox():
            return False
        if self.roblox_running is True and (self.roblox_proxy_active or self.roblox_session_mode == "proxy"):
            if not self._api_mode_restart_warning(action):
                return False
            self._pending_api_after_restart = (action, payload)
            self.restart_roblox_into_attach_mode()
            return True
        return self._start_api_request(action, payload)

    def _resume_pending_api_after_restart(self):
        pending = self._pending_api_after_restart
        self._pending_api_after_restart = None
        if not pending or self.roblox_running is not True:
            return
        action, payload = pending
        self._start_api_request(action, payload)

    def _wait_for_join_before_pending_api(self):
        if not self._pending_api_after_restart:
            return
        self._attach_wait_token += 1
        token = self._attach_wait_token
        baseline = self._attach_restart_join_signature

        def worker():
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline and not self.stopping.is_set():
                if token != self._attach_wait_token or not self._pending_api_after_restart:
                    return
                if not roblox_is_running():
                    time.sleep(0.25)
                    continue
                context = current_roblox_join_context(require_running=True)
                signature = roblox_join_signature(context)
                if context and signature is not None and signature != baseline:
                    time.sleep(1.0)
                    if token == self._attach_wait_token and roblox_is_running():
                        self.roblox_events.put(("attach_join_ready", context))
                    return
                time.sleep(0.25)
            if token == self._attach_wait_token and self._pending_api_after_restart:
                self.roblox_events.put(("attach_join_timeout",))

        self.log("Waiting for Roblox to finish joining before attaching…")
        threading.Thread(target=worker, daemon=True).start()

    def execute_source_text(self, source, label="Script"):
        source = str(source or "")
        if not source.strip():
            return False
        return self._begin_api_action("execute", source)

    def execute(self):
        if self.busy or self.loading:
            return
        if self.editor is None:
            self.log("No script tab is open.", "warning")
            return
        if self.sci(self.editor.SCI_GETLENGTH) == 0:
            self.log("Editor is empty. Add a script first.")
            return
        try:
            source = self.editor.text()
        except MemoryError:
            self.log("Not enough memory to send this script to the API.")
            return
        self._begin_api_action("execute", source)

    def reattach(self):
        action = "reattach" if self.api_attached else "attach"
        self._begin_api_action(action, None)

    def detach_from_fastflags(self):
        if not self.api_attached and not self.busy:
            if self.roblox_running is True and self.proxy_features_needed() and self.roblox_session_mode == "attach":
                self.restart_roblox_into_proxy_mode()
            return
        if self.busy:
            if self.api_cancel is not None:
                self.api_cancel.set()
            QTimer.singleShot(300, self.detach_from_fastflags)
            return
        self._fastflags_detach_restart_in_progress = True
        self._pending_proxy_restart_after_detach = bool(self.roblox_running is True and self.proxy_features_needed())
        self.busy = True
        self.update_editor_action_state()
        self.reattach_button.setEnabled(False)
        self.reattach_button.setText("Detaching...")
        cancel = threading.Event()
        self.api_cancel = cancel
        self.api_action = "detach"
        self.requests.put(("detach", None, cancel))

    def handle_fastflags_mode_link(self, link):
        if str(link) == "detach":
            self.detach_from_fastflags()
        elif str(link) == "proxy_restart":
            self.restart_roblox_into_proxy_mode()

    def _restart_join_context(self):
        context = current_roblox_join_context(require_running=True)
        if not context:
            return None, ""
        place_id = context.get("place_id")
        job_id = context.get("job_id")
        if place_id and job_id:
            return roblox_join_deeplink(place_id, job_id), f"Rejoining previous server in place {place_id}."
        if place_id:
            return roblox_join_deeplink(place_id), f"Rejoining previous game (place {place_id})."
        return None, ""

    def restart_roblox_into_attach_mode(self):
        if self.roblox_busy or self.roblox_running is not True:
            return
        self._attach_restart_join_signature = roblox_join_signature(current_roblox_join_context(require_running=True))
        self._attach_wait_token += 1
        self._auto_proxy_probe_token += 1
        self.stop_interception_proxy()
        self.roblox_proxy_active = False
        self.roblox_session_mode = "attach"
        self.roblox_busy = True
        self.roblox_button.setEnabled(False)
        self.roblox_button.setText("Restarting...")
        self.log("Restarting Roblox without the client proxy for Attach mode.", "warning")
        threading.Thread(target=self.roblox_action_worker, args=("restart_attach",), daemon=True).start()

    def restart_roblox_into_proxy_mode(self, automatic=False):
        if self.roblox_busy:
            return
        if not self.proxy_features_needed():
            self._fastflags_detach_restart_in_progress = False
            if self.fastflags_window is not None:
                self.fastflags_window.update_attached_state()
            return
        self._set_proxy_runtime_suspended(False)
        self.roblox_session_mode = "proxy"
        self._fastflags_detach_restart_in_progress = False
        if self.roblox_running is not True:
            if self.fastflags_window is not None:
                self.fastflags_window.update_attached_state()
            return
        self.roblox_busy = True
        self.roblox_button.setEnabled(False)
        self.roblox_button.setText("Restarting...")
        if automatic:
            self.log("Roblox joined an experience without the client proxy. Restarting once to enable live client settings.", "warning")
            self.notify_user("LelSploit", "Restarting Roblox once to enable live client settings.", 4500)
        else:
            self.log("Restarting Roblox to switch from Attach mode to client proxy mode.", "warning")
        threading.Thread(target=self.roblox_action_worker, args=("restart_proxy",), daemon=True).start()

    def _schedule_auto_proxy_after_join(self):
        return


    def queue_auto_detach_after_roblox_close(self):
        if self._auto_detach_pending:
            return
        self._auto_detach_pending = True
        if self.api_cancel is not None:
            self.api_cancel.set()

        def enqueue_when_idle():
            if self.stopping.is_set():
                self._auto_detach_pending = False
                return
            if self.busy:
                QTimer.singleShot(100, enqueue_when_idle)
                return
            self._auto_detach_pending = False
            try:
                self.requests.put_nowait(("detach_cleanup", None, threading.Event()))
            except queue.Full:
                QTimer.singleShot(100, self.queue_auto_detach_after_roblox_close)

        QTimer.singleShot(0, enqueue_when_idle)

    def request_roblox_check(self):
        if self.roblox_busy or self.roblox_checking or sys.platform != "win32":
            return
        self.roblox_checking = True
        threading.Thread(target=self.roblox_check_worker, daemon=True).start()

    def roblox_check_worker(self):
        try:
            running = roblox_is_running()
            signature = roblox_join_signature(current_roblox_join_context(require_running=False)) if running else None
            self.roblox_events.put(("state", running, signature))
        except Exception as exc:
            self.roblox_events.put(("check_error", str(exc)))

    def handle_roblox_join_signature(self, signature):
        if not self.api_attached or signature is None:
            return
        if self._attached_join_signature is None:
            self._attached_join_signature = signature
            return
        if signature == self._attached_join_signature:
            return
        self.queue_auto_detach_after_roblox_close()

    def set_roblox_state(self, running):
        _previous_extension_roblox_state = getattr(self, "roblox_running", None)
        previous = self.roblox_running
        was_attached = bool(self.api_attached)
        was_api_busy = bool(self.busy and self.api_action in {"attach", "reattach", "execute"})
        self.roblox_running = bool(running)
        if not self.roblox_running:
            self._attached_join_signature = None
            self.roblox_proxy_active = False
            self.roblox_session_mode = "unknown"
            self._fastflags_detach_restart_in_progress = False
            self._auto_proxy_probe_token += 1
            self._attach_wait_token += 1
            if self._pending_api_after_restart is not None and not self.roblox_busy:
                self._pending_api_after_restart = None
            self._set_proxy_runtime_suspended(False)
        self.roblox_button.setText("End Roblox" if running else "Start Roblox")
        self.roblox_button.setIcon(app_icon("end" if running else "start"))
        self.roblox_button.setIconSize(QSize(18, 18))
        self.roblox_button.setEnabled(not self.roblox_busy)
        if self.tray_roblox_action is not None:
            self.tray_roblox_action.setText("End Roblox" if running else "Start Roblox")
            self.tray_roblox_action.setIcon(app_icon("end" if running else "start"))
        if not self.roblox_running and self.fastflags_restart_required():
            self.set_fastflags_restart_required(False)
        if self.fastflags_window is not None:
            self.fastflags_window.update_change_state()
            self.fastflags_window.update_attached_state()
        skip_proxy_detection = bool(
            self.roblox_running and previous is not True and self._proxy_skip_next_detection
        )
        if skip_proxy_detection:
            self._proxy_skip_next_detection = False
        if (
            self.roblox_running
            and previous is not True
            and not skip_proxy_detection
            and not self.roblox_proxy_active
            and self.proxy_features_needed()
            and not self.proxy_suspended_for_api()
            and self.roblox_session_mode != "attach"
            and self._proxy_should_autostart(consume_first=True)
        ):
            self._set_proxy_runtime_suspended(False)
            self.start_proxy_in_background()
        if previous is not None and previous != self.roblox_running:
            if previous and not self.roblox_running and (was_attached or was_api_busy):
                self.queue_auto_detach_after_roblox_close()
            self.set_connection_state(False)
            if previous and not self.roblox_running:
                self.apply_saved_framerate_cap()
                if not self.roblox_busy:
                    self.log("Roblox player closed. LelSploit detached automatically.", "warning")
        if _previous_extension_roblox_state != bool(running) and hasattr(self, "_extension_events"):
            self._queue_extension_event("roblox.changed", 20)

    def set_connection_state(self, attached):
        was_attached = bool(self.api_attached)
        self.api_attached = bool(attached)
        if self.api_attached:
            self._fastflags_detach_restart_in_progress = False
            self.roblox_session_mode = "attach"
            self.stop_interception_proxy()
            if not was_attached or self._attached_join_signature is None:
                self._attached_join_signature = roblox_join_signature(current_roblox_join_context(require_running=True))
        else:
            self._attached_join_signature = None
        if not self.api_attached and self.roblox_running is not True:
            self.roblox_session_mode = "unknown"
            self._set_proxy_runtime_suspended(False)
        elif self.roblox_session_mode == "attach":
            self._set_proxy_runtime_suspended(True)
        self.reattach_button.setText("Reattach" if attached else "Attach")
        self.reattach_button.setIcon(app_icon("reattach" if attached else "attach"))
        self.reattach_button.setIconSize(QSize(18, 18))
        self.reattach_button.setEnabled(not self.busy)
        if self.fastflags_window is not None:
            self.fastflags_window.update_attached_state()

    def toggle_roblox(self):
        if self.roblox_busy or sys.platform != "win32":
            return
        if self.roblox_running is None:
            self.request_roblox_check()
            return
        action = "end" if self.roblox_running else "start"
        auto_proxy = bool(
            action == "start"
            and self.proxy_features_needed()
            and self.roblox_session_mode != "attach"
            and self._proxy_should_autostart(consume_first=False)
        )
        if auto_proxy:
            self._set_proxy_runtime_suspended(False)
            if not self.ensure_interception_proxy(interactive=True):
                answer = QMessageBox.question(
                    self,
                    "Start Roblox",
                    "The local client proxy is unavailable. Start Roblox without live client customization?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No,
                )
                if answer != QMessageBox.StandardButton.Yes:
                    return
                auto_proxy = False
                self._proxy_skip_next_detection = True
                if self.proxy_start_behavior() == "first":
                    self._proxy_first_start_used = True
            elif self.proxy_start_behavior() == "first":
                self._proxy_first_start_used = True
        if action == "end" and self.api_cancel is not None:
            self.api_cancel.set()
            self.log("Attach cancelled because Roblox is being ended.", "warning")
        self.roblox_busy = True
        self.roblox_button.setEnabled(False)
        self.roblox_button.setText("Ending..." if action == "end" else "Starting...")
        threading.Thread(
            target=self.roblox_action_worker, args=(action, auto_proxy if action == "start" else None), daemon=True
        ).start()

    def roblox_action_worker(self, action, auto_proxy=None):
        try:
            env = None
            restart_detail = ""
            if action == "end":
                end_roblox()
            elif action in {"restart", "restart_proxy", "restart_attach"}:
                if action == "restart":
                    restart_behavior = self.fastflag_restart_behavior()
                    join_context = current_roblox_join_context(require_running=True)
                    deeplink = None
                    if restart_behavior in {"game", "server"} and join_context:
                        place_id = join_context.get("place_id")
                        job_id = join_context.get("job_id") if restart_behavior == "server" else None
                        if restart_behavior == "server" and job_id:
                            deeplink = roblox_join_deeplink(place_id, job_id)
                            restart_detail = f"Rejoining previous server in place {place_id}."
                        elif place_id:
                            deeplink = roblox_join_deeplink(place_id)
                            restart_detail = f"Rejoining previous game (place {place_id})."
                    if restart_behavior in {"game", "server"} and deeplink is None:
                        restart_detail = "Previous Roblox join information was not available, so Roblox was restarted normally."
                else:
                    deeplink, restart_detail = self._restart_join_context()

                if roblox_is_running():
                    end_roblox()

                if action == "restart_attach":
                    self.stop_interception_proxy()
                    self.roblox_session_mode = "attach"
                    env = None
                else:
                    sync_saved_fastflags_to_roblox(
                        self.load_effective_fastflags(), self.fastflags_any_enabled()
                    )
                    sync_saved_modifications_to_roblox()
                    self.apply_saved_framerate_cap()
                    activate_username_proxy_runtime()
                    
                    use_proxy = self.proxy_features_needed() and action in {"restart", "restart_proxy"}
                    if use_proxy:
                        self._set_proxy_runtime_suspended(False)
                        self.roblox_session_mode = "proxy"
                        env = self.roblox_launch_environment()
                    else:
                        self.roblox_session_mode = "normal"
                        env = None
                start_roblox(env=env, deeplink=deeplink)
            else:
                sync_saved_fastflags_to_roblox(
                    self.load_effective_fastflags(), self.fastflags_any_enabled()
                )
                sync_saved_modifications_to_roblox()
                self.apply_saved_framerate_cap()
                activate_username_proxy_runtime()
                use_proxy = bool(auto_proxy) and self.proxy_features_needed() and self.roblox_session_mode != "attach"
                if use_proxy:
                    self._set_proxy_runtime_suspended(False)
                    self.roblox_session_mode = "proxy"
                    env = self.roblox_launch_environment()
                else:
                    self.roblox_session_mode = "normal"
                    env = None
                start_roblox(env=env)
            self.roblox_events.put((
                "action_done", action, roblox_is_running(),
                bool(env) if action != "end" else False,
                restart_detail,
            ))
        except Exception as exc:
            self.roblox_events.put(("action_error", action, str(exc)))

    def poll_roblox(self):
        for _ in range(20):
            try:
                event = self.roblox_events.get_nowait()
            except queue.Empty:
                break
            kind = event[0]
            if kind == "state":
                self.roblox_checking = False
                self.set_roblox_state(event[1])
                if len(event) > 2 and event[1]:
                    self.handle_roblox_join_signature(event[2])
            elif kind == "fastflags_synced":
                self.fastflag_checking = False
                if event[1]:
                    target = Path(event[1])
                    if str(target) != self.fastflag_last_target:
                        self.fastflag_last_target = str(target)
                        self.log(f"FastFlags applied to {target.parent.parent.name}.", "success")
            elif kind == "fastflags_sync_error":
                self.fastflag_checking = False
                self.log(f"Could not sync FastFlags: {event[1]}", "warning")
            elif kind == "mods_synced":
                self.mod_checking = False
                if event[1] and event[2] and event[1] != self.mod_last_root:
                    self.mod_last_root = event[1]
                    self.log(f"Client modifications applied to {Path(event[1]).name}.", "success")
            elif kind == "mods_sync_error":
                self.mod_checking = False
                self.log(f"Could not sync client modifications: {event[1]}", "warning")
            elif kind == "check_error":
                self.roblox_checking = False
                self.roblox_button.setEnabled(True)
                self.roblox_button.setToolTip(event[1])
            elif kind == "attach_join_ready":
                self.log("Roblox finished joining. Attaching now.", "success")
                self._resume_pending_api_after_restart()
            elif kind == "attach_join_timeout":
                self._pending_api_after_restart = None
                self.log("Attach was cancelled because Roblox did not finish joining within 120 seconds.", "warning")
                self.notify_user("LelSploit", "Attach cancelled because Roblox did not finish joining in time.", 5000)
            elif kind == "action_done":
                self.roblox_proxy_active = bool(event[3]) if len(event) > 3 and event[2] else False
                if event[1] == "restart_attach":
                    self.roblox_session_mode = "attach"
                elif self.roblox_proxy_active:
                    self.roblox_session_mode = "proxy"
                    if event[1] == "restart_proxy":
                        self._fastflags_detach_restart_in_progress = False
                elif event[2] and event[1] != "end":
                    self.roblox_session_mode = "normal"
                self.set_roblox_state(event[2])
                self.roblox_busy = False
                self.roblox_button.setEnabled(True)
                if event[1] == "end":
                    message = "Roblox ended."
                elif event[1] == "restart_attach":
                    message = "Roblox restarted without the client proxy for Attach mode."
                    if len(event) > 4 and event[4]:
                        message = f"{message} {event[4]}"
                    self._wait_for_join_before_pending_api()
                elif event[1] in {"restart", "restart_proxy"}:
                    self.set_fastflags_restart_required(False)
                    message = "Roblox restarted with client proxy mode." if event[1] == "restart_proxy" else "Roblox restarted."
                    if len(event) > 4 and event[4]:
                        message = f"{message} {event[4]}"
                else:
                    self.set_fastflags_restart_required(False)
                    message = "Roblox started."
                self.log(message, "success")
                if self.fastflags_window is not None:
                    self.fastflags_window.update_attached_state()
            else:
                self.roblox_busy = False
                self.log(f"Could not {event[1]} Roblox: {event[2]}")
                self.request_roblox_check()

    def api_worker(self):
        api = None
        while not self.stopping.is_set():
            request = self.requests.get()
            if request is None:
                return
            if len(request) == 3:
                action, payload, cancel = request
            else:
                action, payload = request
                cancel = threading.Event()
            succeeded = False
            cancelled = False
            try:
                logger = lambda message: self.events.put(("log", message))
                stop = CombinedStop(self.stopping, cancel)
                if action in ("attach", "reattach"):
                    api = reattach_api(
                        logger, stop, api, initial=action == "attach"
                    )
                    succeeded = api is not None and not cancel.is_set()
                elif action in ("detach", "detach_cleanup"):
                    api = detach_api(api, logger if action == "detach" else None)
                    succeeded = False
                else:
                    api = run_script(payload, logger, stop, api)
                    succeeded = api is not None and not cancel.is_set()
                cancelled = cancel.is_set() and api is None and action != "detach"
            except Exception as exc:
                api = None
                if cancel.is_set():
                    cancelled = True
                else:
                    self.events.put(("log", f"Error: {exc}"))
            finally:
                payload = None
                self.events.put(("done", (action, succeeded, cancelled, cancel)))

    def poll_api(self):
        for _ in range(100):
            try:
                kind, value = self.events.get_nowait()
            except queue.Empty:
                break
            if kind == "log":
                self.log(value)
            else:
                if len(value) == 4:
                    action, succeeded, cancelled, cancel = value
                else:
                    action, succeeded = value
                    cancelled = False
                    cancel = None
                self.busy = False
                self.execute_button.setText("Execute")
                self.update_editor_action_state()
                self.set_connection_state(succeeded)
                if action == "detach" and self._pending_proxy_restart_after_detach:
                    self._pending_proxy_restart_after_detach = False
                    if self.roblox_running is True and self.proxy_features_needed():
                        QTimer.singleShot(150, self.restart_roblox_into_proxy_mode)
                if cancel is self.api_cancel:
                    self.api_cancel = None
                    self.api_action = None
                if cancelled:
                    self.log("Attach attempt stopped.", "warning")
        self.poll_roblox()

    def closeEvent(self, event):
        if (
            not self._force_exit
            and not self.screen_capture_hidden()
            and self.close_behavior() == "tray"
            and self.tray_icon is not None
        ):
            event.ignore()
            self.hide_to_tray(show_notice=True)
            return
        self.stopping.set()
        if self.api_cancel is not None:
            self.api_cancel.set()
        if self.load_cancel is not None:
            self.load_cancel.set()
        self.load_timer.stop()
        self.event_timer.stop()
        self.roblox_timer.stop()
        self.fastflag_timer.stop()
        self._restore_custom_fastflags_after_proxy()
        if self.proxy_process is not None and self.proxy_process.poll() is None:
            try:
                self.proxy_process.terminate()
            except OSError:
                pass
        saved_spoofer = load_username_spoofer_settings()
        if not (saved_spoofer.get("save") or saved_spoofer.get("save_settings")):
            try:
                PROXY_RUNTIME_PATH.unlink(missing_ok=True)
            except OSError:
                pass
        if self.tray_icon is not None:
            self.tray_icon.hide()
        try:
            self.requests.put_nowait(None)
        except queue.Full:
            pass
        event.accept()
        QApplication.instance().quit()


def _report_startup_error(exc):
    detail = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    try:
        (BASE_DIR / "startup_error.log").write_text(detail, encoding="utf-8")
    except Exception:
        pass
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(
                None,
                "LelSploit could not start.\n\n" + str(exc) +
                f"\n\nDetails were written to {APPDATA_DIR / 'startup_error.log'}.",
                "LelSploit",
                0x10,
            )
            return
        except Exception:
            pass


def main():
    try:
        configure_windows_identity()
        app = QApplication(sys.argv)
        app.setApplicationName("LelSploit")
        app.setApplicationDisplayName("LelSploit")
        app.setOrganizationName("LelSploit")
        if hasattr(app, "setDesktopFileName"):
            app.setDesktopFileName("LelSploit")
        app.setQuitOnLastWindowClosed(False)
        app.setStyle("Fusion")
        icon = lelsploit_icon()
        if not icon.isNull():
            app.setWindowIcon(icon)
        window = LelSploitWindow()

        try:
            window.log(
                f"RUNNING LELSPLOIT | main.pyw | PID {os.getpid()}",
                "success",
            )
        except Exception:
            pass

        window.show()
        if window.screen_capture_hidden():
            QTimer.singleShot(0, window._apply_capture_exclusion)
        return app.exec()
    except Exception as exc:
        _report_startup_error(exc)
        return 1


