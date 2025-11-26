Rack Architecture Implementation Plan
Goal Description
Transition the "Living Web" from a canvas-based approach to a "Permaculture Rack" UI using standard DOM elements for devices and SVG for cables. This aims to improve accessibility, responsiveness, and maintainability while providing a "patch-bay" style interaction model.

User Review Required
IMPORTANT

This change replaces the existing graph/canvas view in the Living Web panel.

Proposed Changes
Database
[NEW] 
Migration: create_rack_tables
Create devices table (id, name, type, position_x, position_y, etc.)
Create cables table (id, source_device_id, target_device_id, source_port, target_port, etc.)
Backend
[NEW] 
rack.ex
Context module for Rack domain.
[NEW] 
device.ex
Ecto schema for Device.
[NEW] 
cable.ex
Ecto schema for Cable.
Frontend
[NEW] 
rack_component.ex
Main component for the Rack view.
Handles rendering of devices (divs) and cables (SVG).
Handles events for patching (connecting devices).
[MODIFY] 
living_web_panel_component.ex
Replace existing graph rendering with RackComponent.
Verification Plan
Automated Tests
Write unit tests for GreenManTavern.Rack context (create/update/delete devices and cables).
Write LiveView tests for RackComponent rendering.
Manual Verification
Start the server.
Navigate to "Living Web".
Verify devices are rendered as "rack units".
Verify cables can be drawn between devices.
Verify persistence of devices and cables.

