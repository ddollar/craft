Craft  = LibStub("AceAddon-3.0"):NewAddon("Craft", "AceEvent-3.0")

local AceConfig = LibStub("AceConfig-3.0")
local AceGUI    = LibStub("AceGUI-3.0")

local AuctionManager    = LibStub("AuctionManager-1.0")
local InventoryManager  = LibStub("InventoryManager-1.0")
local TradeSkillManager = LibStub("TradeSkillManager-1.0")

AuctionManager:OnScan(function(item, page)
  Craft:UpdateLabel("scan", "Scanning Page "..(page+1).." of "..item)
end)

AuctionManager:OnScanComplete(function()
  Craft:UpdateLabel("scan", "Scan Complete")
  Craft.db.char.auction_database = AuctionManager.database
end)

function Craft:OnInitialize()
  self.recipe_queue = {}
  self.reagent_queue = {}
  self.reagents_in_queue = {}

  self.current_buy_reagent = nil
  self.current_buy_amount = 0
  self.is_buying = false
  self.make_next = nil

  self.db = LibStub("AceDB-3.0"):New("CraftDB")

  if self.db.char.auction_database then
    AuctionManager.database = self.db.char.auction_database
  end
end

function Craft:OnEnable()
  self:RegisterEvents()
end

function Craft:OnDisable()
end

-- UTILITY ###################################################################

local function HideBlizzardFrame(frame)
  if frame and frame:IsVisible() then
    frame:SetAlpha(0)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetPoint("TOPLEFT", SkilletFrame, "TOPLEFT", 5, -5)
    frame:SetWidth(5)
    frame:SetHeight(5)
  end
end

local function CreateTableRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(24)

  row.button = CreateFrame("Button", nil, row, "OptionsButtonTemplate")
  row.button:SetWidth(100)
  row.button:SetHeight(24)
  row.button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("TOPLEFT", row.button, "TOPRIGHT", 12, -7)
  row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetJustifyV("MIDDLE")

  return row
end

local function CreateCraftFrame()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 10, -10)

  -- container frame
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetWidth(470)
  frame:SetHeight(200)
  frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background.blp",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    insets   = { top = 12, right = 12, bottom = 11, left = 11 }
  })

  frame.scan = CreateTableRow(frame)
  frame.scan:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
  frame.scan:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -20)
  frame.scan.button:SetText("Scan")
  frame.scan.button:SetScript("OnClick", function(self)
    Craft:Scan()
  end)

  frame.optimize = CreateTableRow(frame)
  frame.optimize:SetPoint("TOPLEFT",  frame.scan, "BOTTOMLEFT",  0, -10)
  frame.optimize:SetPoint("TOPRIGHT", frame.scan, "BOTTOMRIGHT", 0, -10)
  frame.optimize.button:SetText("Optimize")
  frame.optimize.button:SetScript("OnClick", function(self)
    Craft:Optimize()
  end)

  frame.next_reagent = CreateTableRow(frame)
  frame.next_reagent:SetPoint("TOPLEFT",  frame.optimize, "BOTTOMLEFT",  0, -10)
  frame.next_reagent:SetPoint("TOPRIGHT", frame.optimize, "BOTTOMRIGHT", 0, -10)
  frame.next_reagent.button:SetText("Next Reagent")
  frame.next_reagent.button:SetScript("OnClick", function(self)
    Craft:NextReagent()
  end)

  frame.buy_reagent = CreateTableRow(frame)
  frame.buy_reagent:SetPoint("TOPLEFT",  frame.next_reagent, "BOTTOMLEFT",  0, -10)
  frame.buy_reagent:SetPoint("TOPRIGHT", frame.next_reagent, "BOTTOMRIGHT", 0, -10)
  frame.buy_reagent.button:SetText("Buy Reagent")
  frame.buy_reagent.button:SetScript("OnClick", function(self)
    Craft:BuyReagents()
  end)

  frame.craft = CreateTableRow(frame)
  frame.craft:SetPoint("TOPLEFT",  frame.buy_reagent, "BOTTOMLEFT",  0, -10)
  frame.craft:SetPoint("TOPRIGHT", frame.buy_reagent, "BOTTOMRIGHT", 0, -10)
  frame.craft.button:SetText("Craft")
  frame.craft.button:SetScript("OnClick", function(self)
    Craft:Craft()
  end)

  return(frame)
end

-- EVENTS ####################################################################

function Craft:RegisterEvents()
  self:RegisterEvent("AUCTION_HOUSE_SHOW")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
end

function Craft:AUCTION_HOUSE_SHOW()
  self:ShowFrame()
end

function Craft:AUCTION_HOUSE_CLOSED()
  self:HideFrame()
end

-- FRAMES ####################################################################

function Craft:ShowFrame()
  if not self.frame then
    self.frame = CreateCraftFrame()
  end
  self.frame:Show()
end

function Craft:HideFrame()
  if self.frame then
    self.frame:Hide()
  end
end

-- UTILITY ###################################################################

function Craft:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(message)
end

function Craft:Scan()
  TradeSkillManager:Scan("Enchanting")

  local recipes = Craft:ModernRecipes()

  for _, recipe in pairs(recipes) do
    AuctionManager:Scan(recipe.name)
    for reagent, _ in pairs(recipe.reagents) do
      AuctionManager:Scan(reagent)
    end
  end
end

function Craft:Optimize()
  TradeSkillManager:Scan("Enchanting")

  self:UpdateLabel("next_reagent", "")
  self:UpdateLabel("buy_reagent", "")

  local recipes = Craft:ModernRecipes()
  local recipe_revenue, recipe_cost, reagent_cost

  InventoryManager:Scan()

  total_items = 0
  total_cost = 0
  total_revenue = 0

  self.recipe_queue = {}

  local my_auctions = {}
  for i = 1, GetNumAuctionItems("owner") do
     name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner, saleStatus = GetAuctionItemInfo("owner", i);
     if saleStatus == 0 then
        if type(my_auctions[name]) == "nil" then
           my_auctions[name] = 0
        end
        my_auctions[name] = my_auctions[name] + count
     end
  end

  for _, recipe in pairs(recipes) do
    recipe_revenue = AuctionManager:MinimumPrice(recipe.name)
    if recipe_revenue then

      recipe_cost = 0

      -- calculate recipe cost
      for _, reagent in pairs(recipe.reagents) do
        reagent_cost = AuctionManager:MedianPrice(reagent.name)

        -- disqualify things that dont exist
        if not reagent_cost then
          if not reagent.name:find("ellum") then
            self:Print("couldnt find: "..reagent.name)
            reagent_cost = 10000
          else
            reagent_cost = 5
          end
        end

        recipe_cost = recipe_cost + (reagent_cost * reagent.count)
      end

      -- if it's profitable enough, make it
      if (recipe_revenue / recipe_cost) > 1.4 then
        local already_made = InventoryManager:OnHand(recipe.name)
        local num_to_make = (3 - already_made)

        if my_auctions[recipe.name] then
          num_to_make = num_to_make - my_auctions[recipe.name]
        end

        if num_to_make > 0 then
          total_items = total_items + num_to_make
          total_cost = total_cost + (num_to_make * recipe_cost)
          total_revenue = total_revenue + (num_to_make * recipe_revenue)

          self.recipe_queue[recipe.name] = num_to_make
        end
      end
    end
  end

  self:UpdateLabel("optimize", total_items.." recipes, ".. total_cost.." cost, "..total_revenue.." revenue")

  self.reagent_queue = {}

  local recipes = Craft:ModernRecipes()

  for recipe, num in pairs(self.recipe_queue) do
    for _, reagent in pairs(recipes[recipe].reagents) do
      if not self.reagent_queue[reagent.name] then self.reagent_queue[reagent.name] = 0 end
      self.reagent_queue[reagent.name] = self.reagent_queue[reagent.name] + (reagent.count * num)
    end
  end

  InventoryManager:Scan()

  for reagent, count in pairs(self.reagent_queue) do
    count = count - InventoryManager:OnHand(reagent)
    if count > 0 then
      self.reagent_queue[reagent] = math.ceil(count)
    else
      self.reagent_queue[reagent] = nil
    end
  end

  self:PrepareNextCraft()
end

function Craft:NextReagent()
  local reagent, count

  self:UpdateLabel("next_reagent", "")
  self:UpdateLabel("buy_reagent", "")

  self.current_buy_reagent = nil
  self.current_buy_amount = 0

  for reagent, count in pairs(self.reagent_queue) do
    self:UpdateLabel("next_reagent", reagent)
    self:UpdateLabel("buy_reagent", count .. " needed")
    self.current_buy_reagent = reagent
    self.current_buy_amount = count
    QueryAuctionItems(reagent)
    self.reagent_queue[reagent] = nil
    return
  end
end

function Craft:BuyReagents()
  local num_auctions = GetNumAuctionItems("list")
  local name, texture, count, quality, canUse, level, minBid, minIncrement
  local buyoutPrice, bidAmount, highBidder, owner, saleStatus
  local i

  local reagents = {}
  local median = AuctionManager:MedianPrice(self.current_buy_reagent)

  for i = 1, num_auctions do
    name, texture, count, quality, canUse, level, minBid, minIncrement,
    buyoutPrice, bidAmount, highBidder, owner,
    saleStatus = GetAuctionItemInfo("list", i);

    if name == self.current_buy_reagent then
      table.insert(reagents, {
        name  = name,
        index = i,
        price = math.floor(buyoutPrice / count / 100) / 100,
        count = count,
        total = buyoutPrice
      })
    end
  end

  table.sort(reagents, function(a, b)
    return a.price < b.price
  end)

  for _, reagent in pairs(reagents) do
    if reagent.price < median then
      self:Print("would buy "..reagent.count.." of "..reagent.name)
      self.current_buy_amount = self.current_buy_amount - reagent.count
      if self.current_buy_amount <= 0 then return end
      self:UpdateLabel("buy_reagent", self.current_buy_amount .. " needed")
      PlaceAuctionBid("list", reagent.index, reagent.total)
    else
      self:Print("skipping "..reagent.price.."  "..median)
    end
  end
end

function Craft:Craft()
  if self.make_next then
    self.recipe_queue[self.make_next] = self.recipe_queue[self.make_next] - 1
    TradeSkillManager:Make("Enchanting", self.make_next, 1)

    if self.make_next:match("eapon") or self.make_next:match("taff") then
      InventoryManager:Use("Weapon Vellum III")
    else
      InventoryManager:Use("Armor Vellum III")
    end

    if self.recipe_queue[self.make_next] <= 0 then
      self.recipe_queue[self.make_next] = nil
      self.make_next = nil
      self:UpdateLabel("craft", "")
    end

    self:PrepareNextCraft()
  end
end

-- PRIVATE ###################################################################

local MODERN_REAGENTS = { 'Abyss Crystal', 'Dream Shard',
  "Greater Cosmic Essence", "Lesser Cosmic Essence", "Infinite Dust" }

function Craft:ModernRecipes()
  local recipes = TradeSkillManager:RecipesMatching("Enchanting", function(recipe)
    local modern = false
    local reagent, modern_reagent

    for reagent, _ in pairs(recipe.reagents) do
      for _, modern_reagent in pairs(MODERN_REAGENTS) do
        if reagent == modern_reagent then modern = true end
      end
    end

    return modern
  end)

  return recipes
end

function Craft:UpdateLabel(row, text)
  self.frame[row].label:SetText(text)
end

function Craft:PrepareNextCraft()
  local recipe, count

  for recipe, count in pairs(self.recipe_queue) do
    self:UpdateLabel("craft", recipe .. " (" .. count .. ")")
    self.make_next = recipe
    break
  end
end
