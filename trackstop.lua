-- Overlay to allow changing track stop friction and dump direction after construction
--@ module = true

if not dfhack_flags.module then
  qerror('trackstop cannot be called directly')
end

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
local utils = require('utils')

local NORTH = 'North ^'
local EAST = 'East >'
local SOUTH = 'South v'
local WEST = 'West <'

local LOW = 'Low'
local MEDIUM = 'Medium'
local HIGH = 'High'
local HIGHER = 'Higher'
local MAX = 'Max'

local NONE = 'None'

local FRICTION_MAP = {
  [NONE] = 10,
  [LOW] = 50,
  [MEDIUM] = 500,
  [HIGH] = 10000,
  [MAX] = 50000,
}

local FRICTION_MAP_REVERSE = utils.invert(FRICTION_MAP)

local SPEED_MAP = {
  [LOW] = 10000,
  [MEDIUM] = 20000,
  [HIGH] = 30000,
  [HIGHER] = 40000,
  [MAX] = 50000,
}

local SPEED_MAP_REVERSE = utils.invert(SPEED_MAP)

local DIRECTION_MAP = {
  [NORTH] = df.screw_pump_direction.FromSouth,
  [EAST] = df.screw_pump_direction.FromWest,
  [SOUTH] = df.screw_pump_direction.FromNorth,
  [WEST] = df.screw_pump_direction.FromEast,
}

local DIRECTION_MAP_REVERSE = utils.invert(DIRECTION_MAP)

TrackStopOverlay = defclass(TrackStopOverlay, overlay.OverlayWidget)
TrackStopOverlay.ATTRS{
  default_pos={x=-73, y=29},
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Trap/TrackStop',
  frame={w=25, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function TrackStopOverlay:getFriction()
  return dfhack.gui.getSelectedBuilding().friction
end

function TrackStopOverlay:setFriction(friction)
  local building = dfhack.gui.getSelectedBuilding()

  building.friction = FRICTION_MAP[friction]
end

function TrackStopOverlay:getDumpDirection()
  local building = dfhack.gui.getSelectedBuilding()
  local use_dump = building.use_dump
  local dump_x_shift = building.dump_x_shift
  local dump_y_shift = building.dump_y_shift

  if use_dump == 0 then
    return NONE
  else
    if dump_x_shift == 0 and dump_y_shift == -1 then
      return NORTH
    elseif dump_x_shift == 1 and dump_y_shift == 0 then
      return EAST
    elseif dump_x_shift == 0 and dump_y_shift == 1 then
      return SOUTH
    elseif dump_x_shift == -1 and dump_y_shift == 0 then
      return WEST
    end
  end
end

function TrackStopOverlay:setDumpDirection(direction)
  local building = dfhack.gui.getSelectedBuilding()

  if direction == NONE then
    building.use_dump = 0
    building.dump_x_shift = 0
    building.dump_y_shift = 0
  elseif direction == NORTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = -1
  elseif direction == EAST then
    building.use_dump = 1
    building.dump_x_shift = 1
    building.dump_y_shift = 0
  elseif direction == SOUTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = 1
  elseif direction == WEST then
    building.use_dump = 1
    building.dump_x_shift = -1
    building.dump_y_shift = 0
  end
end

function TrackStopOverlay:render(dc)
  local building = dfhack.gui.getSelectedBuilding()
  local friction = building.friction
  local friction_cycle = self.subviews.friction

  friction_cycle:setOption(FRICTION_MAP_REVERSE[friction])

  self.subviews.dump_direction:setOption(self:getDumpDirection())

  TrackStopOverlay.super.render(self, dc)
end

function TrackStopOverlay:init()
  self:addviews{
    widgets.CycleHotkeyLabel{
      frame={t=0, l=0},
      label='Dump',
      key='CUSTOM_CTRL_X',
      options={
        {label=NONE, value=NONE, pen=COLOR_BLUE},
        NORTH,
        EAST,
        SOUTH,
        WEST,
      },
      view_id='dump_direction',
      on_change=function(val) self:setDumpDirection(val) end,
    },
    widgets.CycleHotkeyLabel{
      label='Friction',
      frame={t=1, l=0},
      key='CUSTOM_CTRL_F',
      options={
        {label=NONE, value=NONE, pen=COLOR_BLUE},
        {label=LOW, value=LOW, pen=COLOR_GREEN},
        {label=MEDIUM, value=MEDIUM, pen=COLOR_YELLOW},
        {label=HIGH, value=HIGH, pen=COLOR_LIGHTRED},
        {label=MAX, value=MAX, pen=COLOR_RED},
      },
      view_id='friction',
      on_change=function(val) self:setFriction(val) end,
    },
  }
end

RollerOverlay = defclass(RollerOverlay, overlay.OverlayWidget)
RollerOverlay.ATTRS{
  default_pos={x=-71, y=29},
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Rollers',
  frame={w=27, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function RollerOverlay:getDirection()
  local building = dfhack.gui.getSelectedBuilding()
  local direction = building.direction

  return DIRECTION_MAP_REVERSE[direction]
end

function RollerOverlay:setDirection(direction)
  local building = dfhack.gui.getSelectedBuilding()

  building.direction = DIRECTION_MAP[direction]
end

function RollerOverlay:getSpeed()
  local building = dfhack.gui.getSelectedBuilding()
  local speed = building.speed

  return SPEED_MAP_REVERSE[speed]
end

function RollerOverlay:setSpeed(speed)
  local building = dfhack.gui.getSelectedBuilding()

  building.speed = SPEED_MAP[speed]
end

function RollerOverlay:render(dc)
  local building = dfhack.gui.getSelectedBuilding()

  self.subviews.direction:setOption(DIRECTION_MAP_REVERSE[building.direction])
  self.subviews.speed:setOption(SPEED_MAP_REVERSE[building.speed])

  TrackStopOverlay.super.render(self, dc)
end

function RollerOverlay:init()
  self:addviews{
    widgets.CycleHotkeyLabel{
      label='Direction',
      frame={t=0, l=0},
      key='CUSTOM_CTRL_X',
      options={NORTH, EAST, SOUTH, WEST},
      view_id='direction',
      on_change=function(val) self:setDirection(val) end,
    },
    widgets.CycleHotkeyLabel{
      label='Speed',
      frame={t=1, l=0},
      key='CUSTOM_CTRL_F',
      options={
        {label=LOW, value=LOW, pen=COLOR_BLUE},
        {label=MEDIUM, value=MEDIUM, pen=COLOR_GREEN},
        {label=HIGH, value=HIGH, pen=COLOR_YELLOW},
        {label=HIGHER, value=HIGHER, pen=COLOR_LIGHTRED},
        {label=MAX, value=MAX, pen=COLOR_RED},
      },
      view_id='speed',
      on_change=function(val) self:setSpeed(val) end,
    },
  }
end

OVERLAY_WIDGETS = {
  trackstop=TrackStopOverlay,
  rollers=RollerOverlay,
}
