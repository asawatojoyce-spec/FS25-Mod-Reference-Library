# FS25 Seasons Animals — Session Handoff Document
**Generated:** End of Session 1
**Purpose:** Bootstrap next Claude conversation with full system context in minimum messages

---

## STEP 1 — FIRST MESSAGE IN NEW SESSION (paste this exactly)

> I am continuing work on my FS25 Seasons Animals mod. Please load the following URL first — it is my master GitHub address file and unlocks access to my entire repository:
> https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GitHub_Addresses_CORRECTED.txt
>
> After loading that, load all GPT System files in this order:
> 1. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Boot%20Prompt.txt
> 2. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Opertaing%20System.txt
> 3. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Reasoning%20engine.txt
> 4. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Knowledge%20and%20Trust.txt
> 5. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/UI%20Timing%20Map.txt
> 6. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/UI%20Failure%20Autopsy.txt
> 7. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Known%20Good.txt
> 8. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Self-Healing%20Debug.txt
> 9. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Auto%20Omega%20Mode.txt
> 10. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Command%20Trust%20Omega.txt
> 11. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/Engine%20Failure%20Model.txt
> 12. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/references.txt
> 13. https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GPT%20System/encyclopedia.txt

---

## STEP 2 — LOAD MOD FILES (paste after system boot confirmed)

### My Mod — FS25_SeasonsAnimals
Paste these URLs to load the actual mod being worked on:

**GUI:**
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/modDesc.xml
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/gui/SeasonsAnimalScreen.xml
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/gui/SeasonsAnimalsGuiProfiles.xml

**Scripts:**
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimals.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalMain.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalManager.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalInfo.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalContainer.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalScreen.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalUI.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalUIController.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalUIHook.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsAnimalsFrame.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsImporter.lua
- https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FS25_SeasonsAnimals/scripts/SeasonsPersistence.lua

---

## PROJECT STATE

### What this mod is
A partial recreation of the FS19 Seasons mod — animals only. Not the full Seasons mod. Targeting FS25.

### Current working state
- Base mod structure is working
- Data is being written to XML (persistence works)
- **BLOCKER: Escape menu page is not rendering** — the tab/page does not appear in the InGameMenu

### Current phase (per encyclopedia)
GUI Ownership Discovery

### Active conflict (C001)
Who creates pageFrames? Currently open. Leading theory: engine creates structure, mods extend it.

---

## KEY TECHNICAL CONTEXT (Active from Session 1)

### FS25 Lua Mandates (always enforce)
- Lua 5.1 sandboxed — NO `os.time()`, NO `goto`, NO `table.pack()`
- GUI coordinates: bottom-left origin (0,0)
- Always nil-check `g_financeManager`, `g_server`, `g_client`
- Use `MessageDialog` — NEVER `DialogElement` (white-box crash)
- Always restore `appendedFunction` hooks on mod unload — they stack on savegame reload

### UI Timing — Critical Rule
UI injection MUST happen during `InGameMenu.onLoad`
- ❌ NOT in `loadMapFinished` (UI already built, tab cache locked)
- ❌ NOT post-render
- ✔ DURING `InGameMenu.onLoad` via `Utils.appendedFunction`

### Known-Good UI Pattern
```lua
-- Hook must be set before menu finalizes
InGameMenu.onLoad = Utils.appendedFunction(InGameMenu.onLoad, MyMod.onMenuLoad)

-- Inside onMenuLoad:
local page = MyFrameClass.new(inGameMenu)
inGameMenu:registerPage(page, index, icons)
g_gui:loadControlFromFile(xmlPath, profile, page, menu)
pagingTabList:rebuildTabs()  -- MUST be called immediately
```

### Autopsy model for current blocker
Likely failure at T6-T7 (pagingTabList already building when registerPage called):
- T0-T4 ✔ correct
- T5 ⚠ registerPage executed
- T6 ❌ pagingTabList already building
- T7 ❌ cache lock
- T8-T9 ❌ tab never renders

### Trust hierarchy (always apply)
1. Logs (absolute truth)
2. FS25 runtime behavior
3. Known-good mods
4. LUADOC
5. Documentation
6. Theory

---

## REFERENCE MODS (all accessible via GitHub_Addresses_CORRECTED.txt)

| Ref | Mod | Purpose |
|-----|-----|---------|
| REF001 | FS25_additionalGameSettings | Escape menu page ordering, settings page registration |
| REF002 | Courseplay | Large-scale mature architecture, GUI ownership |
| REF003 | FS25_CropRotation | Gameplay systems, InGameMenu page |
| REF004 | FS25_EasyDevControls | Developer tools, UI injection |
| REF005 | FS25_EnhancedHelpMenu | Menu pages |
| REF006 | FS25_EnhancedLoanSystem | ⭐ Escape menu pages, GUI profiles, XML — most relevant |
| REF007 | FS25_netWorthTracker | ⭐ Delegates, statistics, frame architecture |
| REF008 | FS25_ObjectBaleStorage | Storage systems |
| REF009 | FS25_ObjectStorageExtension | ⭐ Frame hierarchy, XML ownership |
| REF010 | FS25_RDM_PriceMenuFilters | Sorting, filtering, injected controls |

---

## GITHUB ACCESS NOTES

**Master URL file:** `https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/GitHub_Addresses_CORRECTED.txt`
Fetching this URL at the start of a session unlocks ALL listed files for direct fetch.

**For new files not yet in the address file:**
- Need one blob URL pasted directly, then Claude can construct the rest for that folder
- Pattern: `https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library/blob/main/FOLDER/SUBFOLDER/FILENAME.ext`
- Tree URLs (`/tree/`) are blocked. Blob URLs (`/blob/`) work.
- Raw URLs (`raw.githubusercontent.com`) also work as alternative

**Repo:** `https://github.com/asawatojoyce-spec/FS25-Mod-Reference-Library`
**Owner:** asawatojoyce-spec

---

## WHAT TO DO NEXT SESSION

1. Paste Step 1 message above to boot the system
2. Paste Step 2 mod file URLs to load current mod code
3. Tell Claude: "Run Omega on the escape menu blocker using the loaded mod files and compare against REF006 (EnhancedLoanSystem) and REF009 (ObjectStorageExtension) as known-good references"
4. Provide the FS25 log file output (paste as text, not upload) so Autopsy Engine can reconstruct the T0-T9 timeline

---

## SKILL REFERENCE (FS25 Claude Skill)
https://github.com/TheCodingDad-TisonK/fs25-claude-skill
— Contains LUADOC index, Giants source reference, 20+ pitfalls
— Load README for patterns when starting fresh

---
*End of handoff document. Save this file locally and/or add to your GitHub repo.*
