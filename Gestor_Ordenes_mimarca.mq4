//+------------------------------------------------------------------+
//|                                    Gestor_Ordenes_mimarca.mq4     |
//|                       Gestor de órdenes con TP/SL locales         |
//|                                             Copyright 2024          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property strict

// MagicNumber del EA anterior para identificar las órdenes
input int MagicNumberOperador = 12345;  // Magic Number del operador original
input int MagicNumberGestor = 54321;    // Magic Number para ordenes del gestor
input string ControlPrefix = "ControlCierres_"; // Prefijo para variables globales del indicador
input double DefaultPartial1Qty = 50.0;  // % cierre parcial 1 (por defecto)
input double DefaultPartial2Qty = 30.0;  // % cierre parcial 2 (por defecto)

// Variables para la gestión
struct OrderInfo
{
    int ticket;
    int type;           // OP_BUY o OP_SELL
    string symbol;
    double entryPrice;
    double brokerSL;    // SL del broker (red de seguridad)
    double brokerTP;    // TP del broker (red de seguridad)
    double localSL;     // SL local (gestionado por el EA)
    double localTP;     // TP local (gestionado por el EA)
    double partialLevel1;    // Nivel de cierre parcial 1
    double partialLevel2;    // Nivel de cierre parcial 2
    double partialQty1;      // Cantidad a cerrar en nivel 1 (%)
    double partialQty2;      // Cantidad a cerrar en nivel 2 (%)
    bool partial1Closed;     // Flag para cierre parcial 1
    bool partial2Closed;     // Flag para cierre parcial 2
    double breakevenLevel;   // Nivel para activar breakeven
    bool breakevenApplied;   // Flag de breakeven aplicado
    bool breakevenLineActive; // BE por nivel activo
    double openVolume;       // Volumen actual abierto
    datetime openTime;
};

OrderInfo orders[];
int ordersCount = 0;

// Variables UI
string buttonCloseAll = "BtnCloseAll";
string buttonRefresh = "BtnRefresh";
string panelLabel = "PanelInfo";
string panelTotal = "PanelTotal";

int panelStartX = 10;
int panelStartY = 40;
int rowHeight = 18;
int colGap = 14;
#define COLUMN_COUNT 12
int colWidths[] = {240, 110, 110, 110, 90, 90, 80, 60, 80, 60, 85, 40};
int colX[COLUMN_COUNT];
string headerTitles[] = {"Ticket/Símbolo", "Entry", "SLb", "TPb", "SLv", "TPv", "PL1", "%1", "PL2", "%2", "BE", "BE+"};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    CreateUI();
    RefreshOrders();
    EventSetTimer(1);  // Timer cada 1 segundo
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Monitorear y ejecutar cierres
    ManageOrders();
}

//+------------------------------------------------------------------+
//| OnTimer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Refrescar información cada segundo
    UpdatePanelInfo();
}

//+------------------------------------------------------------------+
//| Chart Events                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == buttonCloseAll)
        {
            CloseAllOrders();
            ObjectSetInteger(0, buttonCloseAll, OBJPROP_STATE, false);
        }
        else if(sparam == buttonRefresh)
        {
            RefreshOrders();
            ObjectSetInteger(0, buttonRefresh, OBJPROP_STATE, false);
        }
    }

    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "GO_BE_") == 0)
        {
            int ticket = (int)StringToInteger(StringSubstr(sparam, StringLen("GO_BE_")));
            ApplyDirectBreakevenByTicket(ticket);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
    }

    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        HandlePanelEdit(sparam);
    }
}

//+------------------------------------------------------------------+
//| Crear UI                                                          |
//+------------------------------------------------------------------+
void CreateUI()
{
    ComputeColumnPositions();

    // Botón Cerrar Todo
    ObjectCreate(0, buttonCloseAll, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_XSIZE, 80);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_YSIZE, 20);
    ObjectSetString(0, buttonCloseAll, OBJPROP_TEXT, "Cerrar Todo");
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, buttonCloseAll, OBJPROP_FONTSIZE, 8);
    
    // Botón Refrescar
    ObjectCreate(0, buttonRefresh, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_XDISTANCE, 100);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_XSIZE, 80);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_YSIZE, 20);
    ObjectSetString(0, buttonRefresh, OBJPROP_TEXT, "Refrescar");
    ObjectSetInteger(0, buttonRefresh, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_BGCOLOR, clrBlue);
    ObjectSetInteger(0, buttonRefresh, OBJPROP_FONTSIZE, 8);
    
    UpdatePanelHeader();

    // Total P&L
    ObjectCreate(0, panelTotal, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, panelTotal, OBJPROP_XDISTANCE, panelStartX);
    ObjectSetInteger(0, panelTotal, OBJPROP_YDISTANCE, panelStartY + rowHeight);
    ObjectSetInteger(0, panelTotal, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, panelTotal, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, panelTotal, OBJPROP_TEXT, "P&L Total: 0.00");
}

//+------------------------------------------------------------------+
//| Refrescar órdenes abiertas                                        |
//+------------------------------------------------------------------+
void RefreshOrders()
{
    // Limpiar array anterior
    ArrayResize(orders, 0);
    ordersCount = 0;
    
    // Buscar todas las órdenes abiertas
    int totalOrders = OrdersTotal();
    
    Print("========================================");
    Print("BÚSQUEDA DE ÓRDENES");
    Print("Total órdenes abiertas en el broker: ", totalOrders);
    Print("Símbolo actual: ", Symbol());
    Print("Magic Number buscado: ", MagicNumberOperador);
    Print("========================================");
    
    for(int i = 0; i < totalOrders; i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            Print("Orden ", i, ": Ticket=", OrderTicket(), " Symbol=", OrderSymbol(), 
                  " Magic=", OrderMagicNumber(), " Type=", OrderType(), " Entry=", OrderOpenPrice());
            
            ArrayResize(orders, ordersCount + 1);
                
                orders[ordersCount].ticket = OrderTicket();
                orders[ordersCount].type = OrderType();
                orders[ordersCount].symbol = OrderSymbol();
                orders[ordersCount].entryPrice = OrderOpenPrice();
                orders[ordersCount].brokerSL = OrderStopLoss();
                orders[ordersCount].brokerTP = OrderTakeProfit();
                orders[ordersCount].openVolume = OrderLots();
                orders[ordersCount].openTime = OrderOpenTime();
                
                // Inicializar SL/TP locales iguales a los del broker
                orders[ordersCount].localSL = OrderStopLoss();
                orders[ordersCount].localTP = OrderTakeProfit();
                
                // Inicializar cierres parciales
                orders[ordersCount].partialLevel1 = 0;
                orders[ordersCount].partialLevel2 = 0;
                orders[ordersCount].partialQty1 = DefaultPartial1Qty;
                orders[ordersCount].partialQty2 = DefaultPartial2Qty;
                orders[ordersCount].partial1Closed = false;
                orders[ordersCount].partial2Closed = false;
                orders[ordersCount].breakevenLevel = 0;
                orders[ordersCount].breakevenApplied = false;
                orders[ordersCount].breakevenLineActive = false;
                
                Print(">>> ORDEN DETECTADA Y AGREGADA: Ticket=", orders[ordersCount].ticket);
                
                ordersCount++;
        }
    }
    
    Print("========================================");
    Print("Órdenes encontradas y agregadas: ", ordersCount);
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Obtener clave de control                                           |
//+------------------------------------------------------------------+
string ControlKey(string orderSymbol, int ticket, string suffix)
{
    return ControlPrefix + orderSymbol + "_" + IntegerToString(ticket) + "_" + suffix;
}

//+------------------------------------------------------------------+
//| Cargar niveles desde variables globales                           |
//+------------------------------------------------------------------+
void LoadControlLevels(int idx)
{
    int ticket = orders[idx].ticket;
    string orderSymbol = orders[idx].symbol;

    string slKey = ControlKey(orderSymbol, ticket, "SL");
    string tpKey = ControlKey(orderSymbol, ticket, "TP");
    string pl1Key = ControlKey(orderSymbol, ticket, "PL1");
    string pl2Key = ControlKey(orderSymbol, ticket, "PL2");
    string pl1PctKey = ControlKey(orderSymbol, ticket, "PL1Pct");
    string pl2PctKey = ControlKey(orderSymbol, ticket, "PL2Pct");
    string beKey = ControlKey(orderSymbol, ticket, "BE");
    string beActiveKey = ControlKey(orderSymbol, ticket, "BELActive");

    if(GlobalVariableCheck(slKey))
        orders[idx].localSL = GlobalVariableGet(slKey);
    if(GlobalVariableCheck(tpKey))
        orders[idx].localTP = GlobalVariableGet(tpKey);
    if(GlobalVariableCheck(pl1Key))
        orders[idx].partialLevel1 = GlobalVariableGet(pl1Key);
    if(GlobalVariableCheck(pl2Key))
        orders[idx].partialLevel2 = GlobalVariableGet(pl2Key);
    if(GlobalVariableCheck(pl1PctKey))
        orders[idx].partialQty1 = GlobalVariableGet(pl1PctKey);
    if(GlobalVariableCheck(pl2PctKey))
        orders[idx].partialQty2 = GlobalVariableGet(pl2PctKey);
    if(GlobalVariableCheck(beKey))
        orders[idx].breakevenLevel = GlobalVariableGet(beKey);
    orders[idx].breakevenLineActive = GlobalVariableCheck(beActiveKey) && GlobalVariableGet(beActiveKey) > 0;
}

//+------------------------------------------------------------------+
//| Gestionar órdenes - verificar cierres                            |
//+------------------------------------------------------------------+
void ManageOrders()
{
    for(int i = 0; i < ordersCount; i++)
    {
        if(!OrderSelect(orders[i].ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
            // Orden cerrada, eliminar del array
            continue;
        }

        LoadControlLevels(i);
        
        double ask = MarketInfo(orders[i].symbol, MODE_ASK);
        double bid = MarketInfo(orders[i].symbol, MODE_BID);
        double currentPrice = (orders[i].type == OP_BUY) ? bid : ask;

        if(orders[i].breakevenLineActive && orders[i].breakevenLevel > 0 && !orders[i].breakevenApplied)
        {
            if((orders[i].type == OP_BUY && currentPrice >= orders[i].breakevenLevel) ||
               (orders[i].type == OP_SELL && currentPrice <= orders[i].breakevenLevel))
            {
                ApplyBreakeven(i);
                orders[i].breakevenApplied = true;
            }
        }
        
        // Verificar SL local
        if(orders[i].type == OP_BUY && currentPrice <= orders[i].localSL)
        {
            Print("SL alcanzado para orden #", orders[i].ticket);
            CloseOrder(i);
            continue;
        }
        
        if(orders[i].type == OP_SELL && currentPrice >= orders[i].localSL)
        {
            Print("SL alcanzado para orden #", orders[i].ticket);
            CloseOrder(i);
            continue;
        }
        
        // Verificar TP local
        if(orders[i].type == OP_BUY && currentPrice >= orders[i].localTP)
        {
            Print("TP alcanzado para orden #", orders[i].ticket);
            CloseOrder(i);
            continue;
        }
        
        if(orders[i].type == OP_SELL && currentPrice <= orders[i].localTP)
        {
            Print("TP alcanzado para orden #", orders[i].ticket);
            CloseOrder(i);
            continue;
        }
        
        // Verificar cierres parciales
        if(orders[i].partialLevel1 > 0 && !orders[i].partial1Closed)
        {
            if(orders[i].type == OP_BUY && currentPrice >= orders[i].partialLevel1)
            {
                ClosePartial(i, 1);
                orders[i].partial1Closed = true;
            }
            else if(orders[i].type == OP_SELL && currentPrice <= orders[i].partialLevel1)
            {
                ClosePartial(i, 1);
                orders[i].partial1Closed = true;
            }
        }
        
        if(orders[i].partialLevel2 > 0 && !orders[i].partial2Closed)
        {
            if(orders[i].type == OP_BUY && currentPrice >= orders[i].partialLevel2)
            {
                ClosePartial(i, 2);
                orders[i].partial2Closed = true;
            }
            else if(orders[i].type == OP_SELL && currentPrice <= orders[i].partialLevel2)
            {
                ClosePartial(i, 2);
                orders[i].partial2Closed = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Cerrar orden completa                                             |
//+------------------------------------------------------------------+
void CloseOrder(int idx)
{
    if(!OrderSelect(orders[idx].ticket, SELECT_BY_TICKET, MODE_TRADES))
        return;
    
    double closePrice = (orders[idx].type == OP_BUY) ? MarketInfo(orders[idx].symbol, MODE_BID) : MarketInfo(orders[idx].symbol, MODE_ASK);
    
    if(OrderClose(orders[idx].ticket, OrderLots(), closePrice, 3, clrNONE))
    {
        Print("Orden #", orders[idx].ticket, " cerrada a ", closePrice);
    }
    else
    {
        Print("Error cerrando orden #", orders[idx].ticket, " Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Cerrar orden parcial                                              |
//+------------------------------------------------------------------+
void ClosePartial(int idx, int level)
{
    if(!OrderSelect(orders[idx].ticket, SELECT_BY_TICKET, MODE_TRADES))
        return;
    
    double lot = OrderLots();
    double qtyPercent = (level == 1) ? orders[idx].partialQty1 : orders[idx].partialQty2;
    double qtyToClose = lot * (qtyPercent / 100.0);
    
    double closePrice = (orders[idx].type == OP_BUY) ? MarketInfo(orders[idx].symbol, MODE_BID) : MarketInfo(orders[idx].symbol, MODE_ASK);
    
    bool closed = OrderClose(orders[idx].ticket, qtyToClose, closePrice, 3, clrNONE);
    
    if(closed)
    {
        Print("Cierre parcial ", level, " de orden #", orders[idx].ticket, " (", qtyPercent, "%) a ", closePrice);
    }
    else
    {
        Print("Error en cierre parcial - Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Cerrar todas las órdenes                                          |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
    for(int i = ordersCount - 1; i >= 0; i--)
    {
        if(OrderSelect(orders[i].ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
            double closePrice = (orders[i].type == OP_BUY) ? MarketInfo(orders[i].symbol, MODE_BID) : MarketInfo(orders[i].symbol, MODE_ASK);
            if(OrderClose(orders[i].ticket, OrderLots(), closePrice, 3, clrNONE))
            {
                Print("Orden #", orders[i].ticket, " cerrada en cierre total a ", closePrice);
            }
            else
            {
                Print("Error cerrando orden #", orders[i].ticket, " en cierre total - Error: ", GetLastError());
            }
        }
    }
    
    Print("Cierre total de todas las órdenes ejecutado");
    RefreshOrders();
}

//+------------------------------------------------------------------+
//| Aplicar Breakeven                                                 |
//+------------------------------------------------------------------+
void ApplyBreakeven(int idx)
{
    if(!OrderSelect(orders[idx].ticket, SELECT_BY_TICKET, MODE_TRADES))
        return;
    
    // Mover SL a la entrada con comisión mínima
    double breakevenPrice = OrderOpenPrice();
    
    if(orders[idx].type == OP_BUY)
    {
        breakevenPrice -= 0.0005 * _Point;  // Pequeña protección
    }
    else
    {
        breakevenPrice += 0.0005 * _Point;
    }
    
    orders[idx].localSL = breakevenPrice;
    
    Print("Breakeven aplicado a orden #", orders[idx].ticket, " a ", breakevenPrice);
}

void ApplyDirectBreakevenByTicket(int ticket)
{
    int idx = FindOrderIndex(ticket);
    if(idx < 0)
        return;

    if(!OrderSelect(orders[idx].ticket, SELECT_BY_TICKET, MODE_TRADES))
        return;

    double entry = OrderOpenPrice();
    if(entry <= 0)
        return;

    orders[idx].localSL = entry;
    GlobalVariableSet(ControlKey(orders[idx].symbol, orders[idx].ticket, "SL"), entry);
    GlobalVariableSet(ControlKey(orders[idx].symbol, orders[idx].ticket, "SLActive"), 1);
}

int FindOrderIndex(int ticket)
{
    for(int i = 0; i < ordersCount; i++)
    {
        if(orders[i].ticket == ticket)
            return i;
    }
    return -1;
}

bool IsBreakevenActive(OrderInfo &info)
{
    if(info.entryPrice == 0)
        return false;

    return MathAbs(info.localSL - info.entryPrice) <= (Point * 2);
}

string FormatValue(double value)
{
    if(value == 0)
        return "";
    return DoubleToString(value, _Digits);
}

string FormatPercent(double value)
{
    if(value == 0)
        return "";
    return DoubleToString(value, 1);
}

void EnsureLabel(string name, int x, int y, string text)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void EnsureReadOnlyEdit(string name, int x, int y, int width, string text)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 16);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrLightGray);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_READONLY, true);
        ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
        ObjectSetString(0, name, OBJPROP_TEXT, "");
    }
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void EnsureEdit(string name, int x, int y, int width, string text)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 16);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_READONLY, false);
        ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
        ObjectSetString(0, name, OBJPROP_TEXT, "");
    }
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void EnsureButton(string name, int x, int y, int w, int h, string text, bool active)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, active ? clrGreen : clrDimGray);
}

void CleanupPanelRows(int rowsUsed)
{
    int maxRows = 20;
    for(int i = rowsUsed; i < maxRows; i++)
    {
        int y = panelStartY + (rowHeight * (i + 2));
        string placeholder = "GO_PLACEHOLDER_" + IntegerToString(i);
        EnsureLabel(placeholder, panelStartX, y, "");
    }
}

void HandlePanelEdit(string name)
{
    if(StringFind(name, "GO_") != 0)
        return;

    int ticketPos = StringFind(name, "_", 3);
    if(ticketPos < 0)
        return;

    string suffix = StringSubstr(name, 3, ticketPos - 3);
    int ticket = (int)StringToInteger(StringSubstr(name, ticketPos + 1));
    int idx = FindOrderIndex(ticket);
    if(idx < 0)
        return;

    string text = ObjectGetString(0, name, OBJPROP_TEXT);
    double value = StringToDouble(text);
    string symbol = orders[idx].symbol;

    if(suffix == "SLV")
    {
        UpdateGlobalValue(symbol, ticket, "SL", "SLActive", value);
        orders[idx].localSL = value;
    }
    else if(suffix == "TPV")
    {
        UpdateGlobalValue(symbol, ticket, "TP", "TPActive", value);
        orders[idx].localTP = value;
    }
    else if(suffix == "PL1")
    {
        UpdateGlobalValue(symbol, ticket, "PL1", "P1Active", value);
        orders[idx].partialLevel1 = value;
    }
    else if(suffix == "PL2")
    {
        UpdateGlobalValue(symbol, ticket, "PL2", "P2Active", value);
        orders[idx].partialLevel2 = value;
    }
    else if(suffix == "PL1PCT")
    {
        UpdateGlobalValue(symbol, ticket, "PL1Pct", "", value);
        orders[idx].partialQty1 = value;
    }
    else if(suffix == "PL2PCT")
    {
        UpdateGlobalValue(symbol, ticket, "PL2Pct", "", value);
        orders[idx].partialQty2 = value;
    }
    else if(suffix == "BEL")
    {
        UpdateGlobalValue(symbol, ticket, "BE", "BELActive", value);
        orders[idx].breakevenLevel = value;
    }
}

void UpdateGlobalValue(string symbol, int ticket, string valueKey, string activeKey, double value)
{
    string key = ControlKey(symbol, ticket, valueKey);
    if(value <= 0)
    {
        GlobalVariableDel(key);
        if(activeKey != "")
            GlobalVariableDel(ControlKey(symbol, ticket, activeKey));
        return;
    }

    GlobalVariableSet(key, value);
    if(activeKey != "")
        GlobalVariableSet(ControlKey(symbol, ticket, activeKey), 1);
}

void ComputeColumnPositions()
{
    int runningX = panelStartX;
    for(int i = 0; i < COLUMN_COUNT; i++)
    {
        colX[i] = runningX;
        runningX += colWidths[i] + colGap;
    }
}

void UpdatePanelHeader()
{
    for(int i = 0; i < COLUMN_COUNT; i++)
    {
        string headerName = "PanelHeader_" + IntegerToString(i);
        int headerX = colX[i] + ((i == 0) ? 0 : 4);
        EnsureLabel(headerName, headerX, panelStartY, headerTitles[i]);
        ObjectSetInteger(0, headerName, OBJPROP_COLOR, clrWhite);
    }
}

//+------------------------------------------------------------------+
//| Actualizar panel de información                                   |
//+------------------------------------------------------------------+
void UpdatePanelInfo()
{
    double totalPL = 0;
    int row = 0;
    int rowY = panelStartY + (rowHeight * 2);
    ComputeColumnPositions();
    UpdatePanelHeader();

    for(int i = 0; i < ordersCount; i++)
    {
        if(!OrderSelect(orders[i].ticket, SELECT_BY_TICKET, MODE_TRADES))
            continue;

        double pl = OrderProfit() + OrderCommission() + OrderSwap();
        totalPL += pl;

        string typeStr = (orders[i].type == OP_BUY) ? "BUY" : "SELL";
        string labelName = "GO_LABEL_" + IntegerToString(orders[i].ticket);
        string labelText = IntegerToString(orders[i].ticket) + " " + orders[i].symbol + " " + typeStr;
        EnsureReadOnlyEdit(labelName, colX[0], rowY, colWidths[0], labelText);

        string entryName = "GO_ENTRY_" + IntegerToString(orders[i].ticket);
        EnsureReadOnlyEdit(entryName, colX[1], rowY, colWidths[1], DoubleToString(orders[i].entryPrice, _Digits));

        string slbName = "GO_SLB_" + IntegerToString(orders[i].ticket);
        EnsureReadOnlyEdit(slbName, colX[2], rowY, colWidths[2], DoubleToString(orders[i].brokerSL, _Digits));

        string tpbName = "GO_TPB_" + IntegerToString(orders[i].ticket);
        EnsureReadOnlyEdit(tpbName, colX[3], rowY, colWidths[3], DoubleToString(orders[i].brokerTP, _Digits));

        string symbol = orders[i].symbol;
        int ticket = orders[i].ticket;
        bool slActive = GlobalVariableCheck(ControlKey(symbol, ticket, "SLActive")) && GlobalVariableGet(ControlKey(symbol, ticket, "SLActive")) > 0;
        bool tpActive = GlobalVariableCheck(ControlKey(symbol, ticket, "TPActive")) && GlobalVariableGet(ControlKey(symbol, ticket, "TPActive")) > 0;
        bool p1Active = GlobalVariableCheck(ControlKey(symbol, ticket, "P1Active")) && GlobalVariableGet(ControlKey(symbol, ticket, "P1Active")) > 0;
        bool p2Active = GlobalVariableCheck(ControlKey(symbol, ticket, "P2Active")) && GlobalVariableGet(ControlKey(symbol, ticket, "P2Active")) > 0;
        bool beLineActive = GlobalVariableCheck(ControlKey(symbol, ticket, "BELActive")) && GlobalVariableGet(ControlKey(symbol, ticket, "BELActive")) > 0;

        string slvName = "GO_SLV_" + IntegerToString(orders[i].ticket);
        EnsureEdit(slvName, colX[4], rowY, colWidths[4], slActive ? DoubleToString(orders[i].localSL, _Digits) : "");

        string tpvName = "GO_TPV_" + IntegerToString(orders[i].ticket);
        EnsureEdit(tpvName, colX[5], rowY, colWidths[5], tpActive ? DoubleToString(orders[i].localTP, _Digits) : "");

        string pl1Name = "GO_PL1_" + IntegerToString(orders[i].ticket);
        EnsureEdit(pl1Name, colX[6], rowY, colWidths[6], p1Active ? FormatValue(orders[i].partialLevel1) : "");

        string pl1pctName = "GO_PL1PCT_" + IntegerToString(orders[i].ticket);
        EnsureEdit(pl1pctName, colX[7], rowY, colWidths[7], p1Active ? FormatPercent(orders[i].partialQty1) : "");

        string pl2Name = "GO_PL2_" + IntegerToString(orders[i].ticket);
        EnsureEdit(pl2Name, colX[8], rowY, colWidths[8], p2Active ? FormatValue(orders[i].partialLevel2) : "");

        string pl2pctName = "GO_PL2PCT_" + IntegerToString(orders[i].ticket);
        EnsureEdit(pl2pctName, colX[9], rowY, colWidths[9], p2Active ? FormatPercent(orders[i].partialQty2) : "");

        string beEditName = "GO_BEL_" + IntegerToString(orders[i].ticket);
        EnsureEdit(beEditName, colX[10], rowY, colWidths[10], beLineActive ? FormatValue(orders[i].breakevenLevel) : "");

        string beBtnName = "GO_BE_" + IntegerToString(orders[i].ticket);
        bool beActive = IsBreakevenActive(orders[i]);
        EnsureButton(beBtnName, colX[11], rowY - 2, 36, 16, "BE+", beActive);

        row++;
        rowY += rowHeight;
    }

    ObjectSetString(0, panelTotal, OBJPROP_TEXT, "P&L Total: " + DoubleToString(totalPL, 2));

    CleanupPanelRows(row);
}

//+------------------------------------------------------------------+

void DeleteAllObjects()
{
    ObjectDelete(0, buttonCloseAll);
    ObjectDelete(0, buttonRefresh);
    ObjectDelete(0, panelTotal);

    for(int i = 0; i < COLUMN_COUNT; i++)
    {
        string headerName = "PanelHeader_" + IntegerToString(i);
        ObjectDelete(0, headerName);
    }
}

