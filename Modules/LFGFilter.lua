-- Modules/LFGFilter.lua
-- DISABLED in v1.0 due to taint propagation.
--
-- The original implementation hooked LFGListSearchEntry_Update via SecureHook
-- and applied a colored texture overlay to flagged players' rows. While this
-- worked visually, it tainted the LFG panel — and because the secure panel
-- manager (UIParentPanelManager) shares state across CharacterFrame, the
-- ItemUpgradeUI, and the LFG panel, this propagated taint into the gear
-- upgrade flow, breaking the protected UpgradeItem() call.
--
-- Replacing it requires either:
--   1. A non-hook approach: scan results periodically and show a separate
--      RepKeeper window listing flagged leaders (no Blizzard frame mutation)
--   2. A tooltip-only approach: extend Tooltip.lua to add reputation lines
--      when hovering an LFG result entry (already partially covered)
--
-- For now, this module is a no-op stub. The setting `lfgFilterEnabled`
-- still exists for forward-compat but does nothing.

local addonName, ns = ...

local LFGFilter = {}
ns.LFGFilter = LFGFilter

function LFGFilter:Initialize()
    -- No-op. See file header for explanation.
end
