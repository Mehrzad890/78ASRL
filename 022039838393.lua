-- CustomAnimationController.lua
-- Place as a LocalScript in StarterCharacterScripts
-- Replace the IDs below with your animation asset ids.

local CustomAnims = {
    Idle   = "rbxassetid://128275345904092",
    Walk   = "rbxassetid://74718661188657",
    Run    = "rbxassetid://109554043735890",
    Jump   = "rbxassetid://109687495808615",
    Fall   = "rbxassetid://109687495808615",
    Climb  = "rbxassetid://82587632175618",
    Swim   = "rbxassetid://118016588766846",
}

-- Configuration
local RUN_THRESHOLD = 12    -- speed (studs/sec) above which "Run" plays instead of "Walk"
local WALK_THRESHOLD = 1    -- minimal speed to be considered walking

-- Internal helpers
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function createAnimation(id, priority)
    local anim = Instance.new("Animation")
    anim.Name = id
    anim.AnimationId = id
    if priority then
        pcall(function() anim.Priority = priority end)
    end
    return anim
end

local function setupForCharacter(character)
    if not character then return end

    -- Wait for humanoid
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    -- Remove any default "Animate" script if present
    local oldAnimate = character:FindFirstChild("Animate")
    if oldAnimate then oldAnimate:Destroy() end

    -- Ensure an Animator exists
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Create Animation objects (AnimationId = rbxassetid://...)
    local animations = {
        Idle  = createAnimation(CustomAnims.Idle, Enum.AnimationPriority.Idle),
        Walk  = createAnimation(CustomAnims.Walk, Enum.AnimationPriority.Movement),
        Run   = createAnimation(CustomAnims.Run, Enum.AnimationPriority.Movement),
        Jump  = createAnimation(CustomAnims.Jump, Enum.AnimationPriority.Action),
        Fall  = createAnimation(CustomAnims.Fall, Enum.AnimationPriority.Action),
        Climb = createAnimation(CustomAnims.Climb, Enum.AnimationPriority.Movement),
        Swim  = createAnimation(CustomAnims.Swim, Enum.AnimationPriority.Movement),
    }

    -- Load tracks (pcall because invalid assets will error)
    local tracks = {}
    for name, anim in pairs(animations) do
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        if ok and track then
            track.Name = name .. "Track"
            -- set looping where appropriate
            if name == "Idle" or name == "Walk" or name == "Run" or name == "Climb" or name == "Swim" then
                track.Looped = true
            else
                track.Looped = false
            end
            tracks[name] = track
        else
            warn("Could not load animation:", name, anim.AnimationId)
        end
    end

    -- Keep track of currently playing state
    local currentState = "Idle"

    local function playState(state, fadeTime)
        fadeTime = fadeTime or 0.12
        if currentState == state then return end

        -- Stop tracks that shouldn't be playing
        for name, track in pairs(tracks) do
            if track then
                if name == state then
                    if not track.IsPlaying then
                        track:Play(fadeTime)
                    end
                else
                    if track.IsPlaying then
                        track:Stop(fadeTime)
                    end
                end
            end
        end
        currentState = state
    end

    -- React to running (speed)
    local function onRunning(speed)
        -- If in special states (Jumping, Falling, Swimming, Climbing) don't override
        local hState = humanoid:GetState()
        if hState == Enum.HumanoidStateType.Freefall or
           hState == Enum.HumanoidStateType.Jumping or
           hState == Enum.HumanoidStateType.Swimming or
           hState == Enum.HumanoidStateType.Climbing then
            return
        end

        if speed >= RUN_THRESHOLD and tracks.Run then
            playState("Run")
        elseif speed >= WALK_THRESHOLD and tracks.Walk then
            playState("Walk")
        else
            playState("Idle")
        end
    end

    -- React to state changes (Jump, Fall, Swim, Climb, Land)
    humanoid.Running:Connect(onRunning)

    humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            if tracks.Jump then
                playState("Jump", 0.08)
            end
        elseif newState == Enum.HumanoidStateType.Freefall then
            if tracks.Fall then
                playState("Fall", 0.12)
            end
        elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.Walking then
            -- resume based on speed
            onRunning(humanoid.MoveDirection.Magnitude > 0 and humanoid.WalkSpeed or 0)
        elseif newState == Enum.HumanoidStateType.Swimming then
            if tracks.Swim then
                playState("Swim", 0.12)
            end
        elseif newState == Enum.HumanoidStateType.Climbing then
            if tracks.Climb then
                playState("Climb", 0.12)
            end
        end
    end)

    -- Ensure Idle plays on spawn
    task.delay(0.15, function()
        if tracks.Idle and not tracks.Idle.IsPlaying then
            playState("Idle", 0.2)
        end
    end)
end

-- Connect to character ready / respawn
if LocalPlayer.Character then
    setupForCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
    -- small delay to let humanoid load
    task.wait(0.05)
    setupForCharacter(char)
end)