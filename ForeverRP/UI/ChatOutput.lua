local Addon = ForeverRP
local Output = {pending = {}, name = "ForeverRP"}
Addon.ChatOutput = Output

function Output:FindWindow()
    if not GetChatWindowInfo then return nil end
    local maximum = NUM_CHAT_WINDOWS or (Constants and Constants.ChatFrameConstants
        and Constants.ChatFrameConstants.MaxChatWindows) or 10
    for index = 3, maximum do
        local frame = _G["ChatFrame" .. index]
        local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(index)
        if Addon.ValueAccess:CanAccess(name, shown, docked) and name == self.name
            and frame and not frame.isTemporary and frame.AddMessage
            and (shown == true or shown == 1 or docked == true
                or type(docked) == "number" and docked > 0) then return frame end
    end
end

function Output:GetWindow()
    local existing = self:FindWindow()
    if existing then return existing end
    if self.attempted or not FCF_OpenNewWindow then return nil end
    local combat = InCombatLockdown and InCombatLockdown()
    if not Addon.ValueAccess:CanAccess(combat) or combat ~= false then
        self.deferred = true
        return nil
    end
    self.attempted = true
    local selected = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow
        and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local ok, frame = pcall(FCF_OpenNewWindow, self.name, true)
    if not ok or not frame or not frame.AddMessage then return nil end
    -- Configure only a newly created window. Preserve user filters on reuse.
    -- Support both the current mixins and the older chat-frame globals.
    if frame.RemoveAllMessageGroups then frame:RemoveAllMessageGroups()
    elseif ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(frame) end
    if frame.RemoveAllChannels then frame:RemoveAllChannels()
    elseif ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
    -- Creating a docked tab normally selects it; keep the user's current tab.
    if selected and FCF_SelectDockFrame then
        FCF_SelectDockFrame(selected)
        if selected.editBox then
            if ChatFrameUtil and ChatFrameUtil.SetLastActiveWindow then
                ChatFrameUtil.SetLastActiveWindow(selected.editBox)
            elseif ChatEdit_SetLastActiveWindow then ChatEdit_SetLastActiveWindow(selected.editBox) end
        end
    end
    return frame
end

local function MainWindow(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else print(text) end
end

function Output:Write(text)
    if not self.ready then
        -- Startup diagnostics may precede chat initialization. Bound runtime storage.
        if #self.pending >= 100 then table.remove(self.pending, 1) end
        self.pending[#self.pending + 1] = text
        return
    end
    local frame = self:GetWindow()
    if frame then frame:AddMessage(text); return end
    -- Keep commands/errors readable if all chat slots are occupied or creation
    -- is unavailable. This is local output, never a chat-channel transmission.
    if not self.warned then
        self.warned = true
        MainWindow("ForeverRP: Local chat tab unavailable; reports are shown here. Free a chat tab and /reload if needed.")
    end
    MainWindow(text)
end

function Output:Initialize()
    self.ready = true
    self:GetWindow()
    local pending = self.pending
    self.pending = {}
    for _, text in ipairs(pending) do self:Write(text) end
end

function Output:OnCombatEnded()
    if self.ready and self.deferred then
        self.deferred = nil
        self:Initialize()
    end
end
