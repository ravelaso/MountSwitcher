-- MountSwitcher.lua
-- WOTLK 3.3.5a
-- Main addon file - now just a loader since all logic has been modularized to lib/
-- This file is kept for compatibility but all functionality is in lib/ modules

-- The actual addon logic is loaded via the .toc file which loads:
--   lib\MS_Constants.lua  (class spell definitions)
--   lib\MS_Utils.lua      (utility functions)
--   lib\MS_Core.lua       (main loader, event frame, initialization)
--   lib\MS_MountDB.lua    (mount database)
--   lib\MS_UI.lua         (bar frame and drag logic)
--   lib\MS_SecureButton.lua (secure button and spell casting)
--   lib\MS_Options.lua    (options panel)
--   lib\MS_ContextMenu.lua (right-click menu)
--   lib\MS_Bindings.lua   (slash commands and key bindings)

-- This file intentionally left empty - all logic is in the modular files above.
