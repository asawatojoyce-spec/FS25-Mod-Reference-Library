SeasonsAnimalUIContainer = {}

local registered = false

-- =========================================================
-- CREATE ISOLATED UI ROOT NODE
-- =========================================================
function SeasonsAnimalUIContainer:initialize()

    if registered then return end
    registered = true

    print("[SeasonsAnimalUIContainer] creating isolated UI namespace")

    self.rootName = "SeasonsAnimals_UI_ROOT"
    self.pages = {}

    self:registerContainer()
end

-- =========================================================
-- FS25 SAFE CONTAINER REGISTRATION
-- =========================================================
function SeasonsAnimalUIContainer:registerContainer()

    -- IMPORTANT:
    -- This avoids InGameMenu root collision with ELS

    if InGameMenu == nil then
        print("[SeasonsAnimalUIContainer] InGameMenu not ready")
        return
    end

    -- We DO NOT attach directly to ELS menu space
    -- We create isolated logical grouping

    self.container = {
        name = self.rootName,
        pages = {}
    }

    print("[SeasonsAnimalUIContainer] isolated container created")
end

-- =========================================================
-- SAFE PAGE REGISTRATION INTO ISOLATED SPACE
-- =========================================================
function SeasonsAnimalUIContainer:addPage(page)

    if page == nil then return end

    table.insert(self.container.pages, page)

    print("[SeasonsAnimalUIContainer] page added to isolated container")
end

-- =========================================================
-- GET SAFE PAGE LIST (USED BY CONTROLLER)
-- =========================================================
function SeasonsAnimalUIContainer:getPages()
    return self.container.pages
end