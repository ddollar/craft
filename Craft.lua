local Craft  = LibStub("AceAddon-3.0"):NewAddon("Craft", "AceConsole-3.0", "AceEvent-3.0")

local AceConfig = LibStub("AceConfig-3.0")
local AceGUI    = LibStub("AceGUI-3.0")

function Craft:OnInitialize()
end

function Craft:OnEnable()
  self:RegisterEvents()
  --self:Print("hi from craft")
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

local function HideBlizzardTradeSkillFrame()
  HideBlizzardFrame(TradeSkillFrame)
end

local function CreateCraftFrame()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetPoint("CENTER", 0, 0)

  -- container frame
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetWidth(800)
  frame:SetHeight(601)
  --frame:SetScript("OnEscapePressed", function(self) self:Hide() end)
  frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background.blp",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    insets   = { top = 12, right = 12, bottom = 11, left = 11 }
  })

  -- container frame dragging
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

  -- title
  -- frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  -- frame.title:SetPoint("TOP", frame,  "TOP", 20, -17)
  -- frame.title:SetText("Craft")

  -- frame.title = frame:CreateTitleRegion()
  -- frame.title:SetHeight(20)
  -- frame.title:SetWidth(1000)
  -- frame.title:SetAnchor("TOP")

  -- search box
  frame.search_box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  frame.search_box:SetWidth(200)
  frame.search_box:SetHeight(24)
  frame.search_box:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -20)
  frame.search_box:SetScript("OnEscapePressed", CloseAuctionHouse)
  frame.search_box:SetText("cardinal ruby")

  -- search button
  frame.search_button = CreateFrame("Button", nil, frame, "OptionsButtonTemplate")
  frame.search_button:SetWidth(100)
  frame.search_button:SetHeight(24)
  frame.search_button:SetPoint("TOPLEFT", frame.search_box, "TOPRIGHT", 10, 0)
  frame.search_button:SetText("Search")
  frame.search_button:SetScript("OnClick", function()
    Craft:SearchAuctionHouse(frame.search_box:GetText())
  end)

  -- scan button
  frame.scan_button = CreateFrame("Button", nil, frame, "OptionsButtonTemplate")
  frame.scan_button:SetWidth(80)
  frame.scan_button:SetHeight(24)
  frame.scan_button:SetPoint("TOPLEFT", frame.search_button, "TOPRIGHT", 10, 0)
  frame.scan_button:SetText("Scan")

  -- auction results
  frame.auction = CreateFrame("Frame", nil, frame)
  frame.auction:SetPoint("TOPLEFT", frame.search_box, "BOTTOMLEFT", -6, -10)
  frame.auction:SetPoint("TOPRIGHT", frame.scan_button, "BOTTOMRIGHT", 0, -10)
  frame.auction:SetPoint("BOTTOM", frame, "BOTTOM", 0, 21)
  frame.auction:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark.blp",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
  })
  frame.auction.results = CreateFrame("ScrollFrame", nil, frame.auction)
  frame.auction.results:SetVerticalScroll(0)
  frame.auction.results:EnableMouse(true)
  frame.auction.results:EnableMouseWheel(true)
  frame.auction.results:SetPoint("TOPLEFT", frame.auction, "TOPLEFT", 10, -10)
  frame.auction.results:SetPoint("BOTTOMRIGHT", frame.auction, "BOTTOMRIGHT", -4, 10)
  frame.auction.results:SetScript("OnMouseWheel", function(self, delta)
    local scroll = self:GetVerticalScroll();
    scroll = scroll + (-1 * delta * 22)
    if scroll < 0 then scroll = 0 end
    if scroll > self:GetVerticalScrollRange() then scroll = self:GetVerticalScrollRange() end
    self:SetVerticalScroll(scroll)
  end)

  return(frame)
end

local function FormatMoney(money)
  local g = math.floor(money / 10000)
  local s = math.floor(money % 10000 / 100)
  local c = math.floor(money % 100)
  if g > 0 then
    return string.format("|cffffd700%d|r.|cffc7c7cf%02d|r.|cffeda55f%02d|r", g, s, c)
  elseif s > 0 then
    return string.format("|cffc7c7cf%d|r.|cffeda55f%02d|r", s, c)
  else
    return string.format("|cffc7c7cf0|r.|cffeda55f%02d|r", c)
  end
end

-- EVENTS ####################################################################

function Craft:RegisterEvents()
  self:RegisterEvent("AUCTION_HOUSE_SHOW")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
end

function Craft:AUCTION_HOUSE_SHOW()
  HideBlizzardFrame(AuctionFrame)
  self:ShowFrame()
end

function Craft:AUCTION_HOUSE_CLOSED()
  self:HideFrame()
end

function Craft:AUCTION_ITEM_LIST_UPDATE()
  self.frame.auction.results:SetVerticalScroll(0)

  local results = self.frame.auction.results;

  if not results.container then
    results.container = CreateFrame("Frame", nil, self.frame.auction.results)
    results.container:SetWidth(results:GetWidth() - 6)
    results.container.rows = {}
  end

  results.container:SetHeight(0)

  for i = 1, #results.container.rows do
    results.container.rows[i]:Hide()
  end

  local prices = {}

  for i = 1, GetNumAuctionItems("list") do
    name, texture, count, quality, canUse, level,
      minBid, minIncrement, buyoutPrice, bidAmount,
      highBidder, owner, saleStatus = GetAuctionItemInfo("list", i);

    local row = results.container.rows[i]

    if not row then
      results.container.rows[i] = CreateFrame("Frame", nil, results.container)
      row = results.container.rows[i]

      row.icon = CreateFrame("Frame", nil, row)
      row.icon:SetHeight(16)
      row.icon:SetWidth(16)
      row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
      row.icon.texture = row.icon:CreateTexture()
      row.icon.texture:SetAllPoints(row.icon)

      row.description = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.description:SetWidth(300)
      row.description:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.description:SetJustifyH("LEFT")
      row.description:SetJustifyV("MIDDLE")

      row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.price:SetWidth(80)
      row.price:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.price:SetJustifyH("RIGHT")
      row.price:SetJustifyV("MIDDLE")

      row.quantity = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.quantity:SetWidth(50)
      row.quantity:SetPoint("RIGHT", row.price, "LEFT", -6, 0)
      row.quantity:SetJustifyH("RIGHT")
      row.quantity:SetJustifyV("MIDDLE")
      row.quantity:SetTextColor(0.9, 0.9, 0.9)

      row:EnableMouse(true)

      row.texture = row:CreateTexture()
      row.texture:SetAllPoints(row)
      row.texture:SetTexture(0, 0, 0, 1.0)

      row:SetScript("OnMouseDown", function(self, button)
        self.texture:SetTexture(0.3, 0.3, 0.3)
      end)

      row:SetPoint("LEFT", results.container, "LEFT")
      row:SetPoint("RIGHT", results.container, "RIGHT")
      row:SetHeight(22)
    end

    local r, g, b = GetItemQualityColor(quality)
    row.description:SetTextColor(r, g, b)

    row.icon.texture:SetTexture(texture)
    row.description:SetText(name)
    row.price:SetText(FormatMoney(buyoutPrice))
    row.quantity:SetText(count)

    results.container.rows[i] = row
    prices[i] = { index = i, price = buyoutPrice }
  end
  
  table.sort(prices, function(a, b) return a.price < b.price end)
  
  local previous = nil

  for _, price in pairs(prices) do
    local row = results.container.rows[price.index]

    if not previous then
      row:SetPoint("TOP", results.container, "TOP")
    else
      row:SetPoint("TOP", previous, "BOTTOM")
    end

    row:Show()

    results.container:SetHeight(results.container:GetHeight() + row:GetHeight())
    previous = row
  end

  self:Print("setting scroll child")
  results:SetScrollChild(results.container)
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

-- AUCTIONS ##################################################################

function Craft:SearchAuctionHouse(term)
  QueryAuctionItems(term)
end
