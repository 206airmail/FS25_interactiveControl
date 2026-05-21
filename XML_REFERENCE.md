# FS25 Interactive Control — XML Reference

Complete reference for configuring Interactive Control (IC) in vehicle and placeable XML files.  
Covers all built-in features plus the `axisMovingTool`/`axisPoint` axis drag system and `WINCH_IN`/`WINCH_OUT` functions added to this fork.

---

## Table of Contents

1. [Top-Level Structure](#1-top-level-structure)
2. [Configurations](#2-configurations)
3. [Outdoor Trigger](#3-outdoor-trigger)
4. [interactiveControl (controller)](#4-interactivecontrol-controller)
5. [Actions — How Controls Are Triggered](#5-actions--how-controls-are-triggered)
   - [clickPoint](#clickpoint)
   - [axisPoint](#axispoint-added)
   - [button](#button)
6. [Actors — What Controls Do](#6-actors--what-controls-do)
   - [animation](#animation)
   - [function](#function)
   - [axisMovingTool](#axismovingtoool-added)
   - [leverAnimation](#leveranimation-added)
   - [objectChange](#objectchange)
   - [dashboard](#dashboard)
   - [dependingInteractiveControl](#dependinginteractivecontrol)
7. [Shared Sub-Elements](#7-shared-sub-elements)
   - [dependingMovingTool](#dependingmovingtool)
   - [dependingMovingPart](#dependingmovingpart)
   - [soundModifier](#soundmodifier)
   - [configurationsRestrictions](#configurationsrestrictions)
8. [Animation Part Blocking](#8-animation-part-blocking)
9. [Custom Click Icons](#9-custom-click-icons)
10. [Function Reference](#10-function-reference) — including `LIGHT_TOGGLE`
11. [Full Example — Winch Controls](#11-full-example--winch-controls)
12. [Full Example — Animation with Function](#12-full-example--animation-with-function)
13. [Full Example — Axis Drag Moving Tool](#13-full-example--axis-drag-moving-tool)
14. [Saving Behaviour](#14-saving-behaviour)

---

## 1. Top-Level Structure

```xml
<interactiveControl>
    <!-- Option A: no configurations, single set of controls -->
    <interactiveControls>
        <outdoorTrigger ... />
        <interactiveControl ... />
    </interactiveControls>

    <!-- Option B: multiple configurations (e.g. tied to shop config variants) -->
    <interactiveControlConfigurations title="$l10n_someTitle">
        <interactiveControlConfiguration>
            <interactiveControls>
                <outdoorTrigger ... />
                <interactiveControl ... />
            </interactiveControls>
        </interactiveControlConfiguration>
    </interactiveControlConfigurations>

    <!-- Optional: register custom click icons -->
    <registers>
        <clickIcon name="MY_ICON" filename="path/to/icon.i3d" node="iconNode" blinkSpeed="1.0" />
    </registers>
</interactiveControl>
```

---

## 2. Configurations

Use `<interactiveControlConfigurations>` when you need different IC setups depending on a shop configuration (e.g. optional equipment). Each `<interactiveControlConfiguration>` maps to one configuration index. The `title` attribute sets the label shown in settings.

To restrict a controller to specific configuration indices, use `<configurationsRestrictions>` inside the controller (see [§7](#7-shared-sub-elements)).

---

## 3. Outdoor Trigger

Defines the volume in which a player on foot can activate outdoor IC click points. Required for any `type="OUTDOOR"` or `type="INDOOR_OUTDOOR"` action.

```xml
<outdoorTrigger
    node="0>3|0"
    linkNode="0>3|0"
    filename="SHARED_INTERACTIVE_TRIGGER"
    rotation="0 0 0"
    translation="0 0 0"
    width="5"
    height="3"
    length="8"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | Existing trigger node in the i3d. Use either `node` or `linkNode`+`filename`. |
| `linkNode` | node | — | Parent node to attach a loaded trigger to. |
| `filename` | string | — | Path to trigger i3d, or `SHARED_INTERACTIVE_TRIGGER` to use the mod's built-in trigger. |
| `rotation` | vec3 | — | Local rotation (degrees) of the loaded trigger. |
| `translation` | vec3 | — | Local translation of the loaded trigger. |
| `width` | float | `5` | Trigger width (X scale). |
| `height` | float | `3` | Trigger height (Y scale). |
| `length` | float | `8` | Trigger length (Z scale). |

**Tip:** `SHARED_INTERACTIVE_TRIGGER` is the easiest option. Set `linkNode` to a node centred on the vehicle, then tune `width`/`height`/`length` to cover the relevant area.

---

## 4. interactiveControl (controller)

Each `<interactiveControl>` is one interactive controller — a pairing of one or more actions (how it's triggered) with one or more actors (what it does).

```xml
<interactiveControl
    posText="Open"
    negText="Close"
    enabled="true"
    analog="false"
    analogSpeed="0.04"
    allowsSaving="true"
>
    <!-- actions and actors go here -->
</interactiveControl>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `posText` | l10n string | `$l10n_actionIC_activate` | HUD text shown when control moves to positive state (state → 1). |
| `negText` | l10n string | `$l10n_actionIC_deactivate` | HUD text shown when control moves to negative state (state → 0). |
| `enabled` | bool | `true` | Whether this controller is active. |
| `analog` | bool | `false` | Enables analog (incremental) mode. See below. |
| `analogSpeed` | float | `0.04` | Step size per click in analog mode (0–1). `1.0` = full travel in one click. |
| `allowsSaving` | bool | `true` | Whether the controller's state is saved to the savegame. Automatically forced to `false` when using `function` or `axisMovingTool` actors (they have no persistent state). |

#### Analog mode explained

In the default (non-analog) mode a click **toggles** the state between exactly `0` and `1` — one click plays the animation fully open, the next plays it fully closed.

With `analog="true"` each click **nudges** the state value by `analogSpeed` in the `direction` specified by whichever click point was used. The state is a float that clamps between `0.0` and `1.0`, so the animation moves in small steps.

`direction` on a `clickPoint` controls which way that icon nudges the state:
- `direction="1"` — increments toward `1.0` (forward / open / deploy)
- `direction="-1"` — decrements toward `0.0` (reverse / close / retract)

The typical pattern is **two click points on the same controller** pointing in opposite directions:

```xml
<!-- Vent that opens/closes in 5 clicks either way -->
<interactiveControl posText="Open Vent" negText="Close Vent" analog="true" analogSpeed="0.2">
    <clickPoint node="ventOpenBtn" type="INDOOR" iconType="ARROW" direction="1"  />
    <clickPoint node="ventCloseBtn" type="INDOOR" iconType="ARROW" direction="-1" />
    <animation name="openVent" speedScale="1.0" />
</interactiveControl>
```

With `analogSpeed="1.0"` and a single click point at `direction="1"` the control behaves like a one-way deploy — one click drives the animation from wherever it is all the way to `1.0`, and the state stays there until something else moves it.

---

## 5. Actions — How Controls Are Triggered

An action defines *how* the controller is activated. Most controllers use a `clickPoint` or `axisPoint`. Buttons are an alternative for proximity key-press triggers.

### clickPoint

A 2D icon projected onto the screen that the player clicks with the mouse. Supports both indoor and outdoor use.

```xml
<clickPoint
    node="0>5|2"
    linkNode="0>5|2"
    rotation="0 0 0"
    translation="0 0 0"
    type="OUTDOOR"
    iconType="CROSS"
    size="0.04"
    scaleOffset="0.004"
    blinkSpeedScale="1"
    alignToCamera="true"
    invertX="false"
    invertZ="false"
    requireHolding="false"
    color="0.518 0.667 0.063"
    intensity="1.0"
    animName="string"
    animMinLimit="0.0"
    animMaxLimit="1.0"
    foldMinLimit="0.0"
    foldMaxLimit="1.0"
    forcedStateValue="float"
    direction="1"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | The i3d node the click icon is positioned at. Use `node` or `linkNode`. |
| `linkNode` | node | — | Alternative positioning node (used with `rotation`/`translation` offset). |
| `rotation` | vec3 | — | Local rotation offset when using `linkNode`. |
| `translation` | vec3 | — | Local translation offset when using `linkNode`. |
| `type` | string | — | **Required.** Where the click icon is active: `INDOOR`, `OUTDOOR`, or `INDOOR_OUTDOOR`. |
| `iconType` | string | `CROSS` | Icon shape. See icon table below. |
| `size` | float | `0.04` | Base display size of the icon. |
| `scaleOffset` | float | `size/10` | Amount the icon pulses up/down from `size` when hovered. |
| `blinkSpeedScale` | float | `1` | Speed multiplier for the hover pulse animation. |
| `alignToCamera` | bool | `true` | Rotates the icon to always face the camera. |
| `invertX` | bool | `false` | Mirrors the icon on the X axis. |
| `invertZ` | bool | `false` | Mirrors the icon on the Z axis. |
| `requireHolding` | bool | `false` | When true, the action only fires while the button is held. Release stops the animation at the current position. Use with `animation returnOnRelease` or `WINCH_IN`/`WINCH_OUT` functions. |
| `requiresEngine` | bool | `false` | When true, clicking the icon while the engine is off shows a "please start the engine first" warning popup and does nothing. The icon stays visible regardless. |
| `color` | vec3 | IC green | RGB color for the icon as normalized floats (0–1). Default is the standard IC green (`0.518 0.667 0.063` = RGB 132 170 16). Examples: `1 0 0` = red, `0 0.8 0` = green, `0 0 1` = blue, `1 1 1` = white. |
| `intensity` | float | `1.0` | Emissive brightness multiplier (0–20). Higher values make the configured color more vivid and dark colors appear darker. `1.0` matches the original IC icon brightness. |
| `animName` | string | — | Restricts this click point to only show when the named animation is within `animMinLimit`–`animMaxLimit`. |
| `animMinLimit` | float | `0.0` | Minimum animation time (0–1) for visibility restriction. |
| `animMaxLimit` | float | `1.0` | Maximum animation time (0–1) for visibility restriction. |
| `foldMinLimit` | float | `0.0` | Minimum fold time for visibility restriction. |
| `foldMaxLimit` | float | `1.0` | Maximum fold time for visibility restriction. |
| `forcedStateValue` | float | — | Forces the controller to this exact state value when clicked, instead of toggling. |
| `direction` | float | `1` | In analog mode: `1` nudges state toward 1.0, `-1` nudges toward 0.0. No effect in toggle mode. See [Analog mode explained](#analog-mode-explained). |

**Available icon types:**

| Icon | Description |
|---|---|
| `CROSS` | Generic crosshair / interact |
| `IGNITIONKEY` | Engine key |
| `CRUISE_CONTROL` | Cruise control |
| `GPS` | GPS / auto-steering |
| `TURN_ON` | Power / on-off |
| `ATTACHERJOINTS_LOWER` | Lower attacher |
| `ATTACHERJOINTS_LIFT` | Raise attacher |
| `ATTACHERJOINT` | Attacher joint |
| `LIGHT` | Lights |
| `LIGHT_HIGH` | High beam |
| `TURNLIGHT_LEFT` | Left indicator |
| `TURNLIGHT_RIGHT` | Right indicator |
| `BEACON_LIGHT` | Beacon / strobe |
| `ARROW` | Generic arrow |
| `PIPE_FOLDING` | Pipe fold |

---

### axisPoint *(added)*

An extension of `clickPoint` for **axis drag** controls. The player holds the button and moves the mouse to drive a moving tool. Always requires holding — no separate `requireHolding` attribute needed.

Used together with the `axisMovingTool` actor.

```xml
<axisPoint
    node="0>5|2"
    type="OUTDOOR"
    iconType="CROSS"
    size="0.04"
    alignToCamera="true"
    sensitivity="1.0"
    dragAxis="Y"
    color="0.518 0.667 0.063"
    intensity="1.0"
/>
```

Inherits **all** `clickPoint` attributes (including `color`, `intensity`, `animName` limits, etc.). Additional attributes:

| Attribute | Type | Default | Description |
|---|---|---|---|
| `sensitivity` | float | `1.0` | Speed multiplier relative to in-vehicle mouse dragging. `1.0` = identical feel. `0.5` = half speed, `2.0` = twice as fast. |
| `dragAxis` | string | `Y` | Which mouse axis drives the tool. `Y` = up/down (default). `X` = left/right. |

**Notes:**
- `requireHolding` is implicit — you do not need to set it.
- Add `requiresEngine="true"` if the drag hold should require the engine to be running. When set and the engine is off, a "please start the engine first" popup is shown.
- Camera rotation on the chosen drag axis is suppressed while dragging.

---

### button

A proximity-based key-press trigger. When the player is within `range` of `refNode`, pressing `input` activates the controller. Works indoors and outdoors.

```xml
<button
    input="IC_CLICK"
    range="5.0"
    refNode="0>0"
    type="OUTDOOR"
    animName="string"
    animMinLimit="0.0"
    animMaxLimit="1.0"
    foldMinLimit="0.0"
    foldMaxLimit="1.0"
    forcedStateValue="float"
    direction="1"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `input` | string | — | **Required.** Input action name (e.g. `IC_CLICK`). |
| `range` | float | `5.0` | Maximum distance in metres from `refNode` for the button to be active. |
| `refNode` | node | rootNode | Reference node used to measure range from the player. |
| `type` | string | — | **Required.** `INDOOR`, `OUTDOOR`, or `INDOOR_OUTDOOR`. |
| `animName` | string | — | Restricts button to only be active when the named animation is within `animMinLimit`–`animMaxLimit`. |
| `animMinLimit` | float | `0.0` | Minimum animation time (0–1) for activity restriction. |
| `animMaxLimit` | float | `1.0` | Maximum animation time (0–1) for activity restriction. |
| `foldMinLimit` | float | `0.0` | Minimum fold time for activity restriction. |
| `foldMaxLimit` | float | `1.0` | Maximum fold time for activity restriction. |
| `forcedStateValue` | float | — | Forces the controller to this exact state value when pressed, instead of toggling. |
| `direction` | float | `1` | In analog mode: `1` nudges state toward 1.0, `-1` nudges toward 0.0. |

---

## 6. Actors — What Controls Do

Actors respond to state changes. A controller can have multiple actors — all fire together when the controller changes state.

---

### animation

Plays a vehicle animation when the controller is activated/deactivated. This is the most common actor. Multiple `<animation>` elements can appear on the same controller to drive several animations at once.

```xml
<animation
    name="openWindow"
    speedScale="1.0"
    initTime="0.0"
    returnOnRelease="false"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | **Required.** Name of the animation as defined in `<animations>`. |
| `speedScale` | float | `1.0` | Playback speed multiplier. Negative values play in reverse. |
| `initTime` | float | — | Sets the animation to this time (0–1) on initial load before savegame state is applied. |
| `returnOnRelease` | bool | `false` | When true (requires `requireHolding="true"` on the clickPoint), the animation plays forward while held and automatically reverses back to time `0` when released. Useful for spring-return levers. |

**Notes:**
- In toggle mode: state `1` → plays forward, state `0` → plays backward at `speedScale`.
- In analog mode: the animation time is set directly to the controller's state value (0–1).
- With `requireHolding`: releasing the button mid-animation stops it at the current position. The position is saved and synced to all multiplayer clients.
- With `returnOnRelease`: releasing always reverses to time 0, regardless of current position. The IC state value is **not** updated on release, so other actors are unaffected.

---

### function

Calls a built-in game function when the controller is activated or deactivated. See the [Function Reference](#10-function-reference) for all available names and their child element requirements.

```xml
<function name="MOTOR_START_STOPP" />

<function name="ATTACHERJOINTS_LIFT_LOWER">
    <attacherJoint indices="1 2" />
</function>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | **Required.** Function name (case-insensitive). |

Functions never save state. `allowsSaving` is automatically forced to `false` on controllers that use them.

---

### axisMovingTool *(added)*

Drives a `<cylindered>` moving tool by mouse drag. Used with an `axisPoint` action. The tool moves while the mouse moves and stops when the mouse is still or the button is released.

```xml
<!-- Reference by moving tool index (preferred) -->
<axisMovingTool movingToolIndex="1" />

<!-- Reference by node -->
<axisMovingTool node="0>4|0" />
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `movingToolIndex` | int | — | 1-based index of the moving tool in the vehicle's `<cylindered><movingTools>` list. Preferred method. |
| `node` | node | — | Alternative: the i3d node of the moving tool. |

Either `movingToolIndex` or `node` is required — not both.

**Requirements:**
- The vehicle must have the `Cylindered` specialization (`spec_cylindered`).
- The controller's action must be an `axisPoint`.
- Add `requiresEngine="true"` on the `axisPoint` if the engine must be running to drag (optional).

**Movement formula** (same as in-vehicle mouse control):
```
move = inputValue × invertAxis × armSensitivity × (16.666 / dt) × mouseSpeedFactor
```
`armSensitivity` is the game setting from Options → Controls. `mouseSpeedFactor` comes from the moving tool's XML definition.

---

### leverAnimation *(added)*

Drives an animation to visually represent the axis drag direction in real time. Pair it with an `axisMovingTool` on the same controller. Both actors receive the same mouse speed signal each frame via `setDriveSpeed`.

- Dragging **positive** (mouse up or right) → animation moves toward `1.0`
- Dragging **negative** (mouse down or left) → animation moves toward `0.0`
- Mouse still or hold released → animation returns to `neutralTime` (the lever's resting position)

```xml
<leverAnimation
    name="hydraulicLever"
    neutralTime="0.5"
    speed="3.0"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | **Required.** Name of the animation to drive. |
| `neutralTime` | float | `0.5` | Animation time (0–1) the lever rests at when not being dragged. `0.5` = centre. Adjust if your animation's neutral pose isn't exactly at the midpoint. |
| `speed` | float | `3.0` | How fast the lever snaps to its target, in full animation lengths per second. `3.0` = reaches target in ~0.33 s. Higher = snappier. |

`leverAnimation` state is never saved (the lever always returns to neutral on load).

**Full controller example:**

```xml
<interactiveControl posText="Move Ramp" negText="">
    <axisPoint node="leverClickNode" type="OUTDOOR" iconType="CROSS" size="0.04" sensitivity="0.6" dragAxis="Y" />
    <axisMovingTool movingToolIndex="1" />
    <leverAnimation name="hydraulicLever" neutralTime="0.5" speed="3.0" />
</interactiveControl>
```

---

### objectChange

Changes a node's visibility, translation, rotation, scale, mass, shader parameters, or rigid body type based on the controller's state. Multiple `<objectChange>` elements can appear on the same controller.

```xml
<objectChange
    node="0>3|1"
    visibilityActive="true"
    visibilityInactive="false"
    translationActive="0 0.5 0"
    translationInactive="0 0 0"
    rotationActive="0 90 0"
    rotationInactive="0 0 0"
    scaleActive="1 1 1"
    scaleInactive="0 0 0"
    interpolation="false"
    interpolationTime="1"
    massActive="100"
    massInactive="0"
    centerOfMassActive="0 0 0"
    centerOfMassInactive="0 0 0"
    rigidBodyTypeActive="Dynamic"
    rigidBodyTypeInactive="Static"
    compoundChildActive="true"
    compoundChildInactive="false"
    parentNodeActive="0>2"
    parentNodeInactive="0>1"
    shaderParameter="colorScale"
    shaderParameterActive="1 0 0 1"
    shaderParameterInactive="0 0 1 1"
    sharedShaderParameter="false"
/>
```

All `*Active` values apply when the controller state is `1` (activated); `*Inactive` values apply at state `0`. Every attribute pair is optional — only include what you need.

---

### dashboard

Ties a vanilla dashboard element to the IC controller state. Uses the existing `<dashboard>` system with IC-specific `valueType` values.

```xml
<dashboard
    node="0>4|0"
    valueType="ic_state"
    onICActivate="true"
    onICDeactivate="true"
    raiseTime="1.0"
    activeTime="1.0"
/>
```

IC-specific `valueType` options:

| valueType | Description |
|---|---|
| `ic_state` | Boolean — true when controller is in positive state. |
| `ic_stateValue` | Float 0–1 — the raw controller state value. |
| `ic_action` | Fires on IC activation/deactivation events (use with `raiseTime`, `activeTime`, `onICActivate`, `onICDeactivate`). |

| Attribute | Type | Default | Description |
|---|---|---|---|
| `raiseTime` | float | `1.0` | Time in seconds to raise/activate the dashboard element. |
| `activeTime` | float | `1.0` | Time in seconds to hold the dashboard active. |
| `onICActivate` | bool | `true` | Fire dashboard when IC activates. |
| `onICDeactivate` | bool | `true` | Fire dashboard when IC deactivates. |

All standard dashboard attributes (`rotAxis`, `minRot`, `maxRot`, `emissiveScale`, etc.) are also valid.

---

### dependingInteractiveControl

Blocks or enables this controller based on the state value of another controller.

```xml
<dependingInteractiveControl
    index="2"
    minLimit="0.0"
    maxLimit="0.5"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `index` | int | — | **Required.** 1-based index of the controlling IC in the same `<interactiveControls>` block. |
| `minLimit` | float | `0.0` | This controller is active only when the referenced controller's state is ≥ `minLimit`. |
| `maxLimit` | float | `1.0` | This controller is active only when the referenced controller's state is ≤ `maxLimit`. |

---

## 7. Shared Sub-Elements

These elements can appear inside any `<interactiveControl>` controller alongside the actors and actions.

---

### dependingMovingTool

Prevents a `<cylindered>` moving tool from being driven while this IC controller is in a specific state. Useful to lock a tool in place. Multiple entries allowed.

```xml
<dependingMovingTool node="0>4|0" isInactive="true" />
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | The moving tool's node. |
| `isInactive` | bool | `true` | When true, the tool is blocked while this IC is active/configured. |

---

### dependingMovingPart

Same as `dependingMovingTool` but for `<movingParts>` elements. Multiple entries allowed.

```xml
<dependingMovingPart node="0>4|1" isInactive="true" />
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | The moving part's node. |
| `isInactive` | bool | `true` | When true, the part is blocked while this IC is active/configured. |

---

### soundModifier

Adjusts interior sound levels when this IC controller is active. Useful for cab controls that open windows or panels.

```xml
<soundModifier
    indoorFactor="0.5"
    delayedSoundAnimationTime="0.3"
    name="openWindow"
/>
```

| Attribute | Type | Default | Description |
|---|---|---|---|
| `indoorFactor` | float | — | Indoor sound volume multiplier while this IC is active. `0.5` = half volume. |
| `delayedSoundAnimationTime` | float | — | Wait until the named animation reaches this time before applying the sound change. |
| `name` | string | — | Animation name to monitor. Defaults to the first `animation` actor on this controller. |

---

### configurationsRestrictions

Restricts this controller to only be available when a specific shop configuration is selected.

```xml
<configurationsRestrictions>
    <restriction name="design" indices="1 3" />
</configurationsRestrictions>
```

| Attribute | Type | Description |
|---|---|---|
| `name` | string | The configuration category name (e.g. `"design"`, `"baseColor"`). |
| `indices` | int list | Space-separated configuration indices for which this controller is **blocked** (unavailable). |

---

## 8. Animation Part Blocking

You can block an IC controller from within an animation track, useful for preventing interaction during certain animation phases.

```xml
<animations>
    <animation name="foldOut">
        <part
            node="..."
            interactiveControlIndex="2"
            interactiveControlBlocked="true"
        />
    </animation>
</animations>
```

| Attribute | Type | Description |
|---|---|---|
| `interactiveControlIndex` | int | 1-based index of the IC controller to block. |
| `interactiveControlBlocked` | bool | `true` to block, `false` to unblock at this animation part. |

---

## 9. Custom Click Icons

Register your own click icons for use with `iconType`.

```xml
<interactiveControl>
    <registers>
        <clickIcon
            name="WINCH"
            filename="path/to/winchIcon.i3d"
            node="iconNode"
            blinkSpeed="1.0"
        />
    </registers>
</interactiveControl>
```

| Attribute | Type | Description |
|---|---|---|
| `name` | string | Name to reference in `iconType`. Case-insensitive; stored uppercase. |
| `filename` | string | Path to the i3d file containing the icon mesh. |
| `node` | string | Node index string within the i3d (e.g. `"0"` for the first node). |
| `blinkSpeed` | float | Base hover blink speed for this icon. |

---

## 10. Function Reference

Functions are used with the `<function name="...">` actor. Some require a child element.

### No child element required

| Function | Description |
|---|---|
| `MOTOR_START_STOPP` | Toggle engine on/off |
| `LIGHTS_TOGGLE` | Toggle all lights |
| `LIGHTS_WORKBACK_TOGGLE` | Toggle rear work lights |
| `LIGHTS_WORKFRONT_TOGGLE` | Toggle front work lights |
| `LIGHTS_HIGHBEAM_TOGGLE` | Toggle high beams |
| `LIGHTS_TURNLIGHT_HAZARD_TOGGLE` | Toggle hazard lights |
| `LIGHTS_TURNLIGHT_LEFT_TOGGLE` | Toggle left indicator |
| `LIGHTS_TURNLIGHT_RIGHT_TOGGLE` | Toggle right indicator |
| `LIGHTS_BEACON_TOGGLE` | Toggle beacon/strobe lights |
| `LIGHTS_PIPE_TOGGLE` | Toggle pipe light |
| `AUTOMATIC_STEERING_TOGGLE` | Toggle auto-steering |
| `AUTOMATIC_STEERING_LINES_TOGGLE` | Show/hide auto-steering lines |
| `CRUISE_CONTROL_TOGGLE` | Toggle cruise control |
| `DRIVE_DIRECTION_TOGGLE` | Toggle drive direction |
| `COVER_TOGGLE` | Toggle cover open/closed |
| `RADIO_TOGGLE` | Toggle radio on/off |
| `RADIO_CHANNEL_NEXT` | Next radio channel |
| `RADIO_CHANNEL_PREVIOUS` | Previous radio channel |
| `RADIO_ITEM_NEXT` | Next item in current radio channel |
| `RADIO_ITEM_PREVIOUS` | Previous item in current radio channel |
| `REVERSEDRIVING_TOGGLE` | Toggle reverse driving mode |
| `TURN_ON_OFF` | Turn implement on/off |
| `FOLDING_TOGGLE` | Fold/unfold vehicle |
| `PIPE_FOLDING_TOGGLE` | Fold/unfold pipe |
| `DISCHARGE_TOGGLE` | Toggle discharge |
| `CRABSTEERING_TOGGLE` | Cycle crab steering mode |
| `VARIABLE_WORK_WIDTH_LEFT_INCREASE` | Increase left work width |
| `VARIABLE_WORK_WIDTH_LEFT_DECREASE` | Decrease left work width |
| `VARIABLE_WORK_WIDTH_RIGHT_INCREASE` | Increase right work width |
| `VARIABLE_WORK_WIDTH_RIGHT_DECREASE` | Decrease right work width |
| `VARIABLE_WORK_WIDTH_TOGGLE` | Toggle work width |
| `BALER_TOGGLE_SIZE` | Toggle bale size |
| `BALER_DROP_BALE` | Drop bale from baler |
| `BALER_TOGGLE_AUTOMATIC_DROP` | Toggle automatic bale drop |
| `BALEWRAPPER_DROP_BALE` | Drop bale from bale wrapper |
| `BALEWRAPPER_TOGGLE_AUTOMATIC_DROP` | Toggle automatic bale drop from wrapper |

### Requires `<attacherJoint indices="..."/>`

```xml
<function name="ATTACHERJOINTS_LIFT_LOWER">
    <attacherJoint indices="1 2" />
</function>
```

`indices` is a space-separated list of 1-based attacher joint indices.

| Function | Description |
|---|---|
| `ATTACHERJOINTS_LIFT_LOWER` | Lift/lower implement on specified joints |
| `ATTACHERJOINTS_TURN_ON_OFF` | Turn on/off implement on specified joints |
| `ATTACHERJOINTS_FOLDING_TOGGLE` | Fold/unfold implement on specified joints |
| `ATTACHERJOINTS_DISCHARGE_TOGGLE` | Toggle discharge on specified joints |
| `ATTACHERJOINTS_ATTACH_DETACH` | Attach or detach implement on specified joints |
| `ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_INCREASE` | Increase left work width on specified joints |
| `ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_DECREASE` | Decrease left work width on specified joints |
| `ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_INCREASE` | Increase right work width on specified joints |
| `ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_DECREASE` | Decrease right work width on specified joints |
| `ATTACHERJOINTS_VARIABLE_WORK_WIDTH_TOGGLE` | Toggle work width on specified joints |

### Winch functions *(added)* — Requires `<winch ropeIndices="..."/>`

```xml
<function name="WINCH_IN">
    <winch ropeIndices="1" />
</function>
```

`ropeIndices` is a space-separated list of 1-based rope indices from the vehicle's `<winch>` definition.

| Function | Description | Note |
|---|---|---|
| `WINCH_IN` | Pulls rope(s) in while the click point is held | Holding is implicit — no `requireHolding` needed on the `clickPoint` |
| `WINCH_OUT` | Releases rope(s) while the click point is held | Holding is implicit — no `requireHolding` needed on the `clickPoint` |

**Notes:**
- The vehicle must have the `Winch` specialization (`spec_winch`).
- Both functions are hold-to-activate — the winch stops as soon as you release the button.
- `allowsSaving` is automatically `false`; do not add `allowsSaving="true"`.

### LIGHT_TOGGLE *(added)* — IC-exclusive individual light control

Toggles one or more individual lights exclusively via IC. The nodes must **not** be defined anywhere in `<vehicle.lights>` — IC owns them completely. If you want a light controllable by the F-key system, define it only in `<vehicle.lights>` and use the existing `LIGHTS_*` functions instead.

```xml
<function name="LIGHT_TOGGLE">
    <realLight node="0>5|1" />
    <staticLightMesh node="0>5|2" intensity="10" />
</function>
```

Both child elements are optional (you can have just a `realLight`, just a `staticLightMesh`, or both), but at least one must be present. Multiple entries of each type are supported.

**`<realLight>`** — a LIGHT_SOURCE node controlled via `setVisibility`. Do **not** list this node in `<vehicle.lights.realLights>`.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | **Required.** The LIGHT_SOURCE node to show/hide. |

**`<staticLightMesh>`** — an emissive mesh using the `staticLight` shader variation, controlled via `lightIds0–3` shader parameters. Do **not** list this node in `<staticLightCompounds>`.

| Attribute | Type | Default | Description |
|---|---|---|---|
| `node` | node | — | **Required.** The mesh node. Must use the `staticLight` custom shader variation (has the `lightIds0` parameter). |
| `intensity` | float | `10` | Emissive intensity when on. Use the same value you would put on a `<staticLightCompound><node intensity="">`. |

Because neither node is registered in the game's light system, the game never writes to their visibility or shader parameters. IC's state persists through F-key cycling, vehicle entry, turn signals, and anything else.

---

## 11. Full Example — Winch Controls

```xml
<interactiveControl>
    <interactiveControlConfigurations title="$l10n_actionIC_winch">
        <interactiveControlConfiguration>
            <interactiveControls>
                <!-- Outdoor trigger covering the winch area -->
                <outdoorTrigger
                    linkNode="0>9|0"
                    filename="SHARED_INTERACTIVE_TRIGGER"
                    width="4"
                    height="3"
                    length="4"
                />

                <!-- Pull rope in (requireHolding is implicit for WINCH_IN/WINCH_OUT) -->
                <interactiveControl posText="Winch In" negText="">
                    <clickPoint
                        node="0>9|1"
                        alignToCamera="true"
                        type="OUTDOOR"
                        iconType="CROSS"
                        size="0.04"
                    />
                    <function name="WINCH_IN">
                        <winch ropeIndices="1" />
                    </function>
                </interactiveControl>

                <!-- Release rope out -->
                <interactiveControl posText="Winch Out" negText="">
                    <clickPoint
                        node="0>9|2"
                        alignToCamera="true"
                        type="OUTDOOR"
                        iconType="CROSS"
                        size="0.04"
                    />
                    <function name="WINCH_OUT">
                        <winch ropeIndices="1" />
                    </function>
                </interactiveControl>
            </interactiveControls>
        </interactiveControlConfiguration>
    </interactiveControlConfigurations>
</interactiveControl>
```

---

## 12. Full Example — Animation with Function

A cab window that toggles open/closed with an indoor click point, mutes interior sound when open, and also turns on the front work lights.

```xml
<interactiveControl>
    <interactiveControls>
        <interactiveControl posText="Open Window" negText="Close Window" allowsSaving="true">
            <clickPoint
                node="windowClickNode"
                type="INDOOR"
                iconType="CROSS"
                size="0.035"
                alignToCamera="true"
            />
            <animation name="openWindow" speedScale="1.0" />
            <function name="LIGHTS_WORKFRONT_TOGGLE" />
            <soundModifier indoorFactor="0.4" delayedSoundAnimationTime="0.6" name="openWindow" />
        </interactiveControl>
    </interactiveControls>
</interactiveControl>
```

---

## 13. Full Example — Axis Drag Moving Tool

A trailer ramp driven up/down by mouse drag while the button is held. Uses `axisPoint` + `axisMovingTool` + `leverAnimation` for a visual lever indicator.

```xml
<interactiveControl>
    <interactiveControlConfigurations title="$l10n_actionIC_ramp">
        <interactiveControlConfiguration>
            <interactiveControls>
                <outdoorTrigger
                    linkNode="rampTriggerLink"
                    filename="SHARED_INTERACTIVE_TRIGGER"
                    width="3"
                    height="2"
                    length="5"
                />

                <interactiveControl posText="Move Ramp" negText="">
                    <axisPoint
                        node="rampClickNode"
                        type="OUTDOOR"
                        iconType="CROSS"
                        size="0.04"
                        alignToCamera="true"
                        sensitivity="0.6"
                        dragAxis="Y"
                    />
                    <axisMovingTool movingToolIndex="1" />
                    <leverAnimation name="hydraulicLever" neutralTime="0.5" speed="3.0" />
                </interactiveControl>
            </interactiveControls>
        </interactiveControlConfiguration>
    </interactiveControlConfigurations>
</interactiveControl>
```

---

## 14. Saving Behaviour

| Actor type | Saves state? | Notes |
|---|---|---|
| `animation` | Yes (default) | State value (0–1) is saved and restored on load. |
| `objectChange` | Yes (default) | Inherits controller save state. |
| `function` | **Never** | Functions have no persistent state. `allowsSaving` forced to `false`. |
| `axisMovingTool` | **Never** | Moving tool position is managed by `Cylindered`, not IC. `allowsSaving` forced to `false`. |
| `leverAnimation` | **Never** | Lever always returns to `neutralTime` on load. No state to save. |
| `dashboard` | No | Dashboard state is cosmetic only. |
| `dependingInteractiveControl` | No | Blocking state is derived at runtime from the referenced controller. |

If you see the log warning `"Loaded interactive control does not allow saving ... skipping this control"`, it means a previously saved savegame had stored state for a controller that now uses a function or axisMovingTool actor. This is harmless — the saved state is ignored and will not be written back on the next save.
