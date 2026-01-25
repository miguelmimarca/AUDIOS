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

// Variables para la gestión
struct OrderInfo
{
    int ticket;
    int type;           // OP_BUY o OP_SELL
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
    double openVolume;       // Volumen actual abierto
    datetime openTime;
    string lineSL;          // Nombre de la línea SL
    string lineTP;          // Nombre de la línea TP
    string linePL1;         // Nombre de la línea parcial 1
    string linePL2;         // Nombre de la línea parcial 2
};

OrderInfo orders[];
int ordersCount = 0;

// Variables para control de cierre parcial
double partialClose1Qty = 50.0;     // % a cerrar en nivel 1
double partialClose2Qty = 30.0;     // % a cerrar en nivel 2

// Variables UI
string buttonCloseAll = "BtnCloseAll";
string buttonRefresh = "BtnRefresh";
string panelLabel = "PanelInfo";

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
    
    // Detectar movimiento de líneas SL/TP
    if(id == CHARTEVENT_OBJECT_DRAG)
    {
        for(int i = 0; i < ordersCount; i++)
        {
            if(sparam == orders[i].lineSL)
            {
                orders[i].localSL = ObjectGetDouble(0, orders[i].lineSL, OBJPROP_PRICE);
            }
            else if(sparam == orders[i].lineTP)
            {
                orders[i].localTP = ObjectGetDouble(0, orders[i].lineTP, OBJPROP_PRICE);
            }
            else if(sparam == orders[i].linePL1)
            {
                orders[i].partialLevel1 = ObjectGetDouble(0, orders[i].linePL1, OBJPROP_PRICE);
            }
            else if(sparam == orders[i].linePL2)
            {
                orders[i].partialLevel2 = ObjectGetDouble(0, orders[i].linePL2, OBJPROP_PRICE);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Crear UI                                                          |
//+------------------------------------------------------------------+
void CreateUI()
{
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
    
    // Panel de información
    ObjectCreate(0, panelLabel, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, panelLabel, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, panelLabel, OBJPROP_YDISTANCE, 40);
    ObjectSetInteger(0, panelLabel, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, panelLabel, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, panelLabel, OBJPROP_TEXT, "Ordenes: 0");
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
            
            // Buscar órdenes del operador O cualquier orden del símbolo actual si está habilitado
            if(OrderSymbol() == Symbol())
            {
                ArrayResize(orders, ordersCount + 1);
                
                orders[ordersCount].ticket = OrderTicket();
                orders[ordersCount].type = OrderType();
                orders[ordersCount].entryPrice = OrderOpenPrice();
                orders[ordersCount].brokerSL = OrderStopLoss();
                orders[ordersCount].brokerTP = OrderTakeProfit();
                orders[ordersCount].openVolume = OrderOpenPrice();
                orders[ordersCount].openTime = OrderOpenTime();
                
                // Inicializar SL/TP locales iguales a los del broker
                orders[ordersCount].localSL = OrderStopLoss();
                orders[ordersCount].localTP = OrderTakeProfit();
                
                // Inicializar cierres parciales
                orders[ordersCount].partialLevel1 = 0;
                orders[ordersCount].partialLevel2 = 0;
                orders[ordersCount].partialQty1 = partialClose1Qty;
                orders[ordersCount].partialQty2 = partialClose2Qty;
                orders[ordersCount].partial1Closed = false;
                orders[ordersCount].partial2Closed = false;
                
                // Crear líneas en el gráfico
                CreateOrderLines(ordersCount);
                
                Print(">>> ORDEN DETECTADA Y AGREGADA: Ticket=", orders[ordersCount].ticket);
                
                ordersCount++;
            }
        }
    }
    
    Print("========================================");
    Print("Órdenes encontradas y agregadas: ", ordersCount);
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Crear líneas para una orden                                       |
//+------------------------------------------------------------------+
void CreateOrderLines(int idx)
{
    string basePrefix = "Order_" + IntegerToString(orders[idx].ticket) + "_";
    
    // Línea SL
    orders[idx].lineSL = basePrefix + "SL";
    if(ObjectFind(0, orders[idx].lineSL) < 0)
    {
        ObjectCreate(0, orders[idx].lineSL, OBJ_HLINE, 0, 0, orders[idx].localSL);
        ObjectSetInteger(0, orders[idx].lineSL, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, orders[idx].lineSL, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, orders[idx].lineSL, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    // Línea TP
    orders[idx].lineTP = basePrefix + "TP";
    if(ObjectFind(0, orders[idx].lineTP) < 0)
    {
        ObjectCreate(0, orders[idx].lineTP, OBJ_HLINE, 0, 0, orders[idx].localTP);
        ObjectSetInteger(0, orders[idx].lineTP, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, orders[idx].lineTP, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, orders[idx].lineTP, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    // Líneas de cierre parcial
    orders[idx].linePL1 = basePrefix + "PL1";
    orders[idx].linePL2 = basePrefix + "PL2";
    
    if(ObjectFind(0, orders[idx].linePL1) < 0&& orders[idx].partialLevel1 > 0)
    {
        ObjectCreate(0, orders[idx].linePL1, OBJ_HLINE, 0, 0, orders[idx].partialLevel1);
        ObjectSetInteger(0, orders[idx].linePL1, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, orders[idx].linePL1, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, orders[idx].linePL1, OBJPROP_STYLE, STYLE_DOT);
    }
    
    if(ObjectFind(0, orders[idx].linePL2) < 0 && orders[idx].partialLevel2 > 0)
    {
        ObjectCreate(0, orders[idx].linePL2, OBJ_HLINE, 0, 0, orders[idx].partialLevel2);
        ObjectSetInteger(0, orders[idx].linePL2, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, orders[idx].linePL2, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, orders[idx].linePL2, OBJPROP_STYLE, STYLE_DOT);
    }
}

//+------------------------------------------------------------------+
//| Gestionar órdenes - verificar cierres                            |
//+------------------------------------------------------------------+
void ManageOrders()
{
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double bid = MarketInfo(Symbol(), MODE_BID);
    
    for(int i = 0; i < ordersCount; i++)
    {
        if(!OrderSelect(orders[i].ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
            // Orden cerrada, eliminar del array
            DeleteOrderLines(i);
            continue;
        }
        
        double currentPrice = (orders[i].type == OP_BUY) ? bid : ask;
        
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
    
    double closePrice = (orders[idx].type == OP_BUY) ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK);
    
    if(OrderClose(orders[idx].ticket, OrderOpenPrice(), closePrice, 3, clrNONE))
    {
        Print("Orden #", orders[idx].ticket, " cerrada a ", closePrice);
        DeleteOrderLines(idx);
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
    
    double lot = OrderOpenPrice();
    double qtyPercent = (level == 1) ? orders[idx].partialQty1 : orders[idx].partialQty2;
    double qtyToClose = lot * (qtyPercent / 100.0);
    
    double closePrice = (orders[idx].type == OP_BUY) ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK);
    
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
            double closePrice = (orders[i].type == OP_BUY) ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK);
            if(OrderClose(orders[i].ticket, OrderOpenPrice(), closePrice, 3, clrNONE))
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
    ObjectSetDouble(0, orders[idx].lineSL, OBJPROP_PRICE, breakevenPrice);
    
    Print("Breakeven aplicado a orden #", orders[idx].ticket, " a ", breakevenPrice);
}

//+------------------------------------------------------------------+
//| Actualizar panel de información                                   |
//+------------------------------------------------------------------+
void UpdatePanelInfo()
{
    string info = "GESTOR DE ÓRDENES\n";
    info += "=================\n";
    info += "Órdenes abiertas: " + IntegerToString(ordersCount) + "\n";
    info += "\n";
    
    double totalPL = 0;
    
    for(int i = 0; i < ordersCount; i++)
    {
        if(OrderSelect(orders[i].ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
            double pl = OrderProfit() + OrderCommission() + OrderSwap();
            totalPL += pl;
            
            string typeStr = (orders[i].type == OP_BUY) ? "BUY" : "SELL";
            info += "Orden #" + IntegerToString(orders[i].ticket) + " (" + typeStr + ")\n";
            info += "  Entry: " + DoubleToString(OrderOpenPrice(), _Digits) + "\n";
            info += "  P&L: " + DoubleToString(pl, 2) + "$\n";
            info += "  SL: " + DoubleToString(orders[i].localSL, _Digits) + " (local)\n";
            info += "  TP: " + DoubleToString(orders[i].localTP, _Digits) + " (local)\n";
            info += "\n";
        }
    }
    
    info += "=================\n";
    info += "P&L Total: " + DoubleToString(totalPL, 2) + "$";
    
    ObjectSetString(0, panelLabel, OBJPROP_TEXT, info);
}

//+------------------------------------------------------------------+
//| Eliminar líneas de una orden                                      |
//+------------------------------------------------------------------+
void DeleteOrderLines(int idx)
{
    ObjectDelete(0, orders[idx].lineSL);
    ObjectDelete(0, orders[idx].lineTP);
    ObjectDelete(0, orders[idx].linePL1);
    ObjectDelete(0, orders[idx].linePL2);
}

//+------------------------------------------------------------------+
//| Eliminar todos los objetos                                        |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    ObjectsDeleteAll(0, OBJ_HLINE);
    ObjectsDeleteAll(0, OBJ_BUTTON);
    ObjectsDeleteAll(0, OBJ_LABEL);
}
