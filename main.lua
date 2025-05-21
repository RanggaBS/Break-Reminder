-- -------------------------------------------------------------------------- --
-- Configuration                                                              --
-- -------------------------------------------------------------------------- --

local config = {
  -- Main Feature

  -- Enable or disable the mod entirely
  enabled = true,

  -- Minimum playtime before the reminder appears (seconds). Default: 1 hour.
  minPlaytimeSeconds = 1 * 60 * 60,
  -- minPlaytimeSeconds = 2, -- DEBUG

  -- Message Content

  -- Reminder message text.
  messageText = "You've been playing for a while. Don't forget to take a break!",

  -- Display: Background Box

  -- Show or hide the background box
  boxShow = true,
  -- RGBA Color: Black, semi-transparent
  boxColor = { r = 0, g = 0, b = 0, a = 127 },
  -- Relative X position (0 = left edge of the screen)
  boxPositionX = 0,
  -- Relative Y position (0 = top edge of the screen)
  boxPositionY = 0,
  -- Relative width (1.0 = full screen width)
  boxWidth = 1.0,
  -- Relative height (0.1 = 10% of screen height).
  -- Ideally, this "adjusts to text height + a little vertical padding".
  -- This requires a function like GetTextHeight() which might not be available.
  -- For now, using a fixed value.
  boxHeight = 0.05,

  -- Display: Text

  -- Text color (e.g., White).
  -- Assumed DrawText uses a default color or it's set globally.
  -- If the API supports it, this can be added.
  textColor = { r = 255, g = 255, b = 255, a = 255 },

  -- Marquee Effect / Running Text

  -- Enable marquee effect for the message text.
  enableMarquee = true,
  -- Marquee text direction: "RTL" (Right to Left) or "LTR" (Left to Right).
  textDirection = 'RTL',
  -- Text scroll speed (relative units per frame). Smaller is slower.
  -- marqueeSpeed = 0.005,
  marqueeSpeed = 0.0008,
  -- Whether the marquee text will loop after disappearing from the screen
  loopMarquee = true,
  -- Key to manually dismiss the marquee message (e.g., 'ESCAPE', 'BACKSPACE').
  -- Leave the string empty '' or set to nil if you don't want to use this feature.
  marqueeDismissKey = 'BACKSPACE',

  -- Debugging
  debugMode = false, -- Enable/Disable debug mode.
  -- Default key: "F5"
  debugTriggerKey = 'F5',
  -- Countdown duration in seconds when debug is activated.
  debugCountdownSeconds = 5,

  -- Padding untuk teks di dalam kotak (jika posisi teks dapat dikontrol lebih lanjut)

  -- Relative horizontal padding (e.g., 2% of screen width)
  textPaddingHorizontal = 0.02,
  -- Relative vertical padding (e.g., 1% of screen height)
  textPaddingVertical = 0.01,
}

local Util = {}

-- -------------------------------------------------------------------------- --
-- Entry Point                                                                --
-- -------------------------------------------------------------------------- --

function main()
  while not SystemIsReady() do
    Wait(0)
  end

  -- If the mod is disabled in the configuration
  if not config.enabled then return end

  local cfg = config

  local playSessionStartTime = GetTimer() -- Time (ms) when the current play session started (for reminder countdown)
  local reminderIsActive = false -- Status whether the reminder is currently being displayed
  local reminderActivationTime = 0 -- Time (ms) when the reminder started to be displayed

  local marqueeTextCurrentX = 0 -- Current X position for the marquee text
  local isDebugCountdownActive = false -- Status whether the debug countdown is active
  local debugCountdownTargetTime = 0 -- Time (ms) when the debug countdown will end

  -- Initial initialization for the marquee text X position.
  -- This will be reset each time the reminder becomes active.
  if cfg.enableMarquee then
    if cfg.textDirection == 'RTL' then
      -- Start slightly outside the right side of the screen/box
      marqueeTextCurrentX = cfg.boxPositionX
        + cfg.boxWidth
        + cfg.textPaddingHorizontal
    else -- LTR
      -- For LTR, ideally we know the text width to start from outside the left screen.
      -- Estimate text width to start from outside the left screen.
      local estimatedTextWidth = 0
      if cfg.messageText and string.len(cfg.messageText) > 0 then
        -- Using the existing function, although it might not be perfect for all fonts/cases
        estimatedTextWidth =
          Util.GetTextWidthByCharactersLength(cfg.messageText, 16) -- Asumsi 16 adalah parameter yang relevan untuk tinggi/lebar karakter
      end
      marqueeTextCurrentX = cfg.boxPositionX
        - estimatedTextWidth
        - cfg.textPaddingHorizontal
    end
  else
    -- If marquee is not active, the text might need to be positioned statically in the center.
    -- For now, it's assumed SetTextPosition will handle this if enableMarquee is false.
  end

  local boxAlpha = 0

  while true do
    Wait(0) -- Important to yield to the game engine every frame

    local currentTime = GetTimer()

    -- DEBUG BLOCK: Trigger marquee message with a key
    if
      cfg.debugMode
      and not reminderIsActive
      and not isDebugCountdownActive
    then
      if IsKeyBeingPressed(cfg.debugTriggerKey) then
        isDebugCountdownActive = true
        -- Calculate playSessionStartTime so the reminder activates after debugCountdownSeconds
        -- Effective playtime now = minPlaytimeSeconds - debugCountdownSeconds
        local effectivePlaytimeMs = (cfg.minPlaytimeSeconds * 1000)
          - (cfg.debugCountdownSeconds * 1000)
        if effectivePlaytimeMs < 0 then effectivePlaytimeMs = 0 end -- Ensure it's not negative

        playSessionStartTime = currentTime - effectivePlaytimeMs
        debugCountdownTargetTime = playSessionStartTime
          + (cfg.minPlaytimeSeconds * 1000)

        -- Don't activate the reminder immediately, let the countdown run
        -- print("BreakReminder Debug: Message activated manually.") -- Optional log line, use game's log function if available

        -- Re-initialize marquee X position each time the reminder is activated
        if cfg.enableMarquee then
          if cfg.textDirection == 'RTL' then
            marqueeTextCurrentX = cfg.boxPositionX
              + cfg.boxWidth
              + cfg.textPaddingHorizontal
          else -- LTR
            local estimatedTextWidth = 0
            if cfg.messageText and string.len(cfg.messageText) > 0 then
              estimatedTextWidth =
                Util.GetTextWidthByCharactersLength(cfg.messageText, 16)
            end
            marqueeTextCurrentX = cfg.boxPositionX
              - estimatedTextWidth
              - cfg.textPaddingHorizontal
          end
        end
        -- Reset alpha for fade-in again
        boxAlpha = 0
      end
    end

    -- Logika Countdown Debug
    if isDebugCountdownActive then
      local remainingMs = debugCountdownTargetTime - currentTime
      if remainingMs > 0 then
        -- local remainingSecsDisplay = math.ceil(remainingMs / 1000)
        local remainingSecsDisplay = string.format('%.2f', remainingMs / 1000)
        DrawTextInline(
          '[DEBUG]\nBreak Reminder starting in: ' .. remainingSecsDisplay .. 's',
          1, -- durationInSeconds for DrawTextInline, will be refreshed each frame
          1 -- objectiveHudStyle
        )
      else
        isDebugCountdownActive = false -- Countdown finished, normal reminder logic will take over
      end
    end

    if reminderIsActive then
      -- Logic to dismiss marquee with a key
      local dismissedByKey = false
      if cfg.marqueeDismissKey and string.len(cfg.marqueeDismissKey) > 0 then
        if IsKeyBeingPressed(cfg.marqueeDismissKey) then
          dismissedByKey = true
        end
      end

      SetTextAlign('RIGHT', 'TOP')
      SetTextPosition(1, 0 + cfg.boxHeight)
      SetTextColor(255, 255, 255, 255)
      DrawText('Dismiss: ' .. cfg.marqueeDismissKey)

      if dismissedByKey then
        reminderIsActive = false
        playSessionStartTime = currentTime -- Reset timer for the next break interval
        -- print("BreakReminder: Marquee dismissed by key.") -- Optional log
      else
        -- Check if the text is off-screen (only if not looping)
        local textWidth =
          Util.GetTextWidthByCharactersLength(cfg.messageText, 16) -- Asumsi 16 adalah parameter yang relevan
        local textOffScreen = false
        if cfg.textDirection == 'RTL' then
          textOffScreen = marqueeTextCurrentX
            < (cfg.boxPositionX - textWidth - cfg.textPaddingHorizontal) -- Text completely to the left outside the box
        else -- LTR
          textOffScreen = marqueeTextCurrentX
            > (cfg.boxPositionX + cfg.boxWidth + cfg.textPaddingHorizontal) -- Teks sepenuhnya di kanan luar kotak
        end

        -- Pengingat masih aktif dan dalam durasi tampil
        if cfg.boxShow then
          local fadeInDurationMs = 1000 -- Fade-in duration in milliseconds (1 second)
          local timeSinceActivation = currentTime - reminderActivationTime

          -- Calculate lerp progress (0.0 to 1.0)
          local t_progress = 0
          if fadeInDurationMs > 0 then
            t_progress =
              math.min(1, math.max(0, timeSinceActivation / fadeInDurationMs))
          elseif timeSinceActivation >= 0 then -- If duration is 0, go directly to target alpha
            t_progress = 1
          end

          -- Lerp alpha from 0 to target alpha
          boxAlpha = Util.Lerp(0, cfg.boxColor.a, t_progress)

          DrawRectangle(
            cfg.boxPositionX,
            cfg.boxPositionY,
            cfg.boxWidth,
            cfg.boxHeight,
            cfg.boxColor.r,
            cfg.boxColor.g,
            cfg.boxColor.b,
            math.floor(boxAlpha) -- Use math.floor to ensure an integer value for alpha
          )
        end

        SetTextPosition(marqueeTextCurrentX, 0 + cfg.boxHeight / 2)

        -- Text drawing process
        if cfg.enableMarquee then
          -- This marquee implementation is conceptual.
          -- Its success heavily depends on the capabilities of the available DrawText API.
          -- If DrawText(text) does not accept position parameters (x,y) or there's no function
          -- like SetTextPosition(x,y), then the visual marquee effect might not occur
          -- and the text will appear static. The marqueeTextCurrentX variable will have no effect.

          -- Update X position for marquee
          if cfg.textDirection == 'RTL' then
            marqueeTextCurrentX = marqueeTextCurrentX
              - (cfg.marqueeSpeed * GetFrameTime() * 100) -- Frame-rate independent speed

            if textOffScreen then
              if cfg.loopMarquee then
                marqueeTextCurrentX = cfg.boxPositionX
                  + cfg.boxWidth
                  + cfg.textPaddingHorizontal -- Reset to the right
              else
                reminderIsActive = false -- Finished if not looping
                playSessionStartTime = currentTime
              end
            end
          else -- LTR
            marqueeTextCurrentX = marqueeTextCurrentX
              + (cfg.marqueeSpeed * GetFrameTime() * 100) -- Frame-rate independent speed

            if textOffScreen then
              if cfg.loopMarquee then
                -- Reset to the left outside (requires text width estimation)
                marqueeTextCurrentX = cfg.boxPositionX
                  - textWidth
                  - cfg.textPaddingHorizontal
              else
                reminderIsActive = false -- Finished if not looping
                playSessionStartTime = currentTime
              end
            end
          end

          -- Format text
          SetTextAlign('LEFT', 'CENTER')
          SetTextColor(
            cfg.textColor.r,
            cfg.textColor.g,
            cfg.textColor.b,
            cfg.textColor.a
          )
          SetTextColor(
            cfg.textColor.r,
            cfg.textColor.g,
            cfg.textColor.b,
            cfg.textColor.a
          )
          local h = Util.PixelToRelative(16, 'y')
          SetTextHeight(h)
          SetTextScale(1)

          -- DRAWTEXT CALL:
          -- Ensure text is only drawn if the reminder is still active (important after loop/dismiss check)
          if reminderIsActive then DrawText(cfg.messageText) end
        else
          marqueeTextCurrentX = 0.5
          local h = Util.PixelToRelative(16, 'y')
          SetTextColor(
            cfg.textColor.r,
            cfg.textColor.g,
            cfg.textColor.b,
            cfg.textColor.a
          )
          SetTextAlign('CENTER', 'CENTER')
          SetTextPosition(marqueeTextCurrentX, 0 + cfg.boxHeight / 2)
          SetTextHeight(h)
          SetTextScale(1)
          -- Static text (no marquee)
          DrawText(cfg.messageText)
        end
      end
    else
      -- Reminder is not active, check if it's time for it to appear
      -- Also ensure debug countdown is not active
      if
        not isDebugCountdownActive
        and currentTime
          >= playSessionStartTime + cfg.minPlaytimeSeconds * 1000
      then
        reminderIsActive = true
        reminderActivationTime = currentTime

        -- Re-initialize marquee X position each time the reminder is activated
        if cfg.enableMarquee then
          if cfg.textDirection == 'RTL' then
            marqueeTextCurrentX = cfg.boxPositionX
              + cfg.boxWidth
              + cfg.textPaddingHorizontal
          else -- LTR
            local estimatedTextWidth = 0
            if cfg.messageText and string.len(cfg.messageText) > 0 then
              estimatedTextWidth =
                Util.GetTextWidthByCharactersLength(cfg.messageText, 16)
            end
            marqueeTextCurrentX = cfg.boxPositionX
              - estimatedTextWidth
              - cfg.textPaddingHorizontal
          end
        end
        -- Reset alpha for fade-in
        boxAlpha = 0
      end
    end

    -- -- local testText = 'a 0-3t-03tgkf0-w 0 rpfkiw2q]-[v01r4-vm no]' -- Some symbols have different width than normal letter???
    -- local testText = 'quick brown fox jumps over the lazy dog'
    -- -- local testText = 'sadhasiudnaskdnhasdjin'
    -- local w = Util.GetTextWidthByCharactersLength(testText, 16) / 2.65
    -- DrawRectangle(0, 0, w, 0.1, 255, 255, 255, 255)
    -- SetTextAlign('LEFT', 'TOP')
    -- SetTextPosition(0, 0)
    -- SetTextColor(0, 0, 0, 255)
    -- DrawText(testText)
  end
end

-- -------------------------------------------------------------------------- --
-- Helper Functions                                                           --
-- -------------------------------------------------------------------------- --

---@param a number
---@param b number
---@param t number
---@return number
function Util.Lerp(a, b, t)
  return a == b and a or t == 0 and a or t == 1 and b or (a + (b - a) * t)
end

---@param px number
---@param axis 'x'|'y'
---@return number
function Util.PixelToRelative(px, axis)
  local screenX, screenY = GetInternalResolution()
  return px / (axis == 'x' and screenX or screenY)
end

---@param text string
---@param heightPerChar number
---@return integer
function Util.GetTextWidthByCharactersLength(text, heightPerChar)
  local len = string.len(text)
  return Util.PixelToRelative(heightPerChar, 'x') * len
end
