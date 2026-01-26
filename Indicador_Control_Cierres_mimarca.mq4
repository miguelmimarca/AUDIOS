//+------------------------------------------------------------------+
//|                       Indicador_Control_Cierres_mimarca.mq4       |
//|              Indicador de control de cierres virtuales           |
//|                                             Copyright 2024       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

input int MagicNumberOperador = 12345;  // Magic Number del EA operador
input string ControlPrefix = "ControlCierres_"; // Prefijo para variables globales

input double DefaultPartial1Percent = 50.0;
input double DefaultPartial2Percent = 30.0;

input color LineColorSL = clrRed;
input color LineColorTP = clrGreen;
input color LineColorPL1 = clrYellow;
input color LineColorPL2 = clrOrange;
input color LineColorBE = clrAqua;

string buttonOrder = "CC_BtnOrder";
string buttonSL = "CC_BtnSL";
string buttonTP = "CC_BtnTP";
string buttonP1 = "CC_BtnP1";
string buttonP2 = "CC_BtnP2";
string buttonBEDirect = "CC_BtnBEDirect";
string buttonBELine = "CC_BtnBELine";
string labelTicket = "CC_LabelTicket";

color orderColors[] = {clrDodgerBlue, clrOrangeRed, clrMediumSeaGreen, clrViolet, clrGold, clrAqua, clrHotPink};

int selectedTicket = -1;

//+------------------------------------------------------------------+
//| Indicator initialization                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    CreateUI();
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Indicator calculation                                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    DeleteUI();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    CreateLinesForOrders();
    UpdateUIState();
}

//+------------------------------------------------------------------+
//| Chart events                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        HandleButtonClick(sparam);
    }

    if(id == CHARTEVENT_OBJECT_DRAG)
    {
        UpdateGlobalsFromLine(sparam);
    }

    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        UpdatePercentFromEdit(sparam);
    }
}

//+------------------------------------------------------------------+
//| UI                                                                 |
//+------------------------------------------------------------------+
void CreateUI()
{
    int baseX = 710;
    int y = 5;
    int w = 40;
    int h = 18;
    int gap = 5;

    CreateButton(buttonOrder, baseX, y, w + 15, h, "ORD");
    CreateButton(buttonSL, baseX + (w + gap) * 2, y, w, h, "SL");
    CreateButton(buttonTP, baseX + (w + gap) * 3, y, w, h, "TP");
    CreateButton(buttonP1, baseX + (w + gap) * 4, y, w, h, "P1");
    CreateButton(buttonP2, baseX + (w + gap) * 5, y, w, h, "P2");
    CreateButton(buttonBEDirect, baseX + (w + gap) * 6, y, w, h, "BE+");
    CreateButton(buttonBELine, baseX + (w + gap) * 7, y, w + 5, h, "BE L");

    ObjectCreate(0, labelTicket, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, labelTicket, OBJPROP_XDISTANCE, baseX);
    ObjectSetInteger(0, labelTicket, OBJPROP_YDISTANCE, y + h + 5);
    ObjectSetInteger(0, labelTicket, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, labelTicket, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelTicket, OBJPROP_TEXT, "Ticket: -");
}

void DeleteUI()
{
    ObjectDelete(0, buttonOrder);
    ObjectDelete(0, buttonSL);
    ObjectDelete(0, buttonTP);
    ObjectDelete(0, buttonP1);
    ObjectDelete(0, buttonP2);
    ObjectDelete(0, buttonBEDirect);
    ObjectDelete(0, buttonBELine);
    ObjectDelete(0, labelTicket);
}

//+------------------------------------------------------------------+
//| Crear líneas para órdenes abiertas                                |
//+------------------------------------------------------------------+
void CreateLinesForOrders()
{
    int totalOrders = OrdersTotal();
    int ordersFound = 0;
    int tickets[];

    ArrayResize(tickets, 0);

    for(int i = 0; i < totalOrders; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

        if(OrderSymbol() != Symbol())
            continue;

        if(OrderMagicNumber() != MagicNumberOperador)
            continue;

        int ticket = OrderTicket();
        int orderType = OrderType();
        double entry = OrderOpenPrice();
        double brokerSL = OrderStopLoss();
        double brokerTP = OrderTakeProfit();

        ArrayResize(tickets, ordersFound + 1);
        tickets[ordersFound] = ticket;
        ordersFound++;

        if(brokerTP == 0)
        {
            WarnMissingTP(ticket);
        }

        string slLine = LineName(ticket, "SL");
        string tpLine = LineName(ticket, "TP");
        string pl1Line = LineName(ticket, "PL1");
        string pl2Line = LineName(ticket, "PL2");
        string beLine = LineName(ticket, "BE");
        string pl1Label = LineName(ticket, "PL1PCT");
        string pl2Label = LineName(ticket, "PL2PCT");

        color orderColor = GetOrderColor(ticket);

        EnsureActionLine(ticket, "SLActive", "SL", slLine, brokerSL, orderColor, STYLE_SOLID);
        EnsureActionLine(ticket, "TPActive", "TP", tpLine, brokerTP, orderColor, STYLE_SOLID);
        EnsureActionLine(ticket, "P1Active", "PL1", pl1Line, brokerTP, orderColor, STYLE_DOT);
        EnsureActionLine(ticket, "P2Active", "PL2", pl2Line, brokerTP, orderColor, STYLE_DOT);
        EnsureActionLine(ticket, "BELActive", "BE", beLine, brokerTP, orderColor, STYLE_DASH);

        EnsurePercentLabel(ticket, pl1Label, "PL1Pct", orderColor);
        EnsurePercentLabel(ticket, pl2Label, "PL2Pct", orderColor);
    }

    UpdateSelectedTicket(tickets, ordersFound);
}

//+------------------------------------------------------------------+
//| Utilidades                                                        |
//+------------------------------------------------------------------+
string LineName(int ticket, string suffix)
{
    return "CC_" + Symbol() + "_" + IntegerToString(ticket) + "_" + suffix;
}

string ControlKey(int ticket, string suffix)
{
    return ControlPrefix + Symbol() + "_" + IntegerToString(ticket) + "_" + suffix;
}

void CreateButton(string name, int x, int y, int w, int h, string text)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDimGray);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
}

color GetOrderColor(int ticket)
{
    int idx = ticket % ArraySize(orderColors);
    return orderColors[idx];
}

void WarnMissingTP(int ticket)
{
    string warnKey = ControlKey(ticket, "TPWarned");
    if(!GlobalVariableCheck(warnKey))
    {
        GlobalVariableSet(warnKey, 1);
        Print("Advertencia: la orden #", ticket, " no tiene TP en el broker.");
        Alert("Advertencia: la orden #", ticket, " no tiene TP en el broker.");
    }
}

void UpdateGlobalsFromLine(string lineName)
{
    if(ObjectFind(0, lineName) < 0)
        return;

    double price = ObjectGetDouble(0, lineName, OBJPROP_PRICE);

    int symbolPos = StringFind(lineName, Symbol() + "_");
    if(symbolPos < 0)
        return;

    int ticketStart = symbolPos + StringLen(Symbol()) + 1;
    int suffixPos = StringFind(lineName, "_", ticketStart);
    if(suffixPos < 0)
        return;

    string ticketStr = StringSubstr(lineName, ticketStart, suffixPos - ticketStart);
    int ticket = (int)StringToInteger(ticketStr);

    string suffix = StringSubstr(lineName, suffixPos + 1);
    if(suffix == "SL" || suffix == "TP" || suffix == "PL1" || suffix == "PL2" || suffix == "BE")
        GlobalVariableSet(ControlKey(ticket, suffix), price);
}

void UpdatePercentFromEdit(string objectName)
{
    if(ObjectFind(0, objectName) < 0)
        return;

    if(StringFind(objectName, "PL1PCT") < 0 && StringFind(objectName, "PL2PCT") < 0)
        return;

    string text = ObjectGetString(0, objectName, OBJPROP_TEXT);
    double percent = StringToDouble(text);
    if(percent <= 0)
        return;

    int symbolPos = StringFind(objectName, Symbol() + "_");
    if(symbolPos < 0)
        return;

    int ticketStart = symbolPos + StringLen(Symbol()) + 1;
    int suffixPos = StringFind(objectName, "_", ticketStart);
    if(suffixPos < 0)
        return;

    string ticketStr = StringSubstr(objectName, ticketStart, suffixPos - ticketStart);
    int ticket = (int)StringToInteger(ticketStr);
    string suffix = StringSubstr(objectName, suffixPos + 1);

    if(suffix == "PL1PCT")
        GlobalVariableSet(ControlKey(ticket, "PL1Pct"), percent);
    else if(suffix == "PL2PCT")
        GlobalVariableSet(ControlKey(ticket, "PL2Pct"), percent);
}

void UpdateSelectedTicket(int &tickets[], int total)
{
    if(total <= 0)
    {
        selectedTicket = -1;
        ObjectSetString(0, labelTicket, OBJPROP_TEXT, "Ticket: -");
        return;
    }

    if(selectedTicket == -1)
        selectedTicket = tickets[0];

    bool found = false;
    for(int i = 0; i < total; i++)
    {
        if(tickets[i] == selectedTicket)
        {
            found = true;
            break;
        }
    }

    if(!found)
        selectedTicket = tickets[0];

    ObjectSetString(0, labelTicket, OBJPROP_TEXT, "Ticket: #" + IntegerToString(selectedTicket));
}

void UpdateUIState()
{
    int totalOrders = CountOrders();
    bool multi = totalOrders > 1;

    ObjectSetInteger(0, buttonOrder, OBJPROP_BGCOLOR, multi ? clrDimGray : clrDarkSlateGray);
    ObjectSetInteger(0, buttonOrder, OBJPROP_COLOR, clrWhite);

    if(selectedTicket <= 0)
        return;

    UpdateActionButton(buttonSL, ControlKey(selectedTicket, "SLActive"));
    UpdateActionButton(buttonTP, ControlKey(selectedTicket, "TPActive"));
    UpdateActionButton(buttonP1, ControlKey(selectedTicket, "P1Active"));
    UpdateActionButton(buttonP2, ControlKey(selectedTicket, "P2Active"));
    UpdateActionButton(buttonBELine, ControlKey(selectedTicket, "BELActive"));
}

void UpdateActionButton(string buttonName, string activeKey)
{
    bool active = GlobalVariableCheck(activeKey) && GlobalVariableGet(activeKey) > 0;
    ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, active ? clrGreen : clrDimGray);
    ObjectSetInteger(0, buttonName, OBJPROP_COLOR, clrWhite);
}

int CountOrders()
{
    int totalOrders = OrdersTotal();
    int count = 0;
    for(int i = 0; i < totalOrders; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderSymbol() != Symbol())
            continue;
        if(OrderMagicNumber() != MagicNumberOperador)
            continue;
        count++;
    }
    return count;
}

void HandleButtonClick(string name)
{
    if(name == buttonOrder)
    {
        RotateSelectedTicket();
        ObjectSetInteger(0, buttonOrder, OBJPROP_STATE, false);
        return;
    }

    if(selectedTicket <= 0)
        return;

    if(name == buttonSL)
        ToggleAction(selectedTicket, "SL", "SLActive");
    else if(name == buttonTP)
        ToggleAction(selectedTicket, "TP", "TPActive");
    else if(name == buttonP1)
        ToggleAction(selectedTicket, "PL1", "P1Active");
    else if(name == buttonP2)
        ToggleAction(selectedTicket, "PL2", "P2Active");
    else if(name == buttonBELine)
        ToggleAction(selectedTicket, "BE", "BELActive");
    else if(name == buttonBEDirect)
        ApplyDirectBreakeven(selectedTicket);

    ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void RotateSelectedTicket()
{
    int totalOrders = OrdersTotal();
    int tickets[];
    int count = 0;
    ArrayResize(tickets, 0);

    for(int i = 0; i < totalOrders; i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
        if(OrderSymbol() != Symbol())
            continue;
        if(OrderMagicNumber() != MagicNumberOperador)
            continue;
        ArrayResize(tickets, count + 1);
        tickets[count] = OrderTicket();
        count++;
    }

    if(count <= 1)
        return;

    int nextIndex = 0;
    for(int i = 0; i < count; i++)
    {
        if(tickets[i] == selectedTicket)
        {
            nextIndex = (i + 1) % count;
            break;
        }
    }

    selectedTicket = tickets[nextIndex];
    ObjectSetString(0, labelTicket, OBJPROP_TEXT, "Ticket: #" + IntegerToString(selectedTicket));
}

void ToggleAction(int ticket, string lineSuffix, string activeSuffix)
{
    string activeKey = ControlKey(ticket, activeSuffix);
    bool active = GlobalVariableCheck(activeKey) && GlobalVariableGet(activeKey) > 0;

    if(active)
    {
        GlobalVariableDel(activeKey);
        DeleteLine(ticket, lineSuffix);
        DeleteLine(ticket, lineSuffix + "PCT");
        GlobalVariableDel(ControlKey(ticket, lineSuffix));
        return;
    }

    if(!OrderSelectByTicket(ticket))
        return;

    double basePrice = 0;
    if(lineSuffix == "SL")
        basePrice = OrderStopLoss();
    else
        basePrice = OrderTakeProfit();

    if(basePrice == 0 && (lineSuffix == "TP" || lineSuffix == "PL1" || lineSuffix == "PL2" || lineSuffix == "BE"))
    {
        WarnMissingTP(ticket);
        return;
    }

    color orderColor = GetOrderColor(ticket);
    string lineName = LineName(ticket, lineSuffix);
    int style = (lineSuffix == "SL" || lineSuffix == "TP") ? STYLE_SOLID : STYLE_DOT;
    if(lineSuffix == "BE")
        style = STYLE_DASH;

    CreateLine(lineName, basePrice, orderColor, style);
    GlobalVariableSet(ControlKey(ticket, lineSuffix), basePrice);
    GlobalVariableSet(activeKey, 1);

    if(lineSuffix == "PL1" || lineSuffix == "PL2")
    {
        string pctName = LineName(ticket, lineSuffix + "PCT");
        EnsurePercentLabel(ticket, pctName, lineSuffix + "Pct", orderColor);
    }
}

bool OrderSelectByTicket(int ticket)
{
    return OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
}

void ApplyDirectBreakeven(int ticket)
{
    if(!OrderSelectByTicket(ticket))
        return;

    double entry = OrderOpenPrice();
    if(entry <= 0)
        return;

    GlobalVariableSet(ControlKey(ticket, "SL"), entry);
    GlobalVariableSet(ControlKey(ticket, "SLActive"), 1);
    CreateLine(LineName(ticket, "SL"), entry, GetOrderColor(ticket), STYLE_SOLID);
}

void EnsureActionLine(int ticket, string activeSuffix, string priceSuffix, string lineName, double brokerPrice, color orderColor, int style)
{
    string activeKey = ControlKey(ticket, activeSuffix);
    bool active = GlobalVariableCheck(activeKey) && GlobalVariableGet(activeKey) > 0;

    if(!active)
        return;

    double price = brokerPrice;
    string priceKey = ControlKey(ticket, priceSuffix);
    if(GlobalVariableCheck(priceKey))
        price = GlobalVariableGet(priceKey);

    if(price <= 0)
        price = brokerPrice;

    if(price <= 0)
        return;

    CreateLine(lineName, price, orderColor, style);
}

void CreateLine(string name, double price, color lineColor, int style)
{
    if(ObjectFind(0, name) >= 0)
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
        return;
    }

    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_RAY, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
}

void DeleteLine(int ticket, string suffix)
{
    ObjectDelete(0, LineName(ticket, suffix));
}

void EnsurePercentLabel(int ticket, string name, string percentKeySuffix, color orderColor)
{
    string percentKey = ControlKey(ticket, percentKeySuffix);
    double pct = DefaultPartial1Percent;
    if(percentKeySuffix == "PL2Pct")
        pct = DefaultPartial2Percent;

    if(GlobalVariableCheck(percentKey))
        pct = GlobalVariableGet(percentKey);

    double price = 0;
    string lineSuffix = (percentKeySuffix == "PL1Pct") ? "PL1" : "PL2";
    string lineName = LineName(ticket, lineSuffix);
    if(ObjectFind(0, lineName) >= 0)
        price = ObjectGetDouble(0, lineName, OBJPROP_PRICE);

    if(price <= 0)
        return;

    CreateOrUpdatePercentEdit(name, pct, price, orderColor);
}

void CreateOrUpdatePercentEdit(string name, double pct, double price, color orderColor)
{
    int x = 10;
    int y = 10;
    datetime t = TimeCurrent();
    if(!ChartTimePriceToXY(0, 0, t, price, x, y))
        return;

    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, 45);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 16);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, orderColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_READONLY, false);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 8);
    ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(pct, 1));
}
